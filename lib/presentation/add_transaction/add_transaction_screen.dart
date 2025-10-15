import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import './widgets/add_transaction_form_widget.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _selectedCrypto;

  /// Navigate to crypto selector and handle selection
  Future<void> _selectCryptocurrency() async {
    final selectedCrypto = await Navigator.pushNamed(
      context,
      AppRoutes.cryptoSelector,
    ) as Map<String, dynamic>?;

    if (selectedCrypto != null && mounted) {
      setState(() {
        _selectedCrypto = selectedCrypto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Add Transaction'),
          actions: [
            // Show ready status since no authentication is required
            Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                    child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.green.withAlpha(51),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle,
                              size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          Text('Ready', style: TextStyle(fontSize: 12)),
                        ])))),
          ],
        ),
        body: AddTransactionFormWidget(
            selectedCrypto: _selectedCrypto,
            onCryptoSelect: _selectCryptocurrency,
            onTransactionSaved: (Map<String, dynamic> transactionData) async {
              // Handle successful transaction save
              if (mounted) {
                Navigator.pop(context, true);
              }
            }));
  }
}
