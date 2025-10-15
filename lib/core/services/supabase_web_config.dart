import 'package:flutter/foundation.dart';
// Use universal_html instead of dart:html for WASM compatibility
import 'package:universal_html/html.dart' as html;

/// Web-specific Supabase configuration service that bypasses index.html requirements
/// Now WASM-compatible by removing dart:js dependencies
class SupabaseWebConfig {
  static SupabaseWebConfig? _instance;
  static SupabaseWebConfig get instance =>
      _instance ??= SupabaseWebConfig._internal();

  SupabaseWebConfig._internal();

  bool _configured = false;

  /// Configure Supabase for web without requiring index.html meta tags
  /// WASM-compatible implementation
  Future<void> configureWebSupabase({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    // Only run on web platform
    if (!kIsWeb) {
      if (kDebugMode) {
        print('✅ Supabase mobile configuration - no web setup needed');
      }
      return;
    }

    try {
      // Method 1: Inject configuration using universal_html
      _injectSupabaseConfig(supabaseUrl, supabaseAnonKey);

      // Method 2: Configure localStorage and session storage
      await _configureWebStorage();

      // Method 3: Set up meta tags programmatically
      await _setupWebMetaTags();

      _configured = true;

      if (kDebugMode) {
        print(
            '✅ Supabase web configuration injected successfully (WASM compatible)');
        print('   URL: ${supabaseUrl.substring(0, 30)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Web configuration failed: $e');
      }
      rethrow;
    }
  }

  /// Inject Supabase configuration using WASM-compatible universal_html
  void _injectSupabaseConfig(String url, String key) {
    // Only execute on web platform
    if (!kIsWeb) return;

    try {
      // Use universal_html instead of dart:js for WASM compatibility
      if (kIsWeb) {
        _setWebConfiguration(url, key);
      }

      if (kDebugMode) {
        print('✅ Supabase config injected using universal_html');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to inject config: $e');
      }
    }
  }

  /// WASM-compatible web configuration using universal_html
  void _setWebConfiguration(String url, String key) {
    if (kIsWeb) {
      try {
        // Create script element to inject configuration
        final script = html.ScriptElement();
        script.type = 'text/javascript';
        script.text = '''
          window.supabaseConfig = {
            url: "$url",
            key: "$key",
            options: {
              auth: {
                flowType: "pkce",
                detectSessionInUri: false,
                persistSession: true,
                autoRefreshToken: true,
                storage: "localStorage"
              },
              global: {
                headers: {
                  "X-Client-Info": "supabase-flutter"
                }
              },
              realtime: {
                params: {
                  eventsPerSecond: 2
                }
              }
            }
          };

          window.supabaseAuthConfig = {
            redirectTo: window.location.origin + "/auth/callback",
            flowType: "pkce",
            provider: "anonymous"
          };
        ''';

        html.document.head?.append(script);

        // Also store in localStorage as backup
        html.window.localStorage['supabase_config'] =
            '{"url":"$url","key":"$key"}';
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Web config injection error: $e');
        }
      }
    }
  }

  /// Configure web storage using universal_html
  Future<void> _configureWebStorage() async {
    if (!kIsWeb) return;

    try {
      // Set up localStorage with Supabase configuration
      html.window.localStorage['supabase.auth.token.storage'] = 'localStorage';
      html.window.localStorage['supabase.auth.debug'] = kDebugMode.toString();

      // Set up session storage for temporary auth data
      html.window.sessionStorage['supabase.session.active'] = 'true';

      if (kDebugMode) {
        print('✅ Web storage configuration set (WASM compatible)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Web storage config warning: $e');
      }
    }
  }

  /// Set up meta tags programmatically for better web integration
  Future<void> _setupWebMetaTags() async {
    if (!kIsWeb) return;

    try {
      // Add viewport meta tag if not exists
      if (html.document.querySelector('meta[name="viewport"]') == null) {
        final viewport = html.MetaElement();
        viewport.name = 'viewport';
        viewport.content =
            'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        html.document.head?.append(viewport);
      }

      // Add charset meta tag if not exists
      if (html.document.querySelector('meta[charset]') == null) {
        final charset = html.MetaElement();
        charset.setAttribute('charset', 'UTF-8');
        html.document.head
            ?.insertBefore(charset, html.document.head?.firstChild);
      }

      // Add theme-color for better PWA support
      if (html.document.querySelector('meta[name="theme-color"]') == null) {
        final themeColor = html.MetaElement();
        themeColor.name = 'theme-color';
        themeColor.content = '#1976D2';
        html.document.head?.append(themeColor);
      }

      if (kDebugMode) {
        print('✅ Web meta tags configured');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Meta tags setup warning: $e');
      }
    }
  }

  /// Get current origin safely using universal_html
  String _getCurrentOrigin() {
    if (kIsWeb) {
      try {
        return html.window.location.origin ?? 'http://localhost';
      } catch (e) {
        return 'http://localhost';
      }
    }
    return 'http://localhost';
  }

  /// Check if web configuration is properly set up
  bool get isConfigured => _configured && kIsWeb;

  /// Get current web configuration status using WASM-compatible methods
  Map<String, dynamic> getWebConfigStatus() {
    if (!kIsWeb) {
      return {'platform': 'mobile', 'webConfigRequired': false};
    }

    try {
      return {
        'platform': 'web',
        'configured': _configured,
        'hasSupabaseConfig': _hasLocalStorageItem('supabase_config'),
        'hasAuthConfig': _hasScriptElement('supabaseAuthConfig'),
        'hasLocalStorage': _hasLocalStorage(),
        'hasServiceWorker': _hasServiceWorker(),
        'userAgent': _getUserAgent(),
        'wasmCompatible': true,
      };
    } catch (e) {
      return {
        'platform': 'web',
        'configured': false,
        'error': e.toString(),
        'wasmCompatible': true,
      };
    }
  }

  /// Check if localStorage item exists
  bool _hasLocalStorageItem(String key) {
    if (kIsWeb) {
      try {
        return html.window.localStorage.containsKey(key);
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Check if script element with specific window property exists
  bool _hasScriptElement(String windowProperty) {
    if (kIsWeb) {
      try {
        final scripts = html.document.querySelectorAll('script');
        for (final script in scripts) {
          if (script.text?.contains(windowProperty) == true) {
            return true;
          }
        }
        return false;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Check if localStorage is available
  bool _hasLocalStorage() {
    if (kIsWeb) {
      try {
        html.window.localStorage['test'] = 'test';
        html.window.localStorage.remove('test');
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Check if service worker is available
  bool _hasServiceWorker() {
    if (kIsWeb) {
      try {
        return html.window.navigator.serviceWorker != null;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Get user agent safely using universal_html
  String _getUserAgent() {
    if (kIsWeb) {
      try {
        return html.window.navigator.userAgent;
      } catch (e) {
        return 'unknown';
      }
    }
    return 'mobile';
  }

  /// Reset web configuration using WASM-compatible methods
  void reset() {
    try {
      if (kIsWeb) {
        // Remove localStorage items
        html.window.localStorage.remove('supabase_config');
        html.window.localStorage.remove('supabase.auth.token.storage');
        html.window.localStorage.remove('supabase.auth.debug');

        // Remove session storage items
        html.window.sessionStorage.remove('supabase.session.active');

        // Remove injected script elements
        final scripts = html.document.querySelectorAll('script');
        for (final script in scripts) {
          if (script.text?.contains('supabaseConfig') == true) {
            script.remove();
          }
        }
      }
      _configured = false;

      if (kDebugMode) {
        print('✅ Web configuration reset (WASM compatible)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Reset error: $e');
      }
    }
  }

  /// Create a service worker configuration for offline support
  void setupServiceWorkerConfig() {
    if (!kIsWeb) return;

    try {
      if (_hasServiceWorker()) {
        final script = html.ScriptElement();
        script.type = 'text/javascript';
        script.text = '''
          if ('serviceWorker' in navigator) {
            navigator.serviceWorker.register('/flutter_service_worker.js')
              .then((registration) => {
                console.log('SW registered: ', registration);
              })
              .catch((registrationError) => {
                console.log('SW registration failed: ', registrationError);
              });
          }
        ''';

        html.document.head?.append(script);

        if (kDebugMode) {
          print('✅ Service worker configuration added');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Service worker setup warning: $e');
      }
    }
  }
}
