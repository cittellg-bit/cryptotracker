import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class CryptoHoldingCard extends StatefulWidget {
  final Map<String, dynamic> cryptoData;
  final VoidCallback? onTap;
  final VoidCallback? onAddPurchase;
  final VoidCallback? onViewHistory;
  final VoidCallback? onDelete;

  const CryptoHoldingCard({
    super.key,
    required this.cryptoData,
    this.onTap,
    this.onAddPurchase,
    this.onViewHistory,
    this.onDelete,
  });

  @override
  State<CryptoHoldingCard> createState() => _CryptoHoldingCardState();
}

class _CryptoHoldingCardState extends State<CryptoHoldingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crypto = widget.cryptoData;

    // HOLDINGS TILES FIX: Enhanced null-safe data extraction with proper fallbacks
    final currentPrice = _extractDoubleValue(crypto['currentPrice']) ??
        _extractDoubleValue(crypto['current_price']) ??
        0.0;
    final holdings = _extractDoubleValue(crypto['holdings']) ??
        _extractDoubleValue(crypto['total_amount']) ??
        0.0;
    final averagePrice = _extractDoubleValue(crypto['averagePrice']) ??
        _extractDoubleValue(crypto['average_price']) ??
        0.0;
    final exchange = crypto['exchange'] as String? ?? 'Unknown';

    // HOLDINGS TILES FIX: Validate all calculations before proceeding
    if (currentPrice <= 0 || holdings == 0) {
      // If we have invalid data, try to recalculate or show error state
      if (kDebugMode) {
        print(
            '⚠️ HOLDINGS TILES FIX: Invalid data detected for ${crypto['symbol']} - currentPrice: $currentPrice, holdings: $holdings');
      }
    }

    final totalValue = currentPrice * holdings;
    final totalInvested = averagePrice * holdings;
    final profitLoss = totalValue - totalInvested;

    // HOLDINGS TILES FIX: Prevent division by zero and handle invalid percentages
    final profitLossPercentage =
        totalInvested != 0.0 ? ((profitLoss / totalInvested.abs()) * 100) : 0.0;

    final isProfit = profitLoss >= 0;
    final priceChange24h = _extractDoubleValue(crypto['priceChange24h']) ??
        _extractDoubleValue(crypto['price_change_24h']) ??
        0.0;
    final isPriceUp = priceChange24h >= 0;

    // HOLDINGS TILES FIX: Debug output to help troubleshoot zero values
    if (kDebugMode && (totalValue == 0.0 || currentPrice == 0.0)) {
      print(
          '🔧 HOLDINGS TILES DEBUG: ${crypto['symbol']} - currentPrice: $currentPrice, holdings: $holdings, totalValue: $totalValue');
      print('   Original data: ${crypto.toString()}');
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onTap?.call();
                },
                onTapDown: (_) => _animationController.forward(),
                onTapUp: (_) => _animationController.reverse(),
                onTapCancel: () => _animationController.reverse(),
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  _showContextMenu(context);
                },
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12.w,
                            height: 12.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                            ),
                            child: ClipOval(
                              child: CustomImageWidget(
                                imageUrl: crypto['icon'] as String? ??
                                    crypto['image'] as String? ??
                                    '',
                                width: 12.w,
                                height: 12.w,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      crypto['symbol'] as String? ?? 'N/A',
                                      style: GoogleFonts.inter(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    SizedBox(width: 2.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 2.w, vertical: 0.3.h),
                                      decoration: BoxDecoration(
                                        color: isPriceUp
                                            ? AppTheme.getSuccessColor(
                                                    theme.brightness ==
                                                        Brightness.light)
                                                .withValues(alpha: 0.1)
                                            : AppTheme.getWarningColor(
                                                    theme.brightness ==
                                                        Brightness.light)
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${isPriceUp ? '+' : ''}${priceChange24h.toStringAsFixed(2)}%',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w500,
                                          color: isPriceUp
                                              ? AppTheme.getSuccessColor(
                                                  theme.brightness ==
                                                      Brightness.light)
                                              : AppTheme.getWarningColor(
                                                  theme.brightness ==
                                                      Brightness.light),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 0.5.h),
                                Text(
                                  crypto['name'] as String? ?? 'Unknown',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                // Exchange display
                                SizedBox(height: 0.3.h),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 1.5.w, vertical: 0.2.h),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    exchange,
                                    style: GoogleFonts.inter(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${currentPrice.toStringAsFixed(currentPrice > 1 ? 2 : 6)}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 0.5.h),
                              Text(
                                '${holdings.toStringAsFixed(holdings > 1 ? 4 : 6)} ${crypto['symbol'] ?? 'N/A'}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w400,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 3.w),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showOptionsMenu(context);
                            },
                            child: Container(
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: CustomIconWidget(
                                iconName: 'settings',
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
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
                                  'Value',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w400,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                SizedBox(height: 0.5.h),
                                Text(
                                  '\$${totalValue.toStringAsFixed(2)}',
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
                                  'P&L',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w400,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                SizedBox(height: 0.5.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isProfit ? '+' : ''}\$${profitLoss.toStringAsFixed(2)}',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: isProfit
                                            ? AppTheme.getSuccessColor(
                                                theme.brightness ==
                                                    Brightness.light)
                                            : AppTheme.getWarningColor(
                                                theme.brightness ==
                                                    Brightness.light),
                                      ),
                                    ),
                                    SizedBox(width: 1.w),
                                    Text(
                                      '(${isProfit ? '+' : ''}${profitLossPercentage.toStringAsFixed(1)}%)',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w500,
                                        color: isProfit
                                            ? AppTheme.getSuccessColor(
                                                theme.brightness ==
                                                    Brightness.light)
                                            : AppTheme.getWarningColor(
                                                theme.brightness ==
                                                    Brightness.light),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_isExpanded) ...[
                        SizedBox(height: 2.h),
                        Container(
                          width: double.infinity,
                          height: 1,
                          color: theme.dividerColor.withValues(alpha: 0.3),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Avg. Price',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w400,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                SizedBox(height: 0.5.h),
                                Text(
                                  '\$${averagePrice.toStringAsFixed(averagePrice > 1 ? 2 : 6)}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Invested',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w400,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                SizedBox(height: 0.5.h),
                                Text(
                                  '\$${totalInvested.toStringAsFixed(2)}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 1.h),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 1.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomIconWidget(
                                iconName: _isExpanded
                                    ? 'keyboard_arrow_up'
                                    : 'keyboard_arrow_down',
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // HOLDINGS TILES FIX: Helper method for safe double value extraction
  double? _extractDoubleValue(dynamic value) {
    if (value == null) return null;

    if (value is double) {
      return value.isFinite ? value : null;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is num) {
      final doubleValue = value.toDouble();
      return doubleValue.isFinite ? doubleValue : null;
    }

    if (value is String && value.isNotEmpty) {
      final parsedValue = double.tryParse(value);
      return (parsedValue != null && parsedValue.isFinite) ? parsedValue : null;
    }

    return null;
  }

  void _showOptionsMenu(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 2.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                child: Row(
                  children: [
                    Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      child: ClipOval(
                        child: CustomImageWidget(
                          imageUrl: widget.cryptoData['icon'] as String,
                          width: 10.w,
                          height: 10.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.cryptoData['name']} Options',
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          widget.cryptoData['symbol'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'add_circle_outline',
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  'Add Purchase',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onAddPurchase?.call();
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'history',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text(
                  'View History',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onViewHistory?.call();
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'info_outline',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text(
                  'View Details',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onTap?.call();
                },
              ),
              const Divider(),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'delete_outline',
                  color: AppTheme.getWarningColor(
                      theme.brightness == Brightness.light),
                  size: 24,
                ),
                title: Text(
                  'Delete Asset',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.getWarningColor(
                        theme.brightness == Brightness.light),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete?.call();
                },
              ),
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 2.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'add_circle_outline',
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  'Add Purchase',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onAddPurchase?.call();
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'history',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text(
                  'View History',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onViewHistory?.call();
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'info_outline',
                  color: theme.colorScheme.onSurface,
                  size: 24,
                ),
                title: Text(
                  'View Details',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onTap?.call();
                },
              ),
              const Divider(),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'delete_outline',
                  color: AppTheme.getWarningColor(
                      theme.brightness == Brightness.light),
                  size: 24,
                ),
                title: Text(
                  'Delete Asset',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.getWarningColor(
                        theme.brightness == Brightness.light),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete?.call();
                },
              ),
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }
}