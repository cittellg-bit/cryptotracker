import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../core/services/crypto_api_service.dart';
import '../../../core/services/pl_persistence_service.dart';

enum TimePeriod { day, week, month, year }

class PortfolioValueChartWidget extends StatefulWidget {
  final double totalValue;
  final double totalInvested;
  final double percentageChange;
  final double profitLoss;
  final DateTime lastUpdated;
  final PLPersistenceService? plPersistenceService;

  const PortfolioValueChartWidget({
    super.key,
    required this.totalValue,
    required this.totalInvested,
    required this.percentageChange,
    required this.profitLoss,
    required this.lastUpdated,
    this.plPersistenceService,
  });

  @override
  State<PortfolioValueChartWidget> createState() =>
      _PortfolioValueChartWidgetState();
}

class _PortfolioValueChartWidgetState extends State<PortfolioValueChartWidget> {
  TimePeriod _selectedPeriod = TimePeriod.day;
  List<FlSpot> _chartData = [];
  bool _usingHistoricalData = false;
  bool _isLoadingHistoricalData = false;
  String? _dataSource;

  @override
  void initState() {
    super.initState();
    _generateChartData();
  }

  @override
  void didUpdateWidget(PortfolioValueChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalValue != widget.totalValue ||
        oldWidget.profitLoss != widget.profitLoss ||
        oldWidget.lastUpdated != widget.lastUpdated) {
      _generateChartData();
    }
  }

  /// ENHANCED: Generate chart data with comprehensive historical data support and 429 error handling
  void _generateChartData() async {
    if (mounted) {
      setState(() {
        _isLoadingHistoricalData = true;
        _dataSource = null;
      });
    }

    final currentValue = widget.totalValue;
    final profitLoss = widget.profitLoss;

    try {
      // PRIORITY 1: Try to load from P&L persistence service time series
      if (widget.plPersistenceService != null) {
        final historicalData = await _tryLoadFromPLTimeSeries();
        if (historicalData != null && historicalData.isNotEmpty) {
          if (mounted) {
            setState(() {
              _chartData = historicalData;
              _usingHistoricalData = true;
              _isLoadingHistoricalData = false;
              _dataSource = 'P&L Time Series';
            });
          }

          if (kDebugMode) {
            print(
              '📈 Using P&L time series for chart: ${historicalData.length} points',
            );
          }
          return;
        }
      }

      // PRIORITY 2: Try to generate from cached market data (prevents 429 errors)
      final cachedMarketData = await _tryGenerateFromCachedMarketData();
      if (cachedMarketData != null && cachedMarketData.isNotEmpty) {
        if (mounted) {
          setState(() {
            _chartData = cachedMarketData;
            _usingHistoricalData = true;
            _isLoadingHistoricalData = false;
            _dataSource = 'Cached Market Data';
          });
        }

        if (kDebugMode) {
          print(
            '💾 Using cached market data for chart: ${cachedMarketData.length} points',
          );
        }
        return;
      }

      // PRIORITY 3: Try fresh historical market data (respects rate limits)
      final freshHistoricalData = await _tryGenerateFromFreshHistoricalData();
      if (freshHistoricalData != null && freshHistoricalData.isNotEmpty) {
        if (mounted) {
          setState(() {
            _chartData = freshHistoricalData;
            _usingHistoricalData = true;
            _isLoadingHistoricalData = false;
            _dataSource = 'Fresh Market Data';
          });
        }

        if (kDebugMode) {
          print(
            '🔄 Using fresh historical data for chart: ${freshHistoricalData.length} points',
          );
        }
        return;
      }

      // FALLBACK: Generate synthetic data based on current P&L
      _usingHistoricalData = false;
      _dataSource = 'Synthetic Data';

      switch (_selectedPeriod) {
        case TimePeriod.day:
          _chartData = _generateDayData(currentValue, profitLoss);
          break;
        case TimePeriod.week:
          _chartData = _generateWeekData(currentValue, profitLoss);
          break;
        case TimePeriod.month:
          _chartData = _generateMonthData(currentValue, profitLoss);
          break;
        case TimePeriod.year:
          _chartData = _generateYearData(currentValue, profitLoss);
          break;
      }

      if (kDebugMode) {
        print(
          '📊 Generated synthetic chart data: ${_chartData.length} points (period: ${_selectedPeriod.name})',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error generating chart data: $e');
      }

      // Emergency fallback to basic synthetic data
      _chartData = _generateBasicFallbackData(currentValue, profitLoss);
      _usingHistoricalData = false;
      _dataSource = 'Emergency Fallback';
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistoricalData = false;
        });
      }
    }
  }

  /// NEW: Try to load historical data from P&L persistence service time series
  Future<List<FlSpot>?> _tryLoadFromPLTimeSeries() async {
    try {
      if (widget.plPersistenceService == null) return null;

      Duration period;
      switch (_selectedPeriod) {
        case TimePeriod.day:
          period = const Duration(hours: 24);
          break;
        case TimePeriod.week:
          period = const Duration(days: 7);
          break;
        case TimePeriod.month:
          period = const Duration(days: 30);
          break;
        case TimePeriod.year:
          period = const Duration(days: 365);
          break;
      }

      final timeSeriesData = await widget.plPersistenceService!.getPLTimeSeries(
        period: period,
      );

      if (timeSeriesData.isEmpty) return null;

      final chartData = <FlSpot>[];
      final now = DateTime.now();
      final startTime = now.subtract(period);

      // Convert P&L time series data to chart points
      for (int i = 0; i < timeSeriesData.length; i++) {
        final dataPoint = timeSeriesData[i];
        final timestamp = dataPoint['timestamp'] as int;
        final totalValue = (dataPoint['totalValue'] as num?)?.toDouble() ?? 0.0;

        final pointTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final relativePosition =
            pointTime.difference(startTime).inMilliseconds.toDouble() /
            period.inMilliseconds.toDouble();

        final xPosition = (relativePosition * (_getMaxX() ?? 23.0)).clamp(
          0.0,
          _getMaxX() ?? 23.0,
        );
        chartData.add(FlSpot(xPosition, totalValue));
      }

      // Ensure current value is the last point
      if (chartData.isNotEmpty) {
        chartData.last = FlSpot((_getMaxX() ?? 23.0), widget.totalValue);
      } else {
        // Create basic chart with current value
        chartData.add(FlSpot(0.0, widget.totalValue));
        chartData.add(FlSpot((_getMaxX() ?? 23.0), widget.totalValue));
      }

      return chartData.isNotEmpty ? chartData : null;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ P&L time series chart generation failed: $e');
      }
      return null;
    }
  }

  /// NEW: Try to generate chart data from cached market data to prevent 429 errors
  Future<List<FlSpot>?> _tryGenerateFromCachedMarketData() async {
    try {
      final cachedData = CryptoApiService.instance.getCachedData();
      if (cachedData == null || cachedData.isEmpty) return null;

      // For now, return null as we need transaction history to properly calculate historical P&L
      // This method can be enhanced later to use transaction data + cached prices
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Cached market data chart generation failed: $e');
      }
      return null;
    }
  }

  /// NEW: Try to fetch fresh historical market data (with rate limit awareness)
  Future<List<FlSpot>?> _tryGenerateFromFreshHistoricalData() async {
    try {
      // Check if API service is rate limited before attempting
      final apiStatus = await CryptoApiService.instance.getApiStatus();
      final isRateLimited = apiStatus['rateLimiting']?['isRateLimited'] == true;

      if (isRateLimited) {
        if (kDebugMode) {
          print('🚫 API rate limited - skipping fresh historical data fetch');
        }
        return null;
      }

      // For this implementation, we'll focus on P&L time series and cached data
      // Fresh historical data fetching can be added later with transaction analysis
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Fresh historical data fetch failed: $e');
      }
      return null;
    }
  }

  /// NEW: Generate basic fallback data for emergency situations
  List<FlSpot> _generateBasicFallbackData(
    double currentValue,
    double profitLoss,
  ) {
    final points = _getPointCount();
    final data = <FlSpot>[];

    for (int i = 0; i < points; i++) {
      final progress = i / (points - 1);
      final baseValue = currentValue - (profitLoss * (1 - progress));
      final value = max(0.0, baseValue);
      data.add(FlSpot(i.toDouble(), value));
    }

    // Ensure last point is current value
    if (data.isNotEmpty) {
      data.last = FlSpot((points - 1).toDouble(), currentValue);
    }

    return data;
  }

  /// Get number of data points based on selected period
  int _getPointCount() {
    switch (_selectedPeriod) {
      case TimePeriod.day:
        return 24;
      case TimePeriod.week:
        return 7;
      case TimePeriod.month:
        return 30;
      case TimePeriod.year:
        return 12;
    }
  }

  double? _getMaxX() {
    switch (_selectedPeriod) {
      case TimePeriod.day:
        return 23.0;
      case TimePeriod.week:
        return 6.0;
      case TimePeriod.month:
        return 29.0;
      case TimePeriod.year:
        return 11.0;
    }
  }

  /// ENHANCED: Generate day data with better P&L-based progression
  List<FlSpot> _generateDayData(double currentValue, double profitLoss) {
    final data = <FlSpot>[];
    final now = DateTime.now();
    const points = 24; // 24 hours

    for (int i = 0; i < points; i++) {
      final hour = i.toDouble();
      // More realistic P&L-based progression
      final progress = i / (points - 1);
      final volatility =
          currentValue * 0.015; // Reduced volatility for more stability
      final random = Random(i + now.day + now.month);
      final fluctuation = (random.nextDouble() - 0.5) * volatility;

      // Calculate base value showing progression towards current P&L
      final baseValue = currentValue - (profitLoss * (1 - progress));
      final value = max(0.0, baseValue + fluctuation);

      data.add(FlSpot(hour, value.toDouble()));
    }

    // Ensure final point is exactly current value
    data[data.length - 1] = FlSpot(
      (points - 1).toDouble(),
      currentValue.toDouble(),
    );
    return data;
  }

  /// ENHANCED: Generate week data with better trend logic
  List<FlSpot> _generateWeekData(double currentValue, double profitLoss) {
    final data = <FlSpot>[];
    const points = 7; // 7 days

    for (int i = 0; i < points; i++) {
      final day = i.toDouble();
      final progress = i / (points - 1);
      final volatility = currentValue * 0.03; // Moderate weekly volatility
      final random = Random(i + 100 + DateTime.now().month);
      final fluctuation = (random.nextDouble() - 0.5) * volatility;

      // Show realistic weekly progression
      final baseValue = currentValue - (profitLoss * (1 - progress));
      final value = max(0.0, baseValue + fluctuation);

      data.add(FlSpot(day, value.toDouble()));
    }

    data[data.length - 1] = FlSpot(
      (points - 1).toDouble(),
      currentValue.toDouble(),
    );
    return data;
  }

  /// ENHANCED: Generate month data with realistic monthly volatility
  List<FlSpot> _generateMonthData(double currentValue, double profitLoss) {
    final data = <FlSpot>[];
    const points = 30; // 30 days

    for (int i = 0; i < points; i++) {
      final day = i.toDouble();
      final progress = i / (points - 1);
      final volatility = currentValue * 0.08; // Higher monthly volatility
      final random = Random(i + 200 + DateTime.now().year);
      final fluctuation = (random.nextDouble() - 0.5) * volatility;

      // More complex monthly trend with mid-month variations
      final midMonthBoost = sin(progress * pi) * (currentValue * 0.02);
      final baseValue =
          currentValue - (profitLoss * (1 - progress)) + midMonthBoost;
      final value = max(0.0, baseValue + fluctuation);

      data.add(FlSpot(day, value.toDouble()));
    }

    data[data.length - 1] = FlSpot(
      (points - 1).toDouble(),
      currentValue.toDouble(),
    );
    return data;
  }

  /// ENHANCED: Generate year data with seasonal patterns
  List<FlSpot> _generateYearData(double currentValue, double profitLoss) {
    final data = <FlSpot>[];
    const points = 12; // 12 months

    for (int i = 0; i < points; i++) {
      final month = i.toDouble();
      final progress = i / (points - 1);
      final volatility = currentValue * 0.15; // Significant yearly volatility
      final random = Random(i + 300 + DateTime.now().year);
      final fluctuation = (random.nextDouble() - 0.5) * volatility;

      // Add seasonal crypto market patterns (typically stronger in Q4, weaker in summer)
      final seasonalMultiplier =
          1.0 + (sin((i + 9) * pi / 6) * 0.1); // Peak around Nov-Dec
      final baseValue =
          (currentValue - (profitLoss * (1 - progress))) * seasonalMultiplier;
      final value = max(0.0, baseValue + fluctuation);

      data.add(FlSpot(month, value.toDouble()));
    }

    data[data.length - 1] = FlSpot(
      (points - 1).toDouble(),
      currentValue.toDouble(),
    );
    return data;
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case TimePeriod.day:
        return '24H';
      case TimePeriod.week:
        return '7D';
      case TimePeriod.month:
        return '30D';
      case TimePeriod.year:
        return '1Y';
    }
  }

  Color _getChartColor() {
    final theme = Theme.of(context);
    return widget.profitLoss >= 0
        ? AppTheme.getSuccessColor(theme.brightness == Brightness.light)
        : AppTheme.getWarningColor(theme.brightness == Brightness.light);
  }

  String _formatXAxisLabel(double value) {
    switch (_selectedPeriod) {
      case TimePeriod.day:
        return '${value.toInt()}h';
      case TimePeriod.week:
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[value.toInt() % days.length];
      case TimePeriod.month:
        return '${value.toInt() + 1}';
      case TimePeriod.year:
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return months[value.toInt() % months.length];
    }
  }

  double _getMinY() {
    if (_chartData.isEmpty) return 0;
    final minValue = _chartData.map((e) => e.y).reduce(min);
    return max(0.0, minValue * 0.95); // 5% padding below minimum
  }

  double _getMaxY() {
    if (_chartData.isEmpty) return widget.totalValue * 1.1;
    final maxValue = _chartData.map((e) => e.y).reduce(max);
    return maxValue * 1.05; // 5% padding above maximum
  }

  double _getHorizontalInterval() {
    final interval = (_getMaxY() - _getMinY()) / 4;
    // Ensure interval is never zero to prevent fl_chart error
    return interval > 0
        ? interval
        : widget.totalValue * 0.01; // 1% of total value as fallback
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profitLoss = widget.profitLoss;
    final isProfit = profitLoss >= 0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with enhanced data source indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portfolio Value',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  if (_dataSource != null) ...[
                    SizedBox(height: 0.5.h),
                    Row(
                      children: [
                        Icon(
                          _usingHistoricalData
                              ? Icons.history
                              : Icons.show_chart,
                          size: 12.sp,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          _dataSource!,
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_isLoadingHistoricalData) ...[
                    SizedBox(height: 0.5.h),
                    Row(
                      children: [
                        SizedBox(
                          width: 12.sp,
                          height: 12.sp,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          'Loading historical data...',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              // Enhanced period selector
              Container(
                padding: EdgeInsets.all(0.5.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      TimePeriod.values.map((period) {
                        final isSelected = period == _selectedPeriod;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPeriod = period;
                            });
                            _generateChartData();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.w,
                              vertical: 0.5.h,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getPeriodText(period),
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // P&L Display with enhanced persistence indicators
          Row(
            children: [
              CustomIconWidget(
                iconName: isProfit ? 'trending_up' : 'trending_down',
                color: _getChartColor(),
                size: 24,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Profit & Loss',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 2.w,
                            vertical: 0.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield,
                                size: 10.sp,
                                color: theme.colorScheme.primary,
                              ),
                              SizedBox(width: 1.w),
                              Text(
                                'Protected',
                                style: GoogleFonts.inter(
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 0.5.h),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        '${isProfit ? '+' : ''}\$${profitLoss.abs().toStringAsFixed(2)}',
                        key: ValueKey('profit_loss_$profitLoss'),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                          color: _getChartColor(),
                        ),
                      ),
                    ),
                    if (widget.percentageChange != 0.0) ...[
                      SizedBox(height: 0.5.h),
                      Text(
                        '${isProfit ? '+' : ''}${widget.percentageChange.toStringAsFixed(2)}%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: _getChartColor().withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),

          // Enhanced Chart Display
          SizedBox(
            height: 25.h,
            child:
                _chartData.isNotEmpty
                    ? LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _getHorizontalInterval(),
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.2,
                              ),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 15.w,
                              interval: _getHorizontalInterval(),
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '\$${value.toStringAsFixed(0)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 4.h,
                              interval:
                                  _chartData.length > 12
                                      ? (_chartData.length / 6).ceilToDouble()
                                      : 1,
                              getTitlesWidget: (value, meta) {
                                if (value < 0 || value >= _chartData.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: EdgeInsets.only(top: 1.h),
                                  child: Text(
                                    _formatXAxisLabel(value),
                                    style: GoogleFonts.inter(
                                      fontSize: 9.sp,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (_chartData.length - 1).toDouble(),
                        minY: _getMinY(),
                        maxY: _getMaxY(),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _chartData,
                            isCurved: true,
                            gradient: LinearGradient(
                              colors: [
                                _getChartColor(),
                                _getChartColor().withValues(alpha: 0.7),
                              ],
                            ),
                            barWidth: _usingHistoricalData ? 2.5 : 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show:
                                  _usingHistoricalData &&
                                  _chartData.length <= 30,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 3,
                                  color: _getChartColor(),
                                  strokeWidth: 1,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _getChartColor().withValues(alpha: 0.3),
                                  _getChartColor().withValues(alpha: 0.05),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.show_chart,
                            size: 24.sp,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            'Loading chart data...',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
          SizedBox(height: 2.h),

          // Enhanced Summary Statistics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Invested',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      '\$${widget.totalInvested.toStringAsFixed(2)}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Current Value',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      '\$${widget.totalValue.toStringAsFixed(2)}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'P&L Ratio',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      widget.totalInvested != 0.0
                          ? '${((profitLoss / widget.totalInvested) * 100).toStringAsFixed(1)}%'
                          : '0.0%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: _getChartColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPeriodText(TimePeriod period) {
    switch (period) {
      case TimePeriod.day:
        return '1D';
      case TimePeriod.week:
        return '1W';
      case TimePeriod.month:
        return '1M';
      case TimePeriod.year:
        return '1Y';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
