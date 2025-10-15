import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/services/crypto_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/crypto_list_item_widget.dart';
import './widgets/crypto_search_widget.dart';

class CryptoSelectorScreen extends StatefulWidget {
  const CryptoSelectorScreen({super.key});

  @override
  State<CryptoSelectorScreen> createState() => _CryptoSelectorScreenState();
}

class _CryptoSelectorScreenState extends State<CryptoSelectorScreen> {
  final CryptoService _cryptoService = CryptoService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _cryptocurrencies = [];
  List<Map<String, dynamic>> _filteredCryptocurrencies = [];
  List<Map<String, dynamic>> _searchResults = [];

  bool _isLoading = true;
  bool _isSearching = false;
  String _errorMessage = '';
  String _currentSearchQuery = '';
  bool _showingFallbackData = false;

  @override
  void initState() {
    super.initState();
    _loadCryptocurrencies();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCryptocurrencies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _showingFallbackData = false;
    });

    try {
      // Try to get cached data first
      final cachedData = _cryptoService.getCachedData();
      if (cachedData != null) {
        setState(() {
          _cryptocurrencies = cachedData;
          _filteredCryptocurrencies = cachedData;
          _isLoading = false;
        });

        if (kDebugMode) {
          print(
            '✅ Loaded ${cachedData.length} cached cryptocurrencies for transaction selection',
          );
        }
        return;
      }

      // ENHANCED: Fetch comprehensive dataset for ALL available cryptocurrencies
      if (kDebugMode) {
        print(
          '🔄 Fetching comprehensive cryptocurrency dataset for transaction selection...',
        );
      }

      // Set a maximum timeout for the entire operation
      final cryptos = await _cryptoService
          .getTopCryptocurrencies(limit: 500)
          .timeout(
            const Duration(
              seconds: 12,
            ), // Extended timeout for comprehensive fetch
            onTimeout: () {
              if (kDebugMode) {
                print('⏰ Timeout reached, using fallback data');
              }
              // Return fallback data on timeout
              return _cryptoService.getFallbackData();
            },
          );

      setState(() {
        _cryptocurrencies = cryptos;
        _filteredCryptocurrencies = cryptos;
        _isLoading = false;
        // Check if we're showing fallback data (less than 50 items means likely fallback)
        _showingFallbackData =
            cryptos.length < 50 || cryptos.any((c) => c['is_fallback'] == true);
      });

      if (kDebugMode) {
        print(
          '✅ Loaded ${cryptos.length} cryptocurrencies for transaction selection',
        );
        print('   Fallback data: ${_showingFallbackData ? "Yes" : "No"}');

        // Log top cryptocurrencies available
        final topCryptos = cryptos
            .take(10)
            .map((c) => '${c['symbol']} (${c['name']})')
            .join(', ');
        print('   Top 10: $topCryptos');
      }

      // Show info message if using fallback data
      if (_showingFallbackData && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Showing ${cryptos.length} cryptocurrencies. Pull to refresh for complete dataset.',
              style: GoogleFonts.inter(fontSize: 12.sp),
            ),
            backgroundColor: AppTheme.getWarningColor(
              Theme.of(context).brightness == Brightness.light,
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: 'Refresh', onPressed: _refreshData),
          ),
        );
      } else if (mounted && cryptos.length >= 200) {
        // Show success message for comprehensive dataset
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Loaded ${cryptos.length} cryptocurrencies for selection',
              style: GoogleFonts.inter(fontSize: 12.sp),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading cryptocurrencies: $e');
      }

      // If everything fails, try to show fallback data
      try {
        final fallbackData = _cryptoService.getFallbackData();
        setState(() {
          _cryptocurrencies = fallbackData;
          _filteredCryptocurrencies = fallbackData;
          _isLoading = false;
          _showingFallbackData = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Connection failed. Showing ${fallbackData.length} popular cryptocurrencies. Pull to refresh.',
                style: GoogleFonts.inter(fontSize: 12.sp),
              ),
              backgroundColor: AppTheme.getWarningColor(
                Theme.of(context).brightness == Brightness.light,
              ),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(label: 'Retry', onPressed: _refreshData),
            ),
          );
        }
      } catch (fallbackError) {
        // If even fallback fails, show error
        setState(() {
          _errorMessage =
              'Unable to load cryptocurrency data. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _currentSearchQuery = query;
    });

    if (query.isEmpty) {
      setState(() {
        _filteredCryptocurrencies = _cryptocurrencies;
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Local filter first
    final localResults =
        _cryptocurrencies.where((crypto) {
          final name = crypto['name'].toString().toLowerCase();
          final symbol = crypto['symbol'].toString().toLowerCase();
          final searchQuery = query.toLowerCase();
          return name.contains(searchQuery) || symbol.contains(searchQuery);
        }).toList();

    setState(() {
      _filteredCryptocurrencies = localResults;
    });

    // If local results are insufficient, search via API
    if (localResults.length < 5 && query.length >= 2) {
      _searchOnline(query);
    }
  }

  Future<void> _searchOnline(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final searchResults = await _cryptoService.searchCryptocurrencies(query);

      if (_currentSearchQuery == query) {
        // Merge search results with local results, avoiding duplicates
        final combinedResults = <Map<String, dynamic>>[];
        final addedIds = <String>{};

        // Add local results first
        for (final crypto in _filteredCryptocurrencies) {
          combinedResults.add(crypto);
          addedIds.add(crypto['id']);
        }

        // Add search results that aren't already included
        for (final crypto in searchResults) {
          if (!addedIds.contains(crypto['id'])) {
            combinedResults.add(crypto);
          }
        }

        setState(() {
          _searchResults = searchResults;
          _filteredCryptocurrencies = combinedResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (_currentSearchQuery == query) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _selectCryptocurrency(Map<String, dynamic> crypto) {
    HapticFeedback.lightImpact();
    Navigator.pop(context, crypto);
  }

  Future<void> _refreshData() async {
    HapticFeedback.lightImpact();
    _cryptoService.clearCache();

    if (kDebugMode) {
      print(
        '🔄 Refreshing cryptocurrency dataset for transaction selection...',
      );
    }

    await _loadCryptocurrencies();

    if (mounted) {
      final datasetInfo =
          _showingFallbackData
              ? '${_cryptocurrencies.length} popular cryptocurrencies loaded'
              : '${_cryptocurrencies.length} cryptocurrencies updated';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(datasetInfo, style: GoogleFonts.inter(fontSize: 14.sp)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              _showingFallbackData
                  ? AppTheme.getWarningColor(
                    Theme.of(context).brightness == Brightness.light,
                  )
                  : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          _buildSearchSection(theme),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: Text(
        'Select Cryptocurrency',
        style: GoogleFonts.inter(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      leading: IconButton(
        icon: CustomIconWidget(
          iconName: 'arrow_back',
          color: theme.colorScheme.onSurface,
          size: 6.w,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: CustomIconWidget(
            iconName: 'refresh',
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            size: 6.w,
          ),
          onPressed: _isLoading ? null : _refreshData,
        ),
      ],
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
    );
  }

  Widget _buildSearchSection(ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CryptoSearchWidget(
            controller: _searchController,
            isSearching: _isSearching,
            onClear: () {
              _searchController.clear();
              FocusScope.of(context).unfocus();
            },
          ),
          SizedBox(height: 1.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  _currentSearchQuery.isEmpty
                      ? '${_filteredCryptocurrencies.length} cryptocurrencies available${_showingFallbackData ? ' (limited set)' : ' for transactions'}'
                      : '${_filteredCryptocurrencies.length} results for "$_currentSearchQuery"',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              if (_showingFallbackData) ...[
                SizedBox(width: 2.w),
                Icon(
                  Icons.cloud_off,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ] else if (_filteredCryptocurrencies.length >= 200) ...[
                SizedBox(width: 2.w),
                Icon(Icons.check_circle, size: 16, color: Colors.green),
              ],
              if (_isSearching) ...[
                SizedBox(width: 2.w),
                SizedBox(
                  width: 4.w,
                  height: 4.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading && _cryptocurrencies.isEmpty) {
      return _buildLoadingState(theme);
    }

    if (_errorMessage.isNotEmpty && _cryptocurrencies.isEmpty) {
      return _buildErrorState(theme);
    }

    if (_filteredCryptocurrencies.isEmpty) {
      return _buildEmptyState(theme);
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        itemCount: _filteredCryptocurrencies.length,
        itemBuilder: (context, index) {
          final crypto = _filteredCryptocurrencies[index];
          return CryptoListItemWidget(
            crypto: crypto,
            onTap: () => _selectCryptocurrency(crypto),
            isFromSearch: _searchResults.any(
              (result) => result['id'] == crypto['id'],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          SizedBox(height: 3.h),
          Text(
            'Loading cryptocurrencies...',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'This may take a few seconds',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'error_outline',
              color: AppTheme.getWarningColor(
                theme.brightness == Brightness.light,
              ),
              size: 15.w,
            ),
            SizedBox(height: 3.h),
            Text(
              'Unable to load cryptocurrencies',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              _errorMessage,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            ElevatedButton(
              onPressed: _loadCryptocurrencies,
              child: Text(
                'Try Again',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'search_off',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              size: 15.w,
            ),
            SizedBox(height: 3.h),
            Text(
              'No cryptocurrencies found',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              'Try searching with a different name or symbol',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}