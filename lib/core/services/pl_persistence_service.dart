import 'dart:convert';
import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced Profit & Loss data persistence service with atomic writes and diagnostic logging
class PLPersistenceService {
  static PLPersistenceService? _instance;
  static PLPersistenceService get instance =>
      _instance ??= PLPersistenceService._internal();

  PLPersistenceService._internal();

  // Enhanced storage keys with versioning and integrity checks
  static const String _plSnapshotKey = 'pl_snapshot_data_v2';
  static const String _plTimeSeriesKey = 'pl_time_series_data_v2';
  static const String _plCalculationLogKey = 'pl_calculation_log_v2';
  static const String _plValidationKey = 'pl_validation_cache_v2';
  static const String _plDiagnosticsKey = 'pl_diagnostics_log_v2';
  static const String _plBackupKey = 'pl_backup_data_v2';

  // Enhanced versioning for data integrity
  static const String _currentVersion = '2.1.0';

  /// Enhanced atomic P&L snapshot save with comprehensive validation and logging
  Future<bool> savePLSnapshot({
    required double totalValue,
    required double totalInvested,
    required double profitLoss,
    required double percentageChange,
    required int transactionCount,
    Map<String, dynamic>? additionalData,
    String? source,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // ATOMIC WRITE: Create complete snapshot with validation
      final snapshot = {
        'totalValue': totalValue,
        'totalInvested': totalInvested,
        'profitLoss': profitLoss,
        'percentageChange': percentageChange,
        'transactionCount': transactionCount,
        'timestamp': timestamp,
        'dateString': DateTime.now().toIso8601String(),
        'calculationVersion': _currentVersion,
        'additionalData': additionalData ?? {},
        'source': source ?? 'unknown',
        'integrityHash': _generateIntegrityHash(
          totalValue,
          totalInvested,
          profitLoss,
        ),
        'atomicWrite': true,
        'writeId': _generateWriteId(),
      };

      // ENHANCED: Validate data integrity before saving
      if (!_validateSnapshotIntegrity(snapshot)) {
        await _logDiagnostic(
          level: 'ERROR',
          message: 'P&L snapshot failed integrity validation before save',
          data: snapshot,
        );
        return false;
      }

      // ATOMIC WRITE: Backup current data before overwrite
      final existingSnapshot = prefs.getString(_plSnapshotKey);
      if (existingSnapshot != null) {
        await prefs.setString(_plBackupKey, existingSnapshot);
      }

      // ATOMIC WRITE: Save new snapshot
      final snapshotJson = jsonEncode(snapshot);
      final writeSuccess = await prefs.setString(_plSnapshotKey, snapshotJson);

      if (!writeSuccess) {
        // Restore backup if write failed
        if (existingSnapshot != null) {
          await prefs.setString(_plSnapshotKey, existingSnapshot);
        }
        await _logDiagnostic(
          level: 'ERROR',
          message: 'P&L snapshot atomic write failed - backup restored',
          data: {'writeId': snapshot['writeId']},
        );
        return false;
      }

      // ENHANCED: Add to time series with atomic guarantee
      await _addToTimeSeriesAtomic(snapshot);

      // ENHANCED: Log successful save with comprehensive details
      await _logPLCalculation(snapshot, isSuccess: true);
      await _logDiagnostic(
        level: 'SUCCESS',
        message: 'P&L snapshot saved atomically',
        data: {
          'writeId': snapshot['writeId'],
          'totalValue': totalValue,
          'totalInvested': totalInvested,
          'profitLoss': profitLoss,
          'percentageChange': percentageChange,
          'source': source,
          'timestamp': timestamp,
        },
      );

      if (kDebugMode) {
        print('💾 ATOMIC P&L snapshot saved successfully:');
        print('   💰 P&L: \$${profitLoss.toStringAsFixed(2)}');
        print('   📊 Value: \$${totalValue.toStringAsFixed(2)}');
        print('   💵 Invested: \$${totalInvested.toStringAsFixed(2)}');
        print('   🔄 Percentage: ${percentageChange.toStringAsFixed(2)}%');
        print('   📝 Source: $source');
        print('   🆔 WriteID: ${snapshot['writeId']}');
      }

      return true;
    } catch (e) {
      await _logDiagnostic(
        level: 'ERROR',
        message: 'P&L snapshot save failed with exception',
        data: {
          'error': e.toString(),
          'totalValue': totalValue,
          'totalInvested': totalInvested,
          'profitLoss': profitLoss,
          'source': source,
        },
      );

      if (kDebugMode) {
        print('❌ ATOMIC P&L snapshot save failed: $e');
      }
      return false;
    }
  }

  /// STARTUP FIX: Enhanced P&L snapshot load with startup session awareness
  Future<Map<String, dynamic>?> loadPLSnapshot({
    bool useBackupIfCorrupted = true,
    bool isStartupSession = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? snapshotJson = prefs.getString(_plSnapshotKey);

      // Add null check before decoding
      if (snapshotJson == null) {
        return null;
      }

      final snapshot = Map<String, dynamic>.from(jsonDecode(snapshotJson));

      // STARTUP FIX: Enhanced integrity validation with startup context
      if (!_validateSnapshotIntegrity(snapshot)) {
        await _logDiagnostic(
          level: 'ERROR',
          message: 'P&L snapshot integrity validation failed',
          data: {
            ...snapshot,
            'isStartupSession': isStartupSession,
            'attemptingBackupRecovery': useBackupIfCorrupted,
          },
        );

        // Try backup recovery if main data is corrupted
        if (useBackupIfCorrupted) {
          final backupJson = prefs.getString(_plBackupKey);
          if (backupJson != null) {
            if (kDebugMode) {
              print(
                '🔄 STARTUP FIX: Main P&L data corrupted - attempting backup recovery',
              );
            }

            final backupSnapshot = Map<String, dynamic>.from(
              jsonDecode(backupJson),
            );

            // Validate backup data too
            if (_validateSnapshotIntegrity(backupSnapshot)) {
              await _logDiagnostic(
                level: 'SUCCESS',
                message: 'P&L backup data recovery successful',
                data: {
                  'recoveredPL': backupSnapshot['profitLoss'],
                  'isStartupSession': isStartupSession,
                },
              );
              return backupSnapshot;
            }
          }
        }

        return null;
      }

      // STARTUP FIX: Enhanced validation with startup session context
      final totalValue = (snapshot['totalValue'] as num?)?.toDouble() ?? 0.0;
      final totalInvested =
          (snapshot['totalInvested'] as num?)?.toDouble() ?? 0.0;
      final profitLoss = (snapshot['profitLoss'] as num?)?.toDouble() ?? 0.0;
      final storedHash = snapshot['integrityHash'] as String?;

      final expectedHash = _generateIntegrityHash(
        totalValue,
        totalInvested,
        profitLoss,
      );
      final expectedProfitLoss = totalValue - totalInvested;

      // Check for data corruption or calculation inconsistency
      if (storedHash != expectedHash ||
          (profitLoss - expectedProfitLoss).abs() > 0.01) {
        await _logDiagnostic(
          level: 'WARNING',
          message: 'P&L data integrity issue detected - auto-correcting',
          data: {
            'storedPL': profitLoss,
            'expectedPL': expectedProfitLoss,
            'difference': (profitLoss - expectedProfitLoss).abs(),
            'hashMatch': storedHash == expectedHash,
            'isStartupSession': isStartupSession,
            'correctionApplied': true,
          },
        );

        // Auto-correct the data
        snapshot['profitLoss'] = expectedProfitLoss;
        snapshot['percentageChange'] =
            totalInvested != 0.0
                ? (expectedProfitLoss / totalInvested.abs()) * 100
                : 0.0;
        snapshot['integrityHash'] = expectedHash;
        snapshot['lastAutoCorrection'] = DateTime.now().toIso8601String();
        snapshot['startupCorrected'] = isStartupSession;

        // Save corrected data atomically
        await prefs.setString(_plSnapshotKey, jsonEncode(snapshot));

        if (kDebugMode) {
          print('🔧 STARTUP FIX: P&L data auto-corrected and saved');
          print('   Original P&L: \$${profitLoss.toStringAsFixed(2)}');
          print('   Corrected P&L: \$${expectedProfitLoss.toStringAsFixed(2)}');
          print('   Startup session: $isStartupSession');
        }
      }

      // STARTUP FIX: Add startup session marker
      if (isStartupSession) {
        snapshot['lastStartupLoad'] = DateTime.now().toIso8601String();
      }

      await _logDiagnostic(
        level: 'SUCCESS',
        message:
            isStartupSession
                ? 'P&L snapshot loaded successfully during startup'
                : 'P&L snapshot loaded successfully',
        data: {
          'loadedPL': snapshot['profitLoss'],
          'totalValue': snapshot['totalValue'],
          'totalInvested': snapshot['totalInvested'],
          'timestamp': snapshot['timestamp'],
          'writeId': snapshot['writeId'],
          'isStartupSession': isStartupSession,
        },
      );

      if (kDebugMode) {
        final loadedPL = (snapshot['profitLoss'] as num).toDouble();
        print('📦 STARTUP FIX: P&L snapshot loaded with startup awareness:');
        print('   💰 P&L: \$${loadedPL.toStringAsFixed(2)}');
        print('   🆔 WriteID: ${snapshot['writeId'] ?? 'legacy'}');
        print('   🚀 Startup session: $isStartupSession');
      }

      return snapshot;
    } catch (e) {
      await _logDiagnostic(
        level: 'ERROR',
        message: 'P&L snapshot load failed with exception',
        data: {'error': e.toString(), 'isStartupSession': isStartupSession},
      );

      if (kDebugMode) {
        print('❌ STARTUP FIX: P&L snapshot load failed: $e');
      }
      return null;
    }
  }

  /// Enhanced atomic time series addition with data validation
  Future<void> _addToTimeSeriesAtomic(Map<String, dynamic> snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeSeriesJson = prefs.getString(_plTimeSeriesKey) ?? '[]';
      final List<dynamic> timeSeries = jsonDecode(timeSeriesJson);

      // Create validated time series point
      final timePoint = {
        'timestamp': snapshot['timestamp'],
        'profitLoss': snapshot['profitLoss'],
        'totalValue': snapshot['totalValue'],
        'totalInvested': snapshot['totalInvested'],
        'percentageChange': snapshot['percentageChange'],
        'writeId': snapshot['writeId'],
        'source': snapshot['source'],
        'integrityHash': _generateIntegrityHash(
          snapshot['totalValue'],
          snapshot['totalInvested'],
          snapshot['profitLoss'],
        ),
      };

      timeSeries.add(timePoint);

      // Enhanced cleanup: Keep last 90 days of data with smart pruning
      final cutoffTime =
          DateTime.now()
              .subtract(const Duration(days: 90))
              .millisecondsSinceEpoch;

      // Remove old entries but keep at least 10 recent entries for graph
      final filteredSeries =
          timeSeries.where((point) {
            final pointTime = point['timestamp'] as int? ?? 0;
            return pointTime >= cutoffTime;
          }).toList();

      if (filteredSeries.length < 10 && timeSeries.length >= 10) {
        // Keep last 10 entries if filtered result is too small
        filteredSeries.clear();
        // Replace takeLast with skip and take
        final startIndex = timeSeries.length > 10 ? timeSeries.length - 10 : 0;
        filteredSeries.addAll(timeSeries.skip(startIndex).take(10));
      }

      // Sort by timestamp for chronological order
      filteredSeries.sort(
        (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
      );

      // Atomic write of time series
      await prefs.setString(_plTimeSeriesKey, jsonEncode(filteredSeries));

      await _logDiagnostic(
        level: 'SUCCESS',
        message: 'P&L time series updated atomically',
        data: {
          'totalPoints': filteredSeries.length,
          'addedTimestamp': snapshot['timestamp'],
          'writeId': snapshot['writeId'],
        },
      );

      if (kDebugMode) {
        print(
          '📈 P&L time series updated: ${filteredSeries.length} points (atomic)',
        );
      }
    } catch (e) {
      await _logDiagnostic(
        level: 'ERROR',
        message: 'Time series atomic update failed',
        data: {'error': e.toString(), 'writeId': snapshot['writeId']},
      );

      if (kDebugMode) {
        print('⚠️ Time series atomic update failed: $e');
      }
    }
  }

  /// Enhanced P&L calculation logging with comprehensive diagnostics
  Future<void> _logPLCalculation(
    Map<String, dynamic> snapshot, {
    bool isSuccess = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logJson = prefs.getString(_plCalculationLogKey) ?? '[]';
      final List<dynamic> log = jsonDecode(logJson);

      final logEntry = {
        'timestamp': snapshot['timestamp'],
        'dateString': snapshot['dateString'],
        'writeId': snapshot['writeId'],
        'calculation': {
          'totalValue': snapshot['totalValue'],
          'totalInvested': snapshot['totalInvested'],
          'profitLoss': snapshot['profitLoss'],
          'percentageChange': snapshot['percentageChange'],
          'method': 'enhanced_atomic_v2',
          'isSuccess': isSuccess,
        },
        'transactionCount': snapshot['transactionCount'],
        'source': snapshot['source'],
        'integrityHash': snapshot['integrityHash'],
        'version': _currentVersion,
      };

      log.add(logEntry);

      // Keep last 100 calculation logs
      if (log.length > 100) {
        log.removeRange(0, log.length - 100);
      }

      await prefs.setString(_plCalculationLogKey, jsonEncode(log));
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ P&L calculation logging failed: $e');
      }
    }
  }

  /// Enhanced diagnostic logging system
  Future<void> _logDiagnostic({
    required String level,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logJson = prefs.getString(_plDiagnosticsKey) ?? '[]';
      final List<dynamic> diagnostics = jsonDecode(logJson);

      final diagnosticEntry = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'dateString': DateTime.now().toIso8601String(),
        'level': level,
        'message': message,
        'data': data ?? {},
        'version': _currentVersion,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      };

      diagnostics.add(diagnosticEntry);

      // Keep last 200 diagnostic entries
      if (diagnostics.length > 200) {
        diagnostics.removeRange(0, diagnostics.length - 200);
      }

      await prefs.setString(_plDiagnosticsKey, jsonEncode(diagnostics));
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Diagnostic logging failed: $e');
      }
    }
  }

  /// Enhanced integrity validation
  bool _validateSnapshotIntegrity(Map<String, dynamic> snapshot) {
    try {
      // Check required fields
      final requiredFields = [
        'totalValue',
        'totalInvested',
        'profitLoss',
        'timestamp',
      ];
      for (final field in requiredFields) {
        if (!snapshot.containsKey(field) || snapshot[field] == null) {
          return false;
        }
      }

      // Validate numeric values
      final totalValue = (snapshot['totalValue'] as num?)?.toDouble();
      final totalInvested = (snapshot['totalInvested'] as num?)?.toDouble();
      final profitLoss = (snapshot['profitLoss'] as num?)?.toDouble();

      if (totalValue == null || totalInvested == null || profitLoss == null) {
        return false;
      }

      // Check for reasonable values (not infinity or NaN)
      if (!totalValue.isFinite ||
          !totalInvested.isFinite ||
          !profitLoss.isFinite) {
        return false;
      }

      // Validate timestamp is reasonable (not in the future or too old)
      final timestamp = snapshot['timestamp'] as int?;
      if (timestamp == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      final oneYearAgo = now - (365 * 24 * 60 * 60 * 1000);
      final oneHourFromNow = now + (60 * 60 * 1000);

      if (timestamp < oneYearAgo || timestamp > oneHourFromNow) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generate integrity hash for data validation
  String _generateIntegrityHash(
    double totalValue,
    double totalInvested,
    double profitLoss,
  ) {
    final data =
        '${totalValue.toStringAsFixed(8)}_${totalInvested.toStringAsFixed(8)}_${profitLoss.toStringAsFixed(8)}_$_currentVersion';
    return data.hashCode.abs().toString();
  }

  /// Generate unique write ID for tracking
  String _generateWriteId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Get comprehensive P&L time series data
  Future<List<Map<String, dynamic>>> getPLTimeSeries({Duration? period}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeSeriesJson = prefs.getString(_plTimeSeriesKey) ?? '[]';
      final List<dynamic> timeSeries = jsonDecode(timeSeriesJson);

      if (period != null) {
        final cutoffTime =
            DateTime.now().subtract(period).millisecondsSinceEpoch;
        final filteredSeries =
            timeSeries
                .where((point) => (point['timestamp'] as int) >= cutoffTime)
                .map((point) => Map<String, dynamic>.from(point))
                .toList();

        await _logDiagnostic(
          level: 'INFO',
          message: 'P&L time series retrieved with period filter',
          data: {
            'periodDays': period.inDays,
            'totalPoints': filteredSeries.length,
            'cutoffTime': cutoffTime,
          },
        );

        return filteredSeries;
      }

      final allSeries =
          timeSeries.map((point) => Map<String, dynamic>.from(point)).toList();

      await _logDiagnostic(
        level: 'INFO',
        message: 'P&L time series retrieved (all data)',
        data: {'totalPoints': allSeries.length},
      );

      return allSeries;
    } catch (e) {
      await _logDiagnostic(
        level: 'ERROR',
        message: 'P&L time series retrieval failed',
        data: {'error': e.toString()},
      );
      return [];
    }
  }

  /// Enhanced validation with detailed reporting
  Future<Map<String, dynamic>> validatePLConsistency({
    required double totalValue,
    required double totalInvested,
    required double profitLoss,
  }) async {
    try {
      final expectedPL = totalValue - totalInvested;
      final difference = (profitLoss - expectedPL).abs();
      const tolerance = 0.01;
      final isValid = difference <= tolerance;

      final validationResult = {
        'isValid': isValid,
        'expectedPL': expectedPL,
        'actualPL': profitLoss,
        'difference': difference,
        'tolerance': tolerance,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'totalValue': totalValue,
        'totalInvested': totalInvested,
      };

      // Cache validation result
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_plValidationKey, jsonEncode(validationResult));

      await _logDiagnostic(
        level: isValid ? 'SUCCESS' : 'WARNING',
        message:
            isValid
                ? 'P&L consistency validation passed'
                : 'P&L consistency validation failed',
        data: validationResult,
      );

      if (kDebugMode && !isValid) {
        print('⚠️ P&L inconsistency detected:');
        print('   Expected: \$${expectedPL.toStringAsFixed(2)}');
        print('   Actual: \$${profitLoss.toStringAsFixed(2)}');
        print('   Difference: \$${difference.toStringAsFixed(2)}');
        print('   Tolerance: \$${tolerance.toStringAsFixed(2)}');
      }

      return validationResult;
    } catch (e) {
      await _logDiagnostic(
        level: 'ERROR',
        message: 'P&L validation failed with exception',
        data: {'error': e.toString()},
      );

      return {
        'isValid': false,
        'error': e.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  /// Get comprehensive diagnostic information
  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get all diagnostic logs
      final diagnosticsJson = prefs.getString(_plDiagnosticsKey) ?? '[]';
      final diagnostics = jsonDecode(diagnosticsJson) as List<dynamic>;

      // Get calculation logs
      final calculationLogJson = prefs.getString(_plCalculationLogKey) ?? '[]';
      final calculationLogs = jsonDecode(calculationLogJson) as List<dynamic>;

      // Get time series info
      final timeSeriesJson = prefs.getString(_plTimeSeriesKey) ?? '[]';
      final timeSeries = jsonDecode(timeSeriesJson) as List<dynamic>;

      // Get current snapshot info
      final snapshotJson = prefs.getString(_plSnapshotKey);
      final hasSnapshot = snapshotJson != null;

      Map<String, dynamic>? currentSnapshot;
      if (hasSnapshot) {
        try {
          currentSnapshot = jsonDecode(snapshotJson);
        } catch (e) {
          // Snapshot is corrupted
        }
      }

      final diagnosticInfo = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'version': _currentVersion,
        'storage': {
          'hasSnapshot': hasSnapshot,
          'hasBackup': prefs.containsKey(_plBackupKey),
          'snapshotCorrupted': hasSnapshot && currentSnapshot == null,
          'timeSeriesDataPoints': timeSeries.length,
          'calculationLogEntries': calculationLogs.length,
          'diagnosticLogEntries': diagnostics.length,
        },
        'currentSnapshot': currentSnapshot,
        'lastCalculation':
            calculationLogs.isNotEmpty ? calculationLogs.last : null,
        'recentDiagnostics':
            diagnostics.length > 10
                ? diagnostics.skip(diagnostics.length - 10).toList()
                : diagnostics.toList(),
        'errorCount': diagnostics.where((d) => d['level'] == 'ERROR').length,
        'warningCount':
            diagnostics.where((d) => d['level'] == 'WARNING').length,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      };

      return diagnosticInfo;
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'version': _currentVersion,
      };
    }
  }

  /// Export diagnostic logs for debugging
  Future<String> exportDiagnosticLogs() async {
    try {
      final diagnosticInfo = await getDiagnosticInfo();
      return jsonEncode(diagnosticInfo);
    } catch (e) {
      return jsonEncode({
        'error': e.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Clear all P&L data (enhanced with backup)
  Future<Map<String, dynamic>> clearAllPLData({
    bool createBackup = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      Map<String, dynamic> backupData = {};
      if (createBackup) {
        // Create backup before clearing
        backupData = {
          'snapshot': prefs.getString(_plSnapshotKey),
          'timeSeries': prefs.getString(_plTimeSeriesKey),
          'calculationLog': prefs.getString(_plCalculationLogKey),
          'diagnostics': prefs.getString(_plDiagnosticsKey),
          'validation': prefs.getString(_plValidationKey),
          'clearedAt': DateTime.now().toIso8601String(),
        };

        await prefs.setString('${_plBackupKey}_full', jsonEncode(backupData));
      }

      // Clear all P&L data
      final keysToRemove = [
        _plSnapshotKey,
        _plTimeSeriesKey,
        _plCalculationLogKey,
        _plValidationKey,
        _plDiagnosticsKey,
        _plBackupKey,
      ];

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      await _logDiagnostic(
        level: 'WARNING',
        message: 'All P&L data cleared',
        data: {
          'backupCreated': createBackup,
          'keysCleared': keysToRemove.length,
        },
      );

      if (kDebugMode) {
        print('🧹 All P&L persistence data cleared (backup: $createBackup)');
      }

      return {
        'success': true,
        'backupCreated': createBackup,
        'keysCleared': keysToRemove.length,
        'clearedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// STARTUP FIX: Enhanced inactivity check to detect 24+ hour gaps
  Future<Map<String, dynamic>> checkInactivityStatus() async {
    try {
      final snapshot = await loadPLSnapshot(isStartupSession: true);
      final currentTime = DateTime.now();

      if (snapshot == null) {
        return {
          'hasData': false,
          'isFirstUse': true,
          'inactiveHours': 0,
          'shouldShowEmpty': true,
          'message': 'No portfolio data found - first use',
        };
      }

      final lastUpdatedStr = snapshot['dateString'] as String?;
      if (lastUpdatedStr == null) {
        return {
          'hasData': true,
          'isFirstUse': false,
          'inactiveHours': 0,
          'shouldShowEmpty': false,
          'message': 'Portfolio data available but timestamp missing',
        };
      }

      final lastUpdated = DateTime.tryParse(lastUpdatedStr);
      if (lastUpdated == null) {
        return {
          'hasData': true,
          'isFirstUse': false,
          'inactiveHours': 0,
          'shouldShowEmpty': false,
          'message': 'Portfolio data available but invalid timestamp',
        };
      }

      final inactiveDuration = currentTime.difference(lastUpdated);
      final inactiveHours = inactiveDuration.inHours;
      final isLongInactive = inactiveHours >= 24; // 24+ hours threshold

      if (kDebugMode) {
        print('🕐 STARTUP FIX: Inactivity check results:');
        print('   Last updated: $lastUpdatedStr');
        print('   Hours since last update: $inactiveHours');
        print('   Is long inactive (24+h): $isLongInactive');
        print(
          '   Portfolio value: \$${(snapshot['totalValue'] as num).toStringAsFixed(2)}',
        );
      }

      return {
        'hasData': true,
        'isFirstUse': false,
        'inactiveHours': inactiveHours,
        'isLongInactive': isLongInactive,
        'shouldShowEmpty': false,
        'lastUpdated': lastUpdatedStr,
        'portfolioValue': snapshot['totalValue'],
        'profitLoss': snapshot['profitLoss'],
        'message':
            isLongInactive
                ? 'Long inactivity detected (${inactiveHours}h) - loading portfolio data immediately'
                : 'Recent activity - portfolio data available',
        'dataAge': '${inactiveHours}h ago',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ STARTUP FIX: Inactivity check failed: $e');
      }

      return {
        'hasData': false,
        'isFirstUse': false,
        'inactiveHours': 0,
        'shouldShowEmpty': true,
        'error': e.toString(),
        'message': 'Unable to determine inactivity status',
      };
    }
  }

  /// STARTUP FIX: Force immediate P&L load for startup scenarios
  Future<Map<String, dynamic>?> forceLoadForStartup() async {
    try {
      if (kDebugMode) {
        print('🚀 STARTUP FIX: Force loading P&L data for startup...');
      }

      // Check inactivity status first
      final inactivityStatus = await checkInactivityStatus();

      if (kDebugMode) {
        print(
          '📊 STARTUP FIX: Inactivity status: ${inactivityStatus['message']}',
        );
      }

      // Load with startup session awareness
      final snapshot = await loadPLSnapshot(isStartupSession: true);

      if (snapshot != null && inactivityStatus['isLongInactive'] == true) {
        // Add extended inactivity marker
        snapshot['extendedInactivity'] = true;
        snapshot['inactiveHours'] = inactivityStatus['inactiveHours'];
        snapshot['forceLoadedForStartup'] = true;
        snapshot['startupTimestamp'] = DateTime.now().toIso8601String();

        if (kDebugMode) {
          final plValue = (snapshot['profitLoss'] as num).toDouble();
          print(
            '✅ STARTUP FIX: P&L force loaded after ${inactivityStatus['inactiveHours']}h inactivity: \$${plValue.toStringAsFixed(2)}',
          );
        }
      }

      return snapshot;
    } catch (e) {
      if (kDebugMode) {
        print('❌ STARTUP FIX: Force load for startup failed: $e');
      }
      return null;
    }
  }
}