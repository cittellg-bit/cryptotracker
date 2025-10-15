import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class CryptoListItemWidget extends StatelessWidget {
  final Map<String, dynamic> crypto;
  final VoidCallback onTap;
  final bool isFromSearch;

  const CryptoListItemWidget({
    super.key,
    required this.crypto,
    required this.onTap,
    this.isFromSearch = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final currentPrice = (crypto['current_price'] as num?)?.toDouble() ?? 0.0;
    final priceChange24h =
        (crypto['price_change_percentage_24h'] as num?)?.toDouble() ?? 0.0;
    final marketCapRank = crypto['market_cap_rank'] as int? ?? 0;
    final marketCap = (crypto['market_cap'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(3.w),
            child: Row(
              children: [
                _buildCryptoIcon(theme),
                SizedBox(width: 3.w),
                Expanded(
                  child: _buildCryptoInfo(theme),
                ),
                _buildPriceInfo(theme, currentPrice, priceChange24h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCryptoIcon(ThemeData theme) {
    return Container(
      width: 12.w,
      height: 12.w,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: crypto['image'] != null
            ? CustomImageWidget(
                imageUrl: crypto['image'],
                width: 12.w,
                height: 12.w,
                fit: BoxFit.cover,
              )
            : CustomIconWidget(
                iconName: 'currency_bitcoin',
                color: theme.colorScheme.primary,
                size: 7.w,
              ),
      ),
    );
  }

  Widget _buildCryptoInfo(ThemeData theme) {
    final marketCapRank = crypto['market_cap_rank'] as int? ?? 0;
    final marketCap = (crypto['market_cap'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (marketCapRank > 0) ...[
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.3.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#$marketCapRank',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(width: 2.w),
            ],
            Expanded(
              child: Text(
                crypto['name'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isFromSearch)
              Container(
                margin: EdgeInsets.only(left: 1.w),
                padding:
                    EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.2.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'NEW',
                  style: GoogleFonts.inter(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 0.5.h),
        Row(
          children: [
            Text(
              crypto['symbol'] ?? '',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (marketCap > 0) ...[
              Text(
                ' • ',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              Text(
                'MC: ${_formatMarketCap(marketCap)}',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPriceInfo(
      ThemeData theme, double currentPrice, double priceChange24h) {
    if (currentPrice == 0.0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Price N/A',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      );
    }

    final isPositive = priceChange24h >= 0;
    final changeColor = isPositive
        ? AppTheme.getSuccessColor(theme.brightness == Brightness.light)
        : AppTheme.getWarningColor(theme.brightness == Brightness.light);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '\$${_formatPrice(currentPrice)}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 0.3.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.3.h),
          decoration: BoxDecoration(
            color: changeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomIconWidget(
                iconName: isPositive ? 'trending_up' : 'trending_down',
                color: changeColor,
                size: 3.w,
              ),
              SizedBox(width: 1.w),
              Text(
                '${isPositive ? '+' : ''}${priceChange24h.toStringAsFixed(2)}%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: changeColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return price.toStringAsFixed(0);
    } else if (price >= 1) {
      return price.toStringAsFixed(2);
    } else if (price >= 0.01) {
      return price.toStringAsFixed(3);
    } else if (price >= 0.001) {
      return price.toStringAsFixed(4);
    } else {
      return price.toStringAsFixed(6);
    }
  }

  String _formatMarketCap(double marketCap) {
    if (marketCap >= 1e12) {
      return '\$${(marketCap / 1e12).toStringAsFixed(1)}T';
    } else if (marketCap >= 1e9) {
      return '\$${(marketCap / 1e9).toStringAsFixed(1)}B';
    } else if (marketCap >= 1e6) {
      return '\$${(marketCap / 1e6).toStringAsFixed(1)}M';
    } else if (marketCap >= 1e3) {
      return '\$${(marketCap / 1e3).toStringAsFixed(1)}K';
    } else {
      return '\$${marketCap.toStringAsFixed(0)}';
    }
  }
}
