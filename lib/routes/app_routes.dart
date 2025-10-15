import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../presentation/add_transaction/add_transaction_screen.dart';
import '../presentation/auth/anonymous_auth_screen.dart';
import '../presentation/auth/sign_in_screen.dart';
import '../presentation/auth/sign_up_screen.dart';
import '../presentation/crypto_selector/crypto_selector_screen.dart';
import '../presentation/cryptocurrency_detail/cryptocurrency_detail.dart';
import '../presentation/edit_transaction/edit_transaction.dart';
import '../presentation/markets/markets_screen.dart';
import '../presentation/portfolio_dashboard/portfolio_dashboard.dart';
import '../presentation/settings/settings.dart';

class AppRoutes {
  // NAVIGATION FIX: Update route constants with proper navigation logging
  static const String initial = '/';
  static const String portfolioDashboard = '/portfolio-dashboard';
  static const String addTransaction = '/add-transaction';
  static const String markets = '/markets';
  static const String settings = '/settings';
  static const String cryptoSelector = '/crypto-selector';
  static const String editTransaction = '/edit-transaction';
  static const String cryptocurrencyDetail = '/cryptocurrency-detail';
  static const String anonymousAuth = '/anonymous-auth';
  static const String signUp = '/sign-up';
  static const String signIn = '/sign-in';

  static Map<String, WidgetBuilder> get routes {
    return {
      // NAVIGATION FIX: Add navigation logging to all routes
      portfolioDashboard: (context) {
        if (kDebugMode) {
          print('🧭 ROUTE: Building PortfolioDashboard');
        }
        return const PortfolioDashboard();
      },
      addTransaction: (context) {
        if (kDebugMode) {
          print('🧭 ROUTE: Building AddTransactionScreen');
        }
        return const AddTransactionScreen();
      },
      markets: (context) {
        if (kDebugMode) {
          print('🧭 ROUTE: Building MarketsScreen');
        }
        return const MarketsScreen();
      },
      settings: (context) {
        if (kDebugMode) {
          print('🧭 ROUTE: Building Settings');
        }
        return const Settings();
      },
      cryptoSelector: (context) {
        if (kDebugMode) {
          print('🧭 ROUTE: Building CryptoSelectorScreen');
        }
        return const CryptoSelectorScreen();
      },
      editTransaction: (context) {
        if (kDebugMode) {
          print('🧭 ROUTE: Building EditTransaction');
        }
        return const EditTransaction();
      },
      cryptocurrencyDetail: (context) {
        if (kDebugMode) {
          print('🧭 ROUTE: Building CryptocurrencyDetail');
        }
        return const CryptocurrencyDetail();
      },
      anonymousAuth: (context) {
        if (kDebugMode) {
          print('🧭 ROUTE: Building AnonymousAuthScreen');
        }
        return const AnonymousAuthScreen();
      },
      signUp: (context) {
        if (kDebugMode) {
          print('🧭 ROUTE: Building SignUpScreen');
        }
        return const SignUpScreen();
      },
      signIn: (context) {
        if (kDebugMode) {
          print('🧭 ROUTE: Building SignInScreen');
        }
        return const SignInScreen();
      },
    };
  }

  /// Check if a route should be accessible without authentication
  static bool isPublicRoute(String? routeName) {
    const publicRoutes = {
      settings,
      anonymousAuth,
      signUp,
      signIn,
    };

    final isPublic = publicRoutes.contains(routeName);

    if (kDebugMode) {
      print(
          '🧭 ROUTE SECURITY: Route $routeName is ${isPublic ? 'PUBLIC' : 'PRIVATE'}');
    }

    return isPublic;
  }

  /// NAVIGATION FIX: Get tab index for bottom navigation
  static int getTabIndexForRoute(String? routeName) {
    switch (routeName) {
      case portfolioDashboard:
        return 0;
      case addTransaction:
        return 1; // Transactions tab
      case markets:
        return 2;
      case settings:
        return 3;
      default:
        if (kDebugMode) {
          print(
              '🧭 ROUTE WARNING: Unknown route $routeName, defaulting to Portfolio tab');
        }
        return 0; // Default to Portfolio
    }
  }

  /// NAVIGATION FIX: Get route name for tab index
  static String getRouteForTabIndex(int index) {
    switch (index) {
      case 0:
        return portfolioDashboard;
      case 1:
        return addTransaction;
      case 2:
        return markets;
      case 3:
        return settings;
      default:
        if (kDebugMode) {
          print(
              '🧭 ROUTE WARNING: Invalid tab index $index, defaulting to Portfolio');
        }
        return portfolioDashboard;
    }
  }
}
