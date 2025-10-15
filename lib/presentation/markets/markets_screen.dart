import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/services/crypto_service.dart';
import '../../widgets/custom_app_bar.dart';
import './widgets/market_crypto_card_widget.dart';
import './widgets/market_header_widget.dart';
import './widgets/market_search_widget.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  final CryptoService _cryptoService = CryptoService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _cryptocurrencies = [];
  List<Map<String, dynamic>> _filteredCryptocurrencies = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSearching = false;
  String _errorMessage = '';
  String _currentSearchQuery = '';
  bool _showingFallbackData = false;

  Timer? _refreshTimer;
  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMarketData();
    _searchController.addListener(_onSearchChanged);
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted && !_isLoading && !_isRefreshing) {
        _refreshMarketData(isAutomatic: true);
      }
    });
  }

  Future<void> _loadMarketData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _showingFallbackData = false;
    });

    try {
      // Try to get cached data first for instant display
      final cachedData = _cryptoService.getCachedData();
      if (cachedData != null) {
        setState(() {
          _cryptocurrencies = cachedData;
          _filteredCryptocurrencies = cachedData;
          _isLoading = false;
          _lastUpdated = DateTime.now();
        });
      }

      // Fetch fresh data from API
      final cryptos =
          await _cryptoService.getTopCryptocurrencies(limit: 100).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          return _cryptoService.getFallbackData();
        },
      );

      setState(() {
        _cryptocurrencies = cryptos;
        _filteredCryptocurrencies = _currentSearchQuery.isEmpty
            ? cryptos
            : _filterCryptocurrencies(cryptos, _currentSearchQuery);
        _isLoading = false;
        _showingFallbackData = cryptos.length < 10;
        _lastUpdated = DateTime.now();
      });

      // Show info message if using fallback data
      if (_showingFallbackData && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Limited market data available. Pull to refresh for live data.',
              style: GoogleFonts.inter(fontSize: 12.sp),
            ),
            backgroundColor: AppTheme.getWarningColor(
                Theme.of(context).brightness == Brightness.light),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Refresh',
              onPressed: () => _refreshMarketData(),
            ),
          ),
        );
      }
    } catch (e) {
      // Try to show fallback data if everything fails
      try {
        final fallbackData = _cryptoService.getFallbackData();
        setState(() {
          _cryptocurrencies = fallbackData;
          _filteredCryptocurrencies = fallbackData;
          _isLoading = false;
          _showingFallbackData = true;
          _lastUpdated = DateTime.now();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Connection failed. Showing offline market data.',
                style: GoogleFonts.inter(fontSize: 12.sp),
              ),
              backgroundColor: AppTheme.getWarningColor(
                  Theme.of(context).brightness == Brightness.light),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _loadMarketData(),
              ),
            ),
          );
        }
      } catch (fallbackError) {
        setState(() {
          _errorMessage =
              'Unable to load market data. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshMarketData({bool isAutomatic = false}) async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    if (!isAutomatic) {
      HapticFeedback.lightImpact();
    }

    try {
      _cryptoService.clearCache();
      final cryptos = await _cryptoService.getTopCryptocurrencies(limit: 100);

      setState(() {
        _cryptocurrencies = cryptos;
        _filteredCryptocurrencies = _currentSearchQuery.isEmpty
            ? cryptos
            : _filterCryptocurrencies(cryptos, _currentSearchQuery);
        _showingFallbackData = cryptos.length < 10;
        _lastUpdated = DateTime.now();
      });

      if (!isAutomatic && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Market data updated successfully',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!isAutomatic && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update market data. Please try again.',
              style: GoogleFonts.inter(fontSize: 12.sp),
            ),
            backgroundColor: AppTheme.getWarningColor(
                Theme.of(context).brightness == Brightness.light),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isRefreshing = false;
      });
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
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _filteredCryptocurrencies =
          _filterCryptocurrencies(_cryptocurrencies, query);
    });

    // Search online if local results are insufficient
    if (_filteredCryptocurrencies.length < 5 && query.length >= 2) {
      _searchOnline(query);
    } else {
      setState(() {
        _isSearching = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterCryptocurrencies(
      List<Map<String, dynamic>> cryptos, String query) {
    return cryptos.where((crypto) {
      final name = crypto['name'].toString().toLowerCase();
      final symbol = crypto['symbol'].toString().toLowerCase();
      final searchQuery = query.toLowerCase();
      return name.contains(searchQuery) || symbol.contains(searchQuery);
    }).toList();
  }

  Future<void> _searchOnline(String query) async {
    try {
      final searchResults = await _cryptoService.searchCryptocurrencies(query);

      if (_currentSearchQuery == query && mounted) {
        // Merge search results with local results
        final combinedResults = <Map<String, dynamic>>[];
        final addedIds = <String>{};

        // Add local results first
        for (final crypto in _filteredCryptocurrencies) {
          combinedResults.add(crypto);
          addedIds.add(crypto['id']);
        }

        // Add new search results
        for (final crypto in searchResults) {
          if (!addedIds.contains(crypto['id'])) {
            combinedResults.add(crypto);
          }
        }

        setState(() {
          _filteredCryptocurrencies = combinedResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (_currentSearchQuery == query && mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _navigateToCryptoDetail(Map<String, dynamic> crypto) {
    HapticFeedback.lightImpact();

    // Create a mock portfolio entry for the detail screen
    final mockCrypto = {
      'id': crypto['id'],
      'symbol': crypto['symbol'],
      'name': crypto['name'],
      'icon': crypto['image'],
      'currentPrice': crypto['current_price'],
      'holdings': 0.0,
      'averagePrice': crypto['current_price'],
      'priceChange24h': crypto['price_change_percentage_24h'],
      'transactions': <dynamic>[],
    };

    Navigator.pushNamed(
      context,
      AppRoutes.cryptocurrencyDetail,
      arguments: mockCrypto,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const CustomAppBar(
        title: 'Markets',
        showBackButton: true,
        centerTitle: true,
      ),
      body: Column(
        children: [
          MarketHeaderWidget(
            onRefresh: () => _refreshMarketData(),
            lastUpdated: _lastUpdated,
            isRefreshing: _isRefreshing,
            showingFallbackData: _showingFallbackData,
          ),
          MarketSearchWidget(
            controller: _searchController,
            isSearching: _isSearching,
            resultCount: _filteredCryptocurrencies.length,
            query: _currentSearchQuery,
            onClear: () {
              _searchController.clear();
              FocusScope.of(context).unfocus();
            },
          ),
          Expanded(
            child: _buildBody(theme),
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
      onRefresh: () => _refreshMarketData(),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(top: 1.h, bottom: 10.h),
        itemCount: _filteredCryptocurrencies.length,
        itemBuilder: (context, index) {
          final crypto = _filteredCryptocurrencies[index];
          return MarketCryptoCardWidget(
            crypto: crypto,
            onTap: () => _navigateToCryptoDetail(crypto),
            rank: index + 1,
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
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          SizedBox(height: 3.h),
          Text(
            'Loading market data...',
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
                  theme.brightness == Brightness.light),
              size: 15.w,
            ),
            SizedBox(height: 3.h),
            Text(
              'Unable to load market data',
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
              onPressed: _loadMarketData,
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
