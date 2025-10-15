import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/services/logging_service.dart';
import '../../../widgets/custom_icon_widget.dart';

class LogCollectionWidget extends StatefulWidget {
  const LogCollectionWidget({super.key});

  @override
  State<LogCollectionWidget> createState() => _LogCollectionWidgetState();
}

class _LogCollectionWidgetState extends State<LogCollectionWidget> {
  bool _isLoading = false;
  Map<String, dynamic>? _loggingStats;

  @override
  void initState() {
    super.initState();
    _loadLoggingStats();
  }

  Future<void> _loadLoggingStats() async {
    try {
      final stats = await LoggingService.instance.getLoggingStats();
      setState(() {
        _loggingStats = stats;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = LoggingService.instance.isLoggingEnabled;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with enable/disable toggle
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isEnabled 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.outline)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: CustomIconWidget(
                    iconName: 'bug_report',
                    color: isEnabled 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.outline,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Collection',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Capture app activity for debugging',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: _isLoading ? null : (value) => _toggleLogging(value),
                activeColor: theme.colorScheme.primary,
              ),
            ],
          ),

          if (isEnabled) ...[
            SizedBox(height: 3.h),
            
            // Stats section
            if (_loggingStats != null) ...[
              _buildStatsSection(theme),
              SizedBox(height: 2.h),
            ],

            // Actions section
            _buildActionsSection(theme),
            
            SizedBox(height: 2.h),
            
            // Log level selector
            _buildLogLevelSelector(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(ThemeData theme) {
    final stats = _loggingStats!;
    
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Session Stats',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(height: 1.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                theme,
                'Total Logs',
                '${stats['total_logs'] ?? 0}',
                CustomIconWidget(
                  iconName: 'list_alt',
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
              ),
              _buildStatItem(
                theme,
                'Errors',
                '${stats['error_count'] ?? 0}',
                CustomIconWidget(
                  iconName: 'error_outline',
                  color: theme.colorScheme.error,
                  size: 16,
                ),
              ),
              _buildStatItem(
                theme,
                'Warnings',
                '${stats['warning_count'] ?? 0}',
                CustomIconWidget(
                  iconName: 'warning_amber',
                  color: Colors.orange,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, String value, Widget icon) {
    return Column(
      children: [
        icon,
        SizedBox(height: 0.5.h),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            theme,
            'Export Logs',
            'file_download',
            () => _exportLogs(),
            theme.colorScheme.primary,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: _buildActionButton(
            theme,
            'Clear Logs',
            'clear_all',
            () => _showClearLogsDialog(),
            theme.colorScheme.error,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    ThemeData theme,
    String label,
    String iconName,
    VoidCallback onPressed,
    Color color,
  ) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: _isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 6.h,
          padding: EdgeInsets.symmetric(horizontal: 3.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomIconWidget(
                iconName: iconName,
                color: color,
                size: 18,
              ),
              SizedBox(width: 2.w),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogLevelSelector(ThemeData theme) {
    final currentLevel = LoggingService.instance.currentLogLevel;

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log Level',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: LogLevel.values.map((level) {
              final isSelected = level == currentLevel;
              final color = _getLogLevelColor(level, theme);
              
              return Material(
                color: isSelected 
                    ? color.withValues(alpha: 0.2) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () => _updateLogLevel(level),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected 
                            ? color 
                            : theme.colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      level.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected 
                            ? color 
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getLogLevelColor(LogLevel level, ThemeData theme) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return theme.colorScheme.primary;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return theme.colorScheme.error;
      case LogLevel.critical:
        return Colors.red.shade700;
    }
  }

  Future<void> _toggleLogging(bool enabled) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await LoggingService.instance.updatePreferences(
        loggingEnabled: enabled,
      );

      HapticFeedback.lightImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled 
                ? 'Log collection enabled' 
                : 'Log collection disabled',
          ),
          backgroundColor: enabled 
              ? Colors.green 
              : Colors.orange,
        ),
      );

      await _loadLoggingStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update logging: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateLogLevel(LogLevel level) async {
    try {
      await LoggingService.instance.updatePreferences(logLevel: level);
      
      HapticFeedback.lightImpact();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Log level updated to ${level.name}'),
          backgroundColor: _getLogLevelColor(level, Theme.of(context)),
        ),
      );

      await _loadLoggingStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update log level: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _exportLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await LoggingService.instance.exportLogs();
      
      HapticFeedback.lightImpact();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export logs: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showClearLogsDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear Logs',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will clear all local logs from the current session. This action cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clearLogs();
    }
  }

  Future<void> _clearLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await LoggingService.instance.clearLocalLogs();
      
      HapticFeedback.lightImpact();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local logs cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadLoggingStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear logs: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}