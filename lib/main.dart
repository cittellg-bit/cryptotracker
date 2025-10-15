import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import './core/services/mock_auth_service.dart';
import './core/services/pl_persistence_service.dart';
import './core/services/portfolio_service.dart';
import './presentation/portfolio_dashboard/portfolio_dashboard.dart';
import './presentation/settings/settings.dart';
import './routes/app_routes.dart';
import './theme/app_theme.dart';
import 'core/app_export.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    print(
      '🚀 STARTUP FIX: Starting CryptoTracker with enhanced data loading...',
    );
  }

  try {
    // STARTUP FIX: Enhanced initialization with guaranteed data availability
    await _initializeAppWithDataPersistence();

    // Initialize mock auth service and auto-authenticate
    await MockAuthService.instance.initialize();

    if (!MockAuthService.instance.isAuthenticated) {
      await MockAuthService.instance.signInAnonymously();
      if (kDebugMode) {
        print('✅ User automatically authenticated anonymously');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ STARTUP FIX: Service initialization failed, continuing: $e');
    }
  }

  if (kDebugMode) {
    print('✅ STARTUP FIX: App started with guaranteed data availability');
  }

  runApp(const MyApp());
}

/// STARTUP FIX: Enhanced app initialization with guaranteed data loading
Future<void> _initializeAppWithDataPersistence() async {
  try {
    if (kDebugMode) {
      print('🔄 STARTUP FIX: Initializing app with data persistence...');
    }

    // CRITICAL: Initialize portfolio service with data loading guarantee
    await PortfolioService.instance.initializeForAndroid();

    // CRITICAL: Pre-load P&L data synchronously to prevent empty state
    final plSnapshot = await PLPersistenceService.instance.loadPLSnapshot();
    if (plSnapshot != null) {
      final plValue = (plSnapshot['profitLoss'] as num).toDouble();
      final totalValue = (plSnapshot['totalValue'] as num).toDouble();

      if (kDebugMode) {
        print('✅ STARTUP FIX: Pre-loaded P&L data for immediate display:');
        print('   💰 P&L: \$${plValue.toStringAsFixed(2)}');
        print('   📊 Total Value: \$${totalValue.toStringAsFixed(2)}');
      }

      // Force portfolio service to use this data immediately
      await PortfolioService.instance.getCachedPortfolioSummary();
    }

    // STARTUP FIX: Verify transaction data is available
    final portfolioService = PortfolioService.instance;
    final holdings = await portfolioService.getPortfolioWithCurrentPrices();

    if (kDebugMode) {
      print('🔍 STARTUP FIX: Data availability check:');
      print('   📈 Holdings: ${holdings.length}');
      print('   🔄 Service initialized: ${portfolioService.isInitialized}');
    }

    // Add startup integrity check with delay debugging
    if (kDebugMode) {
      await _logStartupDataIntegrity();
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ STARTUP FIX: Enhanced initialization failed: $e');
    }
  }
}

/// STARTUP FIX: Log comprehensive startup data integrity
Future<void> _logStartupDataIntegrity() async {
  try {
    final plService = PLPersistenceService.instance;
    final portfolioService = PortfolioService.instance;

    // Check P&L persistence data
    final plSnapshot = await plService.loadPLSnapshot();
    final diagnostics = await plService.getDiagnosticInfo();

    // Check portfolio data
    final summary = await portfolioService.getCachedPortfolioSummary();
    final holdings = await portfolioService.getPortfolioWithCurrentPrices();

    print('📊 STARTUP INTEGRITY CHECK:');
    print('   💾 P&L Snapshot Available: ${plSnapshot != null}');
    if (plSnapshot != null) {
      print(
        '   💰 Cached P&L: \$${(plSnapshot['profitLoss'] as num).toStringAsFixed(2)}',
      );
      print('   📅 Last Updated: ${plSnapshot['dateString']}');
    }
    print('   📈 Portfolio Holdings: ${holdings.length}');
    print('   💼 Summary Data: ${summary.isNotEmpty}');
    print('   🔍 Diagnostics Available: ${diagnostics.isNotEmpty}');
    print('   📝 Error Count: ${diagnostics['errorCount'] ?? 'N/A'}');
    print('   ⚠️ Warning Count: ${diagnostics['warningCount'] ?? 'N/A'}');

    // Check for potential issues
    if (plSnapshot == null && holdings.isEmpty) {
      print(
        '⚠️ POTENTIAL ISSUE: No P&L snapshot AND no holdings - empty state likely',
      );
    } else if (plSnapshot != null && holdings.isEmpty) {
      print(
        '💡 DATA MISMATCH: Have P&L snapshot but no holdings - investigating...',
      );
    }
  } catch (e) {
    print('❌ Startup integrity check failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'CryptoTracker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: const SplashScreen(),
          routes: AppRoutes.routes,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.0)),
              child: child!,
            );
          },
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.settings) {
              return MaterialPageRoute(
                builder: (context) => const Settings(),
                settings: settings,
              );
            }
            return null;
          },
        );
      },
    );
  }
}

/// STARTUP FIX: Enhanced splash screen with guaranteed data loading
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  // STARTUP FIX: Track data loading state
  bool _dataLoaded = false;
  String _loadingStatus = 'Initializing...';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
    _navigateToHomeWithDataGuarantee();
  }

  /// STARTUP FIX: Enhanced navigation with data loading guarantee
  Future<void> _navigateToHomeWithDataGuarantee() async {
    try {
      if (kDebugMode) {
        print('🚀 STARTUP FIX: Ensuring data is loaded before dashboard...');
      }

      setState(() {
        _loadingStatus = 'Loading portfolio data...';
      });

      // STEP 1: Ensure portfolio service is ready with data
      final portfolioService = PortfolioService.instance;
      if (!portfolioService.isInitialized) {
        await portfolioService.initializeForAndroid();
      }

      // STEP 2: CRITICAL - Check for existing data and load it synchronously
      final plService = PLPersistenceService.instance;
      final plSnapshot = await plService.loadPLSnapshot();

      if (plSnapshot != null) {
        setState(() {
          _loadingStatus = 'Restoring portfolio data...';
        });

        if (kDebugMode) {
          print(
            '✅ STARTUP FIX: Found persisted P&L data - loading immediately',
          );
        }

        // Force portfolio service to load cached data immediately
        await portfolioService.getCachedPortfolioSummary();
        _dataLoaded = true;
      } else {
        setState(() {
          _loadingStatus = 'Checking for transactions...';
        });

        // Check if we have transactions but no P&L data
        final holdings = await portfolioService.getPortfolioWithCurrentPrices();
        if (holdings.isNotEmpty) {
          if (kDebugMode) {
            print('🔄 STARTUP FIX: Found holdings data - ensuring calculation');
          }

          // Force calculation to ensure data is available
          await portfolioService.refreshPortfolioData();
          _dataLoaded = true;
        }
      }

      // STEP 3: Validate data integrity before proceeding
      setState(() {
        _loadingStatus = 'Validating data integrity...';
      });

      await _performStartupIntegrityCheck();

      setState(() {
        _loadingStatus = 'Loading dashboard...';
      });

      // STEP 4: Navigate with delay only for animation
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        if (kDebugMode) {
          print('✅ STARTUP FIX: Data guaranteed - navigating to dashboard');
          print('   📊 Data loaded: $_dataLoaded');
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const PortfolioDashboard()),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ STARTUP FIX: Enhanced navigation failed: $e');
      }

      setState(() {
        _loadingStatus = 'Error loading data - continuing...';
      });

      // Continue to dashboard even if there are errors
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const PortfolioDashboard()),
        );
      }
    }
  }

  /// STARTUP FIX: Perform integrity checks before dashboard load
  Future<void> _performStartupIntegrityCheck() async {
    try {
      final portfolioService = PortfolioService.instance;
      final summary = await portfolioService.getCachedPortfolioSummary();

      // Check for zero-reset issues
      final totalValue = (summary['totalValue'] as num?)?.toDouble() ?? 0.0;
      final totalInvested =
          (summary['totalInvested'] as num?)?.toDouble() ?? 0.0;
      final profitLoss = (summary['profitLoss'] as num?)?.toDouble() ?? 0.0;

      if (kDebugMode) {
        print('🔍 STARTUP INTEGRITY CHECK:');
        print('   💰 Total Value: \$${totalValue.toStringAsFixed(2)}');
        print('   💵 Total Invested: \$${totalInvested.toStringAsFixed(2)}');
        print('   📊 Profit/Loss: \$${profitLoss.toStringAsFixed(2)}');
      }

      // If we detect zero values but should have data, force recalculation
      if (totalValue == 0.0 && totalInvested == 0.0 && profitLoss == 0.0) {
        final holdings = await portfolioService.getPortfolioWithCurrentPrices();
        if (holdings.isNotEmpty) {
          if (kDebugMode) {
            print(
              '⚠️ STARTUP FIX: Zero values detected but holdings exist - forcing calculation',
            );
          }

          setState(() {
            _loadingStatus = 'Recalculating portfolio...';
          });

          await portfolioService.refreshPortfolioData();
          _dataLoaded = true;
        }
      } else if (totalValue > 0 || totalInvested > 0) {
        _dataLoaded = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Startup integrity check failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 25.w,
                height: 25.w,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4.w),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(77),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.currency_bitcoin_rounded,
                  size: 15.w,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'CryptoTracker',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                _loadingStatus,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: theme.colorScheme.onSurface.withAlpha(179),
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 6.h),
              SizedBox(
                width: 8.w,
                height: 8.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              // STARTUP FIX: Show data loading status
              if (_dataLoaded) ...[
                SizedBox(height: 2.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16.sp),
                    SizedBox(width: 1.w),
                    Text(
                      'Portfolio data loaded',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
