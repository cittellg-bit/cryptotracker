import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class UpdateFrequencyWidget extends StatefulWidget {
  final int selectedFrequency;
  final ValueChanged<int> onFrequencyChanged;

  const UpdateFrequencyWidget({
    super.key,
    required this.selectedFrequency,
    required this.onFrequencyChanged,
  });

  @override
  State<UpdateFrequencyWidget> createState() => _UpdateFrequencyWidgetState();
}

class _UpdateFrequencyWidgetState extends State<UpdateFrequencyWidget> {
  final List<Map<String, dynamic>> frequencies = [
    {
      'minutes': 5,
      'label': '5 minutes',
      'description': 'High frequency updates (Higher battery usage)',
      'batteryImpact': 'High',
    },
    {
      'minutes': 15,
      'label': '15 minutes',
      'description': 'Recommended frequency (Balanced)',
      'batteryImpact': 'Medium',
    },
    {
      'minutes': 30,
      'label': '30 minutes',
      'description': 'Standard updates (Lower battery usage)',
      'batteryImpact': 'Low',
    },
    {
      'minutes': 60,
      'label': '1 hour',
      'description': 'Minimal updates (Lowest battery usage)',
      'batteryImpact': 'Minimal',
    },
  ];

  void _showFrequencyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FrequencyPickerBottomSheet(
        frequencies: frequencies,
        selectedFrequency: widget.selectedFrequency,
        onFrequencySelected: (frequency) {
          HapticFeedback.selectionClick();
          widget.onFrequencyChanged(frequency);
          Navigator.pop(context);
        },
      ),
    );
  }

  String _getFrequencyLabel(int minutes) {
    final frequency = frequencies.firstWhere(
      (freq) => freq['minutes'] == minutes,
      orElse: () => frequencies[1], // Default to 15 minutes
    );
    return frequency['label'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFrequencyPicker(context),
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
              _getFrequencyLabel(widget.selectedFrequency),
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

class _FrequencyPickerBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> frequencies;
  final int selectedFrequency;
  final ValueChanged<int> onFrequencySelected;

  const _FrequencyPickerBottomSheet({
    required this.frequencies,
    required this.selectedFrequency,
    required this.onFrequencySelected,
  });

  Color _getBatteryImpactColor(String impact, ThemeData theme) {
    switch (impact.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      case 'minimal':
        return Colors.blue;
      default:
        return theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
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
                  'Update Frequency',
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'info',
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Higher frequency updates provide more real-time data but consume more battery.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: frequencies.length,
              itemBuilder: (context, index) {
                final frequency = frequencies[index];
                final isSelected = frequency['minutes'] == selectedFrequency;
                final batteryImpact = frequency['batteryImpact'] as String;

                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.2),
                            width: 1,
                          )
                        : null,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getBatteryImpactColor(batteryImpact, theme)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: CustomIconWidget(
                          iconName: 'schedule',
                          color: _getBatteryImpactColor(batteryImpact, theme),
                          size: 20,
                        ),
                      ),
                    ),
                    title: Text(
                      frequency['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          frequency['description'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            CustomIconWidget(
                              iconName: 'battery_alert',
                              color:
                                  _getBatteryImpactColor(batteryImpact, theme),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Battery: $batteryImpact',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _getBatteryImpactColor(
                                    batteryImpact, theme),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: isSelected
                        ? CustomIconWidget(
                            iconName: 'check_circle',
                            color: theme.colorScheme.primary,
                            size: 24,
                          )
                        : null,
                    onTap: () =>
                        onFrequencySelected(frequency['minutes'] as int),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
