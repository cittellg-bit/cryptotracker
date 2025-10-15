import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './logging_service.dart';

/// Service for handling no-authentication mode with Supabase
/// Following Supabase support's recommendation to disable authentication
class AnonymousAuthService {
  static final AnonymousAuthService _instance =
      AnonymousAuthService._internal();
  static AnonymousAuthService get instance => _instance;
  AnonymousAuthService._internal();

  final _logger = Logger();
  final LoggingService _loggingService = LoggingService.instance;

  // Local user tracking (since authentication is disabled)
  String? _localUserId;
  static const String _localUserIdKey = 'crypto_tracker_no_auth_user_id';

  /// Get current Supabase client
  SupabaseClient get _client => Supabase.instance.client;

  /// Check if currently in no-authentication mode (always true)
  bool get isLocalOnlyMode => true;

  /// Get local user ID when in no-authentication mode
  String? get localUserId => _localUserId;

  /// Initialize authentication service in no-auth mode
  Future<void> initialize() async {
    // Clear any existing authentication data
    await _clearAuthenticationData();

    final prefs = await SharedPreferences.getInstance();
    _localUserId = prefs.getString(_localUserIdKey);

    // Generate local user ID if not exists
    if (_localUserId == null) {
      _localUserId = 'no_auth_user_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_localUserIdKey, _localUserId!);
    }

    await _loggingService.logInfo(
      category: LogCategory.authentication,
      message: 'Initialized in no-authentication mode',
      functionName: 'initialize',
      details: {
        'local_user_id': _localUserId,
        'mode': 'no_authentication',
        'authentication_disabled': true,
      },
    );
  }

  /// Clear authentication data as per Supabase support recommendation
  Future<void> _clearAuthenticationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear authentication tokens (equivalent to localStorage.removeItem)
      await prefs.remove('supabase.auth.token');

      // Clear any other auth-related data
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.contains('auth') ||
            key.contains('session') ||
            key.contains('token')) {
          await prefs.remove(key);
        }
      }

      await _loggingService.logInfo(
        category: LogCategory.authentication,
        message: 'Cleared authentication data as per Supabase support',
        functionName: '_clearAuthenticationData',
        details: {'cleared_keys_count': keys.length},
      );
    } catch (e) {
      await _loggingService.logWarning(
        category: LogCategory.authentication,
        message: 'Could not clear authentication data',
        functionName: '_clearAuthenticationData',
        details: {'error': e.toString()},
      );
    }
  }

  /// Sign in anonymously using Supabase authentication
  Future<User?> signInAnonymously() async {
    try {
      await _loggingService.logInfo(
        category: LogCategory.authentication,
        message: 'Signing in anonymously with Supabase',
        functionName: 'signInAnonymously',
        details: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final response = await _client.auth.signInAnonymously();

      if (response.user != null) {
        await _loggingService.logInfo(
          category: LogCategory.authentication,
          message: 'Anonymous sign in successful',
          functionName: 'signInAnonymously',
          details: {
            'user_id': response.user!.id,
            'is_anonymous': response.user!.isAnonymous,
          },
        );
      }

      return response.user;
    } catch (e) {
      await _loggingService.logError(
        category: LogCategory.authentication,
        message: 'Failed to sign in anonymously',
        functionName: 'signInAnonymously',
        details: {'error': e.toString()},
      );

      // Fallback: ensure we have a local user ID
      if (_localUserId == null) {
        await initialize();
      }

      return null;
    }
  }

  /// Check if current user is anonymous
  bool isAnonymousUser() {
    try {
      final user = _client.auth.currentUser;
      final isAnonymous = user == null || user.isAnonymous;

      _loggingService.logDebug(
        category: LogCategory.authentication,
        message: 'Checking if user is anonymous',
        functionName: 'isAnonymousUser',
        details: {'user_id': user?.id, 'is_anonymous': isAnonymous},
      );

      return isAnonymous;
    } catch (e) {
      _loggingService.logDebug(
        category: LogCategory.authentication,
        message: 'Error checking anonymous status, defaulting to true',
        functionName: 'isAnonymousUser',
        details: {'error': e.toString()},
      );
      return true;
    }
  }

  /// Get current user
  User? getCurrentUser() {
    try {
      final user = _client.auth.currentUser;

      _loggingService.logDebug(
        category: LogCategory.authentication,
        message: 'Getting current user',
        functionName: 'getCurrentUser',
        details: {'user_id': user?.id, 'email': user?.email},
      );

      return user;
    } catch (e) {
      _loggingService.logDebug(
        category: LogCategory.authentication,
        message: 'Error getting current user',
        functionName: 'getCurrentUser',
        details: {'error': e.toString()},
      );
      return null;
    }
  }

  /// Get effective user ID (Supabase user ID or local fallback)
  String? getEffectiveUserId() {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        return user.id;
      }
    } catch (e) {
      // Fallback to local user ID if Supabase is not available
    }
    return _localUserId;
  }

  /// Check if user is signed in
  bool isSignedIn() {
    try {
      final user = _client.auth.currentUser;
      return user != null;
    } catch (e) {
      // Fallback to local tracking if Supabase is not available
      return _localUserId != null;
    }
  }

  /// Check if database operations are available (true but without auth)
  bool isDatabaseAvailable() {
    return true; // Database is available for public operations
  }

  /// Get user display name for UI
  String getUserDisplayName() {
    return 'Local User (No Authentication)';
  }

  /// Convert to permanent user using Supabase authentication
  Future<bool> convertToPermanentUser(String email, String password) async {
    try {
      await _loggingService.logInfo(
        category: LogCategory.authentication,
        message: 'Converting anonymous user to permanent account',
        functionName: 'convertToPermanentUser',
        details: {'email': email},
      );

      final user = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (user.user != null) {
        await _loggingService.logInfo(
          category: LogCategory.authentication,
          message: 'Successfully converted to permanent account',
          functionName: 'convertToPermanentUser',
          details: {'user_id': user.user!.id, 'email': email},
        );
        return true;
      }

      return false;
    } catch (e) {
      await _loggingService.logError(
        category: LogCategory.authentication,
        message: 'Failed to convert to permanent account',
        functionName: 'convertToPermanentUser',
        details: {'error': e.toString(), 'email': email},
      );
      return false;
    }
  }

  /// Sign out using Supabase authentication
  Future<bool> signOut() async {
    try {
      await _loggingService.logInfo(
        category: LogCategory.authentication,
        message: 'Signing out user',
        functionName: 'signOut',
        details: {'user_id': _client.auth.currentUser?.id},
      );

      await _client.auth.signOut();

      await _loggingService.logInfo(
        category: LogCategory.authentication,
        message: 'Sign out successful',
        functionName: 'signOut',
        details: {},
      );

      return true;
    } catch (e) {
      await _loggingService.logError(
        category: LogCategory.authentication,
        message: 'Failed to sign out',
        functionName: 'signOut',
        details: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Cannot cleanup data in no-auth mode
  Future<void> cleanupAnonymousData() async {
    await _loggingService.logWarning(
      category: LogCategory.authentication,
      message: 'Cannot cleanup data - authentication disabled',
      functionName: 'cleanupAnonymousData',
      details: {'mode': 'no_authentication_limitation'},
    );
  }

  /// Get authentication state stream
  Stream<AuthState> get authStateStream => _client.auth.onAuthStateChange;

  /// Create permanent account using Supabase authentication
  Future<User?> createPermanentAccount(String email, String password) async {
    try {
      await _loggingService.logInfo(
        category: LogCategory.authentication,
        message: 'Creating permanent account with Supabase',
        functionName: 'createPermanentAccount',
        details: {'email': email},
      );

      final user = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (user.user != null) {
        await _loggingService.logInfo(
          category: LogCategory.authentication,
          message: 'Permanent account created successfully',
          functionName: 'createPermanentAccount',
          details: {'user_id': user.user!.id, 'email': email},
        );
      }

      return user.user;
    } catch (e) {
      await _loggingService.logError(
        category: LogCategory.authentication,
        message: 'Failed to create permanent account',
        functionName: 'createPermanentAccount',
        details: {'error': e.toString(), 'email': email},
      );
      rethrow;
    }
  }

  /// Sign in with email using Supabase authentication
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      await _loggingService.logInfo(
        category: LogCategory.authentication,
        message: 'Signing in with email using Supabase',
        functionName: 'signInWithEmail',
        details: {'email': email},
      );

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loggingService.logInfo(
          category: LogCategory.authentication,
          message: 'Sign in successful',
          functionName: 'signInWithEmail',
          details: {'user_id': response.user!.id, 'email': email},
        );
      }

      return response.user;
    } catch (e) {
      await _loggingService.logError(
        category: LogCategory.authentication,
        message: 'Failed to sign in with email',
        functionName: 'signInWithEmail',
        details: {'error': e.toString(), 'email': email},
      );
      rethrow;
    }
  }
}
