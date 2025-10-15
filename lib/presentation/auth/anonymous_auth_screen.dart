import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../core/services/anonymous_auth_service.dart';

class AnonymousAuthScreen extends StatefulWidget {
  const AnonymousAuthScreen({super.key});

  @override
  State<AnonymousAuthScreen> createState() => _AnonymousAuthScreenState();
}

class _AnonymousAuthScreenState extends State<AnonymousAuthScreen> {
  final AnonymousAuthService _authService = AnonymousAuthService.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: CustomIconWidget(
                        iconName: 'account_balance_wallet',
                        color: theme.colorScheme.onPrimary,
                        size: 12.w,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'CryptoTracker',
                      style: GoogleFonts.inter(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Track your crypto portfolio\nwith ease',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w400,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Anonymous Trial Button
                    SizedBox(
                      width: double.infinity,
                      height: 6.h,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAnonymousTrial,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CustomIconWidget(
                                    iconName: 'play_arrow',
                                    color: theme.colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    'Try Anonymous Mode',
                                    style: GoogleFonts.inter(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    SizedBox(height: 2.h),

                    // Feature Preview Card
                    Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CustomIconWidget(
                                iconName: 'info',
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                'Anonymous Mode Features',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          _buildFeatureItem(
                              'Track demo transactions', 'trending_up'),
                          _buildFeatureItem(
                              'View portfolio analytics', 'analytics'),
                          _buildFeatureItem('Browse crypto markets', 'public'),
                          _buildFeatureItem(
                              'No signup required', 'verified_user'),
                        ],
                      ),
                    ),

                    SizedBox(height: 3.h),

                    // Create Account Button
                    SizedBox(
                      width: double.infinity,
                      height: 6.h,
                      child: OutlinedButton(
                        onPressed: _handleCreateAccount,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Create Account',
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 2.h),

                    // Sign In Button
                    TextButton(
                      onPressed: _handleSignIn,
                      child: Text(
                        'Already have an account? Sign In',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text, String iconName) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        children: [
          CustomIconWidget(
            iconName: iconName,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
            size: 16,
          ),
          SizedBox(width: 3.w),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAnonymousTrial() async {
    if (_isLoading) return; // Prevent multiple simultaneous attempts

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if Supabase is properly initialized by trying to access the client
      try {
        final client = Supabase.instance.client;
        // Test if client is accessible instead of checking deprecated properties
        final currentUser = client.auth.currentUser;
      } catch (clientError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'error',
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 2.w),
                  const Expanded(
                    child: Text(
                        'Service not configured properly. Please contact support.'),
                  ),
                ],
              ),
              backgroundColor: AppTheme.getWarningColor(
                  Theme.of(context).brightness == Brightness.light),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final user = await _authService.signInAnonymously();

      if (user != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CustomIconWidget(
                  iconName: 'check_circle',
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Welcome! You\'re in anonymous mode',
                    style: GoogleFonts.inter(fontSize: 14.sp),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.getSuccessColor(
                Theme.of(context).brightness == Brightness.light),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Small delay to show success message
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to portfolio
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.portfolioDashboard);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CustomIconWidget(
                  iconName: 'error',
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 2.w),
                const Expanded(
                  child: Text(
                      'Failed to start anonymous mode. Please check your connection and try again.'),
                ),
              ],
            ),
            backgroundColor: AppTheme.getWarningColor(
                Theme.of(context).brightness == Brightness.light),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleAnonymousTrial,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CustomIconWidget(
                  iconName: 'error',
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text('Connection error. Please try again.'),
                ),
              ],
            ),
            backgroundColor: AppTheme.getWarningColor(
                Theme.of(context).brightness == Brightness.light),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleAnonymousTrial,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleCreateAccount() {
    Navigator.pushNamed(context, AppRoutes.signUp);
  }

  void _handleSignIn() {
    Navigator.pushNamed(context, AppRoutes.signIn);
  }
}
