import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class CoinHeaderWidget extends StatelessWidget {
  final Map<String, dynamic> coinData;

  const CoinHeaderWidget({
    super.key,
    required this.coinData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceChange = (coinData["price_change_24h"] as double?) ?? 0.0;
    final priceChangePercent =
        (coinData["price_change_percentage_24h"] as double?) ?? 0.0;
    final isPositive = priceChange >= 0;

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
        children: [
          Row(
            children: [
              Container(
                width: 15.w,
                height: 15.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: CustomImageWidget(
                  imageUrl: coinData["image"] as String? ??
                      "https://cryptologos.cc/logos/bitcoin-btc-logo.png",
                  width: 12.w,
                  height: 12.w,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coinData["name"] as String? ?? "Bitcoin",
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      (coinData["symbol"] as String? ?? "BTC").toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "\$${(coinData["current_price"] as double? ?? 0.0).toStringAsFixed(2)}",
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName:
                              isPositive ? 'trending_up' : 'trending_down',
                          color: isPositive ? Colors.green : Colors.red,
                          size: 12.sp,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          "${isPositive ? '+' : ''}${priceChangePercent.toStringAsFixed(2)}%",
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: isPositive ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "24h Change",
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        "\$${priceChange.toStringAsFixed(2)}",
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 4.h,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "Market Cap",
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        "\$${_formatLargeNumber(coinData["market_cap"] as double? ?? 0.0)}",
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 4.h,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "Volume",
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        "\$${_formatLargeNumber(coinData["total_volume"] as double? ?? 0.0)}",
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLargeNumber(double number) {
    if (number >= 1e12) {
      return "${(number / 1e12).toStringAsFixed(2)}T";
    } else if (number >= 1e9) {
      return "${(number / 1e9).toStringAsFixed(2)}B";
    } else if (number >= 1e6) {
      return "${(number / 1e6).toStringAsFixed(2)}M";
    } else if (number >= 1e3) {
      return "${(number / 1e3).toStringAsFixed(2)}K";
    } else {
      return number.toStringAsFixed(2);
    }
  }
}
