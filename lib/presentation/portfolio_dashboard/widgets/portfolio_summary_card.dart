import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class PortfolioSummaryCard extends StatelessWidget {
  final double totalValue;
  final double totalInvested;
  final double percentageChange;
  final DateTime lastUpdated;

  const PortfolioSummaryCard({
    super.key,
    required this.totalValue,
    required this.totalInvested,
    required this.percentageChange,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profitLoss = totalValue - totalInvested;
    final isProfit = profitLoss >= 0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Portfolio Value',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: isProfit
                      ? AppTheme.getSuccessColor(
                              theme.brightness == Brightness.light)
                          .withValues(alpha: 0.1)
                      : AppTheme.getWarningColor(
                              theme.brightness == Brightness.light)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: isProfit ? 'trending_up' : 'trending_down',
                      color: isProfit
                          ? AppTheme.getSuccessColor(
                              theme.brightness == Brightness.light)
                          : AppTheme.getWarningColor(
                              theme.brightness == Brightness.light),
                      size: 16,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      '${isProfit ? '+' : ''}${percentageChange.toStringAsFixed(2)}%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isProfit
                            ? AppTheme.getSuccessColor(
                                theme.brightness == Brightness.light)
                            : AppTheme.getWarningColor(
                                theme.brightness == Brightness.light),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            '\$${totalValue.toStringAsFixed(2)}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 0.5.h),
          Row(
            children: [
              Text(
                'P&L: ',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '${isProfit ? '+' : ''}\$${profitLoss.toStringAsFixed(2)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: isProfit
                      ? AppTheme.getSuccessColor(
                          theme.brightness == Brightness.light)
                      : AppTheme.getWarningColor(
                          theme.brightness == Brightness.light),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Invested',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      '\$${totalInvested.toStringAsFixed(2)}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Last Updated',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      _formatTime(lastUpdated),
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
