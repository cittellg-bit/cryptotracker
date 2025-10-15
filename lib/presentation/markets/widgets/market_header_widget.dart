import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class MarketHeaderWidget extends StatelessWidget {
  final VoidCallback onRefresh;
  final DateTime lastUpdated;
  final bool isRefreshing;
  final bool showingFallbackData;

  const MarketHeaderWidget({
    super.key,
    required this.onRefresh,
    required this.lastUpdated,
    required this.isRefreshing,
    required this.showingFallbackData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeDifference = DateTime.now().difference(lastUpdated);

    String timeAgo;
    if (timeDifference.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (timeDifference.inMinutes < 60) {
      timeAgo = '${timeDifference.inMinutes}m ago';
    } else if (timeDifference.inHours < 24) {
      timeAgo = '${timeDifference.inHours}h ago';
    } else {
      timeAgo = '${timeDifference.inDays}d ago';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 2.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cryptocurrency Markets',
                    style: GoogleFonts.inter(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Text(
                        'Updated $timeAgo',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      if (showingFallbackData) ...[
                        Text(
                          ' • ',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        Icon(
                          Icons.cloud_off,
                          size: 14,
                          color: AppTheme.getWarningColor(
                              theme.brightness == Brightness.light),
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          'Limited data',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: AppTheme.getWarningColor(
                                theme.brightness == Brightness.light),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: isRefreshing ? null : onRefresh,
                  icon: isRefreshing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : CustomIconWidget(
                          iconName: 'refresh',
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'trending_up',
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    'Top 100 cryptocurrencies by market cap',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
