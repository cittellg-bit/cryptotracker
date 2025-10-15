import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/transaction_form_widget.dart';

class EditTransaction extends StatefulWidget {
  const EditTransaction({super.key});

  @override
  State<EditTransaction> createState() => _EditTransactionState();
}

class _EditTransactionState extends State<EditTransaction>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Mock transaction data - in real app this would come from arguments or state management
  final Map<String, dynamic> _mockTransaction = {
    "id": "tx_001",
    "name": "Bitcoin",
    "symbol": "BTC",
    "amount": 0.5,
    "price": 45000.00,
    "currentPrice": 47500.00,
    "date": "2025-01-15T14:30:00.000Z",
    "notes": "DCA purchase during market dip",
    "createdAt": "2025-01-15T14:30:00.000Z",
    "updatedAt": "2025-01-15T14:30:00.000Z"
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start slide-up animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: SlideTransition(
        position: _slideAnimation,
        child: _buildBody(theme),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: Text(
        'Edit Transaction',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        icon: CustomIconWidget(
          iconName: 'close',
          color: theme.colorScheme.onSurface,
          size: 6.w,
        ),
        onPressed: _handleBackPress,
      ),
      actions: [
        IconButton(
          icon: CustomIconWidget(
            iconName: 'help_outline',
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            size: 6.w,
          ),
          onPressed: _showHelpDialog,
        ),
      ],
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
    );
  }

  Widget _buildBody(ThemeData theme) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Column(
                children: [
                  SizedBox(height: 2.h),
                  TransactionFormWidget(
                    transaction: _mockTransaction,
                    onSave: _handleSaveTransaction,
                    onCancel: _handleCancel,
                    onDelete: _handleDeleteTransaction,
                  ),
                  SizedBox(height: 4.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
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
            children: [
              Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomIconWidget(
                  iconName: 'edit',
                  color: theme.colorScheme.primary,
                  size: 6.w,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modify Transaction',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Update your ${_mockTransaction['name']} purchase details',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildTransactionSummary(theme),
        ],
      ),
    );
  }

  Widget _buildTransactionSummary(ThemeData theme) {
    final amount = (_mockTransaction['amount'] as num).toDouble();
    final price = (_mockTransaction['price'] as num).toDouble();
    final currentPrice = (_mockTransaction['currentPrice'] as num).toDouble();
    final totalInvested = amount * price;
    final currentValue = amount * currentPrice;
    final profitLoss = currentValue - totalInvested;

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Original Investment:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '\$${totalInvested.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 0.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Value:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '\$${currentValue.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 0.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profit/Loss:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '${profitLoss >= 0 ? '+' : ''}\$${profitLoss.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: profitLoss >= 0
                      ? AppTheme.getSuccessColor(
                          theme.brightness == Brightness.light)
                      : AppTheme.getWarningColor(
                          theme.brightness == Brightness.light),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleSaveTransaction(Map<String, dynamic> updatedTransaction) async {
    // Show loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 2.h),
              Text(
                'Saving changes...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      // Provide haptic feedback
      HapticFeedback.lightImpact();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CustomIconWidget(
                iconName: 'check_circle',
                color: Colors.white,
                size: 5.w,
              ),
              SizedBox(width: 2.w),
              const Text('Transaction updated successfully'),
            ],
          ),
          backgroundColor: AppTheme.getSuccessColor(
              Theme.of(context).brightness == Brightness.light),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back with slide-down animation
      _slideController.reverse().then((_) {
        Navigator.pop(context, updatedTransaction);
      });
    }
  }

  void _handleDeleteTransaction() async {
    // Show loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppTheme.getWarningColor(
                    Theme.of(context).brightness == Brightness.light),
              ),
              SizedBox(height: 2.h),
              Text(
                'Deleting transaction...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      // Provide haptic feedback
      HapticFeedback.mediumImpact();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CustomIconWidget(
                iconName: 'delete',
                color: Colors.white,
                size: 5.w,
              ),
              SizedBox(width: 2.w),
              const Text('Transaction deleted successfully'),
            ],
          ),
          backgroundColor: AppTheme.getWarningColor(
              Theme.of(context).brightness == Brightness.light),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back with slide-down animation
      _slideController.reverse().then((_) {
        Navigator.pop(context, {'deleted': true});
      });
    }
  }

  void _handleCancel() {
    _slideController.reverse().then((_) {
      Navigator.pop(context);
    });
  }

  void _handleBackPress() {
    _slideController.reverse().then((_) {
      Navigator.pop(context);
    });
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'help_outline',
              color: Theme.of(context).colorScheme.primary,
              size: 6.w,
            ),
            SizedBox(width: 2.w),
            const Text('Edit Transaction Help'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(
              'Cryptocurrency Type',
              'Cannot be changed to maintain data integrity and accurate portfolio calculations.',
            ),
            SizedBox(height: 2.h),
            _buildHelpItem(
              'Amount & Price',
              'Update the quantity and purchase price. Calculations will update automatically.',
            ),
            SizedBox(height: 2.h),
            _buildHelpItem(
              'Date & Time',
              'Adjust the purchase date and time. Future dates are not allowed.',
            ),
            SizedBox(height: 2.h),
            _buildHelpItem(
              'Delete Transaction',
              'Permanently removes the transaction and recalculates your portfolio.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }
}
