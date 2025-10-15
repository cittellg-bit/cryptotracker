import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class PriceChartWidget extends StatefulWidget {
  final Map<String, dynamic> coinData;

  const PriceChartWidget({super.key, required this.coinData});

  @override
  State<PriceChartWidget> createState() => _PriceChartWidgetState();
}

class _PriceChartWidgetState extends State<PriceChartWidget> {
  int selectedTimeRange = 1; // 0: 1D, 1: 1W, 2: 1M, 3: 3M, 4: 1Y
  final List<String> timeRanges = ['1D', '1W', '1M', '3M', '1Y'];

  // Mock chart data - in real app this would come from API
  final List<List<FlSpot>> chartDataSets = [
    // 1D data
    [
      FlSpot(0, 43250.50),
      FlSpot(1, 43180.25),
      FlSpot(2, 43320.75),
      FlSpot(3, 43450.30),
      FlSpot(4, 43380.60),
      FlSpot(5, 43520.90),
      FlSpot(6, 43680.15),
      FlSpot(7, 43750.40),
      FlSpot(8, 43820.85),
      FlSpot(9, 43900.20),
      FlSpot(10, 44050.75),
      FlSpot(11, 44180.30),
      FlSpot(12, 44250.60),
      FlSpot(13, 44320.90),
      FlSpot(14, 44450.25),
      FlSpot(15, 44580.70),
      FlSpot(16, 44650.15),
      FlSpot(17, 44720.50),
      FlSpot(18, 44850.85),
      FlSpot(19, 44920.20),
      FlSpot(20, 45050.75),
      FlSpot(21, 45180.30),
      FlSpot(22, 45250.60),
      FlSpot(23, 45320.90),
    ],
    // 1W data
    [
      FlSpot(0, 42500.00),
      FlSpot(1, 43200.50),
      FlSpot(2, 43800.75),
      FlSpot(3, 44100.25),
      FlSpot(4, 44500.80),
      FlSpot(5, 45000.30),
      FlSpot(6, 45320.90),
    ],
    // 1M data
    [
      FlSpot(0, 38500.00),
      FlSpot(5, 39200.50),
      FlSpot(10, 40800.75),
      FlSpot(15, 42100.25),
      FlSpot(20, 43500.80),
      FlSpot(25, 44000.30),
      FlSpot(30, 45320.90),
    ],
    // 3M data
    [
      FlSpot(0, 35000.00),
      FlSpot(15, 37500.50),
      FlSpot(30, 40000.75),
      FlSpot(45, 42500.25),
      FlSpot(60, 44000.80),
      FlSpot(75, 45000.30),
      FlSpot(90, 45320.90),
    ],
    // 1Y data
    [
      FlSpot(0, 28000.00),
      FlSpot(60, 32000.50),
      FlSpot(120, 38000.75),
      FlSpot(180, 42000.25),
      FlSpot(240, 44500.80),
      FlSpot(300, 45000.30),
      FlSpot(365, 45320.90),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentData = chartDataSets[selectedTimeRange];
    final isPositiveTrend = currentData.last.y > currentData.first.y;

    return Container(
      width: double.infinity,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Price Chart",
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              CustomIconWidget(
                iconName: 'fullscreen',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildTimeRangeSelector(theme),
          SizedBox(height: 3.h),
          Container(
            height: 25.h,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getOptimalHorizontalInterval(
                    currentData,
                  ),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _getBottomInterval(currentData),
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: AxisSide.bottom,
                          child: Text(
                            _getBottomTitle(value.toInt()),
                            style: GoogleFonts.inter(
                              fontSize: 9.sp,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _getOptimalHorizontalInterval(currentData),
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: AxisSide.left,
                          child: Text(
                            '\${_formatCurrencyValue(value)}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: currentData,
                    isCurved: true,
                    color: isPositiveTrend ? Colors.green : Colors.red,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: (isPositiveTrend ? Colors.green : Colors.red)
                          .withValues(alpha: 0.1),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minY: _getChartMinY(currentData),
                maxY: _getChartMaxY(currentData),
              ),
            ),
          ),
          SizedBox(height: 2.h),
          _buildChartStats(theme, currentData, isPositiveTrend),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector(ThemeData theme) {
    return Container(
      height: 4.h,
      child: Row(
        children:
            timeRanges.asMap().entries.map((entry) {
              final index = entry.key;
              final range = entry.value;
              final isSelected = index == selectedTimeRange;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      selectedTimeRange = index;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 1.w),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        range,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color:
                              isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildChartStats(ThemeData theme, List<FlSpot> data, bool isPositive) {
    final change = data.last.y - data.first.y;
    final changePercent = (change / data.first.y) * 100;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Period Change",
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                "${isPositive ? '+' : ''}\$${_formatCurrencyValue(change.abs())}",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: isPositive ? Colors.green : Colors.red,
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
                "Percentage",
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                "${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: isPositive ? Colors.green : Colors.red,
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
                "High",
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                "\$${_formatCurrencyValue(_getMaxY(data))}",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _getMinY(List<FlSpot> data) {
    double min = data.first.y;
    for (var spot in data) {
      if (spot.y < min) min = spot.y;
    }
    return min;
  }

  double _getMaxY(List<FlSpot> data) {
    double max = data.first.y;
    for (var spot in data) {
      if (spot.y > max) max = spot.y;
    }
    return max;
  }

  double _getChartMinY(List<FlSpot> data) {
    return _getMinY(data) * 0.998; // Add small padding for chart boundaries
  }

  double _getChartMaxY(List<FlSpot> data) {
    return _getMaxY(data) * 1.002; // Add small padding for chart boundaries
  }

  double _getOptimalHorizontalInterval(List<FlSpot> data) {
    final range = _getMaxY(data) - _getMinY(data);
    final numberOfLines = 4;
    final rawInterval = range / numberOfLines;

    // Round to nice numbers for better readability
    if (rawInterval >= 10000) {
      // For large numbers, round to nearest 5000 or 10000
      return (rawInterval / 5000).round() * 5000.0;
    } else if (rawInterval >= 1000) {
      // For medium numbers, round to nearest 1000 or 500
      return (rawInterval / 500).round() * 500.0;
    } else if (rawInterval >= 100) {
      // For smaller numbers, round to nearest 100 or 50
      return (rawInterval / 50).round() * 50.0;
    } else if (rawInterval >= 10) {
      // For very small numbers, round to nearest 10 or 5
      return (rawInterval / 5).round() * 5.0;
    } else {
      // For decimal numbers, round to nearest 1
      return rawInterval.roundToDouble();
    }
  }

  double _getBottomInterval(List<FlSpot> data) {
    final range = data.last.x - data.first.x;
    return range / 4; // Show 4 bottom labels
  }

  String _getBottomTitle(int value) {
    switch (selectedTimeRange) {
      case 0: // 1D
        return "${value}h";
      case 1: // 1W
        return "Day ${value + 1}";
      case 2: // 1M
        return "${value + 1}";
      case 3: // 3M
        return "${value + 1}";
      case 4: // 1Y
        return "${value + 1}";
      default:
        return "$value";
    }
  }

  String _formatCurrencyValue(double price) {
    if (price >= 1000000) {
      // Format millions (e.g., 1.2M)
      return "${(price / 1000000).toStringAsFixed(1)}M";
    } else if (price >= 100000) {
      // Format hundreds of thousands (e.g., 450K)
      return "${(price / 1000).toStringAsFixed(0)}K";
    } else if (price >= 10000) {
      // Format tens of thousands (e.g., 45.2K)
      return "${(price / 1000).toStringAsFixed(1)}K";
    } else if (price >= 1000) {
      // Format thousands (e.g., 4.52K or 4520 if no decimals needed)
      final inK = price / 1000;
      if (inK % 1 == 0) {
        return "${inK.toStringAsFixed(0)}K";
      } else {
        return "${inK.toStringAsFixed(1)}K";
      }
    } else if (price >= 100) {
      // Format hundreds without decimals (e.g., 450)
      return price.toStringAsFixed(0);
    } else if (price >= 10) {
      // Format tens with 1 decimal (e.g., 45.2)
      return price.toStringAsFixed(1);
    } else if (price >= 1) {
      // Format units with 2 decimals (e.g., 4.52)
      return price.toStringAsFixed(2);
    } else {
      // Format decimals with appropriate precision (e.g., 0.0045)
      if (price >= 0.01) {
        return price.toStringAsFixed(2);
      } else if (price >= 0.001) {
        return price.toStringAsFixed(3);
      } else {
        return price.toStringAsFixed(4);
      }
    }
  }
}