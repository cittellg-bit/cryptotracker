import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/services/crypto_service.dart';
import './widgets/coin_header_widget.dart';
import './widgets/holdings_summary_widget.dart';
import './widgets/price_chart_widget.dart';
import './widgets/transaction_history_widget.dart';

class CryptocurrencyDetail extends StatefulWidget {
  const CryptocurrencyDetail({super.key});

  @override
  State<CryptocurrencyDetail> createState() => _CryptocurrencyDetailState();
}

class _CryptocurrencyDetailState extends State<CryptocurrencyDetail>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final CryptoService _cryptoService = CryptoService();

  bool _isLoading = false;
  bool _isRefreshing = false;

  // Will be populated from route arguments
  Map<String, dynamic>? _cryptoData;
  Map<String, dynamic> _coinData = {};
  Map<String, dynamic> _holdingsData = {};
  List<Map<String, dynamic>> _transactions = [];
  String _coinId = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Extract arguments from route
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (arguments != null && _cryptoData == null) {
      _cryptoData = arguments;
      _setupInitialData();
      _loadRealTimeData();
    }
  }

  void _setupInitialData() {
    if (_cryptoData == null) return;

    final symbol = (_cryptoData!['symbol'] as String? ?? 'btc').toLowerCase();
    final holdings = (_cryptoData!['holdings'] as num?)?.toDouble() ?? 0.0;
    final averagePrice =
        (_cryptoData!['averagePrice'] as num?)?.toDouble() ?? 0.0;
    final transactionList =
        _cryptoData!['transactions'] as List<dynamic>? ?? [];

    // Set up coin ID for API calls (convert common symbols to CoinGecko IDs)
    _coinId = _getCoinGeckoId(symbol);

    // FIXED: Use passed current price or fetch from API
    double initialCurrentPrice =
        (_cryptoData!['currentPrice'] as num?)?.toDouble() ?? 0.0;
    double initialPriceChange =
        (_cryptoData!['priceChange24h'] as num?)?.toDouble() ?? 0.0;

    // Setup initial coin data (will be updated with real data from API if needed)
    _coinData = {
      "id": _coinId,
      "name": _cryptoData!['name'] as String? ?? "Cryptocurrency",
      "symbol": symbol,
      "image": _cryptoData!['icon'] as String? ?? "",
      "current_price": initialCurrentPrice, // Use passed value
      "market_cap": 0.0, // Will be fetched from API
      "total_volume": 0.0, // Will be fetched from API
      "price_change_24h": initialPriceChange, // Use passed value
      "price_change_percentage_24h": initialPriceChange, // Use passed value
      "high_24h":
          initialCurrentPrice * 1.05, // Approximation based on current price
      "low_24h":
          initialCurrentPrice * 0.95, // Approximation based on current price
      "ath": 0.0, // Will be fetched from API
      "ath_change_percentage": 0.0, // Will be fetched from API
      "last_updated": DateTime.now().toIso8601String(),
    };

    // FIXED: Use passed holdings data directly
    _holdingsData = {
      "symbol": symbol,
      "total_owned": holdings,
      "average_price": averagePrice,
      "current_value":
          initialCurrentPrice * holdings, // Calculate with passed price
      "total_invested": averagePrice * holdings,
      "transaction_count": transactionList.length,
    };

    // Setup transactions with better null handling
    _transactions = transactionList.map((tx) {
      final transaction = tx as Map<String, dynamic>? ?? {};
      return {
        "id":
            "tx_${transaction['id'] ?? DateTime.now().millisecondsSinceEpoch}",
        "date": transaction['timestamp'] != null
            ? (transaction['timestamp'] as DateTime).toIso8601String()
            : transaction['transaction_date'] as String? ??
                DateTime.now().toIso8601String(),
        "amount": (transaction['amount'] as num?)?.toDouble() ?? 0.0,
        "price": (transaction['price_per_unit'] as num?)?.toDouble() ?? 0.0,
        "type": transaction['transaction_type'] as String? ??
            transaction['type'] as String? ??
            'buy',
        "total": ((transaction['amount'] as num?)?.toDouble() ?? 0.0) *
            ((transaction['price_per_unit'] as num?)?.toDouble() ?? 0.0),
        "exchange": transaction['exchange'] as String? ?? 'Unknown',
      };
    }).toList();
  }

  String _getCoinGeckoId(String symbol) {
    // Map common symbols to CoinGecko IDs
    final symbolToId = {
      'btc': 'bitcoin',
      'eth': 'ethereum',
      'ada': 'cardano',
      'dot': 'polkadot',
      'bnb': 'binancecoin',
      'sol': 'solana',
      'matic': 'polygon',
      'avax': 'avalanche-2',
      'link': 'chainlink',
      'atom': 'cosmos',
      'xrp': 'ripple',
      'ltc': 'litecoin',
      'bch': 'bitcoin-cash',
      'etc': 'ethereum-classic',
      'xlm': 'stellar',
      'vet': 'vechain',
      'algo': 'algorand',
      'icp': 'internet-computer',
      'fil': 'filecoin',
      'trx': 'tron',
    };

    return symbolToId[symbol.toLowerCase()] ?? symbol.toLowerCase();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  Future<void> _loadRealTimeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch real cryptocurrency details from API
      final realCoinData =
          await _cryptoService.getCryptocurrencyDetails(_coinId);

      // Update coin data with real API data - with null safety
      if (realCoinData != null) {
        setState(() {
          _coinData = {
            ..._coinData,
            "current_price": realCoinData['current_price'] ?? 0.0,
            "market_cap": realCoinData['market_cap'] ?? 0.0,
            "total_volume": realCoinData['total_volume'] ?? 0.0,
            "price_change_24h": realCoinData['current_price'] != null &&
                    realCoinData['price_change_percentage_24h'] != null
                ? (realCoinData['current_price'] *
                        realCoinData['price_change_percentage_24h']) /
                    100
                : 0.0,
            "price_change_percentage_24h":
                realCoinData['price_change_percentage_24h'] ?? 0.0,
            "high_24h": realCoinData['current_price'] != null
                ? realCoinData['current_price'] * 1.05
                : 0.0, // Approximation
            "low_24h": realCoinData['current_price'] != null
                ? realCoinData['current_price'] * 0.95
                : 0.0, // Approximation
            "ath": realCoinData['ath'] ?? 0.0,
            "ath_change_percentage":
                realCoinData['ath_change_percentage'] ?? 0.0,
            "last_updated": DateTime.now().toIso8601String(),
          };

          // Update holdings current value with real price
          final currentPrice = realCoinData['current_price'] ?? 0.0;
          _holdingsData["current_value"] =
              (_holdingsData["total_owned"] as double) * currentPrice;
        });
      }
    } catch (e) {
      // If API call fails, show error but keep existing data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to load current price data. Showing cached data.",
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
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    HapticFeedback.lightImpact();

    try {
      // Fetch real-time price data from API
      final realCoinData =
          await _cryptoService.getCryptocurrencyDetails(_coinId);

      // Update with fresh API data - with null safety
      if (realCoinData != null) {
        setState(() {
          _coinData = {
            ..._coinData,
            "current_price": realCoinData['current_price'] ?? 0.0,
            "market_cap": realCoinData['market_cap'] ?? 0.0,
            "total_volume": realCoinData['total_volume'] ?? 0.0,
            "price_change_24h": realCoinData['current_price'] != null &&
                    realCoinData['price_change_percentage_24h'] != null
                ? (realCoinData['current_price'] *
                        realCoinData['price_change_percentage_24h']) /
                    100
                : 0.0,
            "price_change_percentage_24h":
                realCoinData['price_change_percentage_24h'] ?? 0.0,
            "high_24h": realCoinData['current_price'] != null
                ? realCoinData['current_price'] * 1.05
                : 0.0, // Approximation
            "low_24h": realCoinData['current_price'] != null
                ? realCoinData['current_price'] * 0.95
                : 0.0, // Approximation
            "ath": realCoinData['ath'] ?? 0.0,
            "ath_change_percentage":
                realCoinData['ath_change_percentage'] ?? 0.0,
            "last_updated": DateTime.now().toIso8601String(),
          };

          // Update holdings current value with real price
          final currentPrice = realCoinData['current_price'] ?? 0.0;
          _holdingsData["current_value"] =
              (_holdingsData["total_owned"] as double) * currentPrice;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Current price updated successfully",
                style: GoogleFonts.inter(fontSize: 12.sp),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to update price. Please check your connection.",
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show loading if data is not yet loaded or provide fallback handling
    if (_cryptoData == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: CustomIconWidget(
              iconName: 'arrow_back_ios',
              color: theme.colorScheme.onSurface,
              size: 20,
            ),
          ),
          title: Text(
            'Cryptocurrency',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        body: _buildNoDataState(theme),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: _isLoading
          ? _buildLoadingState(theme)
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: theme.colorScheme.primary,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildBody(theme),
                ),
              ),
            ),
      floatingActionButton: _buildFloatingActionButton(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        icon: CustomIconWidget(
          iconName: 'arrow_back_ios',
          color: theme.colorScheme.onSurface,
          size: 20,
        ),
      ),
      title: Text(
        _coinData["name"] as String? ?? "Cryptocurrency",
        style: GoogleFonts.inter(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _showMoreOptions(context);
          },
          icon: CustomIconWidget(
            iconName: 'star_border',
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            size: 24,
          ),
        ),
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _shareAsset(context);
          },
          icon: CustomIconWidget(
            iconName: 'share',
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            size: 24,
          ),
        ),
        SizedBox(width: 2.w),
      ],
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
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
            strokeWidth: 3,
          ),
          SizedBox(height: 2.h),
          Text(
            "Loading cryptocurrency data...",
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'error_outline',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              size: 15.w,
            ),
            SizedBox(height: 3.h),
            Text(
              'No cryptocurrency data available',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              'Please select a cryptocurrency from your portfolio or the markets to view details.',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(
                    context, AppRoutes.portfolioDashboard);
              },
              child: Text(
                'Back to Portfolio',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 2.h),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.markets);
              },
              child: Text(
                'Browse Markets',
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

  Widget _buildBody(ThemeData theme) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coin Header
          CoinHeaderWidget(coinData: _coinData),

          SizedBox(height: 3.h),

          // Price Chart
          PriceChartWidget(coinData: _coinData),

          SizedBox(height: 3.h),

          // Holdings Summary
          HoldingsSummaryWidget(holdingsData: _holdingsData),

          SizedBox(height: 3.h),

          // Transaction History
          TransactionHistoryWidget(
            transactions: _transactions,
            coinSymbol: _coinData["symbol"] as String? ?? "BTC",
            currentPrice: _coinData["current_price"] as double? ?? 0.0,
          ),

          SizedBox(height: 10.h), // Extra space for FAB
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme) {
    return FloatingActionButton.extended(
      onPressed: () {
        HapticFeedback.mediumImpact();
        _addMoreCrypto(context);
      },
      backgroundColor: theme.colorScheme.secondary,
      foregroundColor: theme.colorScheme.onSecondary,
      elevation: 6,
      icon: CustomIconWidget(
        iconName: 'add',
        color: theme.colorScheme.onSecondary,
        size: 24,
      ),
      label: Text(
        "Add More",
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 2.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'star',
                  color: Colors.amber,
                  size: 24,
                ),
                title: Text(
                  "Add to Favorites",
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Added to favorites",
                        style: GoogleFonts.inter(fontSize: 12.sp),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'notifications',
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  "Price Alerts",
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'analytics',
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  "Advanced Analytics",
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                },
              ),
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }

  void _shareAsset(BuildContext context) {
    HapticFeedback.lightImpact();

    final coinName = _coinData["name"] as String? ?? "Cryptocurrency";
    final currentPrice = _coinData["current_price"] as double? ?? 0.0;
    final priceChange =
        _coinData["price_change_percentage_24h"] as double? ?? 0.0;
    final isPositive = priceChange >= 0;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Sharing $coinName: \$${currentPrice.toStringAsFixed(2)} (${isPositive ? '+' : ''}${priceChange.toStringAsFixed(2)}%)",
          style: GoogleFonts.inter(fontSize: 12.sp),
        ),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: "Copy",
          onPressed: () {
            Clipboard.setData(ClipboardData(
              text:
                  "$coinName: \$${currentPrice.toStringAsFixed(2)} (${isPositive ? '+' : ''}${priceChange.toStringAsFixed(2)}%)",
            ));
          },
        ),
      ),
    );
  }

  void _addMoreCrypto(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.editTransaction,
      arguments: {
        'coinSymbol': _coinData["symbol"] as String? ?? "BTC",
        'coinName': _coinData["name"] as String? ?? "Bitcoin",
        'currentPrice': _coinData["current_price"] as double? ?? 0.0,
      },
    ).then((result) {
      if (result == true) {
        // Refresh data after adding transaction
        _refreshData();
      }
    });
  }
}
