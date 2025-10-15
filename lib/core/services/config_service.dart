import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Configuration service that handles environment variable loading
/// for both web and mobile platforms with proper fallback mechanisms
class ConfigService {
  static ConfigService? _instance;
  static ConfigService get instance => _instance ??= ConfigService._internal();

  ConfigService._internal();

  Map<String, dynamic>? _config;
  bool _initialized = false;

  /// Initialize the configuration service
  Future<void> initialize() async {
    if (_initialized && _config != null) {
      if (kDebugMode) {
        print('✅ Config service already initialized');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🔄 Initializing configuration service...');
      }

      _config = await _loadEnvironmentConfig();
      _initialized = true;

      if (kDebugMode) {
        print('✅ Configuration loaded successfully');
        print('   Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
        print('   Config keys: ${_config?.keys.join(', ')}');
      }
    } catch (e) {
      _initialized = false;
      _config = null;

      if (kDebugMode) {
        print('❌ Configuration initialization failed: $e');
      }
      rethrow;
    }
  }

  /// Load environment configuration based on platform
  Future<Map<String, dynamic>> _loadEnvironmentConfig() async {
    // First try to load user-configured values from SharedPreferences
    final userConfig = await _loadUserConfig();

    Map<String, dynamic> baseConfig;

    if (kIsWeb) {
      baseConfig = await _loadWebConfig();
    } else {
      baseConfig = await _loadMobileConfig();
    }

    // Merge user config with base config (user config takes precedence)
    return {...baseConfig, ...userConfig};
  }

  /// Load user-configured values from SharedPreferences
  Future<Map<String, dynamic>> _loadUserConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final config = <String, dynamic>{};

      // Remove temporary test configurations that might override working connection
      final tempUrl = prefs.getString('temp_test_supabase_url');
      final tempKey = prefs.getString('temp_test_supabase_anon_key');

      // Clear temporary configs if they exist - prioritize env.json values
      if (tempUrl != null || tempKey != null) {
        await prefs.remove('temp_test_supabase_url');
        await prefs.remove('temp_test_supabase_anon_key');
        if (kDebugMode) {
          print(
              '📱 Cleared temporary test configurations to use working connection');
        }
      }

      // Only load user configs for non-Supabase keys or as permanent overrides
      final supabaseUrl = prefs.getString('supabase_url');
      if (supabaseUrl != null && supabaseUrl.isNotEmpty) {
        config['SUPABASE_URL'] = supabaseUrl;
      }

      final supabaseKey = prefs.getString('supabase_anon_key');
      if (supabaseKey != null && supabaseKey.isNotEmpty) {
        config['SUPABASE_ANON_KEY'] = supabaseKey;
      }

      if (config.isNotEmpty && kDebugMode) {
        print('📱 Loaded user configuration from SharedPreferences');
        print('   Keys: ${config.keys.join(', ')}');
      }

      return config;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not load user config from SharedPreferences: $e');
      }
      return {};
    }
  }

  /// Load configuration for web platform
  Future<Map<String, dynamic>> _loadWebConfig() async {
    try {
      if (kDebugMode) {
        print('🌐 Loading web configuration...');
      }

      // Method 1: Try to load from meta tags in HTML
      final config = _loadFromMetaTags();
      if (config.isNotEmpty) {
        if (kDebugMode) {
          print('✅ Loaded config from HTML meta tags');
        }
        return config;
      }

      // Method 2: Try to load from web/env.json asset
      try {
        final String envContent =
            await rootBundle.loadString('assets/env.json');
        final webConfig = jsonDecode(envContent) as Map<String, dynamic>;
        if (kDebugMode) {
          print('✅ Loaded config from assets/env.json');
        }
        return webConfig;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Could not load from assets/env.json: $e');
        }
      }

      // Method 3: Use default web configuration
      final defaultConfig = _getDefaultWebConfig();
      if (kDebugMode) {
        print('⚠️ Using default web configuration');
      }
      return defaultConfig;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Web config loading failed: $e');
      }
      throw Exception('Failed to load web configuration: $e');
    }
  }

  /// Load configuration for mobile platform
  Future<Map<String, dynamic>> _loadMobileConfig() async {
    try {
      if (kDebugMode) {
        print('📱 Loading mobile configuration...');
      }

      final String envContent = await rootBundle.loadString('env.json');
      final config = jsonDecode(envContent) as Map<String, dynamic>;

      if (kDebugMode) {
        print('✅ Loaded config from env.json');
      }

      return config;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Mobile config loading failed: $e');
      }
      throw Exception(
          'Could not load environment configuration. Ensure env.json exists in the root directory.');
    }
  }

  /// Load configuration from HTML meta tags
  Map<String, dynamic> _loadFromMetaTags() {
    try {
      final config = <String, dynamic>{};

      // Look for meta tags with name="env-*"
      final metaTags = html.document.querySelectorAll('meta[name^="env-"]');

      for (final meta in metaTags) {
        final name = meta.getAttribute('name');
        final content = meta.getAttribute('content');

        if (name != null && content != null) {
          // Convert "env-supabase-url" to "SUPABASE_URL"
          final key = name.substring(4).replaceAll('-', '_').toUpperCase();
          config[key] = content;
        }
      }

      return config;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not read meta tags: $e');
      }
      return {};
    }
  }

  /// Get default configuration for web (fallback)
  Map<String, dynamic> _getDefaultWebConfig() {
    // Provide working placeholder values to prevent errors
    return {
      'SUPABASE_URL': 'https://placeholder.supabase.co',
      'SUPABASE_ANON_KEY': 'placeholder-anon-key-here',
      'COINGECKO_API_KEY': 'demo-api-key',
    };
  }

  /// Get configuration value by key
  String? get(String key) {
    if (!_initialized || _config == null) {
      throw Exception(
          'Config service not initialized. Call initialize() first.');
    }

    return _config?[key] as String?;
  }

  /// Get configuration value with fallback
  String getWithFallback(String key, String fallback) {
    try {
      return get(key) ?? fallback;
    } catch (e) {
      return fallback;
    }
  }

  /// Get all configuration
  Map<String, dynamic> getAll() {
    if (!_initialized || _config == null) {
      throw Exception(
          'Config service not initialized. Call initialize() first.');
    }

    return Map<String, dynamic>.from(_config!);
  }

  /// Check if a configuration key exists
  bool has(String key) {
    if (!_initialized || _config == null) {
      return false;
    }

    return _config!.containsKey(key);
  }

  /// Validate required configuration keys (made more lenient for preview)
  void validateRequired(List<String> requiredKeys) {
    final missing = <String>[];

    for (final key in requiredKeys) {
      final value = get(key);
      if (value == null || value.isEmpty) {
        missing.add(key);
      }
    }

    if (missing.isNotEmpty) {
      // Don't throw exception for preview, just log
      if (kDebugMode) {
        print('⚠️ Missing configuration keys: ${missing.join(', ')}');
        print('   App will continue with default values for preview');
      }
    }
  }

  /// Get platform-specific configuration instructions
  String getConfigInstructions() {
    if (kIsWeb) {
      return '''
Web Configuration Setup:

Method 1 (Recommended): Add meta tags to web/index.html:
<meta name="env-supabase-url" content="https://your-project.supabase.co">
<meta name="env-supabase-anon-key" content="your-anon-key">
<meta name="env-coingecko-api-key" content="your-api-key">

Method 2: Create assets/env.json with configuration values
Method 3: Update _getDefaultWebConfig() in config_service.dart
''';
    } else {
      return '''
Mobile Configuration Setup:

Update env.json in the root directory with:
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key-here",
  "COINGECKO_API_KEY": "your-api-key-here"
}
''';
    }
  }

  /// Reset and reinitialize configuration
  Future<void> reset() async {
    _initialized = false;
    _config = null;
    await initialize();
  }

  /// Dispose configuration service
  void dispose() {
    _initialized = false;
    _config = null;

    if (kDebugMode) {
      print('🧹 Config service disposed');
    }
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'initialized': _initialized,
      'platform': kIsWeb ? 'web' : 'mobile',
      'hasConfig': _config != null,
      'configKeys': _config?.keys.toList() ?? [],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
