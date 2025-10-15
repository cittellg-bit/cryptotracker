import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance =>
      _instance ??= SupabaseService._internal();

  SupabaseService._internal();

  SupabaseClient? _client;
  SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Connection state tracking
  bool _connectionHealthy = false;
  DateTime? _lastSuccessfulOperation;
  int _consecutiveFailures = 0;

  /// Initialize Supabase with robust error handling and connection validation
  static Future<void> initialize() async {
    await instance._initialize();
  }

  Future<void> _initialize() async {
    if (_initialized && _client != null && _connectionHealthy) {
      if (kDebugMode) {
        print('✅ Supabase already initialized and healthy');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🔄 Initializing Supabase connection...');
      }

      // Reset connection state
      _connectionHealthy = false;
      _consecutiveFailures = 0;

      // Load environment configuration
      final config = await _loadEnvironmentConfig();
      final supabaseUrl = config['SUPABASE_URL'] as String?;
      final supabaseAnonKey = config['SUPABASE_ANON_KEY'] as String?;

      // Validate configuration
      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception(
            'Missing SUPABASE_URL or SUPABASE_ANON_KEY in env.json');
      }

      if (supabaseUrl.contains('dummy') ||
          supabaseAnonKey.contains('dummy') ||
          supabaseUrl.contains('your-') ||
          supabaseAnonKey.contains('your-')) {
        throw Exception(
            'Please update SUPABASE_URL and SUPABASE_ANON_KEY in env.json with real values');
      }

      // Validate URL format
      if (!supabaseUrl.startsWith('https://') ||
          !supabaseUrl.contains('supabase.co')) {
        throw Exception(
            'Invalid SUPABASE_URL format. Expected: https://[project-id].supabase.co');
      }

      // Initialize Supabase with optimized settings
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUri: false, // Optimize for mobile
        ),
      );

      _client = Supabase.instance.client;
      _initialized = true;

      // Test the connection immediately
      await _validateConnection();

      // Auto-authenticate if needed
      if (!isAuthenticated) {
        await signInAnonymously();
      }

      if (kDebugMode) {
        print('✅ Supabase initialized successfully');
        print('   URL: ${supabaseUrl.substring(0, 30)}...');
        print('   Connection: ${_connectionHealthy ? "Healthy" : "Testing"}');
        print(
            '   User: ${currentUser?.id.substring(0, 8) ?? "Not authenticated"}');
      }
    } catch (e) {
      _initialized = false;
      _client = null;
      _connectionHealthy = false;
      _consecutiveFailures++;

      if (kDebugMode) {
        print('❌ Supabase initialization failed: $e');
        print('   Consecutive failures: $_consecutiveFailures');
      }

      // Re-throw with more context
      if (e.toString().contains('env.json')) {
        throw Exception('Configuration Error: $e');
      } else if (e.toString().contains('network')) {
        throw Exception(
            'Network Error: Unable to connect to Supabase. Check your internet connection.');
      } else {
        throw Exception('Supabase Setup Error: $e');
      }
    }
  }

  /// Validate connection by testing database access
  Future<void> _validateConnection() async {
    try {
      // Test database connectivity with a lightweight query
      await _client!
          .from('user_profiles')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 10));

      _connectionHealthy = true;
      _lastSuccessfulOperation = DateTime.now();
      _consecutiveFailures = 0;

      if (kDebugMode) {
        print('✅ Database connection validated');
      }
    } catch (e) {
      _connectionHealthy = false;
      _consecutiveFailures++;

      if (kDebugMode) {
        print('⚠️ Connection validation failed: $e');
      }
      // Don't throw - initialization can succeed even if initial connection test fails
    }
  }

  /// Load environment configuration from env.json
  Future<Map<String, dynamic>> _loadEnvironmentConfig() async {
    try {
      final String envContent = await rootBundle.loadString('env.json');
      final config = jsonDecode(envContent) as Map<String, dynamic>;

      if (kDebugMode) {
        print('📄 Environment config loaded successfully');
      }

      return config;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load env.json: $e');
      }
      throw Exception(
          'Could not load environment configuration. Ensure env.json exists in the root directory.');
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated {
    try {
      return _client?.auth.currentUser != null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Auth check failed: $e');
      }
      return false;
    }
  }

  /// Get current user
  User? get currentUser {
    try {
      return _client?.auth.currentUser;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Current user access failed: $e');
      }
      return null;
    }
  }

  /// Get current user ID
  String? get currentUserId {
    try {
      return _client?.auth.currentUser?.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Current user ID access failed: $e');
      }
      return null;
    }
  }

  /// Enhanced connection and authentication ensuring with better error handling
  Future<bool> ensureAuthenticated() async {
    try {
      if (kDebugMode) {
        print('🔄 Ensuring authentication...');
      }

      // Initialize if needed
      if (!_initialized || _client == null) {
        if (kDebugMode) {
          print('   Initializing Supabase...');
        }
        await _initialize();
      }

      // Check current auth status
      if (isAuthenticated) {
        if (kDebugMode) {
          print(
              '✅ User already authenticated: ${currentUser?.email ?? currentUser?.id}');
        }

        // Update connection health
        _connectionHealthy = true;
        _lastSuccessfulOperation = DateTime.now();
        return true;
      }

      // Try anonymous sign in for app functionality
      if (kDebugMode) {
        print('🔄 Attempting anonymous sign in...');
      }

      await signInAnonymously();

      final success = isAuthenticated;
      if (kDebugMode) {
        print(success
            ? '✅ Authentication successful'
            : '❌ Authentication failed');
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Ensure authenticated failed: $e');
      }
      _consecutiveFailures++;
      return false;
    }
  }

  /// Sign in anonymously with enhanced error handling and retry logic
  Future<void> signInAnonymously() async {
    if (!_initialized || _client == null) {
      await _initialize();
    }

    const maxRetries = 3;
    int currentRetry = 0;

    while (currentRetry < maxRetries) {
      try {
        if (kDebugMode && currentRetry > 0) {
          print('🔄 Anonymous sign in attempt ${currentRetry + 1}/$maxRetries');
        }

        final response = await _client!.auth.signInAnonymously();

        if (response.user == null) {
          throw Exception('Anonymous sign in failed - no user returned');
        }

        // Update connection health on success
        _connectionHealthy = true;
        _lastSuccessfulOperation = DateTime.now();
        _consecutiveFailures = 0;

        if (kDebugMode) {
          print('✅ Anonymous sign in successful');
          print('   User ID: ${response.user!.id}');
          print('   Created: ${response.user!.createdAt}');
        }
        return;
      } catch (e) {
        currentRetry++;
        _consecutiveFailures++;

        if (kDebugMode) {
          print('❌ Anonymous sign in attempt $currentRetry failed: $e');
        }

        if (currentRetry >= maxRetries) {
          // Provide specific error messages
          if (e.toString().toLowerCase().contains('network')) {
            throw Exception(
                'Network error during sign in. Check your internet connection.');
          } else if (e.toString().toLowerCase().contains('api key')) {
            throw Exception(
                'Invalid API key. Check your Supabase configuration.');
          } else {
            throw Exception(
                'Authentication failed after $maxRetries attempts: ${e.toString()}');
          }
        }

        // Wait before retry
        await Future.delayed(Duration(seconds: currentRetry));
      }
    }
  }

  /// Enhanced sign out
  Future<void> signOut() async {
    if (!_initialized || _client == null) return;

    try {
      await _client!.auth.signOut();

      if (kDebugMode) {
        print('✅ User signed out successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign out failed: $e');
      }
      // Don't throw - sign out failure shouldn't break the app
    }
  }

  /// Get user profile with error handling
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (!await ensureAuthenticated()) return null;

      final response = await _client!
          .from('user_profiles')
          .select()
          .eq('id', currentUserId!)
          .maybeSingle();

      _lastSuccessfulOperation = DateTime.now();
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching user profile: $e');
      }
      _consecutiveFailures++;
      return null;
    }
  }

  /// Comprehensive health check with connection test and recovery
  Future<bool> healthCheck() async {
    try {
      if (kDebugMode) {
        print('🔄 Starting Supabase health check...');
      }

      // Step 1: Initialize if needed
      if (!_initialized) {
        if (kDebugMode) {
          print('   Step 1: Initializing...');
        }
        await _initialize();
      }

      // Step 2: Test authentication
      if (!isAuthenticated) {
        if (kDebugMode) {
          print('   Step 2: Authenticating...');
        }
        await signInAnonymously();
      }

      // Step 3: Test database connection with timeout
      if (kDebugMode) {
        print('   Step 3: Testing database connection...');
      }

      await _client!.from('user_profiles').select('id').limit(1).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw Exception('Database connection timeout'),
          );

      // Update health status
      _connectionHealthy = true;
      _lastSuccessfulOperation = DateTime.now();
      _consecutiveFailures = 0;

      if (kDebugMode) {
        print('✅ Supabase health check passed');
      }
      return true;
    } catch (e) {
      _connectionHealthy = false;
      _consecutiveFailures++;

      if (kDebugMode) {
        print('❌ Supabase health check failed: $e');
        print('   Consecutive failures: $_consecutiveFailures');
      }
      return false;
    }
  }

  /// Get detailed connection status
  Map<String, dynamic> getConnectionStatus() {
    return {
      'initialized': _initialized,
      'authenticated': isAuthenticated,
      'hasClient': _client != null,
      'connectionHealthy': _connectionHealthy,
      'consecutiveFailures': _consecutiveFailures,
      'lastSuccessfulOperation': _lastSuccessfulOperation?.toIso8601String(),
      'userId': currentUserId,
      'userEmail': currentUser?.email,
      'lastHealthCheck': DateTime.now().toIso8601String(),
    };
  }

  /// Auto-recovery method for connection issues
  Future<bool> attemptRecovery() async {
    try {
      if (kDebugMode) {
        print('🔄 Attempting connection recovery...');
        print('   Consecutive failures: $_consecutiveFailures');
      }

      // Reset state
      _connectionHealthy = false;

      // Full reinitialization
      await reset();

      // Test the connection
      final healthy = await healthCheck();

      if (kDebugMode) {
        print(healthy
            ? '✅ Connection recovery successful'
            : '❌ Connection recovery failed');
      }

      return healthy;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Connection recovery error: $e');
      }
      return false;
    }
  }

  /// Check if recovery is needed based on failure patterns
  bool shouldAttemptRecovery() {
    return _consecutiveFailures >= 3 ||
        (!_connectionHealthy &&
            _lastSuccessfulOperation != null &&
            DateTime.now().difference(_lastSuccessfulOperation!).inMinutes > 5);
  }

  /// Dispose resources and reset state
  void dispose() {
    try {
      _client = null;
      _initialized = false;
      _connectionHealthy = false;
      _consecutiveFailures = 0;
      _lastSuccessfulOperation = null;

      if (kDebugMode) {
        print('🧹 Supabase service disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during dispose: $e');
      }
    }
  }

  /// Reset and reinitialize with improved error handling
  Future<void> reset() async {
    try {
      if (kDebugMode) {
        print('🔄 Resetting Supabase service...');
      }

      // Sign out if possible
      try {
        if (_client != null && isAuthenticated) {
          await signOut();
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Sign out during reset: $e');
        }
      }

      // Reset state
      dispose();

      // Reinitialize
      await _initialize();

      if (kDebugMode) {
        print('✅ Supabase service reset and reinitialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during reset: $e');
      }
      rethrow;
    }
  }

  /// Get health metrics for debugging
  Map<String, dynamic> getHealthMetrics() {
    final now = DateTime.now();
    final timeSinceLastSuccess = _lastSuccessfulOperation != null
        ? now.difference(_lastSuccessfulOperation!).inMinutes
        : null;

    return {
      'initialized': _initialized,
      'authenticated': isAuthenticated,
      'connectionHealthy': _connectionHealthy,
      'consecutiveFailures': _consecutiveFailures,
      'timeSinceLastSuccess': timeSinceLastSuccess,
      'shouldAttemptRecovery': shouldAttemptRecovery(),
      'clientExists': _client != null,
    };
  }
}
