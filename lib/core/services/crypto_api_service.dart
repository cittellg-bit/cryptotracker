import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import './logging_service.dart';

class CryptoApiService {
  static CryptoApiService? _instance;
  static CryptoApiService get instance =>
      _instance ??= CryptoApiService._internal();

  CryptoApiService._internal();

  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.coingecko.com/api/v3';
  final LoggingService _loggingService = LoggingService.instance;

  // ENHANCED: Rate limiting and intelligent caching for ALL cryptos
  Map<String, dynamic>? _cachedTopCryptos;
  Map<String, Map<String, dynamic>?> _historicalDataCache = {};
  DateTime? _lastCacheUpdate;
  DateTime? _lastApiCall;
  int _apiCallCount = 0;

  // ENHANCED RATE LIMITING: More generous limits for fetching all available cryptos
  static const Duration _rateLimitWindow = Duration(hours: 8); // 8-hour window
  static const Duration _minCallInterval = Duration(
    minutes: 5,
  ); // Reduced to 5 minutes between calls for more data
  static const Duration _cacheTimeout = Duration(
    hours: 6,
  ); // Extended to 6-hour cache validity
  static const int _maxCallsPerWindow =
      5; // Increased to 5 calls per 8-hour window

  // ENHANCED FETCH LIMITS: Target all available cryptocurrencies
  static const int _maxCryptosPerPage = 250; // CoinGecko's maximum per page
  static const int _targetTotalCryptos =
      500; // Target 500+ total cryptocurrencies
  static const int _maxPages = 3; // Fetch up to 3 pages (750 cryptos max)

  // CACHING: Enhanced storage keys with versioning
  static const String _pricesCacheKey = 'crypto_prices_cache_v4';
  static const String _historicalCacheKey = 'crypto_historical_cache_v4';
  static const String _apiCallLogKey = 'crypto_api_call_log_v4';
  static const String _lastApiCallKey = 'crypto_last_api_call_v4';
  static const String _fullDatasetCacheKey = 'crypto_full_dataset_v4';

  /// Initialize the service with enhanced rate limiting for comprehensive data fetching
  void initialize() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 45);

    // Enhanced interceptor for comprehensive API monitoring
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await _enforceRateLimit();
          await _logApiCall('REQUEST', options.path);
          if (kDebugMode) {
            print('🌐 API Request: ${options.method} ${options.path}');
            print(
              '   Rate limit: $_apiCallCount/$_maxCallsPerWindow calls in window',
            );
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          await _logApiCall(
            'RESPONSE_SUCCESS',
            response.requestOptions.path,
            statusCode: response.statusCode,
          );

          // ENHANCED: Log API fetch scope for diagnostics
          if (response.requestOptions.path.contains('/coins/markets')) {
            final dataSize = (response.data as List?)?.length ?? 0;
            await _loggingService.logInfo(
              category: LogCategory.apiCall,
              message: 'Market data API response received',
              details: {
                'cryptoCount': dataSize,
                'path': response.requestOptions.path,
                'queryParams': response.requestOptions.queryParameters,
              },
              functionName: 'API_INTERCEPTOR',
            );

            if (kDebugMode) {
              print(
                '✅ API Success: Fetched $dataSize cryptocurrencies from ${response.requestOptions.path}',
              );
            }
          }

          handler.next(response);
        },
        onError: (error, handler) async {
          await _logApiCall(
            'ERROR',
            error.requestOptions.path,
            statusCode: error.response?.statusCode,
            error: error.message,
          );

          if (error.response?.statusCode == 429) {
            await _handle429Error();
            if (kDebugMode) {
              print('🚫 429 Too Many Requests - implementing backoff');
            }
          } else if (kDebugMode) {
            print(
              '❌ API Error: ${error.response?.statusCode} ${error.message}',
            );
          }
          handler.next(error);
        },
      ),
    );

    // Load cached data and API call history on startup
    _loadCachedDataOnStartup();
  }

  /// ENHANCED: Load cached data and API call history on startup
  Future<void> _loadCachedDataOnStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load price cache
      final pricesCacheJson = prefs.getString(_pricesCacheKey);
      if (pricesCacheJson != null) {
        final cacheData = jsonDecode(pricesCacheJson) as Map<String, dynamic>;
        final cachedAt = DateTime.tryParse(cacheData['cachedAt'] ?? '');

        if (cachedAt != null &&
            DateTime.now().difference(cachedAt) < _cacheTimeout) {
          _cachedTopCryptos = cacheData;
          _lastCacheUpdate = cachedAt;

          if (kDebugMode) {
            print('💾 Loaded valid price cache from startup');
            print(
              '   Cache age: ${DateTime.now().difference(cachedAt).inMinutes} minutes',
            );
          }
        }
      }

      // Load historical data cache
      final historicalCacheJson = prefs.getString(_historicalCacheKey);
      if (historicalCacheJson != null) {
        final historicalCache =
            jsonDecode(historicalCacheJson) as Map<String, dynamic>;
        _historicalDataCache = historicalCache.map(
          (key, value) => MapEntry(key, value as Map<String, dynamic>?),
        );

        if (kDebugMode) {
          print(
            '📈 Loaded historical data cache: ${_historicalDataCache.length} assets',
          );
        }
      }

      // Load API call history for rate limiting
      final lastCallTime = prefs.getString(_lastApiCallKey);
      if (lastCallTime != null) {
        _lastApiCall = DateTime.tryParse(lastCallTime);
      }

      final apiCallLogJson = prefs.getString(_apiCallLogKey);
      if (apiCallLogJson != null) {
        final callLog = jsonDecode(apiCallLogJson) as List<dynamic>;
        final now = DateTime.now();

        // Count calls in current window
        _apiCallCount =
            callLog.where((call) {
              final callTime = DateTime.tryParse(call['timestamp'] ?? '');
              return callTime != null &&
                  now.difference(callTime) < _rateLimitWindow;
            }).length;

        if (kDebugMode) {
          print('📊 API Call History: $_apiCallCount calls in current window');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to load cached data on startup: $e');
      }
    }
  }

  /// RATE LIMITING: Enforce intelligent API rate limiting
  Future<void> _enforceRateLimit() async {
    final now = DateTime.now();

    // Check if we're within rate limit window
    if (_lastApiCall != null) {
      final timeSinceLastCall = now.difference(_lastApiCall!);

      // Enforce minimum interval between calls
      if (timeSinceLastCall < _minCallInterval) {
        final waitTime = _minCallInterval - timeSinceLastCall;
        await _loggingService.logWarning(
          category: LogCategory.apiCall,
          message: 'Rate limit enforced - waiting before API call',
          details: {'waitTime': waitTime.inSeconds},
          functionName: '_enforceRateLimit',
        );

        if (kDebugMode) {
          print(
            '⏰ Rate limit: waiting ${waitTime.inSeconds}s before next call',
          );
        }

        await Future.delayed(waitTime);
      }
    }

    // Check daily call limit
    if (_apiCallCount >= _maxCallsPerWindow) {
      await _loggingService.logWarning(
        category: LogCategory.apiCall,
        message: 'Daily API call limit reached - using cache only',
        details: {'callCount': _apiCallCount, 'maxCalls': _maxCallsPerWindow},
        functionName: '_enforceRateLimit',
      );

      throw DioException(
        requestOptions: RequestOptions(path: '/rate-limited'),
        message: 'Daily API call limit reached. Using cached data.',
        type: DioExceptionType.unknown,
      );
    }

    _lastApiCall = now;
    _apiCallCount++;

    // Persist updated call info
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastApiCallKey, now.toIso8601String());
  }

  /// ENHANCED: Handle 429 errors with intelligent backoff
  Future<void> _handle429Error() async {
    _apiCallCount = _maxCallsPerWindow; // Force cache-only mode

    await _loggingService.logError(
      category: LogCategory.apiCall,
      message: '429 Too Many Requests - switching to cache-only mode',
      details: {
        'apiCallCount': _apiCallCount,
        'cacheAge':
            _lastCacheUpdate != null
                ? DateTime.now().difference(_lastCacheUpdate!).inMinutes
                : null,
      },
      functionName: '_handle429Error',
      errorStack: '429 Rate Limit Exceeded',
    );

    if (kDebugMode) {
      print(
        '🚫 429 Error: Switched to cache-only mode for remainder of window',
      );
      print('   Cache will be used for all subsequent requests');
    }
  }

  /// ENHANCED: API call logging for diagnostics
  Future<void> _logApiCall(
    String type,
    String path, {
    int? statusCode,
    String? error,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiCallLogJson = prefs.getString(_apiCallLogKey) ?? '[]';
      final callLog = jsonDecode(apiCallLogJson) as List<dynamic>;

      final logEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'type': type,
        'path': path,
        'statusCode': statusCode,
        'error': error,
        'callCount': _apiCallCount,
      };

      callLog.add(logEntry);

      // Keep only last 100 entries
      if (callLog.length > 100) {
        callLog.removeRange(0, callLog.length - 100);
      }

      await prefs.setString(_apiCallLogKey, jsonEncode(callLog));

      // Also log to main logging service for serious errors
      if (type == 'ERROR' && statusCode == 429) {
        await _loggingService.logError(
          category: LogCategory.apiCall,
          message: 'CoinGecko API 429 error',
          details: logEntry,
          functionName: '_logApiCall',
          errorStack: error ?? 'Rate limit exceeded',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to log API call: $e');
      }
    }
  }

  /// Check internet connectivity
  Future<bool> _hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Connectivity check failed: $e');
      }
      return false;
    }
  }

  /// ENHANCED: Smart cache validation with better expiration logic for ALL cryptos
  List<Map<String, dynamic>>? _getCachedTopCryptos() {
    if (_cachedTopCryptos != null && _lastCacheUpdate != null) {
      final cacheAge = DateTime.now().difference(_lastCacheUpdate!);

      // Use longer cache during rate limit periods
      final effectiveTimeout =
          _apiCallCount >= _maxCallsPerWindow
              ? Duration(hours: 12) // Extended cache during rate limits
              : _cacheTimeout; // Normal cache timeout

      if (cacheAge < effectiveTimeout) {
        final cachedData = List<Map<String, dynamic>>.from(
          _cachedTopCryptos!['data'] ?? [],
        );

        // Validate cached prices are reasonable
        bool pricesValid = cachedData.every((crypto) {
          final price = (crypto['current_price'] as num?)?.toDouble() ?? 0.0;
          return price > 0 && !price.isNaN && !price.isInfinite;
        });

        if (pricesValid && cachedData.isNotEmpty) {
          if (kDebugMode) {
            final rateLimited =
                _apiCallCount >= _maxCallsPerWindow ? ' (RATE LIMITED)' : '';
            print(
              '✅ Using valid cached data (${cacheAge.inMinutes}m old)$rateLimited',
            );
            print('   Cache contains ${cachedData.length} cryptocurrencies');

            // Log comprehensive dataset info
            _logDatasetInfo(cachedData, 'CACHED');
          }
          return cachedData;
        } else {
          if (kDebugMode) {
            print('⚠️ Cached data invalid, clearing cache');
          }
          clearCache();
        }
      } else {
        if (kDebugMode) {
          print(
            '⏰ Cache expired (${cacheAge.inMinutes}m > ${effectiveTimeout.inMinutes}m)',
          );
        }
        clearCache();
      }
    }
    return null;
  }

  /// ENHANCED: Cache with persistent storage, validation, and comprehensive dataset tracking
  Future<void> _cacheTopCryptos(List<Map<String, dynamic>> data) async {
    try {
      // Validate all data before caching
      bool hasValidPrices = data.every((crypto) {
        final price = (crypto['current_price'] as num?)?.toDouble() ?? 0.0;
        final marketCap = (crypto['market_cap'] as num?)?.toDouble() ?? 0.0;
        return price > 0 && !price.isNaN && !price.isInfinite && marketCap >= 0;
      });

      if (hasValidPrices && data.isNotEmpty) {
        final now = DateTime.now();

        // Add validation timestamp and metadata
        final enrichedData =
            data
                .map(
                  (crypto) => {
                    ...crypto,
                    'cached_at': now.toIso8601String(),
                    'price_validated': true,
                    'cache_version': '4.0',
                  },
                )
                .toList();

        _cachedTopCryptos = {
          'data': enrichedData,
          'cachedAt': now.toIso8601String(),
          'validationPassed': true,
          'apiCallCount': _apiCallCount,
          'cacheVersion': '4.0',
          'datasetSize': enrichedData.length,
          'targetReached': enrichedData.length >= _targetTotalCryptos,
        };
        _lastCacheUpdate = now;

        // Persist to storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_pricesCacheKey, jsonEncode(_cachedTopCryptos));

        if (kDebugMode) {
          print(
            '💾 Cached ${data.length} cryptocurrencies with validated prices',
          );
          print('   Cache persisted to storage for offline access');

          // Log comprehensive dataset information
          _logDatasetInfo(data, 'CACHED');
        }

        await _loggingService.logInfo(
          category: LogCategory.apiCall,
          message: 'Comprehensive market data cached successfully',
          details: {
            'cryptoCount': data.length,
            'cacheVersion': '4.0',
            'apiCallCount': _apiCallCount,
            'targetReached': data.length >= _targetTotalCryptos,
            'topCryptos': data.take(10).map((c) => c['symbol']).toList(),
          },
          functionName: '_cacheTopCryptos',
        );
      } else {
        if (kDebugMode) {
          print('⚠️ Rejecting cache - invalid or empty price data');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to cache market data: $e');
      }
    }
  }

  /// NEW: Log comprehensive dataset information for diagnostics
  void _logDatasetInfo(List<Map<String, dynamic>> data, String source) {
    if (data.isEmpty) return;

    // Calculate dataset statistics
    final totalCount = data.length;
    final topTierCount =
        data.where((c) => (c['market_cap_rank'] ?? 999) <= 50).length;
    final midTierCount =
        data.where((c) {
          final rank = c['market_cap_rank'] ?? 999;
          return rank > 50 && rank <= 200;
        }).length;
    final longTailCount =
        data.where((c) => (c['market_cap_rank'] ?? 999) > 200).length;

    // Calculate total market cap
    final totalMarketCap = data
        .map((c) => (c['market_cap'] as num?)?.toDouble() ?? 0.0)
        .fold(0.0, (sum, cap) => sum + cap);

    // Get sample of available cryptocurrencies
    final sampleSymbols = data.take(20).map((c) => c['symbol']).join(', ');

    if (kDebugMode) {
      print('📊 $source Dataset Analysis:');
      print('   Total Cryptocurrencies: $totalCount');
      print('   Top Tier (Rank 1-50): $topTierCount');
      print('   Mid Tier (Rank 51-200): $midTierCount');
      print('   Long Tail (Rank 200+): $longTailCount');
      print(
        '   Total Market Cap: \$${(totalMarketCap / 1e12).toStringAsFixed(2)}T',
      );
      print('   Sample Cryptos: $sampleSymbols...');
      print(
        '   Target Reached: ${totalCount >= _targetTotalCryptos ? "✅" : "❌"} ($totalCount/$_targetTotalCryptos)',
      );
    }

    // Log to persistent logging system
    _loggingService.logInfo(
      category: LogCategory.apiCall,
      message: '$source cryptocurrency dataset analyzed',
      details: {
        'source': source,
        'totalCount': totalCount,
        'topTierCount': topTierCount,
        'midTierCount': midTierCount,
        'longTailCount': longTailCount,
        'totalMarketCapTrillion': (totalMarketCap / 1e12),
        'targetReached': totalCount >= _targetTotalCryptos,
        'sampleCryptos':
            data.take(10).map((c) => '${c['symbol']}-${c['name']}').toList(),
      },
      functionName: '_logDatasetInfo',
    );
  }

  /// ENHANCED: Cache historical data for comprehensive P&L calculations (1-year data)
  Future<void> _cacheHistoricalData(
    String cryptoId,
    Map<String, dynamic> data,
  ) async {
    try {
      _historicalDataCache[cryptoId] = {
        ...data,
        'cachedAt': DateTime.now().toIso8601String(),
        'cacheVersion': '4.0',
      };

      // Persist to storage
      final prefs = await SharedPreferences.getInstance();
      final cacheMap = _historicalDataCache.map(
        (key, value) => MapEntry(key, value ?? {}),
      );
      await prefs.setString(_historicalCacheKey, jsonEncode(cacheMap));

      if (kDebugMode) {
        final days = data['days'] ?? 'unknown';
        final pricesCount = (data['prices'] as List?)?.length ?? 0;
        print(
          '📈 Cached $days-day historical data for $cryptoId: $pricesCount price points',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to cache historical data for $cryptoId: $e');
      }
    }
  }

  /// ENHANCED: Get historical market data for comprehensive P&L calculations (1-year support)
  Future<Map<String, dynamic>?> getHistoricalMarketData(
    String cryptoId, {
    int days = 365, // Default to 1 year for comprehensive P&L
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = '${cryptoId}_${days}d';

      // Check cache first (unless forced refresh)
      if (!forceRefresh && _historicalDataCache.containsKey(cacheKey)) {
        final cachedData = _historicalDataCache[cacheKey];
        if (cachedData != null) {
          final cachedAt = DateTime.tryParse(cachedData['cachedAt'] ?? '');
          if (cachedAt != null &&
              DateTime.now().difference(cachedAt) < Duration(hours: 24)) {
            // 24-hour cache for historical data
            if (kDebugMode) {
              print(
                '📈 Using cached historical data for $cryptoId ($days days)',
              );
            }
            return cachedData;
          }
        }
      }

      // Check if we can make API calls
      if (_apiCallCount >= _maxCallsPerWindow) {
        if (kDebugMode) {
          print(
            '🚫 Rate limit reached - using cached historical data for $cryptoId',
          );
        }
        return _historicalDataCache[cacheKey];
      }

      if (!await _hasInternetConnection()) {
        return _historicalDataCache[cacheKey];
      }

      if (kDebugMode) {
        print('🔄 Fetching $days-day historical data for $cryptoId...');
      }

      final response = await _dio.get(
        '/coins/$cryptoId/market_chart',
        queryParameters: {
          'vs_currency': 'usd',
          'days': days.toString(),
          'interval': days <= 7 ? 'hourly' : 'daily',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        // Process and validate historical data
        final prices =
            (data['prices'] as List<dynamic>?)
                ?.map(
                  (item) => {
                    'timestamp': (item as List<dynamic>)[0],
                    'price': (item[1] as num).toDouble(),
                  },
                )
                .toList() ??
            [];

        final processedData = {
          'cryptoId': cryptoId,
          'days': days,
          'prices': prices,
          'market_caps': data['market_caps'] ?? [],
          'total_volumes': data['total_volumes'] ?? [],
          'fetchedAt': DateTime.now().toIso8601String(),
        };

        // Cache the data
        await _cacheHistoricalData(cacheKey, processedData);

        if (kDebugMode) {
          print(
            '✅ Fetched historical data: ${prices.length} price points over $days days',
          );
        }

        await _loggingService.logInfo(
          category: LogCategory.apiCall,
          message: 'Historical market data fetched',
          details: {
            'cryptoId': cryptoId,
            'days': days,
            'pricePoints': prices.length,
            'dateRange':
                prices.isNotEmpty
                    ? {
                      'start':
                          DateTime.fromMillisecondsSinceEpoch(
                            prices.first['timestamp'],
                          ).toIso8601String(),
                      'end':
                          DateTime.fromMillisecondsSinceEpoch(
                            prices.last['timestamp'],
                          ).toIso8601String(),
                    }
                    : null,
          },
          functionName: 'getHistoricalMarketData',
        );

        return processedData;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching historical data for $cryptoId: $e');
      }

      // Return cached data on error
      return _historicalDataCache['${cryptoId}_${days}d'];
    }
  }

  /// ENHANCED: Clear cache with better cleanup
  void clearCache() {
    _cachedTopCryptos = null;
    _historicalDataCache.clear();
    _lastCacheUpdate = null;

    if (kDebugMode) {
      print('🧹 All price and historical caches cleared');
    }
  }

  /// ENHANCED: Get ALL available cryptocurrencies with intelligent pagination and comprehensive caching
  Future<List<Map<String, dynamic>>> getTopCryptocurrencies({
    int limit = 500, // Increased default to fetch more comprehensive data
  }) async {
    try {
      // Always check cache first
      final cachedData = _getCachedTopCryptos();
      if (cachedData != null && cachedData.isNotEmpty) {
        final requestedData = cachedData.take(limit).toList();

        // Log that we're using cached data
        _logDatasetInfo(requestedData, 'CACHE_SERVED');

        return requestedData;
      }

      // Check rate limits before making API call
      if (_apiCallCount >= _maxCallsPerWindow) {
        await _loggingService.logWarning(
          category: LogCategory.apiCall,
          message: 'Rate limit reached - cannot fetch fresh comprehensive data',
          details: {'callCount': _apiCallCount, 'maxCalls': _maxCallsPerWindow},
          functionName: 'getTopCryptocurrencies',
        );

        // Return any cached data we have, even if expired
        if (_cachedTopCryptos != null) {
          final data = List<Map<String, dynamic>>.from(
            _cachedTopCryptos!['data'] ?? [],
          );
          if (data.isNotEmpty) {
            if (kDebugMode) {
              print('🚫 Rate limited: returning expired cache data');
            }
            return data.take(limit).toList();
          }
        }

        // Return enhanced fallback data as last resort
        return getEnhancedFallbackData().take(limit).toList();
      }

      // Check internet connection
      if (!await _hasInternetConnection()) {
        throw Exception('No internet connection available');
      }

      if (kDebugMode) {
        print(
          '🔄 Fetching comprehensive market data (targeting $limit cryptocurrencies)...',
        );
        print(
          '   API call ${_apiCallCount + 1}/$_maxCallsPerWindow in current window',
        );
      }

      // ENHANCED: Fetch multiple pages to get comprehensive dataset
      List<Map<String, dynamic>> allCryptos = [];
      int currentPage = 1;
      final targetPerPage = _maxCryptosPerPage;

      // Fetch pages until we have enough data or hit limits
      while (allCryptos.length < limit &&
          currentPage <= _maxPages &&
          _apiCallCount < _maxCallsPerWindow) {
        if (kDebugMode) {
          print(
            '   Fetching page $currentPage (${allCryptos.length} cryptos so far)...',
          );
        }

        final response = await _dio.get(
          '/coins/markets',
          queryParameters: {
            'vs_currency': 'usd',
            'order': 'market_cap_desc',
            'per_page': targetPerPage,
            'page': currentPage,
            'sparkline': false,
            'price_change_percentage': '24h,7d',
            'include_24hr_vol': 'true',
            'include_24hr_change': 'true',
            'include_last_updated_at': 'true',
          },
        );

        if (response.statusCode == 200) {
          final List<dynamic> pageData = response.data;

          if (pageData.isEmpty) {
            if (kDebugMode) {
              print('   No more data available from API (reached end)');
            }
            break; // No more data available
          }

          // Enhanced data mapping with strict validation
          final List<Map<String, dynamic>> pageCryptos =
              pageData
                  .map((crypto) {
                    final price = (crypto['current_price'] as num?)?.toDouble();
                    final marketCap =
                        (crypto['market_cap'] as num?)?.toDouble();
                    final volume = (crypto['total_volume'] as num?)?.toDouble();

                    // Skip invalid entries
                    if (price == null ||
                        price <= 0 ||
                        price.isNaN ||
                        price.isInfinite) {
                      return null;
                    }

                    return {
                      'id': crypto['id'] ?? '',
                      'symbol': crypto['symbol'] ?? '',
                      'name': crypto['name'] ?? '',
                      'image': crypto['image'] ?? '',
                      'current_price': price,
                      'market_cap': marketCap ?? 0.0,
                      'market_cap_rank': crypto['market_cap_rank'] ?? 0,
                      'price_change_percentage_24h':
                          (crypto['price_change_percentage_24h'] ?? 0.0)
                              .toDouble(),
                      'total_volume': volume ?? 0.0,
                      'circulating_supply':
                          (crypto['circulating_supply'] ?? 0.0).toDouble(),
                      'total_supply':
                          (crypto['total_supply'] ?? 0.0).toDouble(),
                      'max_supply': crypto['max_supply']?.toDouble(),
                      'last_updated':
                          crypto['last_updated'] ??
                          DateTime.now().toIso8601String(),
                      'api_call_timestamp': DateTime.now().toIso8601String(),
                      'fetch_page': currentPage,
                    };
                  })
                  .where((crypto) => crypto != null)
                  .cast<Map<String, dynamic>>()
                  .toList();

          if (pageCryptos.isNotEmpty) {
            allCryptos.addAll(pageCryptos);

            if (kDebugMode) {
              print(
                '   ✅ Page $currentPage: Added ${pageCryptos.length} cryptocurrencies (Total: ${allCryptos.length})',
              );
            }
          }

          currentPage++;

          // Small delay between requests to be respectful to the API
          if (currentPage <= _maxPages && allCryptos.length < limit) {
            await Future.delayed(Duration(milliseconds: 500));
          }
        } else {
          if (kDebugMode) {
            print(
              '   ❌ Page $currentPage failed with status: ${response.statusCode}',
            );
          }
          break;
        }
      }

      if (allCryptos.isEmpty) {
        throw Exception(
          'No valid cryptocurrency data received after fetching pages',
        );
      }

      // Remove duplicates by ID (shouldn't happen but safety first)
      final uniqueCryptos = <String, Map<String, dynamic>>{};
      for (final crypto in allCryptos) {
        final id = crypto['id'] as String;
        if (!uniqueCryptos.containsKey(id)) {
          uniqueCryptos[id] = crypto;
        }
      }

      final finalCryptos = uniqueCryptos.values.toList();

      // Cache the comprehensive dataset
      await _cacheTopCryptos(finalCryptos);

      if (kDebugMode) {
        print(
          '✅ Successfully fetched ${finalCryptos.length} cryptocurrencies from $currentPage pages',
        );
        print('   Data cached for ${_cacheTimeout.inHours} hours');
      }

      // Log comprehensive dataset info
      _logDatasetInfo(finalCryptos, 'API_FETCHED');

      await _loggingService.logInfo(
        category: LogCategory.apiCall,
        message: 'Comprehensive cryptocurrency dataset fetched successfully',
        details: {
          'totalFetched': finalCryptos.length,
          'pagesRequested': currentPage - 1,
          'targetReached': finalCryptos.length >= _targetTotalCryptos,
          'apiCallsUsed': _apiCallCount,
          'cacheVersion': '4.0',
        },
        functionName: 'getTopCryptocurrencies',
      );

      return finalCryptos.take(limit).toList();
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ API error during comprehensive fetch: ${e.message}');
      }

      // Return cached data on API errors
      final cachedData = _getCachedTopCryptos();
      if (cachedData != null && cachedData.isNotEmpty) {
        if (kDebugMode) {
          print('🔄 API failed, using cached data as fallback');
        }
        return cachedData.take(limit).toList();
      }

      // Return enhanced fallback data as last resort
      if (kDebugMode) {
        print('📋 No cache available, using enhanced fallback data');
      }
      return getEnhancedFallbackData().take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected error during comprehensive fetch: $e');
      }

      // Always try to return something useful
      final cachedData = _getCachedTopCryptos();
      if (cachedData != null && cachedData.isNotEmpty) {
        return cachedData.take(limit).toList();
      }

      return getEnhancedFallbackData().take(limit).toList();
    }
  }

  /// ENHANCED: Get current price with smart caching and rate limiting
  Future<double?> getCurrentPrice(String cryptoId) async {
    try {
      // Check cache first with extended tolerance during rate limits
      final cachedData = _getCachedTopCryptos();
      if (cachedData != null) {
        final crypto = cachedData.firstWhere(
          (c) => c['id'] == cryptoId,
          orElse: () => <String, dynamic>{},
        );
        if (crypto.isNotEmpty && crypto['current_price'] != null) {
          final price = (crypto['current_price'] as num).toDouble();
          if (price > 0 && !price.isNaN && !price.isInfinite) {
            if (kDebugMode) {
              final rateLimited =
                  _apiCallCount >= _maxCallsPerWindow ? ' (rate limited)' : '';
              print(
                '✅ Using cached price for $cryptoId: \$${price.toStringAsFixed(6)}$rateLimited',
              );
            }
            return price;
          }
        }
      }

      // Don't make individual price calls if rate limited
      if (_apiCallCount >= _maxCallsPerWindow) {
        if (kDebugMode) {
          print(
            '🚫 Rate limited - cannot fetch individual price for $cryptoId',
          );
        }
        return null;
      }

      // Check internet connection
      if (!await _hasInternetConnection()) {
        return null;
      }

      if (kDebugMode) {
        print('🔄 Fetching individual price for: $cryptoId');
      }

      final response = await _dio.get(
        '/simple/price',
        queryParameters: {
          'ids': cryptoId,
          'vs_currencies': 'usd',
          'include_24hr_change': 'true',
          'include_last_updated_at': 'true',
          'precision': '6',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final price = (data[cryptoId]?['usd'] as num?)?.toDouble();

        if (price != null && price > 0 && !price.isNaN && !price.isInfinite) {
          if (kDebugMode) {
            print(
              '✅ Fetched individual price for $cryptoId: \$${price.toStringAsFixed(6)}',
            );
          }
          return price;
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching individual price for $cryptoId: $e');
      }
      return null;
    }
  }

  /// Search cryptocurrencies with enhanced caching
  Future<List<Map<String, dynamic>>> searchCryptocurrencies(
    String query,
  ) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      // First try local cache search
      final cachedData = _getCachedTopCryptos();
      if (cachedData != null) {
        final localResults =
            cachedData.where((crypto) {
              final name = crypto['name'].toString().toLowerCase();
              final symbol = crypto['symbol'].toString().toLowerCase();
              final searchQuery = query.toLowerCase();
              return name.contains(searchQuery) || symbol.contains(searchQuery);
            }).toList();

        // If we have good local results, return them (especially if rate limited)
        if (localResults.length >= 5 || _apiCallCount >= _maxCallsPerWindow) {
          if (kDebugMode) {
            final rateLimited =
                _apiCallCount >= _maxCallsPerWindow ? ' (rate limited)' : '';
            print(
              '✅ Found ${localResults.length} results in cache for "$query"$rateLimited',
            );
          }
          return localResults;
        }
      }

      // Don't make search API calls if rate limited
      if (_apiCallCount >= _maxCallsPerWindow) {
        return cachedData?.where((crypto) {
              final name = crypto['name'].toString().toLowerCase();
              final symbol = crypto['symbol'].toString().toLowerCase();
              final searchQuery = query.toLowerCase();
              return name.contains(searchQuery) || symbol.contains(searchQuery);
            }).toList() ??
            [];
      }

      // Perform API search (counts against rate limit)
      if (!await _hasInternetConnection()) {
        return cachedData?.where((crypto) {
              final name = crypto['name'].toString().toLowerCase();
              final symbol = crypto['symbol'].toString().toLowerCase();
              final searchQuery = query.toLowerCase();
              return name.contains(searchQuery) || symbol.contains(searchQuery);
            }).toList() ??
            [];
      }

      // Make search API call
      final topCryptos = await getTopCryptocurrencies(limit: 100);
      return topCryptos.where((crypto) {
        final name = crypto['name'].toString().toLowerCase();
        final symbol = crypto['symbol'].toString().toLowerCase();
        final searchQuery = query.toLowerCase();
        return name.contains(searchQuery) || symbol.contains(searchQuery);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Search error: $e');
      }

      // Return cached results on error
      final cachedData = _getCachedTopCryptos();
      return cachedData?.where((crypto) {
            final name = crypto['name'].toString().toLowerCase();
            final symbol = crypto['symbol'].toString().toLowerCase();
            final searchQuery = query.toLowerCase();
            return name.contains(searchQuery) || symbol.contains(searchQuery);
          }).toList() ??
          [];
    }
  }

  /// Get cryptocurrency details with caching
  Future<Map<String, dynamic>?> getCryptocurrencyDetails(
    String cryptoId,
  ) async {
    try {
      // Check cache first
      final cachedData = _getCachedTopCryptos();
      if (cachedData != null) {
        final crypto = cachedData.firstWhere(
          (c) => c['id'] == cryptoId,
          orElse: () => <String, dynamic>{},
        );
        if (crypto.isNotEmpty) {
          return crypto;
        }
      }

      // Don't make detail calls if rate limited
      if (_apiCallCount >= _maxCallsPerWindow) {
        if (kDebugMode) {
          print('🚫 Rate limited - using basic cached info for $cryptoId');
        }
        return null;
      }

      if (!await _hasInternetConnection()) {
        return null;
      }

      if (kDebugMode) {
        print('🔄 Fetching detailed info for: $cryptoId');
      }

      final response = await _dio.get('/coins/$cryptoId');

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'id': data['id'] ?? '',
          'symbol': data['symbol'] ?? '',
          'name': data['name'] ?? '',
          'image': data['image']?['large'] ?? data['image']?['small'] ?? '',
          'current_price':
              (data['market_data']?['current_price']?['usd'] ?? 0.0).toDouble(),
          'market_cap':
              (data['market_data']?['market_cap']?['usd'] ?? 0.0).toDouble(),
          'market_cap_rank': data['market_cap_rank'] ?? 0,
          'price_change_percentage_24h':
              (data['market_data']?['price_change_percentage_24h'] ?? 0.0)
                  .toDouble(),
          'total_volume':
              (data['market_data']?['total_volume']?['usd'] ?? 0.0).toDouble(),
          'circulating_supply':
              (data['market_data']?['circulating_supply'] ?? 0.0).toDouble(),
          'total_supply':
              (data['market_data']?['total_supply'] ?? 0.0).toDouble(),
          'max_supply': data['market_data']?['max_supply']?.toDouble(),
          'last_updated': DateTime.now().toIso8601String(),
        };
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching details for $cryptoId: $e');
      }
      return null;
    }
  }

  /// NEW: Get current API status and comprehensive diagnostics
  Future<Map<String, dynamic>> getApiStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Calculate time until rate limit reset
    final windowStart =
        _lastApiCall != null
            ? _lastApiCall!.subtract(Duration(hours: _apiCallCount > 0 ? 8 : 0))
            : now.subtract(_rateLimitWindow);
    final windowEnd = windowStart.add(_rateLimitWindow);
    final timeUntilReset =
        windowEnd.isAfter(now) ? windowEnd.difference(now) : Duration.zero;

    // Get cached dataset info
    final cachedData = _getCachedTopCryptos();
    final datasetStats =
        cachedData != null
            ? {
              'totalCryptos': cachedData.length,
              'topTierCount':
                  cachedData
                      .where((c) => (c['market_cap_rank'] ?? 999) <= 50)
                      .length,
              'targetReached': cachedData.length >= _targetTotalCryptos,
            }
            : null;

    return {
      'timestamp': now.toIso8601String(),
      'version': '4.0',
      'rateLimiting': {
        'currentCalls': _apiCallCount,
        'maxCalls': _maxCallsPerWindow,
        'windowDuration': _rateLimitWindow.inHours,
        'timeUntilReset': timeUntilReset.inMinutes,
        'isRateLimited': _apiCallCount >= _maxCallsPerWindow,
      },
      'caching': {
        'hasPriceCache': _cachedTopCryptos != null,
        'cacheAge':
            _lastCacheUpdate != null
                ? now.difference(_lastCacheUpdate!).inMinutes
                : null,
        'cacheTimeout': _cacheTimeout.inHours,
        'historicalCacheCount': _historicalDataCache.length,
      },
      'dataset': datasetStats,
      'targets': {
        'targetTotalCryptos': _targetTotalCryptos,
        'maxCryptosPerPage': _maxCryptosPerPage,
        'maxPages': _maxPages,
      },
      'connectivity': await _hasInternetConnection(),
      'lastApiCall': _lastApiCall?.toIso8601String(),
    };
  }

  /// ENHANCED: Expanded fallback data with more comprehensive cryptocurrency coverage
  List<Map<String, dynamic>> getEnhancedFallbackData() {
    final now = DateTime.now().toIso8601String();
    return [
      // Top 10 by Market Cap
      {
        'id': 'bitcoin',
        'symbol': 'btc',
        'name': 'Bitcoin',
        'image':
            'https://assets.coingecko.com/coins/images/1/large/bitcoin.png',
        'current_price': 95420.0,
        'market_cap': 1890000000000.0,
        'market_cap_rank': 1,
        'price_change_percentage_24h': 1.8,
        'total_volume': 45000000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'ethereum',
        'symbol': 'eth',
        'name': 'Ethereum',
        'image':
            'https://assets.coingecko.com/coins/images/279/large/ethereum.png',
        'current_price': 3485.0,
        'market_cap': 420000000000.0,
        'market_cap_rank': 2,
        'price_change_percentage_24h': 2.1,
        'total_volume': 18000000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'binancecoin',
        'symbol': 'bnb',
        'name': 'BNB',
        'image':
            'https://assets.coingecko.com/coins/images/825/large/bnb-icon2_2x.png',
        'current_price': 685.0,
        'market_cap': 98000000000.0,
        'market_cap_rank': 3,
        'price_change_percentage_24h': 0.5,
        'total_volume': 2100000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'solana',
        'symbol': 'sol',
        'name': 'Solana',
        'image':
            'https://assets.coingecko.com/coins/images/4128/large/solana.png',
        'current_price': 245.0,
        'market_cap': 118000000000.0,
        'market_cap_rank': 4,
        'price_change_percentage_24h': -1.2,
        'total_volume': 4500000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'ripple',
        'symbol': 'xrp',
        'name': 'XRP',
        'image':
            'https://assets.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png',
        'current_price': 2.32,
        'market_cap': 133000000000.0,
        'market_cap_rank': 5,
        'price_change_percentage_24h': 3.8,
        'total_volume': 8500000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'cardano',
        'symbol': 'ada',
        'name': 'Cardano',
        'image':
            'https://assets.coingecko.com/coins/images/975/large/cardano.png',
        'current_price': 1.15,
        'market_cap': 40000000000.0,
        'market_cap_rank': 6,
        'price_change_percentage_24h': 2.5,
        'total_volume': 1800000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'dogecoin',
        'symbol': 'doge',
        'name': 'Dogecoin',
        'image':
            'https://assets.coingecko.com/coins/images/5/large/dogecoin.png',
        'current_price': 0.42,
        'market_cap': 62000000000.0,
        'market_cap_rank': 7,
        'price_change_percentage_24h': 4.2,
        'total_volume': 3200000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'avalanche-2',
        'symbol': 'avax',
        'name': 'Avalanche',
        'image':
            'https://assets.coingecko.com/coins/images/12559/large/Avalanche_Circle_RedWhite_Trans.png',
        'current_price': 45.8,
        'market_cap': 18000000000.0,
        'market_cap_rank': 8,
        'price_change_percentage_24h': -0.8,
        'total_volume': 850000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'chainlink',
        'symbol': 'link',
        'name': 'Chainlink',
        'image':
            'https://assets.coingecko.com/coins/images/877/large/chainlink-new-logo.png',
        'current_price': 25.4,
        'market_cap': 15000000000.0,
        'market_cap_rank': 9,
        'price_change_percentage_24h': 1.9,
        'total_volume': 420000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'polygon',
        'symbol': 'matic',
        'name': 'Polygon',
        'image':
            'https://assets.coingecko.com/coins/images/4713/large/matic-token-icon.png',
        'current_price': 0.58,
        'market_cap': 5800000000.0,
        'market_cap_rank': 10,
        'price_change_percentage_24h': 3.1,
        'total_volume': 280000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      // Additional popular cryptocurrencies for better selection
      {
        'id': 'polkadot',
        'symbol': 'dot',
        'name': 'Polkadot',
        'image':
            'https://assets.coingecko.com/coins/images/12171/large/polkadot.png',
        'current_price': 8.95,
        'market_cap': 12000000000.0,
        'market_cap_rank': 11,
        'price_change_percentage_24h': 1.2,
        'total_volume': 320000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'litecoin',
        'symbol': 'ltc',
        'name': 'Litecoin',
        'image':
            'https://assets.coingecko.com/coins/images/2/large/litecoin.png',
        'current_price': 108.5,
        'market_cap': 8100000000.0,
        'market_cap_rank': 12,
        'price_change_percentage_24h': 0.9,
        'total_volume': 650000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'uniswap',
        'symbol': 'uni',
        'name': 'Uniswap',
        'image':
            'https://assets.coingecko.com/coins/images/12504/large/uniswap-uni.png',
        'current_price': 15.8,
        'market_cap': 9500000000.0,
        'market_cap_rank': 13,
        'price_change_percentage_24h': 2.4,
        'total_volume': 180000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'stellar',
        'symbol': 'xlm',
        'name': 'Stellar',
        'image':
            'https://assets.coingecko.com/coins/images/100/large/Stellar_symbol_black_RGB.png',
        'current_price': 0.465,
        'market_cap': 14000000000.0,
        'market_cap_rank': 14,
        'price_change_percentage_24h': 1.8,
        'total_volume': 420000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
      {
        'id': 'cosmos',
        'symbol': 'atom',
        'name': 'Cosmos',
        'image':
            'https://assets.coingecko.com/coins/images/1481/large/cosmos_hub.png',
        'current_price': 7.25,
        'market_cap': 2800000000.0,
        'market_cap_rank': 15,
        'price_change_percentage_24h': -0.5,
        'total_volume': 95000000.0,
        'last_updated': now,
        'is_fallback': true,
      },
    ];
  }

  /// Keep backward compatibility
  List<Map<String, dynamic>> getFallbackData() {
    return getEnhancedFallbackData();
  }

  /// Get cached data if available
  List<Map<String, dynamic>>? getCachedData() {
    return _getCachedTopCryptos();
  }
}
