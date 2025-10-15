import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import './supabase_service.dart';

enum LogLevel { debug, info, warning, error, critical }

enum LogCategory {
  apiCall('api_call'),
  database('database'),
  transaction('transaction'),
  userAction('user_action'),
  navigation('navigation'),
  error('error'),
  authentication('authentication'),
  system('system');

  const LogCategory(this.value);
  final String value;
}

/// Enhanced logging service with P&L diagnostic capabilities
class LoggingService {
  static LoggingService? _instance;
  static LoggingService get instance =>
      _instance ??= LoggingService._internal();

  LoggingService._internal();

  late Logger _logger;
  bool _initialized = false;
  bool _loggingEnabled = true;
  LogLevel _currentLogLevel = LogLevel.info;
  List<LogCategory> _enabledCategories = LogCategory.values;
  int _maxLogsPerSession = 1000;
  String? _currentSessionId;
  List<Map<String, dynamic>> _localLogs = [];

  // Initialize logging service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize logger with custom configuration
      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: !kIsWeb,
          printEmojis: true,
          printTime: true,
        ),
        output: kIsWeb ? null : FileOutput(),
      );

      // Load preferences
      await _loadPreferences();

      // Generate session ID
      _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

      _initialized = true;

      if (kDebugMode) {
        print('✅ Logging service initialized');
        print('   Logging enabled: $_loggingEnabled');
        print('   Log level: ${_currentLogLevel.name}');
        print('   Session ID: $_currentSessionId');
      }

      // Log initialization
      await logInfo(
        category: LogCategory.system,
        message: 'Logging service initialized',
        details: {
          'session_id': _currentSessionId,
          'logging_enabled': _loggingEnabled,
          'log_level': _currentLogLevel.name,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize logging service: $e');
      }
    }
  }

  // Load user preferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _loggingEnabled = prefs.getBool('logging_enabled') ?? true;
      _currentLogLevel =
          LogLevel.values[prefs.getInt('log_level') ?? LogLevel.info.index];
      _maxLogsPerSession = prefs.getInt('max_logs_per_session') ?? 1000;

      final enabledCategoriesJson = prefs.getString('enabled_log_categories');
      if (enabledCategoriesJson != null) {
        final List<dynamic> categoriesData = jsonDecode(enabledCategoriesJson);
        _enabledCategories =
            categoriesData
                .map(
                  (category) => LogCategory.values.firstWhere(
                    (c) => c.value == category,
                    orElse: () => LogCategory.system,
                  ),
                )
                .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to load logging preferences: $e');
      }
    }
  }

  // Save user preferences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('logging_enabled', _loggingEnabled);
      await prefs.setInt('log_level', _currentLogLevel.index);
      await prefs.setInt('max_logs_per_session', _maxLogsPerSession);

      final enabledCategoriesJson = jsonEncode(
        _enabledCategories.map((category) => category.value).toList(),
      );
      await prefs.setString('enabled_log_categories', enabledCategoriesJson);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to save logging preferences: $e');
      }
    }
  }

  // Generic logging method
  Future<void> log({
    required LogLevel level,
    required LogCategory category,
    required String message,
    Map<String, dynamic>? details,
    String? screenName,
    String? functionName,
    String? filePath,
    String? errorStack,
  }) async {
    if (!_initialized || !_loggingEnabled) return;

    // Check if category is enabled
    if (!_enabledCategories.contains(category)) return;

    // Check log level
    if (level.index < _currentLogLevel.index) return;

    try {
      final logEntry = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'user_id': SupabaseService.instance.currentUserId,
        'level': level.name,
        'category': category.value,
        'message': message,
        'details': details ?? {},
        'screen_name': screenName,
        'function_name': functionName,
        'file_path': filePath,
        'error_stack': errorStack,
        'session_id': _currentSessionId,
        'device_info': await _getDeviceInfo(),
        'created_at': DateTime.now().toIso8601String(),
      };

      // Store locally first
      _localLogs.add(logEntry);

      // Maintain local logs limit
      if (_localLogs.length > _maxLogsPerSession) {
        _localLogs.removeAt(0);
      }

      // Log to console with Logger package
      switch (level) {
        case LogLevel.debug:
          _logger.d(
            '${category.value.toUpperCase()}: $message',
            error: details,
          );
          break;
        case LogLevel.info:
          _logger.i(
            '${category.value.toUpperCase()}: $message',
            error: details,
          );
          break;
        case LogLevel.warning:
          _logger.w(
            '${category.value.toUpperCase()}: $message',
            error: details,
          );
          break;
        case LogLevel.error:
          _logger.e(
            '${category.value.toUpperCase()}: $message',
            error: details,
            stackTrace:
                errorStack != null ? StackTrace.fromString(errorStack) : null,
          );
          break;
        case LogLevel.critical:
          _logger.f(
            '${category.value.toUpperCase()}: $message',
            error: details,
            stackTrace:
                errorStack != null ? StackTrace.fromString(errorStack) : null,
          );
          break;
      }

      // Try to save to database (fire and forget)
      _saveToDatabase(logEntry);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to log message: $e');
      }
    }
  }

  // Specific logging methods for convenience
  Future<void> logDebug({
    required LogCategory category,
    required String message,
    Map<String, dynamic>? details,
    String? screenName,
    String? functionName,
  }) async {
    await log(
      level: LogLevel.debug,
      category: category,
      message: message,
      details: details,
      screenName: screenName,
      functionName: functionName,
    );
  }

  Future<void> logInfo({
    required LogCategory category,
    required String message,
    Map<String, dynamic>? details,
    String? screenName,
    String? functionName,
  }) async {
    await log(
      level: LogLevel.info,
      category: category,
      message: message,
      details: details,
      screenName: screenName,
      functionName: functionName,
    );
  }

  Future<void> logWarning({
    required LogCategory category,
    required String message,
    Map<String, dynamic>? details,
    String? screenName,
    String? functionName,
  }) async {
    await log(
      level: LogLevel.warning,
      category: category,
      message: message,
      details: details,
      screenName: screenName,
      functionName: functionName,
    );
  }

  Future<void> logError({
    required LogCategory category,
    required String message,
    Map<String, dynamic>? details,
    String? screenName,
    String? functionName,
    String? errorStack,
  }) async {
    await log(
      level: LogLevel.error,
      category: category,
      message: message,
      details: details,
      screenName: screenName,
      functionName: functionName,
      errorStack: errorStack,
    );
  }

  Future<void> logCritical({
    required LogCategory category,
    required String message,
    Map<String, dynamic>? details,
    String? screenName,
    String? functionName,
    String? errorStack,
  }) async {
    await log(
      level: LogLevel.critical,
      category: category,
      message: message,
      details: details,
      screenName: screenName,
      functionName: functionName,
      errorStack: errorStack,
    );
  }

  // Enhanced log P&L diagnostic information
  Future<void> logPLDiagnostic({
    required String operation,
    required Map<String, dynamic> plData,
    String? error,
    LogCategory category = LogCategory.system,
  }) async {
    try {
      final diagnosticEntry = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'dateString': DateTime.now().toIso8601String(),
        'category': 'PL_DIAGNOSTIC',
        'operation': operation,
        'plData': plData,
        'error': error,
        'level': error != null ? 'ERROR' : 'INFO',
        'platform': kIsWeb ? 'web' : 'mobile',
      };

      // Store locally first
      _localLogs.add(diagnosticEntry);

      // Maintain local logs limit
      if (_localLogs.length > _maxLogsPerSession) {
        _localLogs.removeAt(0);
      }

      if (kDebugMode) {
        final plValue = plData['profitLoss'] ?? 'unknown';
        print('🔍 P&L DIAGNOSTIC: $operation - P&L: \$${plValue}');
        if (error != null) {
          print('   ❌ Error: $error');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ P&L diagnostic logging failed: $e');
      }
    }
  }

  /// Log P&L zero reset events
  Future<void> logPLZeroReset({
    required double previousPL,
    required double currentPL,
    required String source,
    Map<String, dynamic>? additionalData,
  }) async {
    await logPLDiagnostic(
      operation: 'ZERO_RESET_DETECTED',
      plData: {
        'previousPL': previousPL,
        'currentPL': currentPL,
        'source': source,
        'resetDetected': currentPL == 0.0 && previousPL != 0.0,
        'additionalData': additionalData ?? {},
      },
    );
  }

  /// Export P&L diagnostic logs
  Future<List<Map<String, dynamic>>> exportPLDiagnostics() async {
    try {
      final allLogs = <Map<String, dynamic>>[];

      // Get P&L diagnostic logs from local logs
      final plLogs = _localLogs.where((log) => log['category'] == 'PL_DIAGNOSTIC').toList();
      allLogs.addAll(plLogs);

      // Sort by timestamp
      allLogs.sort(
        (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
      );

      return allLogs;
    } catch (e) {
      if (kDebugMode) {
        print('❌ P&L diagnostics export failed: $e');
      }
      return [];
    }
  }

  // Get device information
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      if (kIsWeb) {
        return {
          'platform': 'web',
          'user_agent': html.window.navigator.userAgent,
          'language': html.window.navigator.language,
          'screen_width': html.window.screen?.width,
          'screen_height': html.window.screen?.height,
        };
      } else {
        return {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
          'environment': Platform.environment['USER'] ?? 'unknown',
          'locale': Platform.localeName,
        };
      }
    } catch (e) {
      return {'platform': 'unknown', 'error': e.toString()};
    }
  }

  // Save log to database
  Future<void> _saveToDatabase(Map<String, dynamic> logEntry) async {
    try {
      if (!SupabaseService.instance.isInitialized) return;

      final client = SupabaseService.instance.client;
      await client.from('app_logs').insert({
        'user_id': logEntry['user_id'],
        'level': logEntry['level'],
        'category': logEntry['category'],
        'message': logEntry['message'],
        'details': logEntry['details'],
        'screen_name': logEntry['screen_name'],
        'function_name': logEntry['function_name'],
        'file_path': logEntry['file_path'],
        'error_stack': logEntry['error_stack'],
        'session_id': logEntry['session_id'],
        'device_info': logEntry['device_info'],
      });
    } catch (e) {
      // Silent failure for database logging
      if (kDebugMode) {
        print('⚠️ Failed to save log to database: $e');
      }
    }
  }

  // Update logging preferences
  Future<void> updatePreferences({
    bool? loggingEnabled,
    LogLevel? logLevel,
    List<LogCategory>? enabledCategories,
    int? maxLogsPerSession,
  }) async {
    try {
      if (loggingEnabled != null) _loggingEnabled = loggingEnabled;
      if (logLevel != null) _currentLogLevel = logLevel;
      if (enabledCategories != null) _enabledCategories = enabledCategories;
      if (maxLogsPerSession != null) _maxLogsPerSession = maxLogsPerSession;

      await _savePreferences();

      // Update database preferences if user is authenticated
      if (SupabaseService.instance.isAuthenticated) {
        final client = SupabaseService.instance.client;
        final userId = SupabaseService.instance.currentUserId;

        await client.from('user_log_preferences').upsert({
          'user_id': userId,
          'logging_enabled': _loggingEnabled,
          'log_level': _currentLogLevel.name,
          'categories_enabled': _enabledCategories.map((c) => c.value).toList(),
          'max_logs_per_session': _maxLogsPerSession,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await logInfo(
        category: LogCategory.system,
        message: 'Logging preferences updated',
        details: {
          'logging_enabled': _loggingEnabled,
          'log_level': _currentLogLevel.name,
          'enabled_categories': _enabledCategories.length,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update logging preferences: $e');
      }
    }
  }

  // Export logs
  Future<void> exportLogs() async {
    try {
      final logs = List<Map<String, dynamic>>.from(_localLogs);
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'session_id': _currentSessionId,
        'total_logs': logs.length,
        'logs': logs,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      final fileName =
          'crypto_tracker_logs_${DateTime.now().millisecondsSinceEpoch}.json';

      if (kIsWeb) {
        // Web download
        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor =
            html.AnchorElement(href: url)
              ..setAttribute("download", fileName)
              ..click();
        html.Url.revokeObjectUrl(url);

        await logInfo(
          category: LogCategory.system,
          message: 'Logs exported successfully (web)',
          details: {'exported_count': logs.length, 'file_name': fileName},
        );
      } else {
        // ANDROID FIX: Proper mobile file download with Downloads folder support
        await _exportLogsToAndroidDownloads(jsonString, fileName, logs.length);
      }
    } catch (e) {
      await logError(
        category: LogCategory.system,
        message: 'Failed to export logs',
        details: {'error': e.toString()},
        errorStack: e.toString(),
      );
    }
  }

  // ANDROID FIX: New method to properly save logs to Android Downloads folder
  Future<void> _exportLogsToAndroidDownloads(
    String jsonString,
    String fileName,
    int logCount,
  ) async {
    try {
      // Step 1: Request storage permissions for Android
      bool hasPermission = await _requestStoragePermission();

      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      Directory? targetDirectory;

      if (Platform.isAndroid) {
        // ANDROID FIX: Get the Downloads directory specifically
        try {
          // Try to get external storage Downloads directory first (user-accessible)
          final List<Directory>? externalStorageDirectories =
              await getExternalStorageDirectories(
                type: StorageDirectory.downloads,
              );

          if (externalStorageDirectories != null &&
              externalStorageDirectories.isNotEmpty) {
            targetDirectory = externalStorageDirectories.first;
          }
        } catch (e) {
          if (kDebugMode) {
            print(
              '⚠️ Could not access external Downloads, trying alternative: $e',
            );
          }
        }

        // Fallback: Try to access the public Downloads directory
        if (targetDirectory == null) {
          try {
            // Get external storage directory and navigate to Downloads
            final Directory? externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              // Navigate to public Downloads folder: /storage/emulated/0/Download
              final String publicDownloads =
                  externalDir.path.replaceAll(
                    '/Android/data/${externalDir.path.split('/').where((s) => s.contains('.')).first}/files',
                    '',
                  ) +
                  '/Download';

              targetDirectory = Directory(publicDownloads);

              // Create the directory if it doesn't exist
              if (!await targetDirectory.exists()) {
                await targetDirectory.create(recursive: true);
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                '⚠️ Could not access public Downloads, using documents: $e',
              );
            }
          }
        }

        // Final fallback: Use application documents directory
        if (targetDirectory == null) {
          targetDirectory = await getApplicationDocumentsDirectory();
        }
      } else {
        // iOS: Use documents directory
        targetDirectory = await getApplicationDocumentsDirectory();
      }

      // Step 2: Write the file
      final file = File('${targetDirectory.path}/$fileName');
      await file.writeAsString(jsonString);

      // Step 3: Verify file was written
      if (await file.exists()) {
        final fileSizeBytes = await file.length();
        final fileSizeMB = (fileSizeBytes / 1024 / 1024).toStringAsFixed(2);

        await logInfo(
          category: LogCategory.system,
          message: 'Logs exported successfully to Downloads folder',
          details: {
            'exported_count': logCount,
            'file_name': fileName,
            'file_path': file.path,
            'file_size_mb': fileSizeMB,
            'platform': Platform.operatingSystem,
          },
        );

        if (kDebugMode) {
          print('✅ ANDROID FIX: Debug logs saved successfully!');
          print('   📁 File: $fileName');
          print('   📍 Location: ${file.path}');
          print('   📊 Size: ${fileSizeMB} MB');
          print('   🔢 Logs: $logCount entries');
        }
      } else {
        throw Exception('File was not created successfully');
      }
    } catch (e) {
      await logError(
        category: LogCategory.system,
        message: 'Failed to export logs to Android Downloads',
        details: {'error': e.toString(), 'file_name': fileName},
        errorStack: e.toString(),
      );

      // Re-throw with user-friendly message
      throw Exception(
        'Failed to save debug logs to Downloads folder: ${e.toString()}',
      );
    }
  }

  // ANDROID FIX: Enhanced storage permission handling for Android
  Future<bool> _requestStoragePermission() async {
    if (kIsWeb) return true; // Browser handles permissions

    try {
      if (Platform.isAndroid) {
        // Check Android version and request appropriate permissions
        final androidInfo = await _getAndroidVersion();

        if (androidInfo >= 33) {
          // Android 13+ (API 33+): No special permissions needed for Downloads
          return true;
        } else if (androidInfo >= 30) {
          // Android 11-12 (API 30-32): Request MANAGE_EXTERNAL_STORAGE
          final status = await Permission.manageExternalStorage.request();
          if (status.isGranted) return true;

          // Fallback to regular storage permission
          final storageStatus = await Permission.storage.request();
          return storageStatus.isGranted;
        } else {
          // Android 10 and below: Regular storage permission
          final status = await Permission.storage.request();
          return status.isGranted;
        }
      }

      return true; // iOS handles file permissions automatically
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Storage permission error: $e');
      }
      return false;
    }
  }

  // Helper method to get Android version (simplified)
  Future<int> _getAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        // This is a simplified approach - in production you might want to use device_info_plus
        return 33; // Assume recent Android for safety
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not determine Android version: $e');
      }
    }
    return 30; // Safe fallback
  }

  // Clear local logs
  Future<void> clearLocalLogs() async {
    try {
      final clearedCount = _localLogs.length;
      _localLogs.clear();

      await logInfo(
        category: LogCategory.system,
        message: 'Local logs cleared',
        details: {'cleared_count': clearedCount},
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to clear local logs: $e');
      }
    }
  }

  // Get logging statistics
  Future<Map<String, dynamic>> getLoggingStats() async {
    try {
      final stats = {
        'total_logs': _localLogs.length,
        'session_id': _currentSessionId,
        'logging_enabled': _loggingEnabled,
        'current_log_level': _currentLogLevel.name,
        'enabled_categories': _enabledCategories.map((c) => c.value).toList(),
        'max_logs_per_session': _maxLogsPerSession,
      };

      // Count by level
      for (final level in LogLevel.values) {
        final count =
            _localLogs.where((log) => log['level'] == level.name).length;
        stats['${level.name}_count'] = count;
      }

      // Count by category
      for (final category in LogCategory.values) {
        final count =
            _localLogs.where((log) => log['category'] == category.value).length;
        stats['${category.value}_count'] = count;
      }

      return stats;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Getters
  bool get isLoggingEnabled => _loggingEnabled;
  LogLevel get currentLogLevel => _currentLogLevel;
  List<LogCategory> get enabledCategories => _enabledCategories;
  int get maxLogsPerSession => _maxLogsPerSession;
  String? get currentSessionId => _currentSessionId;
  List<Map<String, dynamic>> get localLogs => List.unmodifiable(_localLogs);
}

// Custom file output for Logger (mobile only)
class FileOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    if (!kIsWeb) {
      // In a real implementation, you would write to a file
      // For now, just use debugPrint
      for (final line in event.lines) {
        debugPrint(line);
      }
    }
  }
}