import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../core/services/anonymous_auth_service.dart';
import '../../../core/services/logging_service.dart';
import './settings_item_widget.dart';
import './settings_section_widget.dart';

class AnonymousAuthWidget extends StatefulWidget {
  const AnonymousAuthWidget({super.key});

  @override
  State<AnonymousAuthWidget> createState() => _AnonymousAuthWidgetState();
}

class _AnonymousAuthWidgetState extends State<AnonymousAuthWidget> {
  final AnonymousAuthService _authService = AnonymousAuthService.instance;
  final LoggingService _loggingService = LoggingService.instance;
  bool _isLoading = false;
  bool _isAuthenticating = false;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionWidget(title: 'Authentication Status', children: [
      _buildAuthStatusTile(),
      _buildAuthActionTile(),
      if (_authService.isLocalOnlyMode) _buildLocalModeWarning(),
    ]);
  }

  Widget _buildAuthStatusTile() {
    return SettingsItemWidget(
        title: 'Current Status',
        subtitle: _getAuthStatusText(),
        trailing:
            Icon(_getAuthStatusIcon(), color: _getAuthStatusColor(), size: 24));
  }

  String _getAuthStatusText() {
    if (_authService.isLocalOnlyMode) {
      return 'Local Mode (Database Unavailable)';
    } else if (_authService.isSignedIn()) {
      if (_authService.isAnonymousUser()) {
        return 'Anonymous User (Signed In)';
      } else {
        return 'Permanent User (Signed In)';
      }
    } else {
      return 'Not Signed In';
    }
  }

  IconData _getAuthStatusIcon() {
    if (_authService.isLocalOnlyMode) {
      return Icons.cloud_off;
    } else if (_authService.isSignedIn()) {
      return Icons.cloud_done;
    } else {
      return Icons.cloud_off;
    }
  }

  Color _getAuthStatusColor() {
    if (_authService.isLocalOnlyMode) {
      return Colors.orange;
    } else if (_authService.isSignedIn()) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }

  Widget _buildLocalModeWarning() {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.orange.withAlpha(26),
            border: Border.all(color: Colors.orange.withAlpha(77)),
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Local-Only Mode Active',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                    'App is running without database connection. Some features may be limited.',
                    style:
                        TextStyle(color: Colors.orange.shade600, fontSize: 12)),
              ])),
        ]));
  }

  Widget _buildAuthActionTile() {
    if (_authService.isLocalOnlyMode) {
      return SettingsItemWidget(
          title: 'Retry Connection',
          subtitle: 'Try to reconnect to database',
          onTap: _retryConnection,
          trailing: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.arrow_forward_ios, size: 16));
    } else if (_authService.isAnonymousUser()) {
      return SettingsItemWidget(
          title: 'Convert to Permanent Account',
          subtitle: 'Create account with email and password',
          onTap: _showConvertAccountDialog,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16));
    } else {
      return SettingsItemWidget(
          title: 'Sign Out',
          subtitle: 'Sign out from your account',
          onTap: _showSignOutDialog,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16));
    }
  }

  Future<void> _retryConnection() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Try to sign in anonymously again
      final user = await _authService.signInAnonymously();

      if (!_authService.isLocalOnlyMode && user != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Successfully reconnected to database'),
              backgroundColor: Colors.green));
          setState(() {});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Connection failed - still in local mode'),
              backgroundColor: Colors.orange));
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Connection failed: ${error.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showConvertAccountDialog() {
    final theme = Theme.of(context);

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              backgroundColor: theme.colorScheme.surface,
              title: Row(children: [
                CustomIconWidget(
                    iconName: 'upgrade',
                    color: theme.colorScheme.primary,
                    size: 24),
                SizedBox(width: 3.w),
                Text('Create Account',
                    style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface)),
              ]),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Convert your anonymous account to a permanent account to save your portfolio data.',
                        style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: theme.colorScheme.onSurface)),
                    SizedBox(height: 2.h),
                    Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Benefits:',
                                  style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary)),
                              SizedBox(height: 1.h),
                              _buildBenefitItem('🔒 Secure data storage'),
                              _buildBenefitItem('☁️ Cloud synchronization'),
                              _buildBenefitItem('📱 Access from any device'),
                              _buildBenefitItem(
                                  '📊 Advanced portfolio features'),
                            ])),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7)))),
                ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, AppRoutes.signUp);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: Text('Create Account',
                        style: GoogleFonts.inter(
                            fontSize: 14.sp, fontWeight: FontWeight.w600))),
              ]);
        });
  }

  Widget _buildBenefitItem(String text) {
    final theme = Theme.of(context);

    return Padding(
        padding: EdgeInsets.only(bottom: 0.5.h),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8))));
  }

  void _showSignOutDialog() {
    final theme = Theme.of(context);
    final isAnonymous = _authService.isAnonymousUser();

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              backgroundColor: theme.colorScheme.surface,
              title: Row(children: [
                CustomIconWidget(
                    iconName: 'warning',
                    color: AppTheme.getWarningColor(
                        theme.brightness == Brightness.light),
                    size: 24),
                SizedBox(width: 3.w),
                Text('Sign Out',
                    style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface)),
              ]),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        isAnonymous
                            ? 'You are currently in anonymous mode. Signing out will permanently delete all your portfolio data.'
                            : 'Are you sure you want to sign out?',
                        style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: theme.colorScheme.onSurface)),
                    if (isAnonymous) ...[
                      SizedBox(height: 2.h),
                      Container(
                          padding: EdgeInsets.all(3.w),
                          decoration: BoxDecoration(
                              color:
                                  AppTheme.getWarningColor(theme.brightness == Brightness.light)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.getWarningColor(
                                          theme.brightness == Brightness.light)
                                      .withValues(alpha: 0.3))),
                          child: Text(
                              'This action cannot be undone. Consider creating an account first to save your data.',
                              style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.getWarningColor(
                                      theme.brightness == Brightness.light)))),
                    ],
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7)))),
                if (isAnonymous)
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pushNamed(context, AppRoutes.signUp);
                      },
                      child: Text('Create Account First',
                          style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary))),
                ElevatedButton(
                    onPressed: _handleSignOut,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.getWarningColor(
                            theme.brightness == Brightness.light),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    child: Text('Sign Out',
                        style: GoogleFonts.inter(
                            fontSize: 14.sp, fontWeight: FontWeight.w600))),
              ]);
        });
  }

  Future<void> _handleSignOut() async {
    Navigator.of(context).pop(); // Close dialog
    HapticFeedback.mediumImpact();

    final isAnonymous = _authService.isAnonymousUser();

    try {
      // Clean up anonymous data if needed
      if (isAnonymous) {
        await _authService.cleanupAnonymousData();
      }

      // Sign out
      final success = await _authService.signOut();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              CustomIconWidget(
                  iconName: 'check_circle', color: Colors.white, size: 20),
              SizedBox(width: 2.w),
              Text(
                  isAnonymous
                      ? 'Anonymous session ended'
                      : 'Signed out successfully',
                  style: GoogleFonts.inter(fontSize: 14.sp)),
            ]),
            backgroundColor: AppTheme.getSuccessColor(
                Theme.of(context).brightness == Brightness.light),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating));

        // Navigate to auth screen
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.anonymousAuth, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sign out failed: ${e.toString()}'),
            backgroundColor: AppTheme.getWarningColor(
                Theme.of(context).brightness == Brightness.light),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating));
      }
    }

    // Refresh the widget state
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startAnonymousMode() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    HapticFeedback.lightImpact();

    await _loggingService.logInfo(
        category: LogCategory.userAction,
        message: 'User initiated anonymous mode',
        screenName: 'Settings',
        functionName: '_startAnonymousMode',
        details: {
          'action': 'anonymous_auth_button_pressed',
          'timestamp': DateTime.now().toIso8601String()
        });

    try {
      await _loggingService.logInfo(
          category: LogCategory.authentication,
          message: 'Starting anonymous authentication from UI',
          screenName: 'Settings',
          functionName: '_startAnonymousMode',
          details: {'process': 'ui_auth_start', 'user_triggered': true});

      final user = await _authService.signInAnonymously();

      if (user != null && mounted) {
        await _loggingService.logInfo(
            category: LogCategory.authentication,
            message: 'Anonymous authentication successful from UI',
            screenName: 'Settings',
            functionName: '_startAnonymousMode',
            details: {
              'user_id': user.id,
              'is_anonymous': user.isAnonymous,
              'process': 'ui_auth_success'
            });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              CustomIconWidget(
                  iconName: 'visibility_off', color: Colors.white, size: 20),
              SizedBox(width: 2.w),
              const Text('Started anonymous mode successfully'),
            ]),
            backgroundColor: AppTheme.getSuccessColor(
                Theme.of(context).brightness == Brightness.light),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating));

        // Refresh the widget state
        setState(() {});
      } else {
        await _loggingService.logError(
            category: LogCategory.authentication,
            message: 'Anonymous authentication failed from UI',
            screenName: 'Settings',
            functionName: '_startAnonymousMode',
            details: {
              'user_result': null,
              'process': 'ui_auth_failed',
              'mounted': mounted
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                CustomIconWidget(
                    iconName: 'error', color: Colors.white, size: 20),
                SizedBox(width: 2.w),
                const Text(
                    'Failed to start anonymous mode. Please check your connection and try again.'),
              ]),
              backgroundColor: AppTheme.getWarningColor(
                  Theme.of(context).brightness == Brightness.light),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating));
        }
      }
    } catch (e) {
      await _loggingService.logError(
          category: LogCategory.authentication,
          message: 'Exception during anonymous authentication from UI',
          screenName: 'Settings',
          functionName: '_startAnonymousMode',
          details: {
            'exception': e.toString(),
            'exception_type': e.runtimeType.toString(),
            'process': 'ui_auth_exception'
          },
          errorStack: e.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              CustomIconWidget(
                  iconName: 'error', color: Colors.white, size: 20),
              SizedBox(width: 2.w),
              Text(
                  'Authentication error: ${e.toString().length > 100 ? '${e.toString().substring(0, 100)}...' : e.toString()}'),
            ]),
            backgroundColor: AppTheme.getWarningColor(
                Theme.of(context).brightness == Brightness.light),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }
}