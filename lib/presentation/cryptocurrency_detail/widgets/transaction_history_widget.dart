import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class TransactionHistoryWidget extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;
  final String coinSymbol;
  final double currentPrice;

  const TransactionHistoryWidget({
    super.key,
    required this.transactions,
    required this.coinSymbol,
    required this.currentPrice,
  });

  @override
  State<TransactionHistoryWidget> createState() =>
      _TransactionHistoryWidgetState();
}

class _TransactionHistoryWidgetState extends State<TransactionHistoryWidget> {
  int? expandedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                "Transaction History",
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${widget.transactions.length} transactions",
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          widget.transactions.isEmpty
              ? _buildEmptyState(theme)
              : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.transactions.length,
                separatorBuilder: (context, index) => SizedBox(height: 1.h),
                itemBuilder: (context, index) {
                  final transaction = widget.transactions[index];
                  return _buildTransactionCard(theme, transaction, index);
                },
              ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(6.w),
      child: Column(
        children: [
          CustomIconWidget(
            iconName: 'receipt_long_outlined',
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            size: 48,
          ),
          SizedBox(height: 2.h),
          Text(
            "No transactions yet",
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            "Start by adding your first ${widget.coinSymbol.toUpperCase()} purchase",
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    ThemeData theme,
    Map<String, dynamic> transaction,
    int index,
  ) {
    final amount = (transaction["amount"] as num?)?.toDouble() ?? 0.0;
    final price =
        (transaction["price"] as num?)?.toDouble() ??
        (transaction["price_per_unit"] as num?)?.toDouble() ??
        0.0;
    final totalValue = amount * price;
    final currentValue = amount * widget.currentPrice;
    final profitLoss = currentValue - totalValue;
    final profitLossPercent =
        totalValue > 0 ? (profitLoss / totalValue) * 100 : 0.0;
    final isProfit = profitLoss >= 0;

    final dateString =
        transaction["date"] as String? ??
        transaction["transaction_date"] as String? ??
        DateTime.now().toIso8601String();
    final date = DateTime.tryParse(dateString) ?? DateTime.now();

    final isExpanded = expandedIndex == index;

    final transactionType =
        transaction["type"] as String? ??
        transaction["transaction_type"] as String? ??
        'buy';
    final exchange = transaction["exchange"] as String? ?? 'Unknown';

    return Dismissible(
      key: Key('transaction_${transaction["id"] ?? index}'),
      background: _buildSwipeBackground(theme, false),
      secondaryBackground: _buildSwipeBackground(theme, true),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return await _showDeleteConfirmation(context, transaction);
        } else {
          _editTransaction(context, transaction);
          return false;
        }
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            expandedIndex = isExpanded ? null : index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isExpanded
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomIconWidget(
                      iconName:
                          transactionType.toLowerCase() == 'buy'
                              ? 'add_circle_outline'
                              : 'remove_circle_outline',
                      color:
                          transactionType.toLowerCase() == 'buy'
                              ? AppTheme.getSuccessColor(
                                theme.brightness == Brightness.light,
                              )
                              : AppTheme.getWarningColor(
                                theme.brightness == Brightness.light,
                              ),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${transactionType.capitalize()} ${widget.coinSymbol.toUpperCase()}",
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              "\$${totalValue.toStringAsFixed(2)}",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 0.5.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "${_formatDate(date)} • ${amount.toStringAsFixed(6)} ${widget.coinSymbol.toUpperCase()}",
                                style: GoogleFonts.inter(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w400,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 1.5.w,
                                vertical: 0.3.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isProfit
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "${isProfit ? '+' : ''}${profitLossPercent.toStringAsFixed(1)}%",
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isProfit ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (exchange != 'Unknown') ...[
                          SizedBox(height: 0.3.h),
                          Row(
                            children: [
                              Text(
                                'Exchange: ',
                                style: GoogleFonts.inter(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w400,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              Text(
                                exchange,
                                style: GoogleFonts.inter(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 2.w),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: CustomIconWidget(
                      iconName: 'keyboard_arrow_down',
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                ],
              ),
              if (isExpanded) ...[
                SizedBox(height: 2.h),
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        theme,
                        "Purchase Price",
                        "\$${price.toStringAsFixed(2)}",
                      ),
                      SizedBox(height: 1.h),
                      _buildDetailRow(
                        theme,
                        "Current Price",
                        "\$${widget.currentPrice.toStringAsFixed(2)}",
                      ),
                      SizedBox(height: 1.h),
                      _buildDetailRow(
                        theme,
                        "Amount",
                        "${amount.toStringAsFixed(6)} ${widget.coinSymbol.toUpperCase()}",
                      ),
                      SizedBox(height: 1.h),
                      _buildDetailRow(
                        theme,
                        "Current Value",
                        "\$${currentValue.toStringAsFixed(2)}",
                      ),
                      SizedBox(height: 1.h),
                      _buildDetailRow(
                        theme,
                        "Profit/Loss",
                        "${isProfit ? '+' : ''}\$${profitLoss.toStringAsFixed(2)}",
                        valueColor: isProfit ? Colors.green : Colors.red,
                      ),
                      if (exchange != 'Unknown') ...[
                        SizedBox(height: 1.h),
                        _buildDetailRow(theme, "Exchange", exchange),
                      ],
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  () => _editTransaction(context, transaction),
                              icon: CustomIconWidget(
                                iconName: 'edit_outlined',
                                color: theme.colorScheme.primary,
                                size: 16,
                              ),
                              label: Text(
                                "Edit",
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 1.h),
                              ),
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  () => _showDeleteConfirmation(
                                    context,
                                    transaction,
                                  ),
                              icon: CustomIconWidget(
                                iconName: 'delete_outline',
                                color: Colors.red,
                                size: 16,
                              ),
                              label: Text(
                                "Delete",
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: EdgeInsets.symmetric(vertical: 1.h),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeBackground(ThemeData theme, bool isDelete) {
    return Container(
      alignment: isDelete ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: isDelete ? Colors.red : theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomIconWidget(
            iconName: isDelete ? 'delete' : 'edit',
            color: Colors.white,
            size: 24,
          ),
          SizedBox(height: 0.5.h),
          Text(
            isDelete ? "Delete" : "Edit",
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
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

  void _editTransaction(
    BuildContext context,
    Map<String, dynamic> transaction,
  ) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(
      context,
      '/edit-transaction',
      arguments: {'transaction': transaction, 'coinSymbol': widget.coinSymbol},
    );
  }

  Future<bool> _showDeleteConfirmation(
    BuildContext context,
    Map<String, dynamic> transaction,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Delete Transaction",
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Text(
                "Are you sure you want to delete this transaction? This action cannot be undone.",
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Transaction deleted successfully",
                          style: GoogleFonts.inter(fontSize: 12.sp),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text(
                    "Delete",
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}
