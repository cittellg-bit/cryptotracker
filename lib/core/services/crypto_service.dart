import 'package:flutter/foundation.dart';

import './crypto_api_service.dart';
import './mock_auth_service.dart';

class CryptoService {
  static CryptoService? _instance;
  static CryptoService get instance => _instance ??= CryptoService._internal();

  CryptoService._internal() {
    // Initialize the API service
    _apiService.initialize();
  }

  CryptoService();

  final CryptoApiService _apiService = CryptoApiService.instance;

  /// Clear cached data
  void clearCache() {
    _apiService.clearCache();
    if (kDebugMode) {
      print('🧹 Crypto service cache cleared');
    }
  }

  /// Get all user transactions with local mock data
  Future<List<Map<String, dynamic>>> getUserTransactions() async {
    try {
      // Always return empty list for instant access mode
      if (kDebugMode) {
        print('✅ Retrieved 0 transactions (instant access mode)');
      }

      return <Map<String, dynamic>>[];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching user transactions: $e');
      }
      return [];
    }
  }

  /// Get user portfolio summary with local mock data
  Future<List<Map<String, dynamic>>> getUserPortfolio() async {
    try {
      // Always return empty portfolio for instant access mode
      if (kDebugMode) {
        print('✅ Retrieved empty portfolio (instant access mode)');
      }

      return <Map<String, dynamic>>[];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching user portfolio: $e');
      }
      return [];
    }
  }

  /// Get transactions for a specific cryptocurrency (local mock)
  Future<List<Map<String, dynamic>>> getCryptoTransactions(
      String cryptoId) async {
    try {
      // Always return empty list for instant access mode
      if (kDebugMode) {
        print(
            '✅ Retrieved 0 transactions for crypto $cryptoId (instant access mode)');
      }

      return <Map<String, dynamic>>[];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching crypto transactions: $e');
      }
      return [];
    }
  }

  /// Add a new transaction (local mock - no actual storage)
  Future<Map<String, dynamic>?> addTransaction({
    required String cryptoId,
    required String cryptoSymbol,
    required String cryptoName,
    required String cryptoIconUrl,
    required String transactionType,
    required double amount,
    required double pricePerUnit,
    required DateTime transactionDate,
    String? notes,
  }) async {
    try {
      // Create mock transaction without storage
      final mockTransaction = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'user_id': MockAuthService.instance.currentUserId ?? 'instant_user',
        'crypto_id': cryptoId,
        'crypto_symbol': cryptoSymbol,
        'crypto_name': cryptoName,
        'crypto_icon_url': cryptoIconUrl,
        'transaction_type': transactionType,
        'amount': amount,
        'price_per_unit': pricePerUnit,
        'transaction_date': transactionDate.toIso8601String(),
        'notes': notes ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        print('✅ Mock transaction created successfully (instant access mode)');
      }

      return mockTransaction;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating mock transaction: $e');
      }
      rethrow;
    }
  }

  /// Update an existing transaction (local mock)
  Future<Map<String, dynamic>?> updateTransaction({
    required String transactionId,
    required String cryptoId,
    required String cryptoSymbol,
    required String cryptoName,
    required String cryptoIconUrl,
    required String transactionType,
    required double amount,
    required double pricePerUnit,
    required DateTime transactionDate,
    String? notes,
  }) async {
    try {
      // Create mock updated transaction
      final mockTransaction = {
        'id': transactionId,
        'user_id': MockAuthService.instance.currentUserId ?? 'instant_user',
        'crypto_id': cryptoId,
        'crypto_symbol': cryptoSymbol,
        'crypto_name': cryptoName,
        'crypto_icon_url': cryptoIconUrl,
        'transaction_type': transactionType,
        'amount': amount,
        'price_per_unit': pricePerUnit,
        'transaction_date': transactionDate.toIso8601String(),
        'notes': notes ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        print('✅ Mock transaction updated successfully (instant access mode)');
      }

      return mockTransaction;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating mock transaction: $e');
      }
      rethrow;
    }
  }

  /// Delete a transaction (local mock)
  Future<void> deleteTransaction(String transactionId) async {
    try {
      if (kDebugMode) {
        print(
            '✅ Mock transaction deleted successfully (instant access mode): $transactionId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting mock transaction: $e');
      }
      rethrow;
    }
  }

  /// Get portfolio statistics (local mock)
  Future<Map<String, dynamic>> getPortfolioStatistics() async {
    try {
      // Return empty portfolio stats for instant access mode
      return {
        'totalInvested': 0.0,
        'totalAmount': 0.0,
        'cryptoCount': 0,
        'averageInvestment': 0.0,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching portfolio statistics: $e');
      }
      return {
        'totalInvested': 0.0,
        'totalAmount': 0.0,
        'cryptoCount': 0,
        'averageInvestment': 0.0,
      };
    }
  }

  /// Refresh portfolio summary (local mock - no-op)
  Future<void> refreshPortfolioSummary() async {
    try {
      if (kDebugMode) {
        print('✅ Portfolio summary refresh completed (instant access mode)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refreshing portfolio summary: $e');
      }
    }
  }

  /// Get crypto holding details (local mock)
  Future<Map<String, dynamic>?> getCryptoHolding(String cryptoId) async {
    try {
      if (kDebugMode) {
        print('✅ No crypto holding found for $cryptoId (instant access mode)');
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching crypto holding: $e');
      }
      return null;
    }
  }

  /// Check if user has any transactions (local mock)
  Future<bool> hasTransactions() async {
    try {
      // Always return false for instant access mode
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking for transactions: $e');
      }
      return false;
    }
  }

  // === API SERVICE DELEGATES (unchanged - these provide market data) ===

  /// Get cached data
  List<Map<String, dynamic>>? getCachedData() {
    return _apiService.getCachedData();
  }

  /// Get current price for a cryptocurrency
  Future<double?> getCurrentPrice(String cryptoId) async {
    try {
      final price = await _apiService.getCurrentPrice(cryptoId);
      if (kDebugMode && price != null) {
        print(
            '💰 Retrieved current price for $cryptoId: \$${price.toStringAsFixed(2)}');
      }
      return price;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching current price for $cryptoId: $e');
      }
      return null;
    }
  }

  /// Get top cryptocurrencies with caching
  Future<List<Map<String, dynamic>>> getTopCryptocurrencies(
      {int limit = 100}) async {
    try {
      final cryptos = await _apiService.getTopCryptocurrencies(limit: limit);
      if (kDebugMode) {
        print('✅ Retrieved ${cryptos.length} top cryptocurrencies via API');
      }
      return cryptos;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ API failed, falling back to hardcoded data: $e');
      }
      // Return fallback data on API failure
      return _apiService.getFallbackData();
    }
  }

  /// Search cryptocurrencies
  Future<List<Map<String, dynamic>>> searchCryptocurrencies(
      String query) async {
    try {
      final searchResults = await _apiService.searchCryptocurrencies(query);
      if (kDebugMode) {
        print(
            '🔍 Search for "$query" returned ${searchResults.length} results');
      }
      return searchResults;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error searching cryptocurrencies: $e');
      }
      return [];
    }
  }

  /// Get fallback cryptocurrency data
  List<Map<String, dynamic>> getFallbackData() {
    return _apiService.getFallbackData();
  }

  /// Get cryptocurrency details
  Future<Map<String, dynamic>?> getCryptocurrencyDetails(
      String cryptoId) async {
    try {
      final details = await _apiService.getCryptocurrencyDetails(cryptoId);
      if (kDebugMode && details != null) {
        print('✅ Retrieved details for cryptocurrency: $cryptoId');
      }
      return details;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching cryptocurrency details: $e');
      }
      return null;
    }
  }
}
