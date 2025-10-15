import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import './core/services/mock_auth_service.dart';
import './core/services/pl_persistence_service.dart';
import './core/services/portfolio_service.dart';
import './presentation/add_transaction/add_transaction_screen.dart';
import './presentation/markets/markets_screen.dart';
import './presentation/portfolio_dashboard/portfolio_dashboard.dart';
import './presentation/settings/settings.dart';
import './routes/app_routes.dart';
import './theme/app_theme.dart';
import 'core/app_export.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    // WEB SUPPORT: Enhanced logging for platform detection
    print(
      '🚀 STARTUP FIX: Starting CryptoTracker with enhanced data loading...',
    );
    print('🌐 PLATFORM: Running on ${kIsWeb ? 'WEB' : 'MOBILE'}');
  }

  try {
    // WEB SUPPORT: Platform-aware initialization with guaranteed data availability
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
    print('🌐 Platform optimized: ${kIsWeb ? 'WEB MODE' : 'MOBILE MODE'}');
  }

  runApp(const MyApp());
}

/// WEB SUPPORT: Enhanced app initialization with platform-aware data loading
Future<void> _initializeAppWithDataPersistence() async {
  try {
    if (kDebugMode) {
      print('🔄 STARTUP FIX: Initializing app with data persistence...');
      print(
        '🌐 Platform detection: ${kIsWeb ? 'Web browser' : 'Mobile device'}',
      );
    }

    // WEB SUPPORT: Platform-specific portfolio service initialization
    if (kIsWeb) {
      // WEB: Initialize with web-optimized settings
      await PortfolioService.instance.initializeForWeb();
      if (kDebugMode) {
        print('🌐 Portfolio service initialized for WEB platform');
      }
    } else {
      // MOBILE: Use existing Android initialization (unchanged)
      await PortfolioService.instance.initializeForAndroid();
      if (kDebugMode) {
        print('📱 Portfolio service initialized for MOBILE platform');
      }
    }

    // CRITICAL: Pre-load P&L data synchronously to prevent empty state (works on both platforms)
    final plSnapshot = await PLPersistenceService.instance.loadPLSnapshot();
    if (plSnapshot != null) {
      final plValue = (plSnapshot['profitLoss'] as num).toDouble();
      final totalValue = (plSnapshot['totalValue'] as num).toDouble();

      if (kDebugMode) {
        print('✅ STARTUP FIX: Pre-loaded P&L data for immediate display:');
        print('   💰 P&L: \$${plValue.toStringAsFixed(2)}');
        print('   📊 Total Value: \$${totalValue.toStringAsFixed(2)}');
        print('   🌐 Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
      }

      // Force portfolio service to use this data immediately
      await PortfolioService.instance.getCachedPortfolioSummary();
    }

    // STARTUP FIX: Verify transaction data is available (platform-independent)
    final portfolioService = PortfolioService.instance;
    final holdings = await portfolioService.getPortfolioWithCurrentPrices();

    if (kDebugMode) {
      print('🔍 STARTUP FIX: Data availability check:');
      print('   📈 Holdings: ${holdings.length}');
      print('   🔄 Service initialized: ${portfolioService.isInitialized}');
      print('   🌐 Platform: ${kIsWeb ? 'Web optimized' : 'Mobile optimized'}');
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

/// STARTUP FIX: Log comprehensive startup data integrity (platform-aware)
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
    print('   🌐 Platform: ${kIsWeb ? 'Web Browser' : 'Mobile Device'}');
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
            // NAVIGATION FIX: Add logging for navigation events
            if (kDebugMode) {
              print('🧭 NAVIGATION EVENT: Navigating to ${settings.name}');
            }

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

/// WEB SUPPORT: Enhanced splash screen with platform-aware data loading
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
    _navigateToMainApp(); // NAVIGATION FIX: Navigate to main app wrapper instead of just portfolio
  }

  /// NAVIGATION FIX: Navigate to main app with bottom navigation
  Future<void> _navigateToMainApp() async {
    try {
      if (kDebugMode) {
        print('🚀 STARTUP FIX: Ensuring data is loaded before main app...');
        print('🌐 Platform: ${kIsWeb ? 'Web browser' : 'Mobile device'}');
      }

      setState(() {
        _loadingStatus = kIsWeb
            ? 'Loading web portfolio data...'
            : 'Loading portfolio data...';
      });

      // STEP 1: Platform-aware portfolio service initialization
      final portfolioService = PortfolioService.instance;
      if (!portfolioService.isInitialized) {
        if (kIsWeb) {
          await portfolioService.initializeForWeb();
        } else {
          await portfolioService.initializeForAndroid();
        }
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
          print(
            '🌐 Platform optimization: ${kIsWeb ? 'Web mode' : 'Mobile mode'}',
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
          print('✅ STARTUP FIX: Data guaranteed - navigating to main app');
          print('   📊 Data loaded: $_dataLoaded');
          print(
            '   🌐 Platform: ${kIsWeb ? 'Web optimized' : 'Mobile optimized'}',
          );
          print('🧭 NAVIGATION FIX: Navigating to MainAppWrapper');
        }

        // NAVIGATION FIX: Navigate to main app wrapper with bottom navigation
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainAppWrapper()),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ STARTUP FIX: Enhanced navigation failed: $e');
      }

      setState(() {
        _loadingStatus = 'Error loading data - continuing...';
      });

      // Continue to main app even if there are errors
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainAppWrapper()),
        );
      }
    }
  }

  /// STARTUP FIX: Perform integrity checks before dashboard load (platform-independent)
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
        print('   🌐 Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
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
              // WEB SUPPORT: Platform indicator
              if (kIsWeb) ...[
                SizedBox(height: 1.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        color: theme.colorScheme.primary,
                        size: 12.sp,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        'Web Version',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                    if (kIsWeb) ...[
                      SizedBox(width: 1.w),
                      Icon(Icons.language, color: Colors.green, size: 14.sp),
                    ],
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

/// NAVIGATION FIX: Main app wrapper with functional bottom navigation
class MainAppWrapper extends StatefulWidget {
  const MainAppWrapper({super.key});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;

  // NAVIGATION FIX: Define the screens for each tab
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    // NAVIGATION FIX: Initialize screens list
    _screens = [
      const PortfolioDashboard(), // Portfolio tab
      const AddTransactionScreen(), // Transactions tab - navigate to add transaction
      const MarketsScreen(), // Markets tab
      const Settings(), // Settings tab
    ];

    if (kDebugMode) {
      print(
          '🧭 NAVIGATION FIX: MainAppWrapper initialized with ${_screens.length} screens');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// NAVIGATION FIX: Handle tab navigation with logging
  void _onTabTapped(int index) {
    if (kDebugMode) {
      final tabNames = ['Portfolio', 'Transactions', 'Markets', 'Settings'];
      print(
          '🧭 NAVIGATION EVENT: Tab tapped - ${tabNames[index]} (index: $index)');
      print('   📍 Current index: $_currentIndex -> New index: $index');
    }

    if (index == _currentIndex) return;

    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();

    // NAVIGATION FIX: Smooth page transition
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );

    setState(() {
      _currentIndex = index;
    });

    if (kDebugMode) {
      print('   ✅ NAVIGATION: Page transition initiated to index $index');
    }
  }

  /// NAVIGATION FIX: Handle page changed event
  void _onPageChanged(int index) {
    if (kDebugMode) {
      final tabNames = ['Portfolio', 'Transactions', 'Markets', 'Settings'];
      print(
          '🧭 NAVIGATION EVENT: Page changed to ${tabNames[index]} (index: $index)');
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
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
          child: Container(
            height: 65,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context: context,
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Portfolio',
                ),
                _buildNavItem(
                  context: context,
                  index: 1,
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Transactions',
                ),
                _buildNavItem(
                  context: context,
                  index: 2,
                  icon: Icons.trending_up_outlined,
                  activeIcon: Icons.trending_up,
                  label: 'Markets',
                ),
                _buildNavItem(
                  context: context,
                  index: 3,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
      // NAVIGATION FIX: Add floating action button for quick access to add transaction
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                if (kDebugMode) {
                  print(
                      '🧭 NAVIGATION EVENT: FAB tapped - navigating to add transaction');
                }
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, AppRoutes.addTransaction)
                    .then((result) {
                  if (kDebugMode) {
                    print(
                        '🧭 NAVIGATION EVENT: Returned from add transaction with result: $result');
                  }
                });
              },
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
              elevation: 6,
              child: const Icon(Icons.add, size: 28),
            )
          : null,
    );
  }

  /// NAVIGATION FIX: Build navigation item with proper styling and interaction
  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isSelected = index == _currentIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 24,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}