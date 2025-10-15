import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/services/crypto_service.dart';
import '../../core/services/pl_persistence_service.dart';
import '../../core/services/portfolio_service.dart';
import '../../core/services/transaction_service.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_icon_widget.dart';
import '../../widgets/custom_image_widget.dart';
import './widgets/crypto_holding_card.dart';
import './widgets/empty_portfolio_widget.dart';
import './widgets/individual_transaction_tile.dart';
import './widgets/portfolio_summary_card.dart';

// NEW: Import P&L persistence service

class PortfolioDashboard extends StatefulWidget {
  const PortfolioDashboard({super.key});

  @override
  State<PortfolioDashboard> createState() => _PortfolioDashboardState();
}

class _PortfolioDashboardState extends State<PortfolioDashboard>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  late AnimationController _refreshAnimationController;
  late Timer _priceUpdateTimer;
  late StreamSubscription<List<Map<String, dynamic>>> _portfolioSubscription;

  final CryptoService _cryptoService = CryptoService();
  final TransactionService _transactionService = TransactionService.instance;
  final PortfolioService _portfolioService = PortfolioService.instance;
  final PLPersistenceService _plPersistenceService =
      PLPersistenceService.instance; // NEW: P&L persistence service

  bool _isLoading = true;
  bool _isRefreshing = false;
  DateTime _lastUpdated = DateTime.now();
  int _currentTabIndex = 0;

  // Real portfolio data from services
  List<Map<String, dynamic>> _cryptoHoldings = [];
  List<Map<String, dynamic>> _allTransactions = [];
  Map<String, dynamic> _portfolioSummary = {};

  // NEW: Track if we're using cached data to show appropriate indicators
  bool _isUsingCachedSummary = false;

  // NEW: Toggle between views
  bool _showIndividualTransactions = true; // Default to individual view

  // NEW: Track P&L restoration state
  bool _plRestoredFromPersistence = false;

  // NEW: P&L validation tracking variables
  bool isConsistent = false;
  Map<String, dynamic>? diagnosticsData;

  // NEW: Track manual refresh state
  bool _isManualRefresh = false;

  // NEW: Error state tracking
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });

    // Subscribe to portfolio updates stream
    _portfolioSubscription = _portfolioService.portfolioStream.listen((
      holdings,
    ) {
      if (mounted) {
        setState(() {
          _cryptoHoldings = holdings;
          _lastUpdated = DateTime.now();
        });
        _updatePortfolioSummary();
      }
    });

    // Start automatic price updates every 10 minutes
    _startPriceUpdateTimer();

    // ANDROID FIX: Enhanced initialization with guaranteed data availability
    _initializePortfolioDataRobust();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshAnimationController.dispose();
    _priceUpdateTimer.cancel();
    _portfolioSubscription.cancel();
    super.dispose();
  }

  void _startPriceUpdateTimer() {
    _priceUpdateTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (mounted && !_isRefreshing) {
        _refreshPrices(isAutomatic: true);
      }
    });
  }

  /// STARTUP FIX: Enhanced initialization with immediate data availability guarantee
  Future<void> _initializePortfolioDataRobust() async {
    if (kDebugMode) {
      print('📱 STARTUP FIX: Starting enhanced dashboard initialization...');
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // STEP 1: Initialize portfolio service with data guarantee
      await _portfolioService.initializeForAndroid();

      // STEP 2: CRITICAL - Synchronous P&L data loading check
      await _performStartupDataCheck();

      // STEP 3: Load transactions synchronously
      await _loadAllTransactions();

      // STEP 4: Load crypto holdings with existing data
      try {
        final holdings =
            await _portfolioService.getPortfolioWithCurrentPrices();
        if (mounted && holdings.isNotEmpty) {
          setState(() {
            _cryptoHoldings = holdings;
          });
          if (kDebugMode) {
            print(
              '✅ STARTUP FIX: Loaded ${holdings.length} crypto holdings immediately',
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ STARTUP FIX: Could not load crypto holdings: $e');
        }
      }

      // STEP 5: Validate final state before showing dashboard
      if (mounted) {
        await _validateStartupDataIntegrity();

        // ALWAYS ensure loading is false at the end
        setState(() {
          _isLoading = false;
          _lastUpdated = DateTime.now();
        });

        // STEP 6: Ensure P&L persistence for future restarts
        await _ensurePLPersistence();

        if (kDebugMode) {
          final finalTotalValue =
              (_portfolioSummary['totalValue'] as num?)?.toDouble() ?? 0.0;
          final finalPL =
              (_portfolioSummary['profitLoss'] as num?)?.toDouble() ?? 0.0;
          print('✅ STARTUP FIX: Dashboard initialization completed:');
          print('   📊 Value: \$${finalTotalValue.toStringAsFixed(2)}');
          print('   💰 P&L: \$${finalPL.toStringAsFixed(2)}');
          print('   🏠 Holdings count: ${_cryptoHoldings.length}');
          print('   📄 Transactions count: ${_allTransactions.length}');
          print('   🔄 Should show empty: ${_shouldShowEmptyState()}');
          print('   ⚡ Startup optimization: COMPLETE');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ STARTUP FIX: Enhanced dashboard initialization error: $e');
      }

      // Fallback to restore any available data
      await _attemptDataRecovery();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// STARTUP FIX: Perform comprehensive startup data check
  Future<void> _performStartupDataCheck() async {
    try {
      // Check P&L persistence service first
      final plSnapshot = await _plPersistenceService.loadPLSnapshot();
      if (plSnapshot != null) {
        // We have persisted P&L data - use it immediately
        _portfolioSummary = {
          'totalValue': plSnapshot['totalValue'],
          'totalInvested': plSnapshot['totalInvested'],
          'profitLoss': plSnapshot['profitLoss'],
          'percentageChange': plSnapshot['percentageChange'],
          'totalHoldings': plSnapshot['transactionCount'] ?? 0,
          'lastUpdated':
              plSnapshot['dateString'] ?? DateTime.now().toIso8601String(),
          'restoredFromPersistence': true,
          'startupOptimized': true, // Mark as startup optimized
        };

        _plRestoredFromPersistence = true;

        if (kDebugMode) {
          print('✅ STARTUP FIX: P&L data loaded immediately from persistence:');
          print(
            '   💰 P&L: \$${(plSnapshot['profitLoss'] as num).toStringAsFixed(2)}',
          );
          print(
            '   📊 Value: \$${(plSnapshot['totalValue'] as num).toStringAsFixed(2)}',
          );
          print(
            '   💵 Invested: \$${(plSnapshot['totalInvested'] as num).toStringAsFixed(2)}',
          );
        }

        // CRITICAL: Update UI immediately with restored data and prevent empty state
        if (mounted) {
          setState(() {
            _isLoading = false; // Prevent empty state from showing
          });
        }
      } else {
        if (kDebugMode) {
          print(
            '⚠️ STARTUP FIX: No P&L persistence data found - checking portfolio service',
          );
        }

        // Try to get data from portfolio service
        final summary = await _portfolioService.getCachedPortfolioSummary();
        if (summary.isNotEmpty) {
          final totalValue = (summary['totalValue'] as num?)?.toDouble() ?? 0.0;
          final totalInvested =
              (summary['totalInvested'] as num?)?.toDouble() ?? 0.0;

          if (totalValue > 0 || totalInvested > 0) {
            _portfolioSummary = summary;

            if (kDebugMode) {
              print('✅ STARTUP FIX: Portfolio data loaded from service cache');
            }

            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ STARTUP FIX: Startup data check failed: $e');
      }
    }
  }

  /// STARTUP FIX: Validate startup data integrity
  Future<void> _validateStartupDataIntegrity() async {
    try {
      final totalValue =
          (_portfolioSummary['totalValue'] as num?)?.toDouble() ?? 0.0;
      final totalInvested =
          (_portfolioSummary['totalInvested'] as num?)?.toDouble() ?? 0.0;
      final profitLoss =
          (_portfolioSummary['profitLoss'] as num?)?.toDouble() ?? 0.0;

      if (kDebugMode) {
        print('🔍 STARTUP FIX: Data integrity validation:');
        print('   💰 Total Value: \$${totalValue.toStringAsFixed(2)}');
        print('   💵 Total Invested: \$${totalInvested.toStringAsFixed(2)}');
        print('   📊 Profit/Loss: \$${profitLoss.toStringAsFixed(2)}');
        print('   📄 Transactions: ${_allTransactions.length}');
        print('   🏠 Holdings: ${_cryptoHoldings.length}');
      }

      // If we detect zero values but should have data, attempt recovery
      if (totalValue == 0.0 &&
          totalInvested == 0.0 &&
          profitLoss == 0.0 &&
          _allTransactions.isNotEmpty) {
        if (kDebugMode) {
          print(
            '⚠️ STARTUP FIX: Zero values detected with transactions - attempting recovery',
          );
        }

        // Force portfolio service recalculation
        await _portfolioService.refreshPortfolioData();

        // Reload data
        final freshSummary =
            await _portfolioService.getCachedPortfolioSummary();
        if (freshSummary.isNotEmpty) {
          setState(() {
            _portfolioSummary = freshSummary;
          });

          if (kDebugMode) {
            final recoveredPL =
                (freshSummary['profitLoss'] as num?)?.toDouble() ?? 0.0;
            print(
              '✅ STARTUP FIX: Data recovered - P&L: \$${recoveredPL.toStringAsFixed(2)}',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ STARTUP FIX: Data integrity validation failed: $e');
      }
    }
  }

  /// STARTUP FIX: Attempt data recovery on initialization failure
  Future<void> _attemptDataRecovery() async {
    try {
      if (kDebugMode) {
        print('🔄 STARTUP FIX: Attempting data recovery...');
      }

      // Try to load any available data
      final plSnapshot = await _plPersistenceService.loadPLSnapshot();
      if (plSnapshot != null) {
        _portfolioSummary = {
          'totalValue': plSnapshot['totalValue'],
          'totalInvested': plSnapshot['totalInvested'],
          'profitLoss': plSnapshot['profitLoss'],
          'percentageChange': plSnapshot['percentageChange'],
          'totalHoldings': plSnapshot['transactionCount'] ?? 0,
          'lastUpdated':
              plSnapshot['dateString'] ?? DateTime.now().toIso8601String(),
          'recoveredFromPersistence': true,
        };

        if (kDebugMode) {
          final recoveredPL = (plSnapshot['profitLoss'] as num).toDouble();
          print(
            '🔄 STARTUP FIX: Data recovered from persistence: \$${recoveredPL.toStringAsFixed(2)}',
          );
        }
      }

      // Try to load transactions
      await _loadAllTransactions();
    } catch (e) {
      if (kDebugMode) {
        print('❌ STARTUP FIX: Data recovery failed: $e');
      }

      // Final fallback
      _portfolioSummary = {
        'totalValue': 0.0,
        'totalInvested': 0.0,
        'percentageChange': 0.0,
        'profitLoss': 0.0,
        'totalHoldings': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
        'fallbackState': true,
      };
    }
  }

  /// STARTUP FIX: Enhanced empty state detection with startup optimization
  bool _shouldShowEmptyState() {
    if (kDebugMode) {
      print('🔍 STARTUP FIX: Enhanced empty state check:');
      print('   Portfolio value: \$${_totalPortfolioValue.toStringAsFixed(2)}');
      print('   Holdings count: ${_cryptoHoldings.length}');
      print('   Transactions count: ${_allTransactions.length}');
      print('   Is loading: $_isLoading');
      print('   PL restored from persistence: $_plRestoredFromPersistence');
      print('   Summary cache exists: ${_portfolioSummary.isNotEmpty}');
    }

    // STARTUP FIX: NEVER show empty state if we're loading and have any data
    if (_isLoading &&
        (_plRestoredFromPersistence || _portfolioSummary.isNotEmpty)) {
      if (kDebugMode) {
        print('   ✅ STARTUP FIX: Not empty - loading with data available');
      }
      return false;
    }

    // If we have a meaningful portfolio value, don't show empty state
    if (_totalPortfolioValue > 0) {
      if (kDebugMode) {
        print('   ✅ STARTUP FIX: Not empty - portfolio value > 0');
      }
      return false;
    }

    // If we have crypto holdings, don't show empty state
    if (_cryptoHoldings.isNotEmpty) {
      if (kDebugMode) {
        print('   ✅ STARTUP FIX: Not empty - has crypto holdings');
      }
      return false;
    }

    // If we have transactions, don't show empty state
    if (_allTransactions.isNotEmpty) {
      if (kDebugMode) {
        print('   ✅ STARTUP FIX: Not empty - has transactions');
      }
      return false;
    }

    // STARTUP FIX: Check if we have any persisted portfolio summary data
    if (_portfolioSummary.isNotEmpty) {
      final totalValue =
          (_portfolioSummary['totalValue'] as num?)?.toDouble() ?? 0.0;
      final totalInvested =
          (_portfolioSummary['totalInvested'] as num?)?.toDouble() ?? 0.0;

      if (totalValue > 0 || totalInvested > 0) {
        if (kDebugMode) {
          print('   ✅ STARTUP FIX: Not empty - has portfolio summary data');
        }
        return false;
      }
    }

    // STARTUP FIX: Additional check for P&L restoration state
    if (_plRestoredFromPersistence) {
      if (kDebugMode) {
        print(
          '   ✅ STARTUP FIX: Not empty - P&L was restored from persistence',
        );
      }
      return false;
    }

    // Only show empty state if we truly have no data AND we're not loading
    if (kDebugMode) {
      print(
        '   ❌ STARTUP FIX: Showing empty state - no data found and not loading',
      );
    }
    return !_isLoading;
  }

  /// NEW: Background portfolio refresh without blocking UI
  Future<void> _refreshPortfolioInBackground() async {
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      try {
        if (kDebugMode) {
          print('🔄 Background portfolio refresh starting...');
        }

        // Refresh portfolio data in background
        await _portfolioService.refreshPortfolioData();
        final freshSummary =
            await _portfolioService.getCachedPortfolioSummary();
        final freshHoldings =
            await _portfolioService.getPortfolioWithCurrentPrices();

        // Update UI if values have changed significantly
        final currentPL =
            (_portfolioSummary['profitLoss'] as num?)?.toDouble() ?? 0.0;
        final freshPL = (freshSummary['profitLoss'] as num?)?.toDouble() ?? 0.0;

        if ((currentPL - freshPL).abs() > 0.01 && mounted) {
          setState(() {
            _portfolioSummary = freshSummary;
            _cryptoHoldings = freshHoldings;
            _lastUpdated = DateTime.now();
            _isUsingCachedSummary = false;
          });

          if (kDebugMode) {
            print(
              '🔄 Background refresh updated P&L: \$${freshPL.toStringAsFixed(2)}',
            );
          }

          // Persist the fresh data
          await _ensurePLPersistence();
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Background refresh failed: $e');
        }
      }
    });
  }

  /// NEW: Ensure P&L data is persisted
  Future<void> _ensurePLPersistence() async {
    try {
      final totalValue =
          (_portfolioSummary['totalValue'] as num?)?.toDouble() ?? 0.0;
      final totalInvested =
          (_portfolioSummary['totalInvested'] as num?)?.toDouble() ?? 0.0;
      final profitLoss = (_portfolioSummary['profitLoss'] as num?)?.toDouble();
      final percentageChange =
          (_portfolioSummary['percentageChange'] as num?)?.toDouble() ?? 0.0;

      // Calculate P&L if missing
      final finalPL = profitLoss ?? (totalValue - totalInvested);

      // Validate P&L consistency with complete type safety - NO direct assignment
      final plValidationResult = await _plPersistenceService
          .validatePLConsistency(
            totalValue: totalValue,
            totalInvested: totalInvested,
            profitLoss: finalPL,
          );

      // BULLETPROOF: Process validation result with complete type safety
      bool validationSuccessful = false;
      Map<String, dynamic>? validationDiagnosticsMap;

      // ULTRA-SAFE: Type checking and processing without any dangerous assignments
      try {
        // Handle different possible return types from validatePLConsistency
        if (plValidationResult is bool) {
          // Direct boolean result
          validationSuccessful = plValidationResult as bool;
          if (kDebugMode) {
            print('🔧 P&L validation result: $validationSuccessful (boolean)');
          }
        } else {
          // Map result - extract the boolean value
          validationDiagnosticsMap = Map<String, dynamic>.from(
            plValidationResult as Map,
          );

          // Safely extract isConsistent value with null safety
          final dynamic consistentValue =
              validationDiagnosticsMap['isConsistent'];

          // Convert various types to boolean with complete safety
          if (consistentValue is bool) {
            validationSuccessful = consistentValue;
          } else if (consistentValue is String) {
            validationSuccessful = consistentValue.toLowerCase() == 'true';
          } else if (consistentValue is int) {
            validationSuccessful = consistentValue == 1;
          } else if (consistentValue is num) {
            validationSuccessful = consistentValue != 0;
          } else {
            // Default for null or unknown types
            validationSuccessful = false;
          }

          if (kDebugMode) {
            print('🔧 P&L validation result: $validationSuccessful (from map)');
            if (validationDiagnosticsMap.containsKey('diagnostics')) {
              print(
                '   📋 Diagnostics: ${validationDiagnosticsMap['diagnostics']}',
              );
            }
          }
        }
      } catch (typeProcessingError) {
        // Ultimate safety net for any type processing errors
        validationSuccessful = false;
        if (kDebugMode) {
          print(
            '❌ Error processing P&L validation result: $typeProcessingError',
          );
          print('   Using ultra-safe fallback: validation = false');
        }
      }

      // Store the safely processed boolean result
      isConsistent = validationSuccessful;

      if (!isConsistent) {
        // Recalculate P&L for consistency
        final correctedPL = totalValue - totalInvested;
        _portfolioSummary['profitLoss'] = correctedPL;
        _portfolioSummary['percentageChange'] =
            totalInvested != 0.0
                ? (correctedPL / totalInvested.abs()) * 100
                : 0.0;

        if (kDebugMode) {
          print(
            '🔧 P&L consistency corrected: \$${correctedPL.toStringAsFixed(2)}',
          );
          if (validationDiagnosticsMap != null &&
              validationDiagnosticsMap.containsKey('reason')) {
            print(
              '   📋 Correction reason: ${validationDiagnosticsMap['reason'] ?? 'Validation failed'}',
            );
          }
        }
      }

      // Save P&L snapshot for persistence
      await _plPersistenceService.savePLSnapshot(
        totalValue: totalValue,
        totalInvested: totalInvested,
        profitLoss: _portfolioSummary['profitLoss'] as double,
        percentageChange: _portfolioSummary['percentageChange'] as double,
        transactionCount: _allTransactions.length,
        additionalData: {
          'holdingsCount': _cryptoHoldings.length,
          'calculationTimestamp': DateTime.now().millisecondsSinceEpoch,
          'validationPassed': isConsistent,
          'diagnosticsAvailable': validationDiagnosticsMap != null,
        },
      );

      if (kDebugMode) {
        final plValue = _portfolioSummary['profitLoss'] as double;
        print('💾 P&L persistence ensured: \$${plValue.toStringAsFixed(2)}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ P&L persistence failed: $e');
        print('   Stack trace: $stackTrace');
      }

      // Fallback: Still attempt to save basic P&L data without validation
      try {
        final totalValue =
            (_portfolioSummary['totalValue'] as num?)?.toDouble() ?? 0.0;
        final totalInvested =
            (_portfolioSummary['totalInvested'] as num?)?.toDouble() ?? 0.0;
        final basicPL = totalValue - totalInvested;

        _portfolioSummary['profitLoss'] = basicPL;
        _portfolioSummary['percentageChange'] =
            totalInvested != 0.0 ? (basicPL / totalInvested.abs()) * 100 : 0.0;

        await _plPersistenceService.savePLSnapshot(
          totalValue: totalValue,
          totalInvested: totalInvested,
          profitLoss: basicPL,
          percentageChange: _portfolioSummary['percentageChange'] as double,
          transactionCount: _allTransactions.length,
          additionalData: {
            'holdingsCount': _cryptoHoldings.length,
            'calculationTimestamp': DateTime.now().millisecondsSinceEpoch,
            'fallbackSave': true,
            'originalError': e.toString(),
          },
        );

        if (kDebugMode) {
          print(
            '🔄 Fallback P&L persistence completed: \$${basicPL.toStringAsFixed(2)}',
          );
        }
      } catch (fallbackError) {
        if (kDebugMode) {
          print('❌ Fallback P&L persistence also failed: $fallbackError');
        }
      }
    }
  }

  /// Load portfolio data with clean calculation - renamed to avoid conflicts
  Future<void> _loadPortfolioDataInternal() async {
    try {
      // FIXED: Ensure we get fresh data by forcing calculation if needed
      final summary = await _portfolioService.getCachedPortfolioSummary();
      final holdings = await _portfolioService.getPortfolioWithCurrentPrices();

      // FIXED: Validate that we have meaningful data
      final totalValue = (summary['totalValue'] as num?)?.toDouble() ?? 0.0;
      final totalInvested =
          (summary['totalInvested'] as num?)?.toDouble() ?? 0.0;

      if (kDebugMode) {
        print(
          '📊 Loaded portfolio data: Value=\$${totalValue.toStringAsFixed(2)}, Invested=\$${totalInvested.toStringAsFixed(2)}',
        );
      }

      if (mounted) {
        setState(() {
          _portfolioSummary = summary;
          _cryptoHoldings = holdings;
          _isUsingCachedSummary = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading portfolio data: $e');
      }
    }
  }

  /// ENHANCED: Navigation to add transaction with P&L persistence
  void _navigateToAddTransaction() async {
    final result = await Navigator.pushNamed(context, AppRoutes.addTransaction);

    // Force refresh and ensure P&L persistence after transaction
    if (result == true || result == null) {
      await _refreshPrices();

      // Notify portfolio service about new transaction for immediate P&L persistence
      await _portfolioService.onTransactionAdded();

      // Ensure P&L is persisted after transaction
      await _ensurePLPersistence();

      if (kDebugMode) {
        print('💾 P&L persistence updated after transaction');
      }
    }
  }

  /// ENHANCED: Refresh with P&L persistence
  Future<void> _refreshPrices({bool isAutomatic = false}) async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      if (!isAutomatic) _isLoading = true;
    });

    if (!isAutomatic) {
      HapticFeedback.lightImpact();
      _refreshAnimationController.repeat();
    }

    try {
      if (kDebugMode) {
        print('🔄 Starting enhanced portfolio refresh with P&L persistence...');
      }

      // Refresh portfolio data
      await _portfolioService.refreshPortfolioData();

      // Get fresh data
      await _loadPortfolioDataInternal();

      // Reload transactions
      await _loadAllTransactions();

      // CRITICAL: Ensure P&L persistence after refresh
      await _ensurePLPersistence();

      if (kDebugMode) {
        final totalValue =
            (_portfolioSummary['totalValue'] as num?)?.toDouble() ?? 0.0;
        final profitLoss =
            (_portfolioSummary['profitLoss'] as num?)?.toDouble() ?? 0.0;
        print('✅ Enhanced portfolio refresh completed:');
        print('   📊 Value: \$${totalValue.toStringAsFixed(2)}');
        print('   💰 P&L: \$${profitLoss.toStringAsFixed(2)}');
      }

      // Schedule next automatic refresh
      if (isAutomatic) {
        _schedulePeriodicRefresh();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Enhanced portfolio refresh failed: $e');
      }

      if (!isAutomatic && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Update failed. Please try again.',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            backgroundColor: AppTheme.getWarningColor(
              Theme.of(context).brightness == Brightness.light,
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _refreshPrices(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _isLoading = false;
        });

        if (!isAutomatic) {
          _refreshAnimationController.stop();
          _refreshAnimationController.reset();
        }
      }
    }
  }

  /// Simplified portfolio summary update
  Future<void> _updatePortfolioSummary() async {
    if (_isRefreshing) return;

    try {
      final summary = await _portfolioService.getCachedPortfolioSummary();

      if (mounted) {
        setState(() {
          _portfolioSummary = summary;
          _isUsingCachedSummary = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating portfolio summary: $e');
      }
    }
  }

  /// Enhanced value getters with proper fallbacks
  double get _totalPortfolioValue {
    final summaryValue =
        (_portfolioSummary['totalValue'] as num?)?.toDouble() ?? 0.0;

    if (summaryValue > 0) {
      return summaryValue;
    }

    // Calculate from holdings if summary is zero
    if (_cryptoHoldings.isNotEmpty) {
      double calculatedValue = 0.0;
      for (final holding in _cryptoHoldings) {
        final currentPrice =
            (holding['currentPrice'] as num?)?.toDouble() ?? 0.0;
        final holdings = (holding['holdings'] as num?)?.toDouble() ?? 0.0;

        if (currentPrice > 0 && holdings > 0) {
          calculatedValue += (currentPrice * holdings);
        }
      }

      if (calculatedValue > 0) {
        return calculatedValue;
      }
    }

    return summaryValue; // Return even if zero
  }

  double get _totalInvested {
    final summaryValue =
        (_portfolioSummary['totalInvested'] as num?)?.toDouble() ?? 0.0;

    if (summaryValue != 0.0) {
      return summaryValue;
    }

    // Calculate from holdings if summary is zero
    if (_cryptoHoldings.isNotEmpty) {
      double calculatedValue = 0.0;
      for (final holding in _cryptoHoldings) {
        final totalInvested =
            (holding['total_invested'] as num?)?.toDouble() ?? 0.0;
        calculatedValue += totalInvested.abs(); // FIXED: Ensure positive values
      }
      return calculatedValue;
    }

    return summaryValue;
  }

  double get _portfolioPercentageChange {
    final summaryValue =
        (_portfolioSummary['percentageChange'] as num?)?.toDouble() ?? 0.0;

    if (summaryValue != 0.0) {
      return summaryValue;
    }

    // Calculate from current values if needed
    final totalValue = _totalPortfolioValue;
    final totalInvested = _totalInvested;

    if (totalInvested != 0.0) {
      final profitLoss = totalValue - totalInvested;
      return (profitLoss / totalInvested.abs()) * 100;
    }

    return 0.0;
  }

  // FIXED: Add profit/loss getter for better data access
  double get _portfolioProfitLoss {
    final summaryValue = (_portfolioSummary['profitLoss'] as num?)?.toDouble();

    if (summaryValue != null) {
      return summaryValue;
    }

    // Calculate from current values
    final totalValue = _totalPortfolioValue;
    final totalInvested = _totalInvested;
    return totalValue - totalInvested;
  }

  /// ENHANCED: Refresh with manual refresh capability and 429 error prevention
  Future<void> _refreshPortfolio() async {
    if (_isLoading) return;

    try {
      setState(() {
        _isLoading = true;
        _isManualRefresh = true; // Mark as manual refresh
      });

      if (kDebugMode) {
        print('🔄 Manual portfolio refresh initiated...');
      }

      // Use manual refresh method to bypass rate limits when user explicitly requests
      await PortfolioService.instance.forceManualRefresh();

      // Reload the data
      await _loadPortfolioDataInternal();

      if (kDebugMode) {
        print('✅ Manual portfolio refresh completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Manual portfolio refresh failed: $e');
      }

      // Show user-friendly error message
      if (e.toString().contains('429') ||
          e.toString().contains('rate') ||
          e.toString().contains('limit')) {
        setState(() {
          _error =
              'Rate limit reached. Using cached data. Please try again in a few hours.';
        });
      } else {
        setState(() {
          _error = 'Failed to refresh portfolio. Using cached data.';
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
        _isManualRefresh = false;
      });
    }
  }

  /// NEW: Schedule periodic refresh with intelligent timing
  void _schedulePeriodicRefresh() {
    // Schedule next refresh in 8 hours to respect rate limits
    Timer(const Duration(hours: 8), () {
      if (mounted && !_isRefreshing) {
        _refreshPrices(isAutomatic: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    // Enhanced loading check - show spinner only if no persisted data is available
    if (_isLoading &&
        _cryptoHoldings.isEmpty &&
        _allTransactions.isEmpty &&
        !_isUsingCachedSummary &&
        !_plRestoredFromPersistence) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              SizedBox(height: 2.h),
              Text(
                'Loading your portfolio...',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (_plRestoredFromPersistence) ...[
                SizedBox(height: 1.h),
                Text(
                  'P&L data restored from cache',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child:
                _shouldShowEmptyState()
                    ? EmptyPortfolioWidget(
                      onAddFirstPurchase: () {
                        _navigateToAddTransaction();
                      },
                    )
                    : RefreshIndicator(
                      onRefresh: _refreshPortfolio, // Enhanced manual refresh
                      color: theme.colorScheme.primary,
                      child:
                          _isLoading && !_isManualRefresh
                              ? const Center(child: CircularProgressIndicator())
                              : _error != null
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Error Loading Portfolio',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                    ),
                                    SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() => _error = null);
                                        _loadPortfolioDataInternal();
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                              : _cryptoHoldings.isEmpty
                              ? const EmptyPortfolioWidget()
                              : CustomScrollView(
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Column(
                                      children: [
                                        SizedBox(height: 6.h),

                                        // Portfolio Title Header
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            4.w,
                                            0,
                                            4.w,
                                            2.h,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Portfolio',
                                                style: GoogleFonts.inter(
                                                  fontSize: 24.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      theme
                                                          .colorScheme
                                                          .onSurface,
                                                ),
                                              ),
                                              if (_isRefreshing)
                                                SizedBox(
                                                  width: 6.w,
                                                  height: 6.w,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .primary,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // ENHANCED: Portfolio Summary with rate limit indicators (this contains the P&L data)
                                        PortfolioSummaryCard(
                                          totalValue:
                                              (_portfolioSummary['totalValue']
                                                      as num?)
                                                  ?.toDouble() ??
                                              0.0,
                                          totalInvested:
                                              (_portfolioSummary['totalInvested']
                                                      as num?)
                                                  ?.toDouble() ??
                                              0.0,
                                          percentageChange:
                                              (_portfolioSummary['percentageChange']
                                                      as num?)
                                                  ?.toDouble() ??
                                              0.0,
                                          lastUpdated:
                                              DateTime.tryParse(
                                                _portfolioSummary['lastUpdated']
                                                        as String? ??
                                                    '',
                                              ) ??
                                              DateTime.now(),
                                        ),

                                        // NEW: Rate limit status indicator
                                        (_portfolioSummary['shouldRecommendManualRefresh'] ==
                                                true)
                                            ? Container(
                                              margin: EdgeInsets.symmetric(
                                                horizontal: 4.w,
                                                vertical: 1.h,
                                              ),
                                              padding: EdgeInsets.all(3.w),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.amber
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.refresh,
                                                    color: Colors.amber[700],
                                                    size: 20.sp,
                                                  ),
                                                  SizedBox(width: 3.w),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Data Update Available',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 14.sp,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                Colors
                                                                    .amber[700],
                                                          ),
                                                        ),
                                                        SizedBox(height: 0.5.h),
                                                        Text(
                                                          'Pull down to refresh with latest market data',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 12.sp,
                                                            color:
                                                                Colors
                                                                    .amber[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                            : const SizedBox.shrink(),
                                      ],
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        4.w,
                                        2.h,
                                        4.w,
                                        1.h,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _showIndividualTransactions
                                                ? 'Recent Transactions'
                                                : 'Holdings',
                                            style: GoogleFonts.inter(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  setState(() {
                                                    _showIndividualTransactions =
                                                        !_showIndividualTransactions;
                                                  });
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 3.w,
                                                    vertical: 1.h,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: theme
                                                        .colorScheme
                                                        .primary
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: theme
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      CustomIconWidget(
                                                        iconName:
                                                            _showIndividualTransactions
                                                                ? 'view_list'
                                                                : 'dashboard',
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .primary,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 1.w),
                                                      Text(
                                                        _showIndividualTransactions
                                                            ? 'List View'
                                                            : 'Card View',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 10.sp,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              theme
                                                                  .colorScheme
                                                                  .primary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 2.w),
                                              if (_isRefreshing)
                                                SizedBox(
                                                  width: 4.w,
                                                  height: 4.w,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .primary,
                                                      ),
                                                ),
                                              if (_isRefreshing)
                                                SizedBox(width: 2.w),
                                              Text(
                                                _showIndividualTransactions
                                                    ? '${_allTransactions.length} transactions'
                                                    : '${_cryptoHoldings.length} assets',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w400,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // NEW: Conditional rendering based on view mode
                                  _showIndividualTransactions
                                      ? // Individual Transaction Tiles
                                      SliverList(
                                        delegate: SliverChildBuilderDelegate((
                                          context,
                                          index,
                                        ) {
                                          final transaction =
                                              _allTransactions[index];

                                          return IndividualTransactionTile(
                                            transaction: transaction,
                                            onTap: () async {
                                              // FIXED: Navigate with complete portfolio data instead of just transaction data
                                              try {
                                                // Get complete crypto holding data for this cryptocurrency
                                                final cryptoId =
                                                    transaction['crypto_id']
                                                        as String;
                                                final portfolioHolding =
                                                    await _portfolioService
                                                        .getCryptoHolding(
                                                          cryptoId,
                                                        );

                                                if (portfolioHolding != null &&
                                                    mounted) {
                                                  // Navigate with complete portfolio data
                                                  Navigator.pushNamed(
                                                    context,
                                                    AppRoutes
                                                        .cryptocurrencyDetail,
                                                    arguments: {
                                                      'id':
                                                          portfolioHolding['crypto_id'],
                                                      'symbol':
                                                          portfolioHolding['crypto_symbol'] ??
                                                          portfolioHolding['symbol'],
                                                      'name':
                                                          portfolioHolding['crypto_name'] ??
                                                          portfolioHolding['name'],
                                                      'icon':
                                                          portfolioHolding['crypto_icon_url'] ??
                                                          portfolioHolding['icon'],
                                                      'currentPrice':
                                                          portfolioHolding['current_price'] ??
                                                          portfolioHolding['currentPrice'] ??
                                                          0.0,
                                                      'holdings':
                                                          portfolioHolding['total_amount'] ??
                                                          portfolioHolding['holdings'] ??
                                                          0.0,
                                                      'averagePrice':
                                                          portfolioHolding['average_price'] ??
                                                          portfolioHolding['averagePrice'] ??
                                                          0.0,
                                                      'priceChange24h':
                                                          portfolioHolding['price_change_24h'] ??
                                                          portfolioHolding['priceChange24h'] ??
                                                          0.0,
                                                      'exchange':
                                                          portfolioHolding['exchange'] ??
                                                          'Unknown',
                                                      'transactions':
                                                          await _transactionService
                                                              .getTransactionsForCrypto(
                                                                cryptoId,
                                                              ),
                                                    },
                                                  );
                                                } else {
                                                  // Fallback: Create portfolio data from transaction if portfolio holding not found
                                                  final transactionsList =
                                                      await _transactionService
                                                          .getTransactionsForCrypto(
                                                            cryptoId,
                                                          );

                                                  // Calculate holdings and average price from transactions
                                                  double totalAmount = 0.0;
                                                  double totalInvested = 0.0;

                                                  for (final tx
                                                      in transactionsList) {
                                                    final txType =
                                                        tx['transaction_type']
                                                            as String;
                                                    final amount =
                                                        (tx['amount'] as num?)
                                                            ?.toDouble() ??
                                                        0.0;
                                                    final price =
                                                        (tx['price_per_unit']
                                                                as num?)
                                                            ?.toDouble() ??
                                                        0.0;

                                                    if (txType == 'buy') {
                                                      totalAmount += amount;
                                                      totalInvested +=
                                                          (amount * price);
                                                    } else if (txType ==
                                                        'sell') {
                                                      totalAmount -= amount;
                                                      totalInvested -=
                                                          (amount * price);
                                                    }
                                                  }

                                                  final averagePrice =
                                                      totalAmount > 0
                                                          ? totalInvested /
                                                              totalAmount
                                                          : 0.0;

                                                  // Try to get current price from crypto API
                                                  double currentPrice = 0.0;
                                                  try {
                                                    final cryptoData =
                                                        await _cryptoService
                                                            .getCryptocurrencyDetails(
                                                              cryptoId,
                                                            );
                                                    if (cryptoData != null) {
                                                      currentPrice =
                                                          (cryptoData['current_price']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0.0;
                                                    }
                                                  } catch (e) {
                                                    // Use the most recent transaction price as fallback
                                                    if (transactionsList
                                                        .isNotEmpty) {
                                                      currentPrice =
                                                          (transactionsList
                                                                      .first['price_per_unit']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0.0;
                                                    }
                                                  }

                                                  if (mounted) {
                                                    Navigator.pushNamed(
                                                      context,
                                                      AppRoutes
                                                          .cryptocurrencyDetail,
                                                      arguments: {
                                                        'id': cryptoId,
                                                        'symbol':
                                                            transaction['crypto_symbol'],
                                                        'name':
                                                            transaction['crypto_name'],
                                                        'icon':
                                                            transaction['crypto_icon_url'],
                                                        'exchange':
                                                            transaction['exchange'] ??
                                                            'Unknown',
                                                        'transactions': [
                                                          transaction,
                                                        ],
                                                        // Add fallback values to prevent zeros
                                                        'currentPrice':
                                                            (transaction['price_per_unit']
                                                                    as num?)
                                                                ?.toDouble() ??
                                                            0.0,
                                                        'holdings':
                                                            (transaction['amount']
                                                                    as num?)
                                                                ?.toDouble() ??
                                                            0.0,
                                                        'averagePrice':
                                                            (transaction['price_per_unit']
                                                                    as num?)
                                                                ?.toDouble() ??
                                                            0.0,
                                                        'priceChange24h': 0.0,
                                                      },
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (kDebugMode) {
                                                  print(
                                                    'Error preparing crypto detail data: $e',
                                                  );
                                                }

                                                // Final fallback: Navigate with original transaction data but show error
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Unable to load complete cryptocurrency data. Some information may not be available.',
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontSize: 12.sp,
                                                            ),
                                                      ),
                                                      backgroundColor:
                                                          AppTheme.getWarningColor(
                                                            Theme.of(
                                                                  context,
                                                                ).brightness ==
                                                                Brightness
                                                                    .light,
                                                          ),
                                                      duration: const Duration(
                                                        seconds: 3,
                                                      ),
                                                    ),
                                                  );

                                                  Navigator.pushNamed(
                                                    context,
                                                    AppRoutes
                                                        .cryptocurrencyDetail,
                                                    arguments: {
                                                      'id':
                                                          transaction['crypto_id'],
                                                      'symbol':
                                                          transaction['crypto_symbol'],
                                                      'name':
                                                          transaction['crypto_name'],
                                                      'icon':
                                                          transaction['crypto_icon_url'],
                                                      'exchange':
                                                          transaction['exchange'] ??
                                                          'Unknown',
                                                      'transactions': [
                                                        transaction,
                                                      ],
                                                      // Add fallback values to prevent zeros
                                                      'currentPrice':
                                                          (transaction['price_per_unit']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0.0,
                                                      'holdings':
                                                          (transaction['amount']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0.0,
                                                      'averagePrice':
                                                          (transaction['price_per_unit']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0.0,
                                                      'priceChange24h': 0.0,
                                                    },
                                                  );
                                                }
                                              }
                                            },
                                            onEdit: () {
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.editTransaction,
                                                arguments: transaction,
                                              ).then((result) async {
                                                if (result == true) {
                                                  await _loadPortfolioDataInternal();
                                                  await _loadAllTransactions();
                                                }
                                              });
                                            },
                                            onDelete:
                                                () =>
                                                    _showDeleteTransactionDialog(
                                                      context,
                                                      transaction,
                                                    ),
                                          );
                                        }, childCount: _allTransactions.length),
                                      )
                                      : // Original Crypto Holding Cards
                                      SliverList(
                                        delegate: SliverChildBuilderDelegate((
                                          context,
                                          index,
                                        ) {
                                          final crypto = _cryptoHoldings[index];

                                          // Convert the data format to match the expected format
                                          final formattedCrypto = {
                                            'id': crypto['id'],
                                            'symbol': crypto['symbol'],
                                            'name': crypto['name'],
                                            'icon': crypto['icon'],
                                            'currentPrice':
                                                crypto['currentPrice'],
                                            'holdings': crypto['holdings'],
                                            'averagePrice':
                                                crypto['averagePrice'],
                                            'priceChange24h':
                                                crypto['priceChange24h'],
                                            'transactions':
                                                crypto['transactions'],
                                            'exchange':
                                                crypto['exchange'] ?? 'Unknown',
                                          };

                                          return CryptoHoldingCard(
                                            cryptoData: formattedCrypto,
                                            onTap: () {
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.cryptocurrencyDetail,
                                                arguments: formattedCrypto,
                                              );
                                            },
                                            onAddPurchase: () {
                                              _navigateToAddTransaction();
                                            },
                                            onViewHistory: () {
                                              _showTransactionHistory(
                                                context,
                                                formattedCrypto,
                                              );
                                            },
                                            onDelete: () {
                                              _showDeleteConfirmationDialog(
                                                context,
                                                formattedCrypto,
                                              );
                                            },
                                          );
                                        }, childCount: _cryptoHoldings.length),
                                      ),
                                  SliverToBoxAdapter(
                                    child: SizedBox(height: 10.h),
                                  ),
                                ],
                              ),
                    ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurface.withValues(
              alpha: 0.6,
            ),
            indicatorColor: Colors.transparent,
            labelStyle: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
            ),
            tabs: [
              Tab(
                icon: CustomIconWidget(
                  iconName: 'dashboard',
                  color:
                      _currentTabIndex == 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 24,
                ),
                text: 'Portfolio',
              ),
              Tab(
                icon: CustomIconWidget(
                  iconName: 'receipt',
                  color:
                      _currentTabIndex == 1
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 24,
                ),
                text: 'Transactions',
              ),
              Tab(
                icon: CustomIconWidget(
                  iconName: 'trending_up',
                  color:
                      _currentTabIndex == 2
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 24,
                ),
                text: 'Markets',
              ),
              Tab(
                icon: CustomIconWidget(
                  iconName: 'settings',
                  color:
                      _currentTabIndex == 3
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 24,
                ),
                text: 'Settings',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _navigateToAddTransaction();
        },
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        elevation: 6,
        child: CustomIconWidget(
          iconName: 'add',
          color: theme.colorScheme.onSecondary,
          size: 28,
        ),
      ),
    );
  }

  // Define _loadAllTransactions method
  Future<void> _loadAllTransactions() async {
    try {
      final transactions = await _transactionService.getAllTransactions();
      if (mounted) {
        setState(() {
          _allTransactions = transactions;
        });

        if (kDebugMode) {
          print('📄 Loaded ${transactions.length} transactions for UI display');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading transactions: $e');
      }
    }
  }

  void _showTransactionHistory(
    BuildContext context,
    Map<String, dynamic> crypto,
  ) async {
    final theme = Theme.of(context);
    final cryptoId = crypto['crypto_id'] ?? crypto['id'];
    final transactions = await _transactionService.getTransactionsForCrypto(
      cryptoId,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.symmetric(vertical: 2.h),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Row(
                    children: [
                      Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                        ),
                        child: ClipOval(
                          child: CustomImageWidget(
                            imageUrl: crypto['icon'] as String,
                            width: 10.w,
                            height: 10.w,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${crypto['symbol']} Transaction History',
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${transactions.length} transactions',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final transactionData =
                          transaction['transactions']?[0] ?? transaction;
                      final timestamp =
                          transactionData['timestamp'] is DateTime
                              ? transactionData['timestamp'] as DateTime
                              : DateTime.parse(
                                transaction['date'] ??
                                    DateTime.now().toIso8601String(),
                              );
                      final amount =
                          (transactionData['amount'] as num).toDouble();
                      final price =
                          (transactionData['price'] as num).toDouble();
                      final total = amount * price;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.getSuccessColor(
                              theme.brightness == Brightness.light,
                            ).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: CustomIconWidget(
                            iconName: 'add_circle',
                            color: AppTheme.getSuccessColor(
                              theme.brightness == Brightness.light,
                            ),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Buy ${amount.toStringAsFixed(4)} ${crypto['symbol']}',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${timestamp.month}/${timestamp.day}/${timestamp.year} • \$${price.toStringAsFixed(2)} per ${crypto['symbol']}',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        trailing: Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    Map<String, dynamic> crypto,
  ) async {
    final theme = Theme.of(context);
    final cryptoSymbol = crypto['symbol'] as String;
    final cryptoName = crypto['name'] as String;
    final holdings = (crypto['holdings'] as num).toDouble();
    final currentValue =
        ((crypto['currentPrice'] as num?)?.toDouble() ?? 0.0) * holdings;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: theme.colorScheme.surface,
          title: Row(
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.getWarningColor(
                    theme.brightness == Brightness.light,
                  ).withValues(alpha: 0.1),
                ),
                child: CustomIconWidget(
                  iconName: 'warning',
                  color: AppTheme.getWarningColor(
                    theme.brightness == Brightness.light,
                  ),
                  size: 24,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  'Delete ${cryptoSymbol}',
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete all ${cryptoName} holdings from your portfolio?',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Holdings to be deleted:',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${holdings.toStringAsFixed(4)} ${cryptoSymbol}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '\$${currentValue.toStringAsFixed(2)}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'This action cannot be undone. All transaction history for this asset will be permanently removed.',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.getWarningColor(
                    theme.brightness == Brightness.light,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.7,
                ),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteCrypto(crypto);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.getWarningColor(
                  theme.brightness == Brightness.light,
                ),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCrypto(Map<String, dynamic> crypto) async {
    HapticFeedback.mediumImpact();

    final cryptoId = crypto['crypto_id'] ?? crypto['id'];
    final cryptoSymbol = crypto['symbol'] as String;

    try {
      // Delete cryptocurrency from portfolio (removes all transactions)
      await _portfolioService.deleteCryptocurrencyFromPortfolio(cryptoId);

      // Reload portfolio data
      await _loadPortfolioDataInternal();
      await _loadAllTransactions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CustomIconWidget(
                  iconName: 'check_circle',
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    '${cryptoSymbol} has been removed from your portfolio',
                    style: GoogleFonts.inter(fontSize: 14.sp),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.getSuccessColor(
              Theme.of(context).brightness == Brightness.light,
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete ${cryptoSymbol}. Please try again.',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            backgroundColor: AppTheme.getWarningColor(
              Theme.of(context).brightness == Brightness.light,
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDeleteTransactionDialog(
    BuildContext context,
    Map<String, dynamic> transaction,
  ) async {
    final theme = Theme.of(context);
    final cryptoSymbol = transaction['crypto_symbol'] as String? ?? 'N/A';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final pricePerUnit =
        (transaction['price_per_unit'] as num?)?.toDouble() ?? 0.0;
    final transactionType = transaction['transaction_type'] as String? ?? 'buy';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: theme.colorScheme.surface,
          title: Row(
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.getWarningColor(
                    theme.brightness == Brightness.light,
                  ).withValues(alpha: 0.1),
                ),
                child: CustomIconWidget(
                  iconName: 'warning',
                  color: AppTheme.getWarningColor(
                    theme.brightness == Brightness.light,
                  ),
                  size: 24,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  'Delete Transaction',
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this transaction?',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction to be deleted:',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      '${transactionType.toUpperCase()} ${amount.toStringAsFixed(6)} ${cryptoSymbol}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'at \$${pricePerUnit.toStringAsFixed(2)} per ${cryptoSymbol}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'This action cannot be undone.',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.getWarningColor(
                    theme.brightness == Brightness.light,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.7,
                ),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteTransaction(transaction);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.getWarningColor(
                  theme.brightness == Brightness.light,
                ),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// NEW: Delete individual transaction
  Future<void> _deleteTransaction(Map<String, dynamic> transaction) async {
    HapticFeedback.mediumImpact();

    final transactionId = transaction['id'] as String;
    final cryptoSymbol = transaction['crypto_symbol'] as String? ?? 'N/A';

    try {
      // Delete transaction
      await _transactionService.deleteTransaction(transactionId);

      // Reload data
      await _loadPortfolioDataInternal();
      await _loadAllTransactions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transaction deleted successfully',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            backgroundColor: AppTheme.getSuccessColor(
              Theme.of(context).brightness == Brightness.light,
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete transaction. Please try again.',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            backgroundColor: AppTheme.getWarningColor(
              Theme.of(context).brightness == Brightness.light,
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}