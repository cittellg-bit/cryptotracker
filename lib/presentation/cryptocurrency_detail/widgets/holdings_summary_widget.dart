import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class HoldingsSummaryWidget extends StatelessWidget {
  final Map<String, dynamic> holdingsData;

  const HoldingsSummaryWidget({
    super.key,
    required this.holdingsData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalOwned = (holdingsData["total_owned"] as double?) ?? 0.0;
    final averagePrice = (holdingsData["average_price"] as double?) ?? 0.0;
    final currentValue = (holdingsData["current_value"] as double?) ?? 0.0;
    final totalInvested = (holdingsData["total_invested"] as double?) ?? 0.0;
    final profitLoss = currentValue - totalInvested;
    final profitLossPercent =
        totalInvested > 0 ? (profitLoss / totalInvested) * 100 : 0.0;
    final isProfit = profitLoss >= 0;

    return Container(
      width: double.infinity,
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
                "Your Holdings",
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: isProfit
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: isProfit ? 'trending_up' : 'trending_down',
                      color: isProfit ? Colors.green : Colors.red,
                      size: 12.sp,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      "${isProfit ? '+' : ''}${profitLossPercent.toStringAsFixed(2)}%",
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: isProfit ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isProfit
                      ? Colors.green.withValues(alpha: 0.05)
                      : Colors.red.withValues(alpha: 0.05),
                  isProfit
                      ? Colors.green.withValues(alpha: 0.02)
                      : Colors.red.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isProfit
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Current Value",
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      "\$${currentValue.toStringAsFixed(2)}",
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total P&L",
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      "${isProfit ? '+' : ''}\$${profitLoss.toStringAsFixed(2)}",
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isProfit ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  "Total Owned",
                  "${totalOwned.toStringAsFixed(6)} ${(holdingsData["symbol"] as String? ?? "BTC").toUpperCase()}",
                  Icons.account_balance_wallet_outlined,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildStatCard(
                  theme,
                  "Avg. Price",
                  "\$${averagePrice.toStringAsFixed(2)}",
                  Icons.trending_up_outlined,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  "Total Invested",
                  "\$${totalInvested.toStringAsFixed(2)}",
                  Icons.savings_outlined,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildStatCard(
                  theme,
                  "Transactions",
                  "${holdingsData["transaction_count"] as int? ?? 0}",
                  Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      ThemeData theme, String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: icon
                    .toString()
                    .split('.')
                    .last
                    .replaceAll('IconData(', '')
                    .replaceAll(')', ''),
                color: theme.colorScheme.primary,
                size: 16,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
