import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

enum SettingsItemType {
  navigation,
  toggle,
  selection,
  action,
}

class SettingsItemWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? iconName;
  final SettingsItemType type;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onToggle;
  final String? selectedValue;
  final Color? iconColor;
  final bool showChevron;
  final Widget? trailing;

  const SettingsItemWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.iconName,
    this.type = SettingsItemType.navigation,
    this.onTap,
    this.value,
    this.onToggle,
    this.selectedValue,
    this.iconColor,
    this.showChevron = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.lightImpact();
            onTap!();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              if (iconName != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (iconColor ?? theme.colorScheme.primary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: CustomIconWidget(
                      iconName: iconName!,
                      color: iconColor ?? theme.colorScheme.primary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildTrailing(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final theme = Theme.of(context);

    if (trailing != null) return trailing!;

    switch (type) {
      case SettingsItemType.toggle:
        return Switch(
          value: value ?? false,
          onChanged: onToggle,
          activeColor: theme.colorScheme.primary,
        );

      case SettingsItemType.selection:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedValue != null) ...[
              Text(
                selectedValue!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (showChevron)
              CustomIconWidget(
                iconName: 'chevron_right',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
          ],
        );

      case SettingsItemType.action:
        return const SizedBox.shrink();

      default:
        return showChevron
            ? CustomIconWidget(
                iconName: 'chevron_right',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 20,
              )
            : const SizedBox.shrink();
    }
  }
}
