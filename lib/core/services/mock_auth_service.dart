import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Mock Authentication Service that provides automatic authentication for instant app access
class MockAuthService {
  static MockAuthService? _instance;
  static MockAuthService get instance =>
      _instance ??= MockAuthService._internal();

  MockAuthService._internal();

  // Mock user data storage - always authenticated for instant access
  String? _mockUserId;
  String? _mockUserEmail;
  bool _isAuthenticated = true; // Default to authenticated for instant access
  final Uuid _uuid = const Uuid();

  /// Initialize with automatic authentication for instant access
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mockUserId = prefs.getString('mock_user_id');
      _mockUserEmail = prefs.getString('mock_user_email');
      _isAuthenticated = true; // Always authenticated for instant access

      // Create default user if none exists
      if (_mockUserId == null) {
        final userId = _uuid.v4();
        _mockUserId = userId;
        _mockUserEmail = 'instant_user@cryptotracker.app';
        await prefs.setString('mock_user_id', userId);
        await prefs.setString('mock_user_email', _mockUserEmail!);
        await prefs.setBool('mock_is_authenticated', true);
      }

      if (kDebugMode) {
        print('✅ Mock Auth initialized - Instant Access Mode');
        print('   User ID: $_mockUserId');
        print('   Email: $_mockUserEmail');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Mock Auth initialization failed: $e');
      }
      // Set default values for instant access
      _mockUserId = _uuid.v4();
      _mockUserEmail = 'instant_user@cryptotracker.app';
      _isAuthenticated = true;
    }
  }

  /// Mock sign in with email and password - auto-succeeds for instant access
  Future<MockUser?> signInWithEmail(String email, String password) async {
    try {
      if (kDebugMode) {
        print('🔄 Mock sign in with email: $email (auto-success)');
      }

      // Generate/use existing mock user
      final userId = _mockUserId ?? _uuid.v4();
      final user = MockUser(
        id: userId,
        email: email.isNotEmpty ? email : 'instant_user@cryptotracker.app',
        createdAt: DateTime.now(),
      );

      // Store auth state
      await _setAuthState(userId, user.email!);

      if (kDebugMode) {
        print('✅ Mock sign in successful (instant access)');
      }

      return user;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Mock sign in failed: $e');
      }
      rethrow;
    }
  }

  /// Mock sign up with email and password - auto-succeeds for instant access
  Future<MockUser?> signUpWithEmail(String email, String password) async {
    try {
      if (kDebugMode) {
        print('🔄 Mock sign up with email: $email (auto-success)');
      }

      // Generate mock user
      final userId = _mockUserId ?? _uuid.v4();
      final user = MockUser(
        id: userId,
        email: email.isNotEmpty ? email : 'instant_user@cryptotracker.app',
        createdAt: DateTime.now(),
      );

      // Store auth state
      await _setAuthState(userId, user.email!);

      if (kDebugMode) {
        print('✅ Mock sign up successful (instant access)');
      }

      return user;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Mock sign up failed: $e');
      }
      rethrow;
    }
  }

  /// Mock anonymous sign in - provides instant access
  Future<MockUser?> signInAnonymously() async {
    try {
      if (kDebugMode) {
        print('🔄 Mock anonymous sign in (instant access)');
      }

      final userId = _mockUserId ?? _uuid.v4();
      final user = MockUser(
        id: userId,
        email: null,
        createdAt: DateTime.now(),
        isAnonymous: true,
      );

      // Store auth state
      await _setAuthState(userId, null);

      if (kDebugMode) {
        print('✅ Mock anonymous sign in successful (instant access)');
      }

      return user;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Mock anonymous sign in failed: $e');
      }
      rethrow;
    }
  }

  /// Mock sign out - maintains instant access
  Future<void> signOut() async {
    try {
      if (kDebugMode) {
        print('🔄 Mock sign out (maintaining instant access)');
      }

      // Don't actually sign out to maintain instant access
      // Just log the action for debugging

      if (kDebugMode) {
        print(
            '✅ Mock sign out successful (user remains authenticated for instant access)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Mock sign out failed: $e');
      }
      rethrow;
    }
  }

  /// Always authenticated for instant access
  bool get isAuthenticated => true;

  /// Get current user - always returns a user for instant access
  MockUser? get currentUser {
    final userId = _mockUserId ?? _uuid.v4();

    return MockUser(
      id: userId,
      email: _mockUserEmail ?? 'instant_user@cryptotracker.app',
      createdAt: DateTime.now(),
      isAnonymous: _mockUserEmail == null,
    );
  }

  /// Get current user ID - always returns an ID for instant access
  String? get currentUserId => _mockUserId ?? _uuid.v4();

  /// Store authentication state locally
  Future<void> _setAuthState(String userId, String? email) async {
    _mockUserId = userId;
    _mockUserEmail = email;
    _isAuthenticated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mock_user_id', userId);
      if (email != null) {
        await prefs.setString('mock_user_email', email);
      } else {
        await prefs.remove('mock_user_email');
      }
      await prefs.setBool('mock_is_authenticated', true);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to save auth state: $e');
      }
    }
  }

  /// Get auth status for debugging - always shows authenticated
  Map<String, dynamic> getAuthStatus() {
    return {
      'isAuthenticated': true,
      'userId': _mockUserId ?? 'instant_user_id',
      'userEmail': _mockUserEmail ?? 'instant_user@cryptotracker.app',
      'isAnonymous': _mockUserEmail == null,
      'service': 'MockAuthService (Instant Access)',
      'mode': 'instant_access',
    };
  }
}

/// Mock User class to replace Supabase User
class MockUser {
  final String id;
  final String? email;
  final DateTime createdAt;
  final bool isAnonymous;

  MockUser({
    required this.id,
    this.email,
    required this.createdAt,
    this.isAnonymous = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'is_anonymous': isAnonymous,
    };
  }

  @override
  String toString() {
    return 'MockUser{id: $id, email: $email, isAnonymous: $isAnonymous}';
  }
}
