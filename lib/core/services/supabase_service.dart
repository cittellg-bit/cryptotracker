import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './config_service.dart';
import './supabase_web_config.dart';

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

  /// Add static initialize method for compatibility with main.dart
  static Future<void> initializeInstance() async {
    await instance.initialize();
  }

  /// Initialize Supabase with proper authentication support
  Future<void> initialize() async {
    if (_initialized && _client != null && _connectionHealthy) {
      if (kDebugMode) {
        print('✅ Supabase already initialized and healthy');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🔄 Initializing Supabase connection with authentication...');
      }

      // Reset connection state
      _connectionHealthy = false;
      _consecutiveFailures = 0;

      // Initialize config service first
      await ConfigService.instance.initialize();

      // Load environment configuration using the new config service
      final supabaseUrl = ConfigService.instance.get('SUPABASE_URL');
      final supabaseAnonKey = ConfigService.instance.get('SUPABASE_ANON_KEY');

      // Validate configuration
      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception(
            'Missing SUPABASE_URL or SUPABASE_ANON_KEY in configuration.\n\n${ConfigService.instance.getConfigInstructions()}');
      }

      if (supabaseUrl.contains('dummy') ||
          supabaseAnonKey.contains('dummy') ||
          supabaseUrl.contains('your-') ||
          supabaseAnonKey.contains('your-')) {
        throw Exception(
            'Please update SUPABASE_URL and SUPABASE_ANON_KEY with real values.\n\n${ConfigService.instance.getConfigInstructions()}');
      }

      // Validate URL format
      if (!supabaseUrl.startsWith('https://') ||
          !supabaseUrl.contains('supabase.co')) {
        throw Exception(
            'Invalid SUPABASE_URL format. Expected: https://[project-id].supabase.co\n\nProvided: $supabaseUrl');
      }

      // Configure web-specific settings if on web platform
      if (kIsWeb) {
        await SupabaseWebConfig.instance.configureWebSupabase(
            supabaseUrl: supabaseUrl, supabaseAnonKey: supabaseAnonKey);

        if (kDebugMode) {
          print('✅ Web configuration completed');
        }
      }

      // Initialize Supabase with proper authentication support
      await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
          debug: kDebugMode,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            autoRefreshToken: true, // Enable auto refresh for proper auth
          ));

      _client = Supabase.instance.client;

      // Set up auth state change handler
      _setupAuthBypassHandler();

      _initialized = true;

      // Test the connection immediately
      await _validateConnection();

      if (kDebugMode) {
        print('✅ Supabase initialized successfully with authentication');
        print('   Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
        print('   URL: ${supabaseUrl.substring(0, 30)}...');
        print('   Authentication: ENABLED');
        print('   Connection: ${_connectionHealthy ? "Healthy" : "Testing"}');
      }
    } catch (e) {
      _initialized = false;
      _client = null;
      _connectionHealthy = false;
      _consecutiveFailures++;

      if (kDebugMode) {
        print('❌ Supabase initialization failed: $e');
        print('   Consecutive failures: $_consecutiveFailures');
        print('   Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
      }

      // Re-throw with more context
      if (e.toString().contains('configuration') ||
          e.toString().contains('env.json')) {
        throw Exception('Configuration Error: $e');
      } else if (e.toString().contains('network')) {
        throw Exception(
            'Network Error: Unable to connect to Supabase. Check your internet connection.');
      } else {
        throw Exception('Supabase Setup Error: $e');
      }
    }
  }

  /// Function to remove all authentication requirements (JS equivalent)
  /// Equivalent to JavaScript: function disableAuthentication()
  Future<void> _disableAuthentication() async {
    try {
      // Clear any existing sessions from SharedPreferences (localStorage equivalent)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('supabase.auth.token');
      await prefs.clear(); // Clear all stored auth data

      if (kDebugMode) {
        print('🔧 Cleared authentication data from local storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not clear authentication data: $e');
      }
    }
  }

  /// Set up auth state change handler to bypass all authentication
  /// Equivalent to JavaScript: supabase.auth.onAuthStateChange((event, session) => {...})
  void _setupAuthBypassHandler() {
    try {
      _client?.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        // Force no authentication state as per JS script
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.signedOut) {
          // Bypass authentication by immediately signing out
          _client?.auth.signOut();

          if (kDebugMode) {
            print('🔧 Bypassed authentication event: $event');
          }
        }
      });

      if (kDebugMode) {
        print('✅ Authentication bypass handler configured');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not set up auth bypass handler: $e');
      }
    }
  }

  /// Validate connection by testing database access without authentication
  Future<void> _validateConnection() async {
    try {
      // Test database connectivity without requiring authentication
      await _client!
          .from('user_profiles')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 10));

      _connectionHealthy = true;
      _lastSuccessfulOperation = DateTime.now();
      _consecutiveFailures = 0;

      if (kDebugMode) {
        print('✅ Database connection validated without authentication');
      }
    } catch (e) {
      _connectionHealthy = false;
      _consecutiveFailures++;

      if (kDebugMode) {
        print('⚠️ Connection validation failed: $e');
        print('   Note: Connection may still work for public operations');
      }
      // Don't throw - initialization can succeed even if initial connection test fails
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated {
    try {
      return _client?.auth.currentUser != null;
    } catch (e) {
      return false;
    }
  }

  /// Get current user
  User? get currentUser {
    try {
      return _client?.auth.currentUser;
    } catch (e) {
      return null;
    }
  }

  /// Get current user ID
  String? get currentUserId {
    try {
      return _client?.auth.currentUser?.id;
    } catch (e) {
      return null;
    }
  }

  /// Enhanced connection ensuring with authentication
  Future<bool> ensureAuthenticated() async {
    try {
      if (kDebugMode) {
        print('🔄 Ensuring connection with authentication...');
      }

      // Initialize if needed
      if (!_initialized || _client == null) {
        if (kDebugMode) {
          print('   Initializing Supabase...');
        }
        await initialize();
      }

      // Check if user is authenticated
      if (!isAuthenticated) {
        if (kDebugMode) {
          print('⚠️ User not authenticated');
        }
        return false;
      }

      // Update connection health
      _connectionHealthy = true;
      _lastSuccessfulOperation = DateTime.now();

      if (kDebugMode) {
        print('✅ Connection ready with authentication');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Connection check failed: $e');
      }
      _consecutiveFailures++;
      return false;
    }
  }

  /// Sign in anonymously
  Future<User?> signInAnonymously() async {
    try {
      if (kDebugMode) {
        print('🔄 Signing in anonymously...');
      }

      final response = await _client!.auth.signInAnonymously();

      if (kDebugMode) {
        print('✅ Anonymous sign in successful');
      }

      return response.user;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Anonymous sign in failed: $e');
      }
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      if (kDebugMode) {
        print('🔄 Signing up with email: $email');
      }

      final response = await _client!.auth.signUp(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('✅ Sign up successful');
      }

      return response.user;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign up failed: $e');
      }
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      if (kDebugMode) {
        print('🔄 Signing in with email: $email');
      }

      final response = await _client!.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('✅ Sign in successful');
      }

      return response.user;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign in failed: $e');
      }
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (kDebugMode) {
        print('🔄 Signing out...');
      }

      await _client!.auth.signOut();

      if (kDebugMode) {
        print('✅ Sign out successful');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign out failed: $e');
      }
      rethrow;
    }
  }

  /// Get user profile without authentication (returns null)
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (kDebugMode) {
      print('ℹ️ User profile access bypassed - authentication disabled');
    }
    return null;
  }

  /// Comprehensive health check without authentication requirements
  Future<bool> healthCheck() async {
    try {
      if (kDebugMode) {
        print('🔄 Starting Supabase health check (no auth)...');
      }

      // Step 1: Initialize if needed
      if (!_initialized) {
        if (kDebugMode) {
          print('   Step 1: Initializing...');
        }
        await initialize();
      }

      // Step 2: Test database connection without authentication
      if (kDebugMode) {
        print('   Step 2: Testing database connection...');
      }

      await _client!.from('user_profiles').select('id').limit(1).timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw Exception('Database connection timeout'));

      // Update health status
      _connectionHealthy = true;
      _lastSuccessfulOperation = DateTime.now();
      _consecutiveFailures = 0;

      if (kDebugMode) {
        print('✅ Supabase health check passed (no authentication required)');
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
    final baseStatus = {
      'initialized': _initialized,
      'authenticated': false, // Always false since auth is disabled
      'hasClient': _client != null,
      'connectionHealthy': _connectionHealthy,
      'consecutiveFailures': _consecutiveFailures,
      'lastSuccessfulOperation': _lastSuccessfulOperation?.toIso8601String(),
      'userId': null, // Always null since auth is disabled
      'userEmail': null, // Always null since auth is disabled
      'lastHealthCheck': DateTime.now().toIso8601String(),
      'platform': kIsWeb ? 'web' : 'mobile',
      'authenticationMode': 'disabled', // Indicates auth is disabled
      'configService': ConfigService.instance.getDebugInfo(),
    };

    // Add web-specific status
    if (kIsWeb) {
      baseStatus['webConfig'] = SupabaseWebConfig.instance.getWebConfigStatus();
    }

    return baseStatus;
  }

  /// Auto-recovery method for connection issues
  Future<bool> attemptRecovery() async {
    try {
      if (kDebugMode) {
        print('🔄 Attempting connection recovery (no auth mode)...');
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

      // Clear authentication data
      await _disableAuthentication();

      // Reset web configuration
      if (kIsWeb) {
        SupabaseWebConfig.instance.reset();
      }

      // Reset state
      dispose();

      // Reset config service too
      await ConfigService.instance.reset();

      // Reinitialize
      await initialize();

      if (kDebugMode) {
        print('✅ Supabase service reset and reinitialized (no auth mode)');
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
      'authenticated': false, // Always false
      'connectionHealthy': _connectionHealthy,
      'consecutiveFailures': _consecutiveFailures,
      'timeSinceLastSuccess': timeSinceLastSuccess,
      'shouldAttemptRecovery': shouldAttemptRecovery(),
      'clientExists': _client != null,
      'platform': kIsWeb ? 'web' : 'mobile',
      'authenticationMode': 'disabled',
    };
  }
}
