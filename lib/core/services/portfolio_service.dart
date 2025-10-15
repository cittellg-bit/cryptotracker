import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './crypto_api_service.dart';
import './logging_service.dart';
import './pl_persistence_service.dart';
import './supabase_service.dart';
import './transaction_service.dart';

// NEW: Import enhanced P&L service

/// Simplified and reliable portfolio calculation system with enhanced P&L persistence and 429 error prevention
class PortfolioService {
  static PortfolioService? _instance;
  static PortfolioService get instance =>
      _instance ??= PortfolioService._internal();

  PortfolioService._internal();

  factory PortfolioService() => instance;

  // ENHANCED: Additional storage keys for comprehensive P&L persistence
  static const String _transactionsKey = 'local_transactions';
  static const String _portfolioSummaryKey = 'portfolio_summary_cache_v4';
  static const String _pricesCacheKey = 'crypto_prices_cache_v4';
  static const String _plHistoryKey = 'pl_historical_data_v4';
  static const String _plChartDataKey = 'pl_chart_data_cache_v4';
  static const String _lastApiRefreshKey =
      'last_api_refresh_v4'; // NEW: Track API refresh timing

  final StreamController<List<Map<String, dynamic>>> _portfolioController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> get portfolioStream =>
      _portfolioController.stream;

  // Enhanced cache management with P&L persistence
  Map<String, dynamic>? _summaryCache;
  List<Map<String, dynamic>>? _holdingsCache;
  Map<String, double>? _pricesCache;
  Map<String, dynamic>? _plHistoryCache; // NEW: P&L history cache
  List<Map<String, dynamic>>? _plChartDataCache; // NEW: Chart data cache

  bool _isInitialized = false;
  bool _isCalculating = false;

  final LoggingService _loggingService = LoggingService.instance;
  final CryptoApiService _cryptoApiService = CryptoApiService.instance;
  final PLPersistenceService _plPersistenceService =
      PLPersistenceService.instance; // NEW: Enhanced P&L service

  // NEW: Enhanced rate limiting and refresh tracking
  DateTime? _lastApiRefresh;
  static const Duration _apiRefreshCooldown = Duration(
    hours: 8,
  ); // 8-hour cooldown to prevent 429 errors
  bool _isApiRefreshAllowed = true;

  /// PUBLIC GETTER: Check if the portfolio service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if Supabase is available
  bool get _isSupabaseAvailable {
    try {
      return SupabaseService.instance.isInitialized;
    } catch (e) {
      return false;
    }
  }

  /// Get Supabase client
  dynamic get _client => SupabaseService.instance.client;

  /// ENHANCED: Check if API refresh is allowed (rate limiting protection)
  bool _canMakeApiRefresh() {
    if (_lastApiRefresh == null) return true;

    final timeSinceLastRefresh = DateTime.now().difference(_lastApiRefresh!);
    return timeSinceLastRefresh >= _apiRefreshCooldown;
  }

  /// ENHANCED: Mark API refresh as completed
  Future<void> _markApiRefreshCompleted() async {
    _lastApiRefresh = DateTime.now();
    _isApiRefreshAllowed = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastApiRefreshKey,
      _lastApiRefresh!.toIso8601String(),
    );

    if (kDebugMode) {
      print('🕐 API refresh marked complete - next allowed in 8 hours');
    }
  }

  /// ENHANCED: Load API refresh timing on startup
  Future<void> _loadApiRefreshTiming() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRefreshStr = prefs.getString(_lastApiRefreshKey);

      if (lastRefreshStr != null) {
        _lastApiRefresh = DateTime.tryParse(lastRefreshStr);
        _isApiRefreshAllowed = _canMakeApiRefresh();

        if (kDebugMode) {
          final timeSince =
              _lastApiRefresh != null
                  ? DateTime.now().difference(_lastApiRefresh!).inHours
                  : 0;
          print('📅 Last API refresh: ${timeSince}h ago');
          print(
            '   Next refresh allowed: ${_isApiRefreshAllowed ? 'NOW' : 'in ${8 - timeSince}h'}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to load API refresh timing: $e');
      }
    }
  }

  /// ENHANCED: Comprehensive P&L data persistence with atomic writes and validation
  Future<void> _persistCacheToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Enhanced summary persistence with P&L integrity validation
      if (_summaryCache != null) {
        final totalValue =
            (_summaryCache!['totalValue'] as num?)?.toDouble() ?? 0.0;
        final totalInvested =
            (_summaryCache!['totalInvested'] as num?)?.toDouble() ?? 0.0;
        final explicitProfitLoss = totalValue - totalInvested;
        final percentageChange =
            totalInvested != 0.0
                ? (explicitProfitLoss / totalInvested.abs()) * 100
                : 0.0;
        final transactionCount =
            (_summaryCache!['totalHoldings'] as num?)?.toInt() ?? 0;

        // ENHANCED: Use atomic P&L persistence service with 429 error context
        final persistenceSuccess = await _plPersistenceService.savePLSnapshot(
          totalValue: totalValue,
          totalInvested: totalInvested,
          profitLoss: explicitProfitLoss,
          percentageChange: percentageChange,
          transactionCount: transactionCount,
          additionalData: {
            'portfolioMethod': _summaryCache!['calculationMethod'] ?? 'unknown',
            'lastUpdated': _summaryCache!['lastUpdated'],
            'calculatedAt': _summaryCache!['calculatedAt'],
            'apiRefreshAllowed': _isApiRefreshAllowed,
            'lastApiRefresh': _lastApiRefresh?.toIso8601String(),
            'rateLimitProtection': 'active',
          },
          source: 'portfolio_service_enhanced_v4',
        );

        if (!persistenceSuccess) {
          // Enhanced fallback with 429 error protection
          final enhancedSummary = {
            ..._summaryCache!,
            'profitLoss': explicitProfitLoss,
            'cachedAt': DateTime.now().toIso8601String(),
            'persistenceVersion': '4.0',
            'plIntegrityCheck': true,
            'lastCalculationTimestamp': DateTime.now().millisecondsSinceEpoch,
            'apiRateLimitProtection': true,
          };

          final summaryJson = jsonEncode(enhancedSummary);
          await prefs.setString(_portfolioSummaryKey, summaryJson);
        }

        // Validate P&L consistency after persistence
        await _plPersistenceService.validatePLConsistency(
          totalValue: totalValue,
          totalInvested: totalInvested,
          profitLoss: explicitProfitLoss,
        );

        if (kDebugMode) {
          print('💾 Enhanced P&L persistence completed with validation');
          print('   💰 P&L: \$${explicitProfitLoss.toStringAsFixed(2)}');
          print('   📊 Value: \$${totalValue.toStringAsFixed(2)}');
          print('   💵 Invested: \$${totalInvested.toStringAsFixed(2)}');
          print('   🔄 Percentage: ${percentageChange.toStringAsFixed(2)}%');
          print('   🔒 Atomic: $persistenceSuccess');
        }
      }

      // ENHANCED: Price cache persistence with 429 error protection
      if (_pricesCache != null) {
        final pricesJson = jsonEncode({
          ..._pricesCache!,
          'cachedAt': DateTime.now().toIso8601String(),
          'validUntil':
              DateTime.now()
                  .add(const Duration(hours: 8))
                  .toIso8601String(), // Extended validity
          'apiCallsProtected': true,
          'rateLimitSafe': true,
        });
        await prefs.setString(_pricesCacheKey, pricesJson);
      }

      // NEW: Persist chart data for immediate restoration
      if (_plChartDataCache != null && _plChartDataCache!.isNotEmpty) {
        final chartDataJson = jsonEncode({
          'chartData': _plChartDataCache!,
          'cachedAt': DateTime.now().toIso8601String(),
          'generatedFor': {
            'totalValue':
                (_summaryCache?['totalValue'] as num?)?.toDouble() ?? 0.0,
            'profitLoss':
                (_summaryCache?['profitLoss'] as num?)?.toDouble() ?? 0.0,
          },
        });
        await prefs.setString(_plChartDataKey, chartDataJson);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Enhanced persistence failed: $e');
      }
      await _loggingService.logError(
        category: LogCategory.database,
        message: 'Enhanced portfolio persistence failed',
        details: {'error': e.toString()},
        functionName: '_persistCacheToStorage',
        errorStack: e.toString(),
      );
    }
  }

  /// NEW: Persist P&L historical data for chart persistence
  Future<void> _persistPLHistoricalData(Map<String, dynamic> plRecord) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load existing P&L history
      final existingHistoryJson = prefs.getString(_plHistoryKey) ?? '[]';
      final List<dynamic> existingHistory = jsonDecode(existingHistoryJson);

      // Add new record
      existingHistory.add(plRecord);

      // Keep only last 100 records for performance (covers ~3 months of daily updates)
      if (existingHistory.length > 100) {
        existingHistory.removeRange(0, existingHistory.length - 100);
      }

      // Sort by timestamp to maintain chronological order
      existingHistory.sort(
        (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
      );

      // Persist updated history
      await prefs.setString(_plHistoryKey, jsonEncode(existingHistory));

      if (kDebugMode) {
        print(
          '📈 P&L historical data updated: ${existingHistory.length} records',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ P&L history persistence failed: $e');
      }
    }
  }

  /// ENHANCED: Load cached data with immediate P&L restoration and API refresh timing
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load API refresh timing first
      await _loadApiRefreshTiming();

      // PRIORITY: Load from enhanced P&L service first
      final plSnapshot = await _plPersistenceService.loadPLSnapshot();

      if (plSnapshot != null) {
        // Create summary from P&L service data (highest priority)
        _summaryCache = {
          'totalValue': plSnapshot['totalValue'],
          'totalInvested': plSnapshot['totalInvested'],
          'profitLoss': plSnapshot['profitLoss'],
          'percentageChange': plSnapshot['percentageChange'],
          'totalHoldings': plSnapshot['transactionCount'] ?? 0,
          'lastUpdated': plSnapshot['dateString'],
          'calculatedAt': plSnapshot['timestamp'],
          'calculationMethod': 'enhanced_pl_service_v4',
          'plIntegrityCheck': true,
          'loadedFrom': 'pl_persistence_service',
          'rateLimitProtected': true, // NEW: Mark as rate limit protected
        };

        if (kDebugMode) {
          final plValue = (plSnapshot['profitLoss'] as num).toDouble();
          print(
            '🚀 P&L loaded from enhanced service with 429 protection: \$${plValue.toStringAsFixed(2)}',
          );
          print(
            '   📊 Total Value: \$${(plSnapshot['totalValue'] as num).toStringAsFixed(2)}',
          );
          print(
            '   💵 Total Invested: \$${(plSnapshot['totalInvested'] as num).toStringAsFixed(2)}',
          );
          print('   🛡️ Rate limit protection: ACTIVE');
        }
      } else {
        // Fallback to legacy summary loading with enhanced validation
        final summaryJson = prefs.getString(_portfolioSummaryKey);
        if (summaryJson != null) {
          try {
            final loadedSummary = Map<String, dynamic>.from(
              jsonDecode(summaryJson),
            );

            // Enhanced P&L validation and restoration
            final totalValue =
                (loadedSummary['totalValue'] as num?)?.toDouble() ?? 0.0;
            final totalInvested =
                (loadedSummary['totalInvested'] as num?)?.toDouble() ?? 0.0;
            final cachedProfitLoss =
                (loadedSummary['profitLoss'] as num?)?.toDouble();
            final calculatedProfitLoss = totalValue - totalInvested;

            // Ensure P&L data integrity with auto-correction
            if (cachedProfitLoss == null ||
                (cachedProfitLoss - calculatedProfitLoss).abs() > 0.01) {
              loadedSummary['profitLoss'] = calculatedProfitLoss;
              loadedSummary['percentageChange'] =
                  totalInvested != 0.0
                      ? (calculatedProfitLoss / totalInvested.abs()) * 100
                      : 0.0;

              if (kDebugMode) {
                print(
                  '🔧 Legacy P&L data auto-corrected with 429 protection: \$${calculatedProfitLoss.toStringAsFixed(2)}',
                );
              }
            }

            loadedSummary['plIntegrityCheck'] = true;
            loadedSummary['loadedFrom'] = 'legacy_fallback_v4';
            loadedSummary['rateLimitProtected'] = true;
            _summaryCache = loadedSummary;

            // IMPORTANT: Immediately save to enhanced service
            if (totalValue > 0 || totalInvested > 0) {
              await _plPersistenceService.savePLSnapshot(
                totalValue: totalValue,
                totalInvested: totalInvested,
                profitLoss: calculatedProfitLoss,
                percentageChange:
                    totalInvested != 0.0
                        ? (calculatedProfitLoss / totalInvested.abs()) * 100
                        : 0.0,
                transactionCount:
                    (loadedSummary['totalHoldings'] as num?)?.toInt() ?? 0,
                source: 'legacy_migration',
              );

              if (kDebugMode) {
                print('📤 Legacy data migrated to enhanced P&L service');
              }
            }
          } catch (e) {
            await prefs.remove(_portfolioSummaryKey);
            if (kDebugMode) {
              print('⚠️ Corrupted legacy cache cleared');
            }
          }
        }
      }

      // Load enhanced price cache with validation
      final pricesJson = prefs.getString(_pricesCacheKey);
      if (pricesJson != null) {
        try {
          final pricesData = Map<String, dynamic>.from(jsonDecode(pricesJson));

          // Check if price cache is still valid (extended during rate limits)
          final validUntilStr = pricesData['validUntil'] as String?;
          final isValid =
              validUntilStr != null &&
              DateTime.parse(validUntilStr).isAfter(DateTime.now());

          // Extended validity check during rate limit protection
          final cachedAtStr = pricesData['cachedAt'] as String?;
          final isRecentEnough =
              cachedAtStr != null &&
              DateTime.now().difference(DateTime.parse(cachedAtStr)) <
                  Duration(
                    hours: _isApiRefreshAllowed ? 4 : 12,
                  ); // Extended during rate limits

          if (isValid && isRecentEnough) {
            _pricesCache = {};
            pricesData.forEach((key, value) {
              if (value is num &&
                  key != 'cachedAt' &&
                  key != 'validUntil' &&
                  key != 'apiCallsProtected' &&
                  key != 'rateLimitSafe') {
                _pricesCache![key] = value.toDouble();
              }
            });

            if (kDebugMode) {
              final rateLimited =
                  !_isApiRefreshAllowed
                      ? ' (RATE LIMITED - using extended cache)'
                      : '';
              print(
                '💰 Valid price cache loaded: ${_pricesCache!.length} prices$rateLimited',
              );
            }
          } else {
            if (_isApiRefreshAllowed) {
              await prefs.remove(_pricesCacheKey);
              if (kDebugMode) {
                print(
                  '⏰ Price cache expired and refresh allowed - clearing cache',
                );
              }
            } else {
              if (kDebugMode) {
                print(
                  '🚫 Price cache expired but refresh not allowed - keeping stale cache',
                );
              }
              // Keep expired cache during rate limit period
              _pricesCache = {};
              pricesData.forEach((key, value) {
                if (value is num &&
                    ![
                      'cachedAt',
                      'validUntil',
                      'apiCallsProtected',
                      'rateLimitSafe',
                    ].contains(key)) {
                  _pricesCache![key] = value.toDouble();
                }
              });
            }
          }
        } catch (e) {
          await prefs.remove(_pricesCacheKey);
          if (kDebugMode) {
            print('⚠️ Corrupted price cache cleared');
          }
        }
      }

      // NEW: Load P&L historical data
      await _loadPLHistoricalData();

      // NEW: Load chart data cache
      await _loadChartDataCache();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Enhanced cache loading with 429 protection failed: $e');
      }
    }
  }

  /// NEW: Restore P&L from historical data
  Future<Map<String, dynamic>?> _restorePLFromHistory() async {
    try {
      if (_plHistoryCache == null || _plHistoryCache!.isEmpty) return null;

      final historyList = _plHistoryCache!['history'] as List<dynamic>?;
      if (historyList == null || historyList.isEmpty) return null;

      // Get the most recent record
      final latestRecord = historyList.last as Map<String, dynamic>;

      return {
        'profitLoss': latestRecord['profitLoss'],
        'totalValue': latestRecord['totalValue'],
        'totalInvested': latestRecord['totalInvested'],
        'percentageChange': latestRecord['percentageChange'],
      };
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ P&L history restoration failed: $e');
      }
      return null;
    }
  }

  /// NEW: Load P&L historical data
  Future<void> _loadPLHistoricalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_plHistoryKey);

      if (historyJson != null) {
        final historyData = jsonDecode(historyJson) as List<dynamic>;
        _plHistoryCache = {
          'history': historyData,
          'loadedAt': DateTime.now().toIso8601String(),
          'recordCount': historyData.length,
        };

        if (kDebugMode) {
          print('📊 P&L history loaded: ${historyData.length} records');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ P&L history loading failed: $e');
      }
    }
  }

  /// NEW: Load chart data cache
  Future<void> _loadChartDataCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chartDataJson = prefs.getString(_plChartDataKey);

      if (chartDataJson != null) {
        final chartCache = Map<String, dynamic>.from(jsonDecode(chartDataJson));
        _plChartDataCache = List<Map<String, dynamic>>.from(
          chartCache['chartData'] ?? [],
        );

        if (kDebugMode) {
          print(
            '📈 Chart data cache loaded: ${_plChartDataCache!.length} points',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Chart data cache loading failed: $e');
      }
    }
  }

  /// FIXED: Load transactions from the same storage as TransactionService
  Future<List<Map<String, dynamic>>> _loadTransactionsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = prefs.getString(_transactionsKey) ?? '[]';
      final List<dynamic> transactionsList = jsonDecode(transactionsJson);

      if (kDebugMode) {
        print('📄 Loaded ${transactionsList.length} transactions from storage');
      }

      return transactionsList.map((t) => Map<String, dynamic>.from(t)).toList();
    } catch (e) {
      await _loggingService.logError(
        category: LogCategory.database,
        message: 'Error loading transactions from storage',
        details: {'error': e.toString()},
        functionName: '_loadTransactionsFromStorage',
        errorStack: e.toString(),
      );
      return [];
    }
  }

  /// Calculate portfolio with clean, straightforward logic
  Future<void> _calculatePortfolio() async {
    if (_isCalculating) return;
    _isCalculating = true;

    try {
      if (kDebugMode) {
        print(
          '🧮 Starting enhanced portfolio calculation with P&L persistence...',
        );
      }

      // Load transactions
      final transactions = await _loadTransactionsFromStorage();

      if (transactions.isEmpty) {
        _summaryCache = _createEmptySummary();
        _holdingsCache = [];
        await _persistCacheToStorage();
        return;
      }

      // Build holdings from transactions
      final holdings = await _buildHoldingsFromTransactions(transactions);

      // Calculate summary with enhanced validation
      final summary = _calculateSummaryFromHoldings(holdings);

      // CRITICAL: Validate P&L consistency before saving
      final totalValue = (summary['totalValue'] as num?)?.toDouble() ?? 0.0;
      final totalInvested =
          (summary['totalInvested'] as num?)?.toDouble() ?? 0.0;
      final profitLoss = (summary['profitLoss'] as num?)?.toDouble() ?? 0.0;

      final validationResult = await _plPersistenceService
          .validatePLConsistency(
            totalValue: totalValue,
            totalInvested: totalInvested,
            profitLoss: profitLoss,
          );

      if (validationResult['isValid'] != true) {
        // Auto-correct the P&L if validation failed
        final correctedPL = totalValue - totalInvested;
        summary['profitLoss'] = correctedPL;
        summary['percentageChange'] =
            totalInvested != 0.0
                ? (correctedPL / totalInvested.abs()) * 100
                : 0.0;

        if (kDebugMode) {
          print(
            '🔧 P&L auto-corrected during calculation: \$${correctedPL.toStringAsFixed(2)}',
          );
        }
      }

      // Update caches
      _holdingsCache = holdings;
      _summaryCache = summary;

      // ENHANCED: Persist with comprehensive validation
      await _persistCacheToStorage();

      // Notify listeners
      _portfolioController.add(holdings);

      if (kDebugMode) {
        final finalPL =
            (_summaryCache!['profitLoss'] as num?)?.toDouble() ?? 0.0;
        print(
          '✅ Enhanced portfolio calculation completed with P&L persistence:',
        );
        print('   💰 P&L: \$${finalPL.toStringAsFixed(2)}');
        print('   📊 Holdings: ${holdings.length}');
        print('   🔒 Validation: ${validationResult['isValid']}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Enhanced portfolio calculation failed: $e');
      }

      // Fallback to empty state with diagnostic logging
      _summaryCache ??= _createEmptySummary();
      _holdingsCache ??= [];

      await _plPersistenceService.savePLSnapshot(
        totalValue: 0.0,
        totalInvested: 0.0,
        profitLoss: 0.0,
        percentageChange: 0.0,
        transactionCount: 0,
        source: 'calculation_error_fallback',
        additionalData: {'error': e.toString()},
      );
    } finally {
      _isCalculating = false;
    }
  }

  /// Build holdings from transactions with proper price handling
  Future<List<Map<String, dynamic>>> _buildHoldingsFromTransactions(
    List<Map<String, dynamic>> transactions,
  ) async {
    // Group transactions by crypto_id
    final transactionsByCrypto = <String, List<Map<String, dynamic>>>{};
    for (final transaction in transactions) {
      final cryptoId = transaction['crypto_id'] as String;
      transactionsByCrypto.putIfAbsent(cryptoId, () => []).add(transaction);
    }

    final holdings = <Map<String, dynamic>>[];

    for (final entry in transactionsByCrypto.entries) {
      final cryptoId = entry.key;
      final cryptoTransactions = entry.value;

      if (cryptoTransactions.isEmpty) continue;

      // Extract crypto metadata from first transaction
      final firstTransaction = cryptoTransactions.first;
      final cryptoSymbol = firstTransaction['crypto_symbol'] as String;
      final cryptoName = firstTransaction['crypto_name'] as String;
      final cryptoIconUrl = firstTransaction['crypto_icon_url'] as String;

      // FIXED: Calculate holdings totals with proper accounting for buy/sell
      double totalAmount = 0.0;
      double totalInvested = 0.0;
      String latestExchange = 'Unknown';

      for (final transaction in cryptoTransactions) {
        final transactionType = transaction['transaction_type'] as String;
        final amount = (transaction['amount'] as num).toDouble();
        final pricePerUnit = (transaction['price_per_unit'] as num).toDouble();
        final exchange = transaction['exchange'] as String? ?? 'Unknown';

        if (transactionType.toLowerCase() == 'buy') {
          totalAmount += amount;
          totalInvested += (amount * pricePerUnit);
        } else if (transactionType.toLowerCase() == 'sell') {
          totalAmount -= amount;
          // For sells, reduce invested amount proportionally
          if (totalAmount > 0) {
            final sellRatio = amount / (totalAmount + amount);
            totalInvested -= (totalInvested * sellRatio);
          }
        }

        latestExchange = exchange;

        if (kDebugMode) {
          print(
            '📝 Transaction: ${transactionType.toUpperCase()} ${amount.toStringAsFixed(6)} $cryptoSymbol @ \$${pricePerUnit.toStringAsFixed(6)}',
          );
        }
      }

      // Skip if no holdings remaining
      if (totalAmount <= 0) {
        if (kDebugMode) {
          print('⏭️ Skipping $cryptoSymbol - no holdings remaining');
        }
        continue;
      }

      // Get current price with fallbacks
      double currentPrice = await _getCurrentPriceWithFallbacks(
        cryptoId,
        cryptoSymbol,
        totalAmount,
        totalInvested,
      );

      final averagePrice =
          totalAmount != 0.0 ? (totalInvested / totalAmount).abs() : 0.0;

      // FIXED: Ensure totalInvested is stored correctly
      holdings.add({
        'id': cryptoId,
        'crypto_id': cryptoId,
        'symbol': cryptoSymbol,
        'name': cryptoName,
        'icon': cryptoIconUrl,
        'currentPrice': currentPrice,
        'holdings': totalAmount,
        'averagePrice': averagePrice,
        'priceChange24h': 0.0,
        'total_invested':
            totalInvested
                .abs(), // FIXED: Store absolute value to prevent negative invested amounts
        'transaction_count': cryptoTransactions.length,
        'transactions': cryptoTransactions,
        'exchange': latestExchange,
        'calculatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (kDebugMode) {
        final currentValue = totalAmount * currentPrice;
        final profitLoss = currentValue - totalInvested.abs();
        print(
          '💰 ${cryptoSymbol}: ${totalAmount.toStringAsFixed(6)} @ \$${currentPrice.toStringAsFixed(6)} = \$${currentValue.toStringAsFixed(2)}',
        );
        print(
          '   📊 Invested: \$${totalInvested.abs().toStringAsFixed(2)}, P&L: \$${profitLoss.toStringAsFixed(2)}',
        );
      }
    }

    return holdings;
  }

  /// ENHANCED: Get current price with 429 error protection and extended caching
  Future<double> _getCurrentPriceWithFallbacks(
    String cryptoId,
    String symbol,
    double totalAmount,
    double totalInvested,
  ) async {
    // Priority 1: Try cached price (extended validity during rate limits)
    if (_pricesCache != null && _pricesCache!.containsKey(cryptoId)) {
      final cachedPrice = _pricesCache![cryptoId]!;
      if (cachedPrice > 0) {
        if (kDebugMode) {
          final rateLimited =
              !_isApiRefreshAllowed
                  ? ' (using extended cache due to rate limits)'
                  : '';
          print(
            '💵 Using cached price for $symbol: \$${cachedPrice.toStringAsFixed(6)}$rateLimited',
          );
        }
        return cachedPrice;
      }
    }

    // Priority 2: Check if API calls are allowed (429 error prevention)
    if (!_isApiRefreshAllowed) {
      if (kDebugMode) {
        print(
          '🚫 API refresh not allowed for $symbol - using fallback price calculation',
        );
      }

      // Use average purchase price as fallback during rate limits
      if (totalAmount > 0 && totalInvested > 0) {
        final averagePrice = (totalInvested / totalAmount).abs();
        if (averagePrice > 0) {
          if (kDebugMode) {
            print(
              '📊 Using average purchase price for $symbol: \$${averagePrice.toStringAsFixed(6)}',
            );
          }
          return averagePrice;
        }
      }
      return 1.0; // Emergency fallback
    }

    // Priority 3: Try fresh API call (with 429 error handling)
    try {
      final freshPrice = await _cryptoApiService.getCurrentPrice(cryptoId);
      if (freshPrice != null && freshPrice > 0) {
        _pricesCache ??= {};
        _pricesCache![cryptoId] = freshPrice;
        if (kDebugMode) {
          print(
            '🔄 Fetched fresh price for $symbol: \$${freshPrice.toStringAsFixed(6)}',
          );
        }
        return freshPrice;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ API price fetch failed for $symbol (possible 429): $e');
      }

      // Mark API refresh as completed to trigger cooldown on 429-like errors
      if (e.toString().contains('429') ||
          e.toString().contains('rate') ||
          e.toString().contains('limit')) {
        await _markApiRefreshCompleted();
        await _loggingService.logError(
          category: LogCategory.database,
          message:
              '429 error detected during price fetch - activating cooldown',
          details: {
            'symbol': symbol,
            'cryptoId': cryptoId,
            'error': e.toString(),
          },
          functionName: '_getCurrentPriceWithFallbacks',
          errorStack: e.toString(),
        );
      }
    }

    // Priority 4: Try alternative API method
    try {
      final cryptoData = await _cryptoApiService.getCryptocurrencyDetails(
        cryptoId,
      );
      if (cryptoData != null) {
        final apiPrice =
            (cryptoData['current_price'] as num?)?.toDouble() ?? 0.0;
        if (apiPrice > 0) {
          _pricesCache ??= {};
          _pricesCache![cryptoId] = apiPrice;
          if (kDebugMode) {
            print(
              '🔄 Got price from details API for $symbol: \$${apiPrice.toStringAsFixed(6)}',
            );
          }
          return apiPrice;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Alternative API failed for $symbol: $e');
      }
    }

    // Priority 5: Use average purchase price as reliable fallback
    if (totalAmount > 0 && totalInvested > 0) {
      final averagePrice = (totalInvested / totalAmount).abs();
      if (averagePrice > 0) {
        if (kDebugMode) {
          print(
            '📊 Using average purchase price fallback for $symbol: \$${averagePrice.toStringAsFixed(6)}',
          );
        }
        return averagePrice;
      }
    }

    // Final emergency fallback
    if (kDebugMode) {
      print('⚠️ All price sources failed for $symbol, using emergency value');
    }
    return 1.0;
  }

  /// FIXED: Enhanced summary calculation to ensure P&L persistence
  Map<String, dynamic> _calculateSummaryFromHoldings(
    List<Map<String, dynamic>> holdings,
  ) {
    double totalValue = 0.0;
    double totalInvested = 0.0;
    int validHoldings = 0;

    if (kDebugMode) {
      print(
        '🧮 Enhanced summary calculation from ${holdings.length} holdings...',
      );
    }

    for (final holding in holdings) {
      final currentPrice = (holding['currentPrice'] as num?)?.toDouble() ?? 0.0;
      final amount = (holding['holdings'] as num?)?.toDouble() ?? 0.0;
      final invested = (holding['total_invested'] as num?)?.toDouble() ?? 0.0;

      if (kDebugMode) {
        print(
          '📊 ${holding['symbol']}: price=\$${currentPrice.toStringAsFixed(6)}, amount=${amount.toStringAsFixed(6)}, invested=\$${invested.toStringAsFixed(2)}',
        );
      }

      if (currentPrice > 0 && amount > 0) {
        final currentValue = currentPrice * amount;
        totalValue += currentValue;
        totalInvested += invested.abs();
        validHoldings++;

        if (kDebugMode) {
          print('   💰 Current value: \$${currentValue.toStringAsFixed(2)}');
        }
      } else if (invested != 0.0) {
        totalInvested += invested.abs();
      }
    }

    // CRITICAL: Enhanced P&L calculation with validation
    final profitLoss = totalValue - totalInvested;
    final profitLossPercentage =
        totalInvested != 0.0 ? (profitLoss / totalInvested.abs()) * 100 : 0.0;

    if (kDebugMode) {
      print('📈 Enhanced summary calculation:');
      print('   Total Value: \$${totalValue.toStringAsFixed(2)}');
      print('   Total Invested: \$${totalInvested.toStringAsFixed(2)}');
      print('   Profit/Loss: \$${profitLoss.toStringAsFixed(2)}');
      print('   P&L Percentage: ${profitLossPercentage.toStringAsFixed(2)}%');
    }

    return {
      'totalValue': totalValue,
      'totalInvested': totalInvested,
      'percentageChange': profitLossPercentage,
      'profitLoss': profitLoss, // CRITICAL: Always include explicit P&L
      'totalHoldings': validHoldings,
      'lastUpdated': DateTime.now().toIso8601String(),
      'calculatedAt': DateTime.now().millisecondsSinceEpoch,
      'calculationMethod': 'enhanced_persistent_v2',
    };
  }

  /// Create empty summary
  Map<String, dynamic> _createEmptySummary() {
    return {
      'totalValue': 0.0,
      'totalInvested': 0.0,
      'percentageChange': 0.0,
      'profitLoss': 0.0,
      'totalHoldings': 0,
      'lastUpdated': DateTime.now().toIso8601String(),
      'calculatedAt': DateTime.now().millisecondsSinceEpoch,
      'calculationMethod': 'empty_v1',
    };
  }

  /// Refresh portfolio data with intelligent 429 error prevention
  Future<void> refreshPortfolioData() async {
    try {
      if (kDebugMode) {
        print('🔄 Enhanced portfolio refresh with 429 error prevention...');
        print('   API refresh allowed: $_isApiRefreshAllowed');

        if (!_isApiRefreshAllowed && _lastApiRefresh != null) {
          final hoursUntilNext =
              8 - DateTime.now().difference(_lastApiRefresh!).inHours;
          print('   Next API refresh in: ${hoursUntilNext}h');
        }
      }

      // Store current P&L before refresh to prevent zero resets
      final currentPL =
          _summaryCache != null
              ? (_summaryCache!['profitLoss'] as num?)?.toDouble()
              : null;
      final currentTotalValue =
          _summaryCache != null
              ? (_summaryCache!['totalValue'] as num?)?.toDouble()
              : null;

      // SMART REFRESH: Only clear price cache if API refresh is allowed
      if (_isApiRefreshAllowed) {
        // Clear caches to force fresh calculation with new API data
        _summaryCache = null;
        _holdingsCache = null;
        _pricesCache = null;

        if (kDebugMode) {
          print('✅ API refresh allowed - clearing caches for fresh data');
        }
      } else {
        // Keep existing data during rate limit period
        if (kDebugMode) {
          print(
            '🚫 API refresh not allowed - using cached data with recalculation',
          );
        }
      }

      // Recalculate with available data
      await _calculatePortfolio();

      // Mark API refresh as completed if we made API calls
      if (_isApiRefreshAllowed) {
        await _markApiRefreshCompleted();
      }

      // CRITICAL: Zero-reset prevention check with enhanced logic
      if (_summaryCache != null &&
          currentPL != null &&
          currentTotalValue != null) {
        final newPL = (_summaryCache!['profitLoss'] as num?)?.toDouble() ?? 0.0;
        final newTotalValue =
            (_summaryCache!['totalValue'] as num?)?.toDouble() ?? 0.0;

        // Enhanced zero-reset prevention
        if (newPL == 0.0 &&
            currentPL != 0.0 &&
            currentTotalValue > 0.0 &&
            newTotalValue == 0.0) {
          // Load from enhanced P&L service as backup
          final plSnapshot = await _plPersistenceService.loadPLSnapshot();
          if (plSnapshot != null) {
            _summaryCache!['profitLoss'] = plSnapshot['profitLoss'];
            _summaryCache!['totalValue'] = plSnapshot['totalValue'];
            _summaryCache!['totalInvested'] = plSnapshot['totalInvested'];
            _summaryCache!['percentageChange'] = plSnapshot['percentageChange'];

            if (kDebugMode) {
              print(
                '🛡️ Zero-reset prevented during refresh with 429 protection',
              );
              print('   Previous P&L: \$${currentPL.toStringAsFixed(2)}');
              print(
                '   Restored P&L: \$${(plSnapshot['profitLoss'] as num).toStringAsFixed(2)}',
              );
              print('   Rate limit protection: ACTIVE');
            }
          }
        }
      }

      if (kDebugMode) {
        final totalValue =
            (_summaryCache?['totalValue'] as num?)?.toDouble() ?? 0.0;
        print(
          '✅ Enhanced portfolio refresh completed with 429 protection: \$${totalValue.toStringAsFixed(2)}',
        );
        print('   🛡️ Zero-reset prevention: ACTIVE');
        print('   🚫 429 error protection: ACTIVE');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Enhanced portfolio refresh with 429 protection failed: $e');
      }

      // Handle potential 429 errors
      if (e.toString().contains('429') ||
          e.toString().contains('rate') ||
          e.toString().contains('limit')) {
        await _markApiRefreshCompleted();
        await _loggingService.logError(
          category: LogCategory.database,
          message: '429 error during portfolio refresh - cooldown activated',
          details: {'error': e.toString()},
          functionName: 'refreshPortfolioData',
          errorStack: e.toString(),
        );
      }
    }
  }

  /// NEW: Force manual API refresh (user-initiated dashboard pull)
  Future<void> forceManualRefresh() async {
    if (kDebugMode) {
      print('👆 Manual refresh requested by user');
    }

    // Allow manual refresh even during cooldown (but with extended cooldown after)
    final wasApiRefreshAllowed = _isApiRefreshAllowed;
    _isApiRefreshAllowed = true;

    try {
      await refreshPortfolioData();

      // Extend cooldown after manual refresh to prevent abuse
      if (!wasApiRefreshAllowed) {
        _lastApiRefresh = DateTime.now().add(
          Duration(hours: 2),
        ); // Add 2 hours penalty
        await _markApiRefreshCompleted();

        if (kDebugMode) {
          print(
            '⏰ Manual refresh completed with extended cooldown (rate limit protection)',
          );
        }
      }
    } catch (e) {
      _isApiRefreshAllowed =
          wasApiRefreshAllowed; // Restore previous state on error
      rethrow;
    }
  }

  /// NEW: Check if manual refresh is recommended
  bool shouldRecommendManualRefresh() {
    if (_summaryCache == null) return true;

    final lastUpdated = _summaryCache!['lastUpdated'] as String?;
    if (lastUpdated == null) return true;

    final lastUpdateTime = DateTime.tryParse(lastUpdated);
    if (lastUpdateTime == null) return true;

    final hoursSinceUpdate = DateTime.now().difference(lastUpdateTime).inHours;
    return hoursSinceUpdate >= 8; // Recommend refresh if data is 8+ hours old
  }

  /// NEW: Get enhanced diagnostic information including 429 error protection status
  Future<Map<String, dynamic>> getEnhancedDiagnosticsWithRateLimit() async {
    try {
      final plDiagnostics = await _plPersistenceService.getDiagnosticInfo();
      final transactions = await _loadTransactionsFromStorage();
      final apiStatus = await _cryptoApiService.getApiStatus();

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'portfolioService': {
          'isInitialized': _isInitialized,
          'isCalculating': _isCalculating,
          'hasSummaryCache': _summaryCache != null,
          'hasHoldingsCache': _holdingsCache != null,
          'hasPricesCache': _pricesCache != null,
          'transactionCount': transactions.length,
          'currentPL': _summaryCache?['profitLoss'],
          'rateLimitProtection': {
            'isApiRefreshAllowed': _isApiRefreshAllowed,
            'lastApiRefresh': _lastApiRefresh?.toIso8601String(),
            'cooldownHours': _apiRefreshCooldown.inHours,
            'hoursUntilNextRefresh':
                _lastApiRefresh != null
                    ? (_apiRefreshCooldown.inHours -
                            DateTime.now().difference(_lastApiRefresh!).inHours)
                        .clamp(0, 8)
                    : 0,
            'shouldRecommendManualRefresh': shouldRecommendManualRefresh(),
          },
        },
        'cryptoApiService': apiStatus,
        'plPersistenceService': plDiagnostics,
        'validation':
            _summaryCache != null
                ? await _plPersistenceService.validatePLConsistency(
                  totalValue:
                      (_summaryCache!['totalValue'] as num?)?.toDouble() ?? 0.0,
                  totalInvested:
                      (_summaryCache!['totalInvested'] as num?)?.toDouble() ??
                      0.0,
                  profitLoss:
                      (_summaryCache!['profitLoss'] as num?)?.toDouble() ?? 0.0,
                )
                : {'isValid': false, 'reason': 'no_summary_cache'},
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Clear all caches
  void clearCache() {
    _summaryCache = null;
    _holdingsCache = null;
    _pricesCache = null;
    _plHistoryCache = null;
    _plChartDataCache = null;

    if (kDebugMode) {
      print('🧹 Portfolio caches cleared');
    }
  }

  // ===== COMPATIBILITY METHODS =====

  /// Get portfolio holdings (compatibility)
  Future<List<Map<String, dynamic>>> getPortfolioHoldings() async {
    return await getPortfolioWithCurrentPrices();
  }

  /// Get portfolio summary (compatibility)
  Future<Map<String, dynamic>> getPortfolioSummary() async {
    return await getCachedPortfolioSummary();
  }

  /// Mobile-optimized portfolio calculation (compatibility)
  Future<Map<String, dynamic>> getPortfolioSummaryMobileOptimized() async {
    return await getCachedPortfolioSummary();
  }

  /// Refresh portfolio (compatibility)
  Future<bool> refreshPortfolio() async {
    try {
      await refreshPortfolioData();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete cryptocurrency from portfolio
  Future<void> deleteCryptocurrencyFromPortfolio(String cryptoId) async {
    try {
      await _deleteLocalTransactionsByCrypto(cryptoId);
      await refreshPortfolioData();

      if (kDebugMode) {
        print('✅ Deleted cryptocurrency $cryptoId from portfolio');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting cryptocurrency: $e');
      }
      rethrow;
    }
  }

  /// Delete local transactions for a specific crypto
  Future<void> _deleteLocalTransactionsByCrypto(String cryptoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingTransactionsJson =
          prefs.getString(_transactionsKey) ?? '[]';
      final List<dynamic> existingTransactions = jsonDecode(
        existingTransactionsJson,
      );

      existingTransactions.removeWhere((t) => t['crypto_id'] == cryptoId);
      await prefs.setString(_transactionsKey, jsonEncode(existingTransactions));

      await _loggingService.logInfo(
        category: LogCategory.database,
        message: 'Deleted local transactions for crypto',
        details: {'crypto_id': cryptoId},
        functionName: '_deleteLocalTransactionsByCrypto',
      );
    } catch (e) {
      await _loggingService.logError(
        category: LogCategory.database,
        message: 'Error deleting local transactions for crypto',
        details: {'crypto_id': cryptoId, 'error': e.toString()},
        functionName: '_deleteLocalTransactionsByCrypto',
        errorStack: e.toString(),
      );
    }
  }

  /// Get specific crypto holding details
  Future<Map<String, dynamic>?> getCryptoHolding(String cryptoId) async {
    try {
      final allHoldings = await getPortfolioWithCurrentPrices();
      return allHoldings.firstWhere(
        (holding) => holding['crypto_id'] == cryptoId,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if portfolio is empty
  Future<bool> isPortfolioEmpty() async {
    try {
      final holdings = await getPortfolioHoldings();
      return holdings.isEmpty;
    } catch (e) {
      return true;
    }
  }

  /// Export portfolio data
  Future<Map<String, dynamic>> exportPortfolioData() async {
    try {
      final holdings = await getPortfolioHoldings();
      final summary = await getPortfolioSummary();

      return {
        'export_date': DateTime.now().toIso8601String(),
        'user_id': 'local_user',
        'summary': summary,
        'holdings': holdings,
        'total_holdings': holdings.length,
        'storage_type': 'local_simplified',
      };
    } catch (e) {
      return {};
    }
  }

  /// Dispose resources
  void dispose() {
    _portfolioController.close();
  }

  // Legacy compatibility methods
  Future<void> refreshPortfolioSummary() async => await refreshPortfolioData();
  Future<void> refreshPortfolioCache() async => await refreshPortfolioData();
  Future<void> preloadCachedData() async => await initializeForAndroid();
  Future<Map<String, dynamic>> getCachedPortfolioSummaryImmediate() async =>
      await getCachedPortfolioSummary();

  /// ENHANCED: Initialize portfolio service with 429 error protection
  Future<void> initializeForAndroid() async {
    if (_isInitialized) return;

    try {
      if (kDebugMode) {
        print(
          '📱 STARTUP FIX: Enhanced portfolio initialization with data loading guarantee...',
        );
      }

      // Initialize crypto API service with rate limiting
      _cryptoApiService.initialize();

      // STARTUP FIX: Load cached data with integrity checks first
      await _loadCachedDataWithStartupFix();

      // CRITICAL: Validate P&L data immediately after loading
      if (_summaryCache != null) {
        final cachedProfitLoss =
            (_summaryCache!['profitLoss'] as num?)?.toDouble() ?? 0.0;
        final totalValue =
            (_summaryCache!['totalValue'] as num?)?.toDouble() ?? 0.0;
        final totalInvested =
            (_summaryCache!['totalInvested'] as num?)?.toDouble() ?? 0.0;

        // Ensure P&L is consistent with values
        final expectedPL = totalValue - totalInvested;
        if ((cachedProfitLoss - expectedPL).abs() > 0.01) {
          _summaryCache!['profitLoss'] = expectedPL;
          await _persistCacheToStorage();
          if (kDebugMode) {
            print(
              '🔧 P&L consistency enforced: \$${expectedPL.toStringAsFixed(2)}',
            );
          }
        }

        if (kDebugMode) {
          print(
            '✅ STARTUP FIX: P&L data validated and ready: \$${cachedProfitLoss.toStringAsFixed(2)}',
          );
          print('📊 Portfolio Value: \$${totalValue.toStringAsFixed(2)}');
          print('💵 Total Invested: \$${totalInvested.toStringAsFixed(2)}');
        }
      } else {
        if (kDebugMode) {
          print(
            '⚠️ STARTUP FIX: No cached P&L data found - checking transactions',
          );
        }

        // Check if we have transactions that need calculation
        final transactions = await _loadTransactionsFromStorage();
        if (transactions.isNotEmpty) {
          if (kDebugMode) {
            print(
              '🔄 STARTUP FIX: Found ${transactions.length} transactions - calculating portfolio',
            );
          }

          // Force immediate calculation with existing cached prices
          await _calculatePortfolioForStartup();
        }
      }

      _isInitialized = true;

      if (kDebugMode) {
        print(
          '✅ STARTUP FIX: Portfolio service initialized with guaranteed data availability',
        );
        print('   🚫 API rate limiting: ACTIVE');
        print('   🛡️ Zero-reset prevention: ACTIVE');
        print('   📊 P&L persistence: ENHANCED');
        print('   🚀 Startup optimization: ENABLED');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ STARTUP FIX: Portfolio initialization failed: $e');
      }
      _isInitialized = true; // Continue with partial initialization
    }
  }

  /// STARTUP FIX: Enhanced cached data loading with startup optimization
  Future<void> _loadCachedDataWithStartupFix() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load API refresh timing first
      await _loadApiRefreshTiming();

      // STARTUP FIX: PRIORITY - Load from enhanced P&L service with immediate display
      final plSnapshot = await _plPersistenceService.loadPLSnapshot();

      if (plSnapshot != null) {
        // Create summary from P&L service data (highest priority)
        _summaryCache = {
          'totalValue': plSnapshot['totalValue'],
          'totalInvested': plSnapshot['totalInvested'],
          'profitLoss': plSnapshot['profitLoss'],
          'percentageChange': plSnapshot['percentageChange'],
          'totalHoldings': plSnapshot['transactionCount'] ?? 0,
          'lastUpdated': plSnapshot['dateString'],
          'calculatedAt': plSnapshot['timestamp'],
          'calculationMethod': 'startup_enhanced_pl_service_v4',
          'plIntegrityCheck': true,
          'loadedFrom': 'pl_persistence_service',
          'rateLimitProtected': true,
          'startupOptimized': true, // NEW: Mark as startup optimized
        };

        if (kDebugMode) {
          final plValue = (plSnapshot['profitLoss'] as num).toDouble();
          print(
            '🚀 STARTUP FIX: P&L loaded immediately from enhanced service: \$${plValue.toStringAsFixed(2)}',
          );
          print(
            '   📊 Total Value: \$${(plSnapshot['totalValue'] as num).toStringAsFixed(2)}',
          );
          print(
            '   💵 Total Invested: \$${(plSnapshot['totalInvested'] as num).toStringAsFixed(2)}',
          );
          print('   🛡️ Rate limit protection: ACTIVE');
          print('   ⚡ Startup optimization: ENABLED');
        }

        // STARTUP FIX: Immediately try to load holdings to match P&L data
        await _loadHoldingsForStartup();
      } else {
        // Fallback to legacy summary loading with enhanced validation
        final summaryJson = prefs.getString(_portfolioSummaryKey);
        if (summaryJson != null) {
          try {
            final loadedSummary = Map<String, dynamic>.from(
              jsonDecode(summaryJson),
            );

            // Enhanced P&L validation and restoration
            final totalValue =
                (loadedSummary['totalValue'] as num?)?.toDouble() ?? 0.0;
            final totalInvested =
                (loadedSummary['totalInvested'] as num?)?.toDouble() ?? 0.0;
            final cachedProfitLoss =
                (loadedSummary['profitLoss'] as num?)?.toDouble();
            final calculatedProfitLoss = totalValue - totalInvested;

            // Ensure P&L data integrity with auto-correction
            if (cachedProfitLoss == null ||
                (cachedProfitLoss - calculatedProfitLoss).abs() > 0.01) {
              loadedSummary['profitLoss'] = calculatedProfitLoss;
              loadedSummary['percentageChange'] =
                  totalInvested != 0.0
                      ? (calculatedProfitLoss / totalInvested.abs()) * 100
                      : 0.0;

              if (kDebugMode) {
                print(
                  '🔧 STARTUP FIX: Legacy P&L data auto-corrected: \$${calculatedProfitLoss.toStringAsFixed(2)}',
                );
              }
            }

            loadedSummary['plIntegrityCheck'] = true;
            loadedSummary['loadedFrom'] = 'startup_legacy_fallback_v4';
            loadedSummary['rateLimitProtected'] = true;
            loadedSummary['startupOptimized'] = true;
            _summaryCache = loadedSummary;

            // IMPORTANT: Immediately save to enhanced service
            if (totalValue > 0 || totalInvested > 0) {
              await _plPersistenceService.savePLSnapshot(
                totalValue: totalValue,
                totalInvested: totalInvested,
                profitLoss: calculatedProfitLoss,
                percentageChange:
                    totalInvested != 0.0
                        ? (calculatedProfitLoss / totalInvested.abs()) * 100
                        : 0.0,
                transactionCount:
                    (loadedSummary['totalHoldings'] as num?)?.toInt() ?? 0,
                source: 'startup_legacy_migration',
              );

              if (kDebugMode) {
                print(
                  '📤 STARTUP FIX: Legacy data migrated to enhanced P&L service',
                );
              }
            }
          } catch (e) {
            await prefs.remove(_portfolioSummaryKey);
            if (kDebugMode) {
              print('⚠️ STARTUP FIX: Corrupted legacy cache cleared');
            }
          }
        }
      }

      // STARTUP FIX: Load price cache with extended validity during startup
      await _loadPriceCacheForStartup(prefs);

      // Load P&L historical data
      await _loadPLHistoricalData();

      // Load chart data cache
      await _loadChartDataCache();

      if (kDebugMode) {
        final hasData = _summaryCache != null && _summaryCache!.isNotEmpty;
        print('🔍 STARTUP FIX: Cached data loading completed');
        print('   📊 Summary cache available: $hasData');
        if (hasData) {
          final plValue =
              (_summaryCache!['profitLoss'] as num?)?.toDouble() ?? 0.0;
          print('   💰 Cached P&L: \$${plValue.toStringAsFixed(2)}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ STARTUP FIX: Enhanced cache loading failed: $e');
      }
    }
  }

  /// STARTUP FIX: Load holdings immediately for startup display
  Future<void> _loadHoldingsForStartup() async {
    try {
      final transactions = await _loadTransactionsFromStorage();
      if (transactions.isNotEmpty) {
        if (kDebugMode) {
          print(
            '🔄 STARTUP FIX: Loading holdings from ${transactions.length} transactions',
          );
        }

        // Build holdings without API calls using cached prices
        final holdings = await _buildHoldingsFromTransactionsStartup(
          transactions,
        );
        _holdingsCache = holdings;

        if (kDebugMode) {
          print(
            '✅ STARTUP FIX: Holdings loaded immediately: ${holdings.length} assets',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ STARTUP FIX: Holdings loading failed: $e');
      }
    }
  }

  /// STARTUP FIX: Load price cache with startup optimization
  Future<void> _loadPriceCacheForStartup(SharedPreferences prefs) async {
    final pricesJson = prefs.getString(_pricesCacheKey);
    if (pricesJson != null) {
      try {
        final pricesData = Map<String, dynamic>.from(jsonDecode(pricesJson));

        // STARTUP FIX: Always load price cache during startup, even if expired
        _pricesCache = {};
        pricesData.forEach((key, value) {
          if (value is num &&
              ![
                'cachedAt',
                'validUntil',
                'apiCallsProtected',
                'rateLimitSafe',
              ].contains(key)) {
            _pricesCache![key] = value.toDouble();
          }
        });

        if (kDebugMode) {
          print(
            '💰 STARTUP FIX: Price cache loaded for immediate use: ${_pricesCache!.length} prices',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ STARTUP FIX: Price cache loading failed: $e');
        }
      }
    }
  }

  /// STARTUP FIX: Build holdings from transactions optimized for startup
  Future<List<Map<String, dynamic>>> _buildHoldingsFromTransactionsStartup(
    List<Map<String, dynamic>> transactions,
  ) async {
    // Group transactions by crypto_id
    final transactionsByCrypto = <String, List<Map<String, dynamic>>>{};
    for (final transaction in transactions) {
      final cryptoId = transaction['crypto_id'] as String;
      transactionsByCrypto.putIfAbsent(cryptoId, () => []).add(transaction);
    }

    final holdings = <Map<String, dynamic>>[];

    for (final entry in transactionsByCrypto.entries) {
      final cryptoId = entry.key;
      final cryptoTransactions = entry.value;

      if (cryptoTransactions.isEmpty) continue;

      // Extract crypto metadata from first transaction
      final firstTransaction = cryptoTransactions.first;
      final cryptoSymbol = firstTransaction['crypto_symbol'] as String;
      final cryptoName = firstTransaction['crypto_name'] as String;
      final cryptoIconUrl = firstTransaction['crypto_icon_url'] as String;

      // Calculate holdings totals
      double totalAmount = 0.0;
      double totalInvested = 0.0;
      String latestExchange = 'Unknown';

      for (final transaction in cryptoTransactions) {
        final transactionType = transaction['transaction_type'] as String;
        final amount = (transaction['amount'] as num).toDouble();
        final pricePerUnit = (transaction['price_per_unit'] as num).toDouble();
        final exchange = transaction['exchange'] as String? ?? 'Unknown';

        if (transactionType.toLowerCase() == 'buy') {
          totalAmount += amount;
          totalInvested += (amount * pricePerUnit);
        } else if (transactionType.toLowerCase() == 'sell') {
          totalAmount -= amount;
          if (totalAmount > 0) {
            final sellRatio = amount / (totalAmount + amount);
            totalInvested -= (totalInvested * sellRatio);
          }
        }

        latestExchange = exchange;
      }

      // Skip if no holdings remaining
      if (totalAmount <= 0) continue;

      // STARTUP FIX: Get current price with startup optimization (cache-first)
      double currentPrice = await _getCurrentPriceForStartup(
        cryptoId,
        cryptoSymbol,
        totalAmount,
        totalInvested,
      );

      final averagePrice =
          totalAmount != 0.0 ? (totalInvested / totalAmount).abs() : 0.0;

      holdings.add({
        'id': cryptoId,
        'crypto_id': cryptoId,
        'symbol': cryptoSymbol,
        'name': cryptoName,
        'icon': cryptoIconUrl,
        'currentPrice': currentPrice,
        'holdings': totalAmount,
        'averagePrice': averagePrice,
        'priceChange24h': 0.0,
        'total_invested': totalInvested.abs(),
        'transaction_count': cryptoTransactions.length,
        'transactions': cryptoTransactions,
        'exchange': latestExchange,
        'calculatedAt': DateTime.now().millisecondsSinceEpoch,
        'startupOptimized': true, // Mark as startup optimized
      });

      if (kDebugMode) {
        final currentValue = totalAmount * currentPrice;
        final profitLoss = currentValue - totalInvested.abs();
        print(
          '💰 STARTUP FIX: ${cryptoSymbol}: ${totalAmount.toStringAsFixed(6)} @ \$${currentPrice.toStringAsFixed(6)} = \$${currentValue.toStringAsFixed(2)}',
        );
      }
    }

    return holdings;
  }

  /// STARTUP FIX: Get current price optimized for startup (cache-first approach)
  Future<double> _getCurrentPriceForStartup(
    String cryptoId,
    String symbol,
    double totalAmount,
    double totalInvested,
  ) async {
    // STARTUP FIX: ALWAYS use cached price first during startup
    if (_pricesCache != null && _pricesCache!.containsKey(cryptoId)) {
      final cachedPrice = _pricesCache![cryptoId]!;
      if (cachedPrice > 0) {
        if (kDebugMode) {
          print(
            '💵 STARTUP FIX: Using cached price for $symbol: \$${cachedPrice.toStringAsFixed(6)} (startup mode)',
          );
        }
        return cachedPrice;
      }
    }

    // STARTUP FIX: Use average purchase price as reliable fallback during startup
    if (totalAmount > 0 && totalInvested > 0) {
      final averagePrice = (totalInvested / totalAmount).abs();
      if (averagePrice > 0) {
        if (kDebugMode) {
          print(
            '📊 STARTUP FIX: Using average purchase price for $symbol: \$${averagePrice.toStringAsFixed(6)} (startup fallback)',
          );
        }
        return averagePrice;
      }
    }

    // Final emergency fallback
    if (kDebugMode) {
      print('⚠️ STARTUP FIX: Emergency fallback price for $symbol');
    }
    return 1.0;
  }

  /// STARTUP FIX: Portfolio calculation optimized for startup
  Future<void> _calculatePortfolioForStartup() async {
    if (_isCalculating) return;
    _isCalculating = true;

    try {
      if (kDebugMode) {
        print('🧮 STARTUP FIX: Starting portfolio calculation for startup...');
      }

      // Load transactions
      final transactions = await _loadTransactionsFromStorage();

      if (transactions.isEmpty) {
        _summaryCache = _createEmptySummary();
        _holdingsCache = [];
        await _persistCacheToStorage();
        return;
      }

      // Build holdings from transactions (startup optimized)
      final holdings = await _buildHoldingsFromTransactionsStartup(
        transactions,
      );

      // Calculate summary
      final summary = _calculateSummaryFromHoldings(holdings);

      // Update caches
      _holdingsCache = holdings;
      _summaryCache = summary;

      // Mark as startup optimized
      _summaryCache!['startupOptimized'] = true;
      _summaryCache!['calculationMethod'] = 'startup_enhanced_v4';

      // Persist with comprehensive validation
      await _persistCacheToStorage();

      // Notify listeners
      _portfolioController.add(holdings);

      if (kDebugMode) {
        final finalPL =
            (_summaryCache!['profitLoss'] as num?)?.toDouble() ?? 0.0;
        print('✅ STARTUP FIX: Portfolio calculation completed:');
        print('   💰 P&L: \$${finalPL.toStringAsFixed(2)}');
        print('   📊 Holdings: ${holdings.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ STARTUP FIX: Portfolio calculation failed: $e');
      }

      // Fallback to empty state
      _summaryCache ??= _createEmptySummary();
      _holdingsCache ??= [];
    } finally {
      _isCalculating = false;
    }
  }

  /// ENHANCED: Get cached portfolio summary with startup data loading guarantee
  Future<Map<String, dynamic>> getCachedPortfolioSummary() async {
    if (!_isInitialized) {
      await initializeForAndroid();
    }

    // STARTUP FIX: Load transactions to validate we have data for calculation
    final transactions = await _loadTransactionsFromStorage();
    final hasTransactions = transactions.isNotEmpty;

    // STARTUP FIX: PRIORITY - Check enhanced P&L service first with startup optimization
    if (_summaryCache == null ||
        (_summaryCache!['profitLoss'] as num?)?.toDouble() == 0.0) {
      final plSnapshot = await _plPersistenceService.loadPLSnapshot();

      if (plSnapshot != null) {
        _summaryCache = {
          'totalValue': plSnapshot['totalValue'],
          'totalInvested': plSnapshot['totalInvested'],
          'profitLoss': plSnapshot['profitLoss'],
          'percentageChange': plSnapshot['percentageChange'],
          'totalHoldings': plSnapshot['transactionCount'] ?? 0,
          'lastUpdated': plSnapshot['dateString'],
          'calculatedAt': plSnapshot['timestamp'],
          'calculationMethod': 'startup_pl_service_restore_v4',
          'plIntegrityCheck': true,
          'restoredFrom': 'pl_service',
          'rateLimitProtected': true,
          'startupOptimized': true, // Mark as startup optimized
        };

        if (kDebugMode) {
          final plValue = (plSnapshot['profitLoss'] as num).toDouble();
          print(
            '🔄 STARTUP FIX: P&L restored from enhanced service immediately: \$${plValue.toStringAsFixed(2)}',
          );
        }
      }
    }

    // Enhanced cached summary validation with zero-prevention logic
    if (_summaryCache != null) {
      final totalValue =
          (_summaryCache!['totalValue'] as num?)?.toDouble() ?? 0.0;
      final totalInvested =
          (_summaryCache!['totalInvested'] as num?)?.toDouble() ?? 0.0;
      final cachedProfitLoss =
          (_summaryCache!['profitLoss'] as num?)?.toDouble();
      final expectedProfitLoss = totalValue - totalInvested;

      // STARTUP FIX: Enhanced zero-reset prevention with immediate correction
      if (cachedProfitLoss == null || cachedProfitLoss == 0.0) {
        if (hasTransactions && (totalValue > 0 || totalInvested > 0)) {
          // Restore from expected calculation immediately
          _summaryCache!['profitLoss'] = expectedProfitLoss;
          _summaryCache!['percentageChange'] =
              totalInvested != 0.0
                  ? (expectedProfitLoss / totalInvested.abs()) * 100
                  : 0.0;

          // Immediately persist the correction
          await _plPersistenceService.savePLSnapshot(
            totalValue: totalValue,
            totalInvested: totalInvested,
            profitLoss: expectedProfitLoss,
            percentageChange:
                totalInvested != 0.0
                    ? (expectedProfitLoss / totalInvested.abs()) * 100
                    : 0.0,
            transactionCount:
                (_summaryCache!['totalHoldings'] as num?)?.toInt() ?? 0,
            source: 'startup_zero_reset_prevention',
            additionalData: {
              'apiRefreshAllowed': _isApiRefreshAllowed,
              'rateLimitProtection': 'active',
              'startupOptimized': true,
            },
          );

          if (kDebugMode) {
            print(
              '🛡️ STARTUP FIX: ZERO RESET PREVENTED immediately - P&L restored: \$${expectedProfitLoss.toStringAsFixed(2)}',
            );
            print('   📊 Transactions: ${transactions.length}');
            print('   💰 Portfolio Value: \$${totalValue.toStringAsFixed(2)}');
            print('   ⚡ Startup optimization: ACTIVE');
          }
        }
      } else if ((cachedProfitLoss - expectedProfitLoss).abs() > 0.01) {
        // P&L inconsistency detected - use expected value and save
        _summaryCache!['profitLoss'] = expectedProfitLoss;
        await _persistCacheToStorage();

        if (kDebugMode) {
          print(
            '🔧 STARTUP FIX: P&L consistency enforced immediately: \$${expectedProfitLoss.toStringAsFixed(2)}',
          );
        }
      }

      // Return cached data if meaningful or no transactions exist
      if ((totalValue > 0 || totalInvested > 0) || !hasTransactions) {
        // Add startup optimization context to returned data
        _summaryCache!['apiRateLimitProtected'] = true;
        _summaryCache!['isApiRefreshAllowed'] = _isApiRefreshAllowed;
        _summaryCache!['shouldRecommendManualRefresh'] =
            shouldRecommendManualRefresh();
        _summaryCache!['startupOptimized'] = true;

        if (kDebugMode) {
          final profitLoss = (_summaryCache!['profitLoss'] as num).toDouble();
          print(
            '📦 STARTUP FIX: Enhanced cached summary returned immediately: \$${profitLoss.toStringAsFixed(2)}',
          );
          print('   🔒 Zero-reset protection: ACTIVE');
          print('   ⚡ Startup optimization: ACTIVE');
        }
        return _summaryCache!;
      }
    }

    // STARTUP FIX: Force calculation if needed but with startup optimizations
    if (hasTransactions) {
      if (kDebugMode) {
        print('🔄 STARTUP FIX: Forcing startup-optimized P&L calculation');
      }
      await _calculatePortfolioForStartup();
    }

    return _summaryCache ?? _createEmptySummary();
  }

  /// NEW: Get P&L historical data for graph persistence
  Future<List<Map<String, dynamic>>> getPLHistoricalData() async {
    if (_plHistoryCache == null) {
      await _loadPLHistoricalData();
    }

    return _plHistoryCache?['history']?.cast<Map<String, dynamic>>() ?? [];
  }

  /// NEW: Update transaction with P&L persistence
  Future<void> onTransactionAdded() async {
    if (kDebugMode) {
      print(
        '💰 New transaction detected - triggering enhanced P&L recalculation',
      );
    }

    // Force recalculation for new transactions regardless of rate limits
    // (uses existing cached prices to avoid 429 errors)
    await _calculatePortfolio();

    // Double-check P&L persistence after transaction
    if (_summaryCache != null) {
      final totalValue =
          (_summaryCache!['totalValue'] as num?)?.toDouble() ?? 0.0;
      final totalInvested =
          (_summaryCache!['totalInvested'] as num?)?.toDouble() ?? 0.0;
      final profitLoss =
          (_summaryCache!['profitLoss'] as num?)?.toDouble() ?? 0.0;

      await _plPersistenceService.savePLSnapshot(
        totalValue: totalValue,
        totalInvested: totalInvested,
        profitLoss: profitLoss,
        percentageChange:
            totalInvested != 0.0
                ? (profitLoss / totalInvested.abs()) * 100
                : 0.0,
        transactionCount:
            (_summaryCache!['totalHoldings'] as num?)?.toInt() ?? 0,
        source: 'transaction_added_with_rate_limit_protection',
        additionalData: {
          'apiRefreshAllowed': _isApiRefreshAllowed,
          'usedCachedPrices': !_isApiRefreshAllowed,
        },
      );

      if (kDebugMode) {
        print(
          '💾 Enhanced P&L persisted after transaction: \$${profitLoss.toStringAsFixed(2)}',
        );
        print(
          '   Used API: ${_isApiRefreshAllowed ? 'YES' : 'NO (cached prices)'}',
        );
      }
    }
  }

  /// NEW: Force enhanced P&L refresh and persistence
  Future<void> forceEnhancedPLRefresh() async {
    try {
      await _calculatePortfolio();

      if (_summaryCache != null) {
        final totalValue =
            (_summaryCache!['totalValue'] as num?)?.toDouble() ?? 0.0;
        final totalInvested =
            (_summaryCache!['totalInvested'] as num?)?.toDouble() ?? 0.0;
        final profitLoss = totalValue - totalInvested;

        _summaryCache!['profitLoss'] = profitLoss;
        _summaryCache!['percentageChange'] =
            totalInvested != 0.0
                ? (profitLoss / totalInvested.abs()) * 100
                : 0.0;

        await _plPersistenceService.savePLSnapshot(
          totalValue: totalValue,
          totalInvested: totalInvested,
          profitLoss: profitLoss,
          percentageChange:
              totalInvested != 0.0
                  ? (profitLoss / totalInvested.abs()) * 100
                  : 0.0,
          transactionCount:
              (_summaryCache!['totalHoldings'] as num?)?.toInt() ?? 0,
          source: 'forced_refresh',
        );

        if (kDebugMode) {
          print(
            '🔄 Enhanced P&L force refresh completed: \$${profitLoss.toStringAsFixed(2)}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Enhanced P&L force refresh failed: $e');
      }
    }
  }

  /// NEW: Get enhanced diagnostic information
  Future<Map<String, dynamic>> getEnhancedDiagnostics() async {
    try {
      final plDiagnostics = await _plPersistenceService.getDiagnosticInfo();
      final transactions = await _loadTransactionsFromStorage();

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'portfolioService': {
          'isInitialized': _isInitialized,
          'isCalculating': _isCalculating,
          'hasSummaryCache': _summaryCache != null,
          'hasHoldingsCache': _holdingsCache != null,
          'hasPricesCache': _pricesCache != null,
          'transactionCount': transactions.length,
          'currentPL': _summaryCache?['profitLoss'],
        },
        'plPersistenceService': plDiagnostics,
        'validation':
            _summaryCache != null
                ? await _plPersistenceService.validatePLConsistency(
                  totalValue:
                      (_summaryCache!['totalValue'] as num?)?.toDouble() ?? 0.0,
                  totalInvested:
                      (_summaryCache!['totalInvested'] as num?)?.toDouble() ??
                      0.0,
                  profitLoss:
                      (_summaryCache!['profitLoss'] as num?)?.toDouble() ?? 0.0,
                )
                : {'isValid': false, 'reason': 'no_summary_cache'},
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get portfolio holdings with guaranteed calculation
  Future<List<Map<String, dynamic>>> getPortfolioWithCurrentPrices() async {
    if (!_isInitialized) {
      await initializeForAndroid();
    }

    // FIXED: Check if we have transactions but no valid holdings
    final transactions = await _loadTransactionsFromStorage();
    final hasTransactions = transactions.isNotEmpty;

    // If we have recent holdings with valid data, return them
    if (_holdingsCache != null && _holdingsCache!.isNotEmpty) {
      // Validate that holdings have meaningful data
      bool hasValidHoldings = false;
      for (final holding in _holdingsCache!) {
        final amount = (holding['holdings'] as num?)?.toDouble() ?? 0.0;
        final invested = (holding['total_invested'] as num?)?.toDouble() ?? 0.0;
        if (amount > 0 || invested > 0) {
          hasValidHoldings = true;
          break;
        }
      }

      if (hasValidHoldings || !hasTransactions) {
        if (kDebugMode) {
          print(
            '📦 Using cached portfolio holdings: ${_holdingsCache!.length} assets',
          );
        }
        return _holdingsCache!;
      }
    }

    // FIXED: Force calculation if we have transactions but invalid holdings
    if (hasTransactions) {
      if (kDebugMode) {
        print(
          '🔄 Forcing portfolio calculation for holdings due to invalid cached data',
        );
      }
      await _calculatePortfolio();
    }

    return _holdingsCache ?? [];
  }
}
