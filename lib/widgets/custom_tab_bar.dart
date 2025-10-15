import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum CustomTabBarVariant {
  standard,
  pills,
  underline,
  segmented,
  scrollable,
}

class CustomTabBar extends StatefulWidget {
  final List<String> tabs;
  final CustomTabBarVariant variant;
  final int initialIndex;
  final ValueChanged<int>? onTap;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? indicatorColor;
  final EdgeInsets? padding;
  final bool isScrollable;
  final double? height;

  const CustomTabBar({
    super.key,
    required this.tabs,
    this.variant = CustomTabBarVariant.standard,
    this.initialIndex = 0,
    this.onTap,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedColor,
    this.indicatorColor,
    this.padding,
    this.isScrollable = false,
    this.height,
  });

  @override
  State<CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tabs.length,
      initialIndex: widget.initialIndex,
      vsync: this,
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.lightImpact();
        widget.onTap?.call(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.variant) {
      case CustomTabBarVariant.pills:
        return _buildPillsTabBar(context);
      case CustomTabBarVariant.underline:
        return _buildUnderlineTabBar(context);
      case CustomTabBarVariant.segmented:
        return _buildSegmentedTabBar(context);
      case CustomTabBarVariant.scrollable:
        return _buildScrollableTabBar(context);
      default:
        return _buildStandardTabBar(context);
    }
  }

  Widget _buildStandardTabBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: widget.height ?? 48,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: widget.isScrollable,
        labelColor: widget.selectedColor ?? theme.colorScheme.primary,
        unselectedLabelColor: widget.unselectedColor ??
            theme.colorScheme.onSurface.withValues(alpha: 0.6),
        indicatorColor: widget.indicatorColor ?? theme.colorScheme.primary,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: widget.tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildPillsTabBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: widget.height ?? 40,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: widget.tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == _tabController.index;

          return Expanded(
            child: GestureDetector(
              onTap: () => _onTabTapped(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (widget.selectedColor ?? theme.colorScheme.primary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? (widget.selectedColor ?? theme.colorScheme.primary)
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : (widget.unselectedColor ??
                            theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUnderlineTabBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: widget.height ?? 44,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: widget.tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == _tabController.index;

          return Expanded(
            child: GestureDetector(
              onTap: () => _onTabTapped(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? (widget.indicatorColor ?? theme.colorScheme.primary)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? (widget.selectedColor ?? theme.colorScheme.primary)
                        : (widget.unselectedColor ??
                            theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSegmentedTabBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: widget.height ?? 36,
      margin: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: widget.tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == _tabController.index;
          final isFirst = index == 0;
          final isLast = index == widget.tabs.length - 1;

          return Expanded(
            child: GestureDetector(
              onTap: () => _onTabTapped(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (widget.selectedColor ?? theme.colorScheme.primary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(
                    left: isFirst ? const Radius.circular(7) : Radius.zero,
                    right: isLast ? const Radius.circular(7) : Radius.zero,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    tab,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : (widget.unselectedColor ??
                              theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7)),
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

  Widget _buildScrollableTabBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: widget.height ?? 48,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: widget.selectedColor ?? theme.colorScheme.primary,
        unselectedLabelColor: widget.unselectedColor ??
            theme.colorScheme.onSurface.withValues(alpha: 0.6),
        indicatorColor: widget.indicatorColor ?? theme.colorScheme.primary,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        tabs: widget.tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  void _onTabTapped(int index) {
    _tabController.animateTo(index);
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }
}

// Crypto-specific tab bar for portfolio sections
class CryptoTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const CryptoTabBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = ['Overview', 'Holdings', 'Transactions', 'Analytics'];

    return CustomTabBar(
      tabs: tabs,
      variant: CustomTabBarVariant.underline,
      initialIndex: currentIndex,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

// Market data tab bar
class MarketTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const MarketTabBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = ['Price', 'Chart', 'News', 'Stats'];

    return CustomTabBar(
      tabs: tabs,
      variant: CustomTabBarVariant.pills,
      initialIndex: currentIndex,
      onTap: onTap,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

// Time period tab bar for charts
class TimePeriodTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const TimePeriodTabBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = ['1H', '1D', '1W', '1M', '3M', '1Y', 'ALL'];

    return CustomTabBar(
      tabs: tabs,
      variant: CustomTabBarVariant.segmented,
      initialIndex: currentIndex,
      onTap: onTap,
      height: 32,
      isScrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
