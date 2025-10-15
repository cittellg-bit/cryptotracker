import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class CurrencySelectionWidget extends StatefulWidget {
  final String selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;

  const CurrencySelectionWidget({
    super.key,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
  });

  @override
  State<CurrencySelectionWidget> createState() =>
      _CurrencySelectionWidgetState();
}

class _CurrencySelectionWidgetState extends State<CurrencySelectionWidget> {
  final List<Map<String, dynamic>> currencies = [
    {
      'code': 'USD',
      'name': 'US Dollar',
      'symbol': '\$',
      'flag': '🇺🇸',
    },
    {
      'code': 'EUR',
      'name': 'Euro',
      'symbol': '€',
      'flag': '🇪🇺',
    },
    {
      'code': 'GBP',
      'name': 'British Pound',
      'symbol': '£',
      'flag': '🇬🇧',
    },
    {
      'code': 'JPY',
      'name': 'Japanese Yen',
      'symbol': '¥',
      'flag': '🇯🇵',
    },
  ];

  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CurrencyPickerBottomSheet(
        currencies: currencies,
        selectedCurrency: widget.selectedCurrency,
        onCurrencySelected: (currency) {
          HapticFeedback.selectionClick();
          widget.onCurrencyChanged(currency);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCurrencyData = currencies.firstWhere(
      (currency) => currency['code'] == widget.selectedCurrency,
      orElse: () => currencies.first,
    );

    return GestureDetector(
      onTap: () => _showCurrencyPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedCurrencyData['flag'] as String,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 8),
            Text(
              selectedCurrencyData['code'] as String,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            CustomIconWidget(
              iconName: 'keyboard_arrow_down',
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyPickerBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> currencies;
  final String selectedCurrency;
  final ValueChanged<String> onCurrencySelected;

  const _CurrencyPickerBottomSheet({
    required this.currencies,
    required this.selectedCurrency,
    required this.onCurrencySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Select Currency',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: CustomIconWidget(
                    iconName: 'close',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: currencies.length,
              itemBuilder: (context, index) {
                final currency = currencies[index];
                final isSelected = currency['code'] == selectedCurrency;

                return ListTile(
                  leading: Text(
                    currency['flag'] as String,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    currency['name'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '${currency['code']} (${currency['symbol']})',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: isSelected
                      ? CustomIconWidget(
                          iconName: 'check',
                          color: theme.colorScheme.primary,
                          size: 24,
                        )
                      : null,
                  onTap: () => onCurrencySelected(currency['code'] as String),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
