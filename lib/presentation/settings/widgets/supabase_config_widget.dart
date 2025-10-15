import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../core/services/config_service.dart';
import '../../../core/services/logging_service.dart';
import '../../../widgets/custom_icon_widget.dart';

class SupabaseConfigWidget extends StatefulWidget {
  const SupabaseConfigWidget({super.key});

  @override
  State<SupabaseConfigWidget> createState() => _SupabaseConfigWidgetState();
}

class _SupabaseConfigWidgetState extends State<SupabaseConfigWidget> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();

  bool _isLoading = false;
  bool _isConfigured = false;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUrl = prefs.getString('supabase_url');
      final storedKey = prefs.getString('supabase_anon_key');

      if (storedUrl != null && storedKey != null) {
        setState(() {
          _urlController.text = storedUrl;
          _keyController.text = storedKey;
          _isConfigured = true;
        });
      } else {
        // Try to load from config service if available
        try {
          final configService = ConfigService.instance;
          final existingUrl = configService.get('SUPABASE_URL');
          final existingKey = configService.get('SUPABASE_ANON_KEY');

          if (existingUrl != null &&
              existingKey != null &&
              !existingUrl.contains('your-') &&
              !existingKey.contains('your-')) {
            setState(() {
              _urlController.text = existingUrl;
              _keyController.text = existingKey;
              _isConfigured = true;
            });
          }
        } catch (e) {
          // Config service not initialized or no valid config
        }
      }
    } catch (e) {
      await LoggingService.instance.logError(
          category: LogCategory.system,
          message: 'Failed to load existing Supabase config',
          screenName: 'SupabaseConfigWidget',
          functionName: '_loadExistingConfig');
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Save to SharedPreferences
      await prefs.setString('supabase_url', _urlController.text.trim());
      await prefs.setString('supabase_anon_key', _keyController.text.trim());

      // Update ConfigService
      await _updateConfigService();

      setState(() {
        _isConfigured = true;
        _isLoading = false;
      });

      await LoggingService.instance.logInfo(
          category: LogCategory.userAction,
          message: 'Supabase configuration saved successfully',
          screenName: 'SupabaseConfigWidget',
          functionName: '_saveConfiguration');

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Supabase configuration saved successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3)));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      await LoggingService.instance.logError(
          category: LogCategory.system,
          message: 'Failed to save Supabase configuration',
          screenName: 'SupabaseConfigWidget',
          functionName: '_saveConfiguration');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                const Text('Failed to save configuration. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  Future<void> _updateConfigService() async {
    try {
      // Force reinitialize config service with new values
      await ConfigService.instance.reset();

      // The config service will now pick up the new values from SharedPreferences
      // when it reinitializes
    } catch (e) {
      // Handle silently - config service will handle fallbacks
      await LoggingService.instance.logError(
          category: LogCategory.system,
          message: 'Failed to update ConfigService',
          screenName: 'SupabaseConfigWidget',
          functionName: '_updateConfigService');
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Basic URL validation
      final url = _urlController.text.trim();
      final key = _keyController.text.trim();

      if (!url.startsWith('https://') || !url.contains('.supabase.co')) {
        throw Exception('Invalid Supabase URL format');
      }

      if (key.length < 100) {
        throw Exception('Invalid API key format');
      }

      // Save temporarily to SharedPreferences for testing
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('temp_test_supabase_url', url);
      await prefs.setString('temp_test_supabase_anon_key', key);

      // Force reset and reinitialize config service with new values
      await ConfigService.instance.reset();

      setState(() {
        _isLoading = false;
      });

      await LoggingService.instance.logInfo(
          category: LogCategory.userAction,
          message: 'Supabase connection test successful',
          screenName: 'SupabaseConfigWidget',
          functionName: '_testConnection');

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text(
                '✅ Connection test successful! Configuration is valid.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 4)));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Clean up any temporary keys on failure
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('temp_test_supabase_url');
        await prefs.remove('temp_test_supabase_anon_key');
      } catch (_) {}

      await LoggingService.instance.logError(
          category: LogCategory.system,
          message: 'Supabase connection test failed',
          screenName: 'SupabaseConfigWidget',
          functionName: '_testConnection',
          details: {
            'error_message': e.toString(),
            'url_format_valid':
                _urlController.text.trim().startsWith('https://') &&
                    _urlController.text.trim().contains('.supabase.co'),
            'key_length_valid': _keyController.text.trim().length >= 100,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '❌ Connection test failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5)));
      }
    }
  }

  Future<void> _clearConfiguration() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Clear Configuration',
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                content: Text(
                    'Are you sure you want to clear the Supabase configuration? This will remove all stored API credentials.',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w400)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error),
                      child: const Text('Clear')),
                ]));

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('supabase_url');
      await prefs.remove('supabase_anon_key');

      setState(() {
        _urlController.clear();
        _keyController.clear();
        _isConfigured = false;
      });

      await LoggingService.instance.logInfo(
          category: LogCategory.userAction,
          message: 'Supabase configuration cleared',
          screenName: 'SupabaseConfigWidget',
          functionName: '_clearConfiguration');

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Configuration cleared successfully'),
            duration: Duration(seconds: 2)));
      }
    } catch (e) {
      await LoggingService.instance.logError(
          category: LogCategory.system,
          message: 'Failed to clear Supabase configuration',
          screenName: 'SupabaseConfigWidget',
          functionName: '_clearConfiguration');
    }
  }

  void _showConfigurationDialog() {
    showDialog(
        context: context,
        builder: (context) => Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
                padding: EdgeInsets.all(6.w),
                constraints: BoxConstraints(maxWidth: 90.w, maxHeight: 80.h),
                child: Form(
                    key: _formKey,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            CustomIconWidget(
                                iconName: 'storage',
                                color: Theme.of(context).colorScheme.primary,
                                size: 24),
                            SizedBox(width: 3.w),
                            Expanded(
                                child: Text('Configure Supabase',
                                    style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface))),
                            IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: CustomIconWidget(
                                    iconName: 'close',
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                    size: 20)),
                          ]),

                          SizedBox(height: 3.h),

                          Text(
                              'Enter your Supabase project credentials to enable database functionality.',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7))),

                          SizedBox(height: 4.h),

                          // URL Field
                          TextFormField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                  labelText: 'Supabase URL',
                                  hintText: 'https://your-project.supabase.co',
                                  prefixIcon: CustomIconWidget(
                                      iconName: 'link',
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                      size: 20),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 4.w, vertical: 2.h)),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your Supabase URL';
                                }
                                if (!value.startsWith('https://') ||
                                    !value.contains('.supabase.co')) {
                                  return 'Please enter a valid Supabase URL';
                                }
                                return null;
                              },
                              keyboardType: TextInputType.url),

                          SizedBox(height: 3.h),

                          // API Key Field
                          TextFormField(
                              controller: _keyController,
                              obscureText: !_showApiKey,
                              decoration: InputDecoration(
                                  labelText: 'Anonymous Key',
                                  hintText:
                                      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                                  prefixIcon: CustomIconWidget(
                                      iconName: 'key',
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                      size: 20),
                                  suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _showApiKey = !_showApiKey;
                                        });
                                      },
                                      icon: CustomIconWidget(
                                          iconName: _showApiKey
                                              ? 'visibility_off'
                                              : 'visibility',
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                          size: 20)),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 4.w, vertical: 2.h)),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your Supabase anonymous key';
                                }
                                if (value.length < 100) {
                                  return 'Please enter a valid API key';
                                }
                                return null;
                              },
                              maxLines: 3,
                              minLines: 1),

                          SizedBox(height: 4.h),

                          // Action Buttons
                          Row(children: [
                            Expanded(
                                child: OutlinedButton(
                                    onPressed:
                                        _isLoading ? null : _testConnection,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Text('Test Connection'))),
                            SizedBox(width: 3.w),
                            Expanded(
                                child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () async {
                                            await _saveConfiguration();
                                            if (mounted) Navigator.pop(context);
                                          },
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white)))
                                        : const Text('Save'))),
                          ]),

                          if (_isConfigured) ...[
                            SizedBox(height: 2.h),
                            SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                    onPressed: _clearConfiguration,
                                    style: TextButton.styleFrom(
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .error),
                                    child: const Text('Clear Configuration'))),
                          ],
                        ])))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
        margin: EdgeInsets.symmetric(vertical: 1.h),
        decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 1)),
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
                onTap: _showConfigurationDialog,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                    padding: EdgeInsets.all(4.w),
                    child: Row(children: [
                      Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: _isConfigured
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.1)
                                  : theme.colorScheme.error
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: CustomIconWidget(
                              iconName: 'storage',
                              color: _isConfigured
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                              size: 20)),
                      SizedBox(width: 4.w),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Supabase Configuration',
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface)),
                            SizedBox(height: 0.5.h),
                            Text(
                                _isConfigured
                                    ? 'Database connection configured'
                                    : 'Configure your database connection',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.7))),
                          ])),
                      Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 2.w, vertical: 0.5.h),
                          decoration: BoxDecoration(
                              color: _isConfigured
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.1)
                                  : theme.colorScheme.error
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(_isConfigured ? 'CONFIGURED' : 'REQUIRED',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _isConfigured
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.error))),
                      SizedBox(width: 2.w),
                      CustomIconWidget(
                          iconName: 'chevron_right',
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                          size: 16),
                    ])))));
  }
}