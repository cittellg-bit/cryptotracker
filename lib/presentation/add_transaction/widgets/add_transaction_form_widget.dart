import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/services/transaction_service.dart';
import '../../../core/services/crypto_service.dart';

class AddTransactionFormWidget extends StatefulWidget {
  final Map<String, dynamic>? selectedCrypto;
  final Map<String, dynamic>? transaction;
  final Function(Map<String, dynamic>)? onTransactionSaved;
  final Function(Map<String, dynamic>)? onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onCryptoSelect;
  final bool isLoadingPrice;

  const AddTransactionFormWidget({
    super.key,
    this.selectedCrypto,
    this.transaction,
    this.onTransactionSaved,
    this.onSave,
    this.onCancel,
    this.onCryptoSelect,
    this.isLoadingPrice = false,
  });

  @override
  State<AddTransactionFormWidget> createState() =>
      _AddTransactionFormWidgetState();
}

class _AddTransactionFormWidgetState extends State<AddTransactionFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _exchangeController = TextEditingController();

  String _transactionType = 'buy';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isLoadingPrice = false;
  String? _errorMessage;

  final CryptoService _cryptoService = CryptoService.instance;

  // Popular exchanges list for dropdown
  final List<String> _popularExchanges = [
    'Binance',
    'Coinbase',
    'Kraken',
    'Bitfinex',
    'Huobi',
    'KuCoin',
    'Gate.io',
    'Bybit',
    'OKX',
    'Crypto.com',
    'Other',
  ];
  String _selectedExchange = 'Binance';

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void didUpdateWidget(AddTransactionFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-populate price when crypto is selected or changed
    if (oldWidget.selectedCrypto != widget.selectedCrypto &&
        widget.selectedCrypto != null) {
      _autoPopulatePrice();
    }
  }

  void _initializeForm() {
    if (widget.transaction != null) {
      // Editing existing transaction
      final transaction = widget.transaction!;
      _quantityController.text = (transaction['amount'] ?? 0.0).toString();
      _priceController.text = (transaction['price_per_unit'] ?? 0.0).toString();
      _notesController.text = transaction['notes'] ?? '';
      _transactionType = transaction['transaction_type'] ?? 'buy';
      _selectedExchange =
          transaction['exchange'] ?? 'Binance'; // Load existing exchange
      _exchangeController.text =
          _selectedExchange == 'Other' ? (transaction['exchange'] ?? '') : '';

      if (transaction['transaction_date'] != null) {
        try {
          _selectedDate = DateTime.parse(transaction['transaction_date']);
        } catch (e) {
          _selectedDate = DateTime.now();
        }
      }
    } else if (widget.selectedCrypto != null) {
      // New transaction with selected crypto - auto-populate price
      _autoPopulatePrice();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _exchangeController.dispose();
    super.dispose();
  }

  /// Auto-populate price from selected cryptocurrency data
  Future<void> _autoPopulatePrice() async {
    if (widget.selectedCrypto == null) return;

    final crypto = widget.selectedCrypto!;
    double? price;

    // First try to get price from crypto data
    if (crypto['current_price'] != null && crypto['current_price'] > 0) {
      price = (crypto['current_price'] as num).toDouble();
    } else {
      // If no price in crypto data, fetch from API
      setState(() {
        _isLoadingPrice = true;
      });

      try {
        price = await _cryptoService.getCurrentPrice(crypto['id'] ?? '');
      } catch (e) {
        // Failed to fetch price, continue without auto-population
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingPrice = false;
          });
        }
      }
    }

    // Populate the price field if we got a valid price
    if (price != null && price > 0 && mounted) {
      setState(() {
        _priceController.text = price.toString();
      });

      // HIDDEN: Show a subtle indication that price was auto-populated
      // User requested to hide this banner while keeping functionality
      /*
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Current price auto-filled: \$${price.toStringAsFixed(2)}',
            style: GoogleFonts.inter(fontSize: 12.sp),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
      */
    }
  }

  Future<void> _saveTransaction() async {
    // Clear any previous error messages
    setState(() {
      _errorMessage = null;
    });

    // Validate cryptocurrency selection
    if (widget.selectedCrypto == null) {
      setState(() {
        _errorMessage = 'Please select a cryptocurrency first';
      });
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get final exchange value
      String finalExchange =
          _selectedExchange == 'Other'
              ? _exchangeController.text.trim()
              : _selectedExchange;

      // Create transaction data with proper parameters for saveTransaction
      await TransactionService.instance.saveTransaction(
        cryptoId: widget.selectedCrypto?['id'] ?? '',
        symbol:
            widget.selectedCrypto?['symbol'] ??
            widget.selectedCrypto?['crypto_symbol'] ??
            '',
        name:
            widget.selectedCrypto?['name'] ??
            widget.selectedCrypto?['crypto_name'] ??
            '',
        iconUrl:
            widget.selectedCrypto?['image'] ??
            widget.selectedCrypto?['crypto_icon_url'] ??
            '',
        type: _transactionType,
        amount: double.parse(_quantityController.text),
        price: double.parse(_priceController.text),
        date: _selectedDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        exchange: finalExchange, // Pass exchange parameter
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Create transaction data for callback
        final transactionData = {
          'cryptocurrency_id': widget.selectedCrypto?['id'],
          'transaction_type': _transactionType,
          'quantity': double.parse(_quantityController.text),
          'price_per_unit': double.parse(_priceController.text),
          'transaction_date': _selectedDate.toIso8601String(),
          'notes': _notesController.text.isEmpty ? null : _notesController.text,
          'exchange': finalExchange, // Include exchange in callback data
          'created_at': DateTime.now().toIso8601String(),
        };

        widget.onTransactionSaved?.call(transactionData);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving transaction: $e');
      }

      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save transaction: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save transaction: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(label: 'Retry', onPressed: _saveTransaction),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveTransactionForParent() async {
    // Clear any previous error messages
    setState(() {
      _errorMessage = null;
    });

    // Validate cryptocurrency selection
    if (widget.selectedCrypto == null) {
      setState(() {
        _errorMessage = 'Please select a cryptocurrency first';
      });
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final crypto = widget.selectedCrypto!;
      final amount = double.parse(_quantityController.text);
      final price = double.parse(_priceController.text);

      // Get final exchange value
      String finalExchange =
          _selectedExchange == 'Other'
              ? _exchangeController.text.trim()
              : _selectedExchange;

      final transactionData = {
        'crypto': crypto,
        'type': _transactionType,
        'amount': amount,
        'price': price,
        'date': _selectedDate,
        'notes': _notesController.text,
        'exchange': finalExchange, // Include exchange in parent data
      };

      // Call parent's save method
      widget.onSave!(transactionData);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: const ColorScheme.light()),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Refresh current price for selected cryptocurrency
  Future<void> _refreshPrice() async {
    if (widget.selectedCrypto == null) return;

    setState(() {
      _isLoadingPrice = true;
    });

    try {
      final price = await _cryptoService.getCurrentPrice(
        widget.selectedCrypto!['id'] ?? '',
      );

      if (price != null && mounted) {
        setState(() {
          _priceController.text = price.toString();
        });

        // Haptic feedback for successful refresh
        HapticFeedback.lightImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Price updated: \$${price.toStringAsFixed(2)}',
              style: GoogleFonts.inter(fontSize: 12.sp),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to fetch current price. Please enter manually.',
              style: GoogleFonts.inter(fontSize: 12.sp),
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to refresh price. Check your connection.',
              style: GoogleFonts.inter(fontSize: 12.sp),
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPrice = false;
        });
      }
    }
  }

  String get _totalValue {
    try {
      final amount = double.tryParse(_quantityController.text) ?? 0.0;
      final price = double.tryParse(_priceController.text) ?? 0.0;
      return (amount * price).toStringAsFixed(2);
    } catch (e) {
      return '0.00';
    }
  }

  @override
  Widget build(BuildContext context) {
    final crypto = widget.selectedCrypto;

    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Crypto selection button if no crypto is selected
            if (crypto == null) ...[
              GestureDetector(
                onTap: widget.onCryptoSelect,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(3.w),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 6.w,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'Select Cryptocurrency',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 4.h),
            ],

            // Selected crypto display
            if (crypto != null) ...[
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(3.w),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(6.w),
                      ),
                      child: Center(
                        child: Text(
                          (crypto['symbol'] ?? crypto['crypto_symbol'] ?? 'N/A')
                              .toString()
                              .toUpperCase()
                              .substring(0, 2),
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            crypto['name'] ??
                                crypto['crypto_name'] ??
                                'Unknown',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            (crypto['symbol'] ??
                                    crypto['crypto_symbol'] ??
                                    'N/A')
                                .toString()
                                .toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 10.sp),
                          ),
                          // Show current price if available
                          if (crypto['current_price'] != null &&
                              crypto['current_price'] > 0)
                            Text(
                              'Current: \$${(crypto['current_price'] as num).toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.onCryptoSelect != null)
                      GestureDetector(
                        onTap: widget.onCryptoSelect,
                        child: Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(2.w),
                          ),
                          child: Text(
                            'Change',
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 4.h),
            ],

            // Transaction type selector
            Text(
              'Transaction Type',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _transactionType = 'buy'),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 3.h),
                      decoration: BoxDecoration(
                        color:
                            _transactionType == 'buy'
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(2.w),
                        border: Border.all(
                          color:
                              _transactionType == 'buy'
                                  ? Colors.green
                                  : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Buy',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color:
                                _transactionType == 'buy'
                                    ? Colors.green
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _transactionType = 'sell'),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 3.h),
                      decoration: BoxDecoration(
                        color:
                            _transactionType == 'sell'
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(2.w),
                        border: Border.all(
                          color:
                              _transactionType == 'sell'
                                  ? Colors.red
                                  : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Sell',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color:
                                _transactionType == 'sell'
                                    ? Colors.red
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),

            // Total Coins field
            Text(
              'Total Coins',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            TextFormField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: 'Enter total coins',
                suffixText:
                    (crypto?['symbol'] ?? crypto?['crypto_symbol'] ?? '')
                        .toString()
                        .toUpperCase(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                filled: true,
              ),
              style: GoogleFonts.inter(fontSize: 11.sp),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter total coins';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
              onChanged: (value) => setState(() {}), // Update total value
            ),
            SizedBox(height: 3.h),

            // Price per unit field with refresh functionality
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Price per unit (USD)',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (crypto != null)
                  GestureDetector(
                    onTap: _isLoadingPrice ? null : _refreshPrice,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(1.5.w),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoadingPrice)
                            SizedBox(
                              width: 3.w,
                              height: 3.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          else
                            Icon(
                              Icons.refresh,
                              size: 3.5.w,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          SizedBox(width: 1.w),
                          Text(
                            _isLoadingPrice ? 'Loading...' : 'Current',
                            style: GoogleFonts.inter(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 1.h),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: 'Enter price per unit',
                prefixText: '\$ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                filled: true,
              ),
              style: GoogleFonts.inter(fontSize: 11.sp),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a price';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Please enter a valid price';
                }
                return null;
              },
              onChanged: (value) => setState(() {}), // Update total value
            ),
            SizedBox(height: 3.h),

            // Exchange field
            Text(
              'Exchange',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            DropdownButtonFormField<String>(
              value: _selectedExchange,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                filled: true,
              ),
              items:
                  _popularExchanges.map((String exchange) {
                    return DropdownMenuItem<String>(
                      value: exchange,
                      child: Text(
                        exchange,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedExchange = newValue ?? 'Binance';
                  if (_selectedExchange != 'Other') {
                    _exchangeController.clear();
                  }
                });
              },
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
              ),
              dropdownColor: Theme.of(context).colorScheme.surface,
              iconEnabledColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
              iconDisabledColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),

            // Show custom exchange input when "Other" is selected
            if (_selectedExchange == 'Other') ...[
              SizedBox(height: 2.h),
              TextFormField(
                controller: _exchangeController,
                decoration: InputDecoration(
                  hintText: 'Enter exchange name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2.w),
                    borderSide: const BorderSide(),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2.w),
                    borderSide: const BorderSide(),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2.w),
                    borderSide: const BorderSide(),
                  ),
                  filled: true,
                ),
                style: GoogleFonts.inter(fontSize: 11.sp),
                validator: (value) {
                  if (_selectedExchange == 'Other' &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Please enter exchange name';
                  }
                  return null;
                },
              ),
            ],
            SizedBox(height: 3.h),

            // Total value display
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(2.w),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Value:',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '\$ $_totalValue',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3.h),

            // Date selector
            Text(
              'Date',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: GoogleFonts.inter(fontSize: 11.sp),
                    ),
                    Icon(Icons.calendar_today, size: 5.w),
                  ],
                ),
              ),
            ),
            SizedBox(height: 3.h),

            // Notes field
            Text(
              'Notes (Optional)',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add any notes about this transaction...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.w),
                  borderSide: const BorderSide(),
                ),
                filled: true,
              ),
              style: GoogleFonts.inter(fontSize: 11.sp),
            ),

            // Error message
            if (_errorMessage != null) ...[
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(2.w),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 5.w),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 3.h),

            // Action buttons
            Row(
              children: [
                if (widget.onCancel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 3.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2.w),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                              // Fixed: Simplified save button logic
                              if (widget.onSave != null) {
                                // This is for passing data to parent (form data only)
                                _saveTransactionForParent();
                              } else {
                                // This is for actual database save (standalone mode)
                                _saveTransaction();
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 3.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      elevation: 0,
                    ),
                    child:
                        _isLoading
                            ? SizedBox(
                              width: 5.w,
                              height: 5.w,
                              child: const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                              widget.transaction != null
                                  ? 'Update Transaction'
                                  : 'Save Transaction',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ],
            ),
            // Add bottom padding to ensure save button is accessible
            SizedBox(height: 5.h),
          ],
        ),
      ),
    );
  }
}
