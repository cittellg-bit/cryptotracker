import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class TransactionFormWidget extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const TransactionFormWidget({
    super.key,
    required this.transaction,
    required this.onSave,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  State<TransactionFormWidget> createState() => _TransactionFormWidgetState();
}

class _TransactionFormWidgetState extends State<TransactionFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _hasChanges = false;
  bool _isLoading = false;

  double _currentPrice = 0.0;
  double _totalValue = 0.0;
  double _profitLoss = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _calculateValues();
  }

  void _initializeForm() {
    _amountController.text = widget.transaction['amount']?.toString() ?? '';
    _priceController.text = widget.transaction['price']?.toString() ?? '';
    _notesController.text = widget.transaction['notes']?.toString() ?? '';
    _selectedDate = DateTime.parse(
        widget.transaction['date'] ?? DateTime.now().toIso8601String());
    _currentPrice =
        (widget.transaction['currentPrice'] as num?)?.toDouble() ?? 0.0;

    _amountController.addListener(_onFormChanged);
    _priceController.addListener(_onFormChanged);
    _notesController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    setState(() {
      _hasChanges = true;
    });
    _calculateValues();
  }

  void _calculateValues() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final purchasePrice = double.tryParse(_priceController.text) ?? 0.0;

    setState(() {
      _totalValue = amount * _currentPrice;
      _profitLoss = (amount * _currentPrice) - (amount * purchasePrice);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCryptocurrencyField(theme),
          SizedBox(height: 3.h),
          _buildAmountField(theme),
          SizedBox(height: 3.h),
          _buildPriceField(theme),
          SizedBox(height: 3.h),
          _buildDateField(theme),
          SizedBox(height: 3.h),
          _buildNotesField(theme),
          SizedBox(height: 4.h),
          _buildCalculationSummary(theme),
          SizedBox(height: 4.h),
          _buildActionButtons(theme),
        ],
      ),
    );
  }

  Widget _buildCryptocurrencyField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cryptocurrency',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: CustomIconWidget(
                  iconName: 'currency_bitcoin',
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
                      widget.transaction['name'] ?? 'Bitcoin',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.transaction['symbol'] ?? 'BTC',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              CustomIconWidget(
                iconName: 'lock',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 4.w,
              ),
            ],
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          'Cryptocurrency type cannot be changed for data integrity',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 10.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          decoration: InputDecoration(
            hintText: 'Enter amount',
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'numbers',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 5.w,
              ),
            ),
            suffixText: widget.transaction['symbol'] ?? 'BTC',
            suffixStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid positive amount';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPriceField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price per Unit',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          decoration: InputDecoration(
            hintText: 'Enter price per unit',
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'attach_money',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 5.w,
              ),
            ),
            suffixText: 'USD',
            suffixStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter price per unit';
            }
            final price = double.tryParse(value);
            if (price == null || price <= 0) {
              return 'Please enter a valid positive price';
            }
            if (price > 1000000) {
              return 'Price seems unrealistic. Please verify.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDateField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Purchase Date & Time',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        GestureDetector(
          onTap: _selectDateTime,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'calendar_today',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 5.w,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(_selectedDate),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatTime(_selectedDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                CustomIconWidget(
                  iconName: 'keyboard_arrow_down',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 5.w,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add any notes about this transaction...',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 3.w, right: 3.w, top: 3.w),
              child: CustomIconWidget(
                iconName: 'note',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 5.w,
              ),
            ),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCalculationSummary(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Updated Calculation',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Value:',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '\$${_totalValue.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profit/Loss:',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${_profitLoss >= 0 ? '+' : ''}\$${_profitLoss.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _profitLoss >= 0
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

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 6.h,
          child: ElevatedButton(
            onPressed: _hasChanges && !_isLoading ? _saveChanges : null,
            child: _isLoading
                ? SizedBox(
                    width: 5.w,
                    height: 5.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Text(
                    'Save Changes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 2.h),
        SizedBox(
          width: double.infinity,
          height: 6.h,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _handleCancel,
            child: Text(
              'Cancel',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h),
        SizedBox(
          width: double.infinity,
          height: 6.h,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _showDeleteConfirmation,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppTheme.getWarningColor(
                    theme.brightness == Brightness.light),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomIconWidget(
                  iconName: 'delete_outline',
                  color: AppTheme.getWarningColor(
                      theme.brightness == Brightness.light),
                  size: 5.w,
                ),
                SizedBox(width: 2.w),
                Text(
                  'Delete Transaction',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.getWarningColor(
                        theme.brightness == Brightness.light),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2009), // Bitcoin creation year
      lastDate: DateTime.now(),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          _hasChanges = true;
        });
      }
    }
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    final updatedTransaction = {
      ...widget.transaction,
      'amount': double.parse(_amountController.text),
      'price': double.parse(_priceController.text),
      'date': _selectedDate.toIso8601String(),
      'notes': _notesController.text.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isLoading = false;
    });

    widget.onSave(updatedTransaction);
  }

  void _handleCancel() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
              'You have unsaved changes. Are you sure you want to cancel?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onCancel();
              },
              child: const Text('Discard Changes'),
            ),
          ],
        ),
      );
    } else {
      widget.onCancel();
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
            'Are you sure you want to delete this transaction? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showFinalDeleteConfirmation();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.getWarningColor(
                  Theme.of(context).brightness == Brightness.light),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFinalDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: const Text(
            'This will permanently delete the transaction and recalculate your portfolio. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.getWarningColor(
                  Theme.of(context).brightness == Brightness.light),
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
