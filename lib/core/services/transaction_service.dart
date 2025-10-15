import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './logging_service.dart';
import './portfolio_service.dart';
import './mock_auth_service.dart';

class TransactionService {
  static TransactionService? _instance;
  static TransactionService get instance =>
      _instance ??= TransactionService._internal();

  TransactionService._internal();

  // Local storage keys
  static const String _transactionsKey = 'local_transactions';
  static const String _transactionIdCounterKey = 'transaction_id_counter';

  // Generate a user ID for local transactions
  String get _localUserId {
    final authService = MockAuthService.instance;
    return authService.currentUserId ??
        'local-user-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Generate unique ID for local storage
  Future<String> _generateLocalId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCounter = prefs.getInt(_transactionIdCounterKey) ?? 0;
      final newCounter = currentCounter + 1;
      await prefs.setInt(_transactionIdCounterKey, newCounter);
      return 'local_$newCounter';
    } catch (e) {
      // Fallback to timestamp-based ID
      return 'local_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Save transaction to local storage
  Future<Map<String, dynamic>?> _saveToLocalStorage({
    required String cryptoId,
    required String symbol,
    required String name,
    required String iconUrl,
    required String type,
    required double amount,
    required double price,
    required DateTime date,
    String? notes,
    String? transactionId,
    String? exchange,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingTransactionsJson =
          prefs.getString(_transactionsKey) ?? '[]';
      final List<dynamic> existingTransactions =
          jsonDecode(existingTransactionsJson);

      final transactionData = {
        'id': transactionId ?? await _generateLocalId(),
        'user_id': _localUserId,
        'crypto_id': cryptoId,
        'crypto_symbol': symbol.toUpperCase(),
        'crypto_name': name,
        'crypto_icon_url': iconUrl,
        'transaction_type': type.toLowerCase(),
        'amount': amount,
        'price_per_unit': price,
        'transaction_date': date.toIso8601String(),
        'notes': notes ?? '',
        'exchange': exchange ?? 'Unknown',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_local': true,
      };

      // Update existing transaction or add new one
      if (transactionId != null) {
        final index =
            existingTransactions.indexWhere((t) => t['id'] == transactionId);
        if (index != -1) {
          existingTransactions[index] = transactionData;
        } else {
          existingTransactions.add(transactionData);
        }
      } else {
        existingTransactions.add(transactionData);
      }

      await prefs.setString(_transactionsKey, jsonEncode(existingTransactions));

      await LoggingService.instance.logInfo(
        category: LogCategory.transaction,
        message: 'Transaction saved to local storage',
        details: {
          'transaction_id': transactionData['id'],
          'crypto_symbol': symbol,
          'storage_type': 'local',
        },
        functionName: '_saveToLocalStorage',
      );

      return transactionData;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.transaction,
        message: 'Error saving transaction to local storage',
        details: {'error': e.toString()},
        functionName: '_saveToLocalStorage',
        errorStack: e.toString(),
      );
      return null;
    }
  }

  /// Load transactions from local storage
  Future<List<Map<String, dynamic>>> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = prefs.getString(_transactionsKey) ?? '[]';
      final List<dynamic> transactionsList = jsonDecode(transactionsJson);

      return transactionsList.map((t) => Map<String, dynamic>.from(t)).toList();
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.transaction,
        message: 'Error loading transactions from local storage',
        details: {'error': e.toString()},
        functionName: '_loadFromLocalStorage',
        errorStack: e.toString(),
      );
      return [];
    }
  }

  /// Delete transaction from local storage
  Future<bool> _deleteFromLocalStorage(String transactionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingTransactionsJson =
          prefs.getString(_transactionsKey) ?? '[]';
      final List<dynamic> existingTransactions =
          jsonDecode(existingTransactionsJson);

      existingTransactions.removeWhere((t) => t['id'] == transactionId);
      await prefs.setString(_transactionsKey, jsonEncode(existingTransactions));

      await LoggingService.instance.logInfo(
        category: LogCategory.transaction,
        message: 'Transaction deleted from local storage',
        details: {'transaction_id': transactionId},
        functionName: '_deleteFromLocalStorage',
      );

      return true;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.transaction,
        message: 'Error deleting transaction from local storage',
        details: {'transaction_id': transactionId, 'error': e.toString()},
        functionName: '_deleteFromLocalStorage',
        errorStack: e.toString(),
      );
      return false;
    }
  }

  /// Refresh portfolio cache
  Future<void> refreshPortfolioCache() async {
    try {
      await LoggingService.instance.logInfo(
        category: LogCategory.database,
        message: 'Refreshing portfolio cache',
        functionName: 'refreshPortfolioCache',
      );

      await PortfolioService.instance.refreshPortfolioSummary();

      await LoggingService.instance.logInfo(
        category: LogCategory.database,
        message: 'Portfolio cache refreshed successfully',
        functionName: 'refreshPortfolioCache',
      );

      if (kDebugMode) {
        print('✅ Portfolio cache refreshed successfully');
      }
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.database,
        message: 'Error refreshing portfolio cache',
        details: {'error': e.toString()},
        functionName: 'refreshPortfolioCache',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error refreshing portfolio cache: $e');
      }
      rethrow;
    }
  }

  /// Get transactions for crypto (alias for getTransactionsByCrypto)
  Future<List<Map<String, dynamic>>> getTransactionsForCrypto(
      String cryptoId) async {
    return await getTransactionsByCrypto(cryptoId);
  }

  /// Add transaction method (alias for saveTransaction)
  Future<Map<String, dynamic>?> addTransaction({
    required String cryptoId,
    required String symbol,
    required String name,
    required String iconUrl,
    required String type,
    required double amount,
    required double price,
    required DateTime date,
    String? notes,
    String? exchange,
  }) async {
    return await saveTransaction(
      cryptoId: cryptoId,
      symbol: symbol,
      name: name,
      iconUrl: iconUrl,
      type: type,
      amount: amount,
      price: price,
      date: date,
      notes: notes,
      exchange: exchange,
    );
  }

  /// Save a transaction using local storage only
  Future<Map<String, dynamic>?> saveTransaction({
    required String cryptoId,
    required String symbol,
    required String name,
    required String iconUrl,
    required String type,
    required double amount,
    required double price,
    required DateTime date,
    String? notes,
    String? exchange,
  }) async {
    try {
      await LoggingService.instance.logInfo(
        category: LogCategory.transaction,
        message: 'Saving transaction with immediate portfolio update',
        details: {
          'crypto_symbol': symbol,
          'transaction_type': type,
          'amount': amount,
          'price': price,
          'total_value': amount * price,
          'exchange': exchange ?? 'Unknown',
        },
        functionName: 'saveTransaction',
      );

      // Validate inputs
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }
      if (price <= 0) {
        throw Exception('Price must be greater than 0');
      }
      if (!['buy', 'sell'].contains(type.toLowerCase())) {
        throw Exception('Transaction type must be either "buy" or "sell"');
      }

      if (kDebugMode) {
        print(
            '💾 Saving transaction: ${symbol.toUpperCase()} ${type.toLowerCase()} $amount @ \$${price.toStringAsFixed(2)}');
        print('   Exchange: ${exchange ?? 'Unknown'}');
        print('   Storage: Local only');
      }

      // Save to local storage
      final savedTransaction = await _saveToLocalStorage(
        cryptoId: cryptoId,
        symbol: symbol,
        name: name,
        iconUrl: iconUrl,
        type: type,
        amount: amount,
        price: price,
        date: date,
        notes: notes,
        exchange: exchange,
      );

      if (savedTransaction == null) {
        throw Exception('Failed to save transaction to local storage');
      }

      if (kDebugMode) {
        print(
            '✅ Transaction saved to local storage: ${savedTransaction['id']}');
        print('   Exchange saved: ${savedTransaction['exchange']}\n');
        print('   Total value: \$${(amount * price).toStringAsFixed(2)}');
      }

      // Force immediate portfolio calculation and cache invalidation
      try {
        await LoggingService.instance.logInfo(
          category: LogCategory.database,
          message: 'Starting immediate portfolio refresh',
          details: {'transaction_saved': savedTransaction['id']},
          functionName: 'saveTransaction',
        );

        // Clear all portfolio caches to prevent stale data
        PortfolioService.instance.clearCache();

        // Force fresh portfolio summary calculation
        final portfolioSummary =
            await PortfolioService.instance.getPortfolioSummary();

        if (kDebugMode) {
          print(
              '✅ Portfolio total immediately updated to: \$${portfolioSummary['totalValue']?.toStringAsFixed(2) ?? '0.00'}');
          print(
              '   Total invested: \$${portfolioSummary['totalInvested']?.toStringAsFixed(2) ?? '0.00'}');
          print('   Holdings count: ${portfolioSummary['totalHoldings'] ?? 0}');
        }

        await LoggingService.instance.logInfo(
          category: LogCategory.database,
          message: 'Portfolio total successfully updated after transaction',
          details: {
            'new_total_value': portfolioSummary['totalValue'],
            'new_total_invested': portfolioSummary['totalInvested'],
            'transaction_id': savedTransaction['id'],
          },
          functionName: 'saveTransaction',
        );
      } catch (refreshError) {
        // Log but don't fail the transaction save if portfolio refresh fails
        await LoggingService.instance.logWarning(
          category: LogCategory.database,
          message:
              'Portfolio refresh failed after transaction save (non-critical)',
          details: {'refresh_error': refreshError.toString()},
          functionName: 'saveTransaction',
        );

        if (kDebugMode) {
          print(
              '⚠️ Portfolio refresh failed (transaction still saved): $refreshError');
        }
      }

      return savedTransaction;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.transaction,
        message: 'Error saving transaction',
        details: {
          'crypto_symbol': symbol,
          'transaction_type': type,
          'amount': amount,
          'price': price,
          'exchange': exchange ?? 'Unknown',
          'error': e.toString(),
        },
        functionName: 'saveTransaction',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error saving transaction: $e');
      }
      rethrow;
    }
  }

  /// Update an existing transaction using local storage only
  Future<Map<String, dynamic>?> updateTransaction({
    required String transactionId,
    required String cryptoId,
    required String symbol,
    required String name,
    required String iconUrl,
    required String type,
    required double amount,
    required double price,
    required DateTime date,
    String? notes,
    String? exchange,
  }) async {
    try {
      await LoggingService.instance.logInfo(
        category: LogCategory.transaction,
        message: 'Updating transaction with portfolio refresh',
        details: {
          'transaction_id': transactionId,
          'crypto_symbol': symbol,
          'transaction_type': type,
          'amount': amount,
          'price': price,
        },
        functionName: 'updateTransaction',
      );

      // Validate inputs
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }
      if (price <= 0) {
        throw Exception('Price must be greater than 0');
      }
      if (!['buy', 'sell'].contains(type.toLowerCase())) {
        throw Exception('Transaction type must be either "buy" or "sell"');
      }

      if (kDebugMode) {
        print('🔄 Updating transaction $transactionId');
      }

      // Update in local storage
      final updatedTransaction = await _saveToLocalStorage(
        cryptoId: cryptoId,
        symbol: symbol,
        name: name,
        iconUrl: iconUrl,
        type: type,
        amount: amount,
        price: price,
        date: date,
        notes: notes,
        transactionId: transactionId,
        exchange: exchange,
      );

      if (updatedTransaction == null) {
        throw Exception('Failed to update transaction in local storage');
      }

      if (kDebugMode) {
        print('✅ Transaction updated in local storage successfully');
      }

      // Force immediate portfolio recalculation after update
      try {
        // Clear caches and force fresh calculation
        PortfolioService.instance.clearCache();
        final portfolioSummary =
            await PortfolioService.instance.getPortfolioSummary();

        if (kDebugMode) {
          print(
              '✅ Portfolio total recalculated after update: \$${portfolioSummary['totalValue']?.toStringAsFixed(2) ?? '0.00'}');
        }

        await LoggingService.instance.logInfo(
          category: LogCategory.database,
          message: 'Portfolio recalculated after transaction update',
          details: {
            'updated_total_value': portfolioSummary['totalValue'],
            'transaction_id': transactionId,
          },
          functionName: 'updateTransaction',
        );
      } catch (refreshError) {
        await LoggingService.instance.logWarning(
          category: LogCategory.database,
          message: 'Portfolio refresh failed after transaction update',
          details: {'refresh_error': refreshError.toString()},
          functionName: 'updateTransaction',
        );

        if (kDebugMode) {
          print('⚠️ Portfolio refresh failed after update: $refreshError');
        }
      }

      return updatedTransaction;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.transaction,
        message: 'Error updating transaction',
        details: {'transaction_id': transactionId, 'error': e.toString()},
        functionName: 'updateTransaction',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error updating transaction: $e');
      }
      rethrow;
    }
  }

  /// Delete a transaction using local storage only
  Future<bool> deleteTransaction(String transactionId) async {
    try {
      await LoggingService.instance.logInfo(
        category: LogCategory.transaction,
        message: 'Deleting transaction with portfolio refresh',
        details: {'transaction_id': transactionId},
        functionName: 'deleteTransaction',
      );

      if (kDebugMode) {
        print('🗑️ Deleting transaction $transactionId');
      }

      // Delete from local storage
      final deleteResult = await _deleteFromLocalStorage(transactionId);

      if (deleteResult && kDebugMode) {
        print('✅ Transaction deleted from local storage successfully');
      }

      // Force immediate portfolio recalculation after delete
      if (deleteResult) {
        try {
          // Clear caches and force fresh calculation
          PortfolioService.instance.clearCache();
          final portfolioSummary =
              await PortfolioService.instance.getPortfolioSummary();

          if (kDebugMode) {
            print(
                '✅ Portfolio total recalculated after delete: \$${portfolioSummary['totalValue']?.toStringAsFixed(2) ?? '0.00'}');
          }

          await LoggingService.instance.logInfo(
            category: LogCategory.database,
            message: 'Portfolio recalculated after transaction deletion',
            details: {
              'updated_total_value': portfolioSummary['totalValue'],
              'deleted_transaction_id': transactionId,
            },
            functionName: 'deleteTransaction',
          );
        } catch (refreshError) {
          await LoggingService.instance.logWarning(
            category: LogCategory.database,
            message: 'Portfolio refresh failed after transaction deletion',
            details: {'refresh_error': refreshError.toString()},
            functionName: 'deleteTransaction',
          );

          if (kDebugMode) {
            print('⚠️ Portfolio refresh failed after delete: $refreshError');
          }
        }
      }

      return deleteResult;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.transaction,
        message: 'Error deleting transaction',
        details: {'transaction_id': transactionId, 'error': e.toString()},
        functionName: 'deleteTransaction',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error deleting transaction: $e');
      }
      return false;
    }
  }

  /// Get all transactions using local storage only
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    try {
      await LoggingService.instance.logDebug(
        category: LogCategory.database,
        message: 'Fetching all transactions',
        functionName: 'getAllTransactions',
      );

      // Load from local storage
      final localTransactions = await _loadFromLocalStorage();

      // Sort by transaction_date descending
      localTransactions.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['transaction_date'] ?? '') ?? DateTime.now();
        final dateB =
            DateTime.tryParse(b['transaction_date'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      await LoggingService.instance.logDebug(
        category: LogCategory.database,
        message: 'Retrieved transactions from local storage',
        details: {'count': localTransactions.length, 'storage_type': 'local'},
        functionName: 'getAllTransactions',
      );

      if (kDebugMode) {
        print(
            '✅ Retrieved ${localTransactions.length} transactions from local storage');
      }

      return localTransactions;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.database,
        message: 'Error fetching transactions',
        details: {'error': e.toString()},
        functionName: 'getAllTransactions',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error fetching transactions: $e');
      }
      return [];
    }
  }

  /// Get transactions for a specific cryptocurrency using local storage only
  Future<List<Map<String, dynamic>>> getTransactionsByCrypto(
      String cryptoId) async {
    try {
      await LoggingService.instance.logDebug(
        category: LogCategory.database,
        message: 'Fetching transactions by crypto',
        details: {'crypto_id': cryptoId},
        functionName: 'getTransactionsByCrypto',
      );

      // Load from local storage
      final allLocalTransactions = await _loadFromLocalStorage();
      final cryptoTransactions = allLocalTransactions
          .where((t) => t['crypto_id'] == cryptoId)
          .toList();

      // Sort by transaction_date descending
      cryptoTransactions.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['transaction_date'] ?? '') ?? DateTime.now();
        final dateB =
            DateTime.tryParse(b['transaction_date'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      await LoggingService.instance.logDebug(
        category: LogCategory.database,
        message: 'Retrieved crypto transactions from local storage',
        details: {
          'crypto_id': cryptoId,
          'count': cryptoTransactions.length,
          'storage_type': 'local',
        },
        functionName: 'getTransactionsByCrypto',
      );

      if (kDebugMode) {
        print(
            '✅ Retrieved ${cryptoTransactions.length} transactions for $cryptoId from local storage');
      }

      return cryptoTransactions;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.database,
        message: 'Error fetching crypto transactions',
        details: {'crypto_id': cryptoId, 'error': e.toString()},
        functionName: 'getTransactionsByCrypto',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error fetching crypto transactions: $e');
      }
      return [];
    }
  }

  /// Get a specific transaction by ID using local storage only
  Future<Map<String, dynamic>?> getTransaction(String transactionId) async {
    try {
      await LoggingService.instance.logDebug(
        category: LogCategory.database,
        message: 'Fetching transaction by ID',
        details: {'transaction_id': transactionId},
        functionName: 'getTransaction',
      );

      // Load from local storage
      final localTransactions = await _loadFromLocalStorage();
      final transaction = localTransactions.firstWhere(
        (t) => t['id'] == transactionId,
        orElse: () => <String, dynamic>{},
      );

      if (transaction.isNotEmpty) {
        if (kDebugMode) {
          print('✅ Retrieved transaction from local storage: $transactionId');
        }
        return transaction;
      }

      return null;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.database,
        message: 'Error fetching transaction',
        details: {'transaction_id': transactionId, 'error': e.toString()},
        functionName: 'getTransaction',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error fetching transaction: $e');
      }
      return null;
    }
  }

  /// Get transaction summary statistics using local storage only
  Future<Map<String, dynamic>> getTransactionSummary() async {
    try {
      await LoggingService.instance.logDebug(
        category: LogCategory.database,
        message: 'Calculating transaction summary',
        functionName: 'getTransactionSummary',
      );

      final transactions = await getAllTransactions();

      int totalTransactions = transactions.length;
      int buyTransactions = 0;
      int sellTransactions = 0;
      double totalInvested = 0;
      double totalReceived = 0;

      for (final transaction in transactions) {
        final type = transaction['transaction_type'] as String;
        final amount = (transaction['amount'] as num).toDouble();
        final pricePerUnit = (transaction['price_per_unit'] as num).toDouble();
        final totalValue = amount * pricePerUnit;

        if (type == 'buy') {
          buyTransactions++;
          totalInvested += totalValue;
        } else if (type == 'sell') {
          sellTransactions++;
          totalReceived += totalValue;
        }
      }

      final summary = {
        'totalTransactions': totalTransactions,
        'buyTransactions': buyTransactions,
        'sellTransactions': sellTransactions,
        'totalInvested': totalInvested,
        'totalReceived': totalReceived,
        'netInvestment': totalInvested - totalReceived,
      };

      await LoggingService.instance.logDebug(
        category: LogCategory.database,
        message: 'Transaction summary calculated',
        details: summary,
        functionName: 'getTransactionSummary',
      );

      return summary;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.database,
        message: 'Error calculating transaction summary',
        details: {'error': e.toString()},
        functionName: 'getTransactionSummary',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error calculating transaction summary: $e');
      }
      return {
        'totalTransactions': 0,
        'buyTransactions': 0,
        'sellTransactions': 0,
        'totalInvested': 0.0,
        'totalReceived': 0.0,
        'netInvestment': 0.0,
      };
    }
  }

  /// Check if user has any transactions using local storage only
  Future<bool> hasTransactions() async {
    try {
      // Check local storage
      final localTransactions = await _loadFromLocalStorage();
      return localTransactions.isNotEmpty;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.database,
        message: 'Error checking for transactions',
        details: {'error': e.toString()},
        functionName: 'hasTransactions',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error checking for transactions: $e');
      }
      return false;
    }
  }

  /// Get recent transactions (last 10) using local storage only
  Future<List<Map<String, dynamic>>> getRecentTransactions() async {
    try {
      await LoggingService.instance.logDebug(
        category: LogCategory.database,
        message: 'Fetching recent transactions',
        functionName: 'getRecentTransactions',
      );

      // Get from local storage
      final allLocalTransactions = await _loadFromLocalStorage();

      // Sort by transaction_date descending and take first 10
      allLocalTransactions.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['transaction_date'] ?? '') ?? DateTime.now();
        final dateB =
            DateTime.tryParse(b['transaction_date'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      final recentTransactions = allLocalTransactions.take(10).toList();

      await LoggingService.instance.logDebug(
        category: LogCategory.database,
        message: 'Retrieved recent transactions from local storage',
        details: {'count': recentTransactions.length, 'storage_type': 'local'},
        functionName: 'getRecentTransactions',
      );

      if (kDebugMode) {
        print(
            '✅ Retrieved ${recentTransactions.length} recent transactions from local storage');
      }

      return recentTransactions;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.database,
        message: 'Error fetching recent transactions',
        details: {'error': e.toString()},
        functionName: 'getRecentTransactions',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error fetching recent transactions: $e');
      }
      return [];
    }
  }

  /// Get transactions within a date range using local storage only
  Future<List<Map<String, dynamic>>> getTransactionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      await LoggingService.instance.logDebug(
        category: LogCategory.database,
        message: 'Fetching transactions by date range',
        details: {
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
        },
        functionName: 'getTransactionsByDateRange',
      );

      // Get from local storage
      final allLocalTransactions = await _loadFromLocalStorage();
      final filteredTransactions = allLocalTransactions.where((transaction) {
        final transactionDate =
            DateTime.tryParse(transaction['transaction_date'] ?? '');
        if (transactionDate == null) return false;

        return transactionDate
                .isAfter(startDate.subtract(const Duration(days: 1))) &&
            transactionDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      // Sort by transaction_date descending
      filteredTransactions.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['transaction_date'] ?? '') ?? DateTime.now();
        final dateB =
            DateTime.tryParse(b['transaction_date'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      await LoggingService.instance.logDebug(
        category: LogCategory.database,
        message: 'Retrieved transactions for date range from local storage',
        details: {
          'count': filteredTransactions.length,
          'storage_type': 'local',
        },
        functionName: 'getTransactionsByDateRange',
      );

      if (kDebugMode) {
        print(
            '✅ Retrieved ${filteredTransactions.length} transactions for date range from local storage');
      }

      return filteredTransactions;
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.database,
        message: 'Error fetching transactions by date range',
        details: {
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'error': e.toString(),
        },
        functionName: 'getTransactionsByDateRange',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error fetching transactions by date range: $e');
      }
      return [];
    }
  }

  /// Clear all local transactions
  Future<void> clearLocalTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_transactionsKey);
      await prefs.remove(_transactionIdCounterKey);

      await LoggingService.instance.logInfo(
        category: LogCategory.system,
        message: 'Local transactions cleared',
        functionName: 'clearLocalTransactions',
      );

      if (kDebugMode) {
        print('✅ Local transactions cleared');
      }
    } catch (e) {
      await LoggingService.instance.logError(
        category: LogCategory.system,
        message: 'Error clearing local transactions',
        details: {'error': e.toString()},
        functionName: 'clearLocalTransactions',
        errorStack: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Error clearing local transactions: $e');
      }
    }
  }

  /// Get storage status info
  Map<String, dynamic> getStorageStatus() {
    return {
      'supabase_available': false,
      'storage_type': 'local_only',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

// Extension to capitalize strings
extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}
