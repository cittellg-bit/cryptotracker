import 'package:flutter/material.dart';

import '../presentation/add_transaction/add_transaction_screen.dart';
import '../presentation/auth/anonymous_auth_screen.dart';
import '../presentation/auth/sign_in_screen.dart';
import '../presentation/auth/sign_up_screen.dart';
import '../presentation/crypto_selector/crypto_selector_screen.dart';
import '../presentation/cryptocurrency_detail/cryptocurrency_detail.dart';
import '../presentation/edit_transaction/edit_transaction.dart';
import '../presentation/markets/markets_screen.dart';
import '../presentation/settings/settings.dart';

class AppRoutes {
  static const String initial = '/';
  static const String portfolioDashboard = '/';
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
      addTransaction: (context) => const AddTransactionScreen(),
      markets: (context) => const MarketsScreen(),
      settings: (context) => const Settings(),
      cryptoSelector: (context) => const CryptoSelectorScreen(),
      editTransaction: (context) => const EditTransaction(),
      cryptocurrencyDetail: (context) => const CryptocurrencyDetail(),
      anonymousAuth: (context) => const AnonymousAuthScreen(),
      signUp: (context) => const SignUpScreen(),
      signIn: (context) => const SignInScreen(),
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
    return publicRoutes.contains(routeName);
  }
}
