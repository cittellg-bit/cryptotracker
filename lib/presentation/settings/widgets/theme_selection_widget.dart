import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class ThemeSelectionWidget extends StatefulWidget {
  final ThemeMode selectedTheme;
  final ValueChanged<ThemeMode> onThemeChanged;

  const ThemeSelectionWidget({
    super.key,
    required this.selectedTheme,
    required this.onThemeChanged,
  });

  @override
  State<ThemeSelectionWidget> createState() => _ThemeSelectionWidgetState();
}

class _ThemeSelectionWidgetState extends State<ThemeSelectionWidget> {
  final List<Map<String, dynamic>> themes = [
    {
      'mode': ThemeMode.light,
      'name': 'Light',
      'description': 'Light theme for better visibility',
      'icon': 'light_mode',
    },
    {
      'mode': ThemeMode.dark,
      'name': 'Dark',
      'description': 'Dark theme for reduced eye strain',
      'icon': 'dark_mode',
    },
    {
      'mode': ThemeMode.system,
      'name': 'System',
      'description': 'Follow system theme settings',
      'icon': 'settings_brightness',
    },
  ];

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ThemePickerBottomSheet(
        themes: themes,
        selectedTheme: widget.selectedTheme,
        onThemeSelected: (theme) {
          HapticFeedback.selectionClick();
          widget.onThemeChanged(theme);
          Navigator.pop(context);
        },
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showThemePicker(context),
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
              _getThemeName(widget.selectedTheme),
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

class _ThemePickerBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> themes;
  final ThemeMode selectedTheme;
  final ValueChanged<ThemeMode> onThemeSelected;

  const _ThemePickerBottomSheet({
    required this.themes,
    required this.selectedTheme,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
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
                  'Select Theme',
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
              itemCount: themes.length,
              itemBuilder: (context, index) {
                final themeData = themes[index];
                final isSelected = themeData['mode'] == selectedTheme;

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: CustomIconWidget(
                        iconName: themeData['icon'] as String,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    themeData['name'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    themeData['description'] as String,
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
                  onTap: () => onThemeSelected(themeData['mode'] as ThemeMode),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
