import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class IndividualTransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const IndividualTransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Extract transaction data with null safety
    final cryptoSymbol = transaction['crypto_symbol'] as String? ?? 'N/A';
    final cryptoName = transaction['crypto_name'] as String? ?? 'Unknown';
    final cryptoIconUrl = transaction['crypto_icon_url'] as String? ?? '';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final pricePerUnit =
        (transaction['price_per_unit'] as num?)?.toDouble() ?? 0.0;
    final transactionType = transaction['transaction_type'] as String? ?? 'buy';
    final exchange = transaction['exchange'] as String? ?? 'Unknown';
    final transactionDate =
        DateTime.tryParse(transaction['transaction_date'] as String? ?? '') ??
        DateTime.now();
    final totalValue = amount * pricePerUnit;

    final isBuyTransaction = transactionType.toLowerCase() == 'buy';
    final transactionColor =
        isBuyTransaction
            ? AppTheme.getSuccessColor(theme.brightness == Brightness.light)
            : AppTheme.getWarningColor(theme.brightness == Brightness.light);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showActionMenu(context);
          },
          child: Padding(
            padding: EdgeInsets.all(3.w),
            child: Row(
              children: [
                // Crypto Icon and Transaction Type Indicator
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      child: ClipOval(
                        child: CustomImageWidget(
                          imageUrl: cryptoIconUrl,
                          width: 12.w,
                          height: 12.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      width: 4.w,
                      height: 4.w,
                      decoration: BoxDecoration(
                        color: transactionColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isBuyTransaction ? Icons.add : Icons.remove,
                        color: Colors.white,
                        size: 2.5.w,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 3.w),

                // Transaction Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${isBuyTransaction ? 'Buy' : 'Sell'} $cryptoSymbol',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 1.5.w,
                              vertical: 0.2.h,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              exchange,
                              style: GoogleFonts.inter(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        '${amount.toStringAsFixed(6)} $cryptoSymbol at \$${pricePerUnit.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        _formatDate(transactionDate),
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Total Value
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${totalValue.toStringAsFixed(2)}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: transactionColor,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 1.5.w,
                        vertical: 0.3.h,
                      ),
                      decoration: BoxDecoration(
                        color: transactionColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        transactionType.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w600,
                          color: transactionColor,
                        ),
                      ),
                    ),
                  ],
                ),

                // More Options
                SizedBox(width: 2.w),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showActionMenu(context);
                  },
                  child: Container(
                    padding: EdgeInsets.all(1.5.w),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: CustomIconWidget(
                      iconName: 'more_vert',
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Today";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} days ago";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  void _showActionMenu(BuildContext context) {
    final theme = Theme.of(context);
    final cryptoSymbol = transaction['crypto_symbol'] as String? ?? 'N/A';
    final transactionType = transaction['transaction_type'] as String? ?? 'buy';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10.w,
                          height: 10.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                          ),
                          child: ClipOval(
                            child: CustomImageWidget(
                              imageUrl:
                                  transaction['crypto_icon_url'] as String? ??
                                  '',
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
                              '${transactionType.capitalize()} $cryptoSymbol',
                              style: GoogleFonts.inter(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '${amount.toStringAsFixed(6)} $cryptoSymbol',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
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
                      onTap?.call();
                    },
                  ),

                  ListTile(
                    leading: CustomIconWidget(
                      iconName: 'edit_outlined',
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    title: Text(
                      'Edit Transaction',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onEdit?.call();
                    },
                  ),

                  const Divider(),

                  ListTile(
                    leading: CustomIconWidget(
                      iconName: 'delete_outline',
                      color: AppTheme.getWarningColor(
                        theme.brightness == Brightness.light,
                      ),
                      size: 24,
                    ),
                    title: Text(
                      'Delete Transaction',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.getWarningColor(
                          theme.brightness == Brightness.light,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onDelete?.call();
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

// Extension to capitalize strings
extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}
