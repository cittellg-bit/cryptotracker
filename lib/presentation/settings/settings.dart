import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/services/anonymous_auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import './widgets/anonymous_auth_widget.dart';
import './widgets/currency_selection_widget.dart';
import './widgets/export_portfolio_widget.dart';
import './widgets/log_collection_widget.dart';
import './widgets/settings_item_widget.dart';
import './widgets/settings_section_widget.dart';
import './widgets/theme_selection_widget.dart';
import './widgets/update_frequency_widget.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final AnonymousAuthService _authService = AnonymousAuthService.instance;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  void _checkAuthenticationStatus() {
    setState(() {
      _isAuthenticated = _authService.isSignedIn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: CustomAppBar(
            title: 'Settings',
            leading: IconButton(
                onPressed: () {
                  // Always go back to portfolio dashboard regardless of auth status
                  // Settings page can be accessed from anywhere but should return to main screen
                  Navigator.pushReplacementNamed(
                      context, AppRoutes.portfolioDashboard);
                },
                icon: CustomIconWidget(
                    iconName: 'arrow_back',
                    color: theme.colorScheme.onSurface,
                    size: 24))),
        body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Authentication Status Banner
              if (!_isAuthenticated) ...[
                Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(4.w),
                    margin: EdgeInsets.only(bottom: 2.h),
                    decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                theme.colorScheme.error.withValues(alpha: 0.3),
                            width: 1)),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.onErrorContainer, size: 24),
                      SizedBox(width: 3.w),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Debug Mode Access',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onErrorContainer)),
                            Text(
                                'You are accessing settings without authentication for debugging purposes.',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onErrorContainer
                                        .withValues(alpha: 0.8))),
                          ])),
                    ])),
              ],

              // Debug & Configuration Section (Always Available)
              SettingsSectionWidget(title: 'Debug & Configuration', children: [
                const LogCollectionWidget(),
              ]),

              SizedBox(height: 3.h),

              // Authentication Section (Always Available)
              SettingsSectionWidget(title: 'Authentication', children: [
                const AnonymousAuthWidget(),
              ]),

              // App Preferences Section (Available when authenticated or for debugging)
              if (_isAuthenticated || !_isAuthenticated) ...[
                SizedBox(height: 3.h),
                SettingsSectionWidget(title: 'App Preferences', children: [
                  ThemeSelectionWidget(
                    selectedTheme: ThemeMode.system,
                    onThemeChanged: (theme) {
                      // TODO: Implement theme change logic
                    },
                  ),
                  SizedBox(height: 2.h),
                  CurrencySelectionWidget(
                    selectedCurrency: 'USD',
                    onCurrencyChanged: (currency) {
                      // TODO: Implement currency change logic
                    },
                  ),
                  SizedBox(height: 2.h),
                  UpdateFrequencyWidget(
                    selectedFrequency: 5,
                    onFrequencyChanged: (frequency) {
                      // TODO: Implement frequency change logic
                    },
                  ),
                ]),
              ],

              // Portfolio Management (Only when authenticated)
              if (_isAuthenticated) ...[
                SizedBox(height: 3.h),
                SettingsSectionWidget(title: 'Portfolio Management', children: [
                  const ExportPortfolioWidget(),
                ]),
              ],

              // Quick Actions for Debug Mode
              if (!_isAuthenticated) ...[
                SizedBox(height: 3.h),
                SettingsSectionWidget(title: 'Quick Actions', children: [
                  SettingsItemWidget(
                      title: 'Go to Authentication',
                      subtitle: 'Set up your account to access full features',
                      iconName: 'login',
                      onTap: () {
                        Navigator.pushReplacementNamed(
                            context, AppRoutes.anonymousAuth);
                      }),
                ]),
              ],

              // Add some bottom padding
              SizedBox(height: 5.h),
            ])));
  }
}
