import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum CustomBottomBarVariant {
  standard,
  floating,
  minimal,
  withFab,
}

class CustomBottomBar extends StatefulWidget {
  final CustomBottomBarVariant variant;
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double? elevation;
  final bool showLabels;
  final EdgeInsets? margin;

  const CustomBottomBar({
    super.key,
    this.variant = CustomBottomBarVariant.standard,
    this.currentIndex = 0,
    this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.elevation,
    this.showLabels = true,
    this.margin,
  });

  @override
  State<CustomBottomBar> createState() => _CustomBottomBarState();
}

class _CustomBottomBarState extends State<CustomBottomBar>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  final List<_BottomBarItem> _items = [
    _BottomBarItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Portfolio',
      route: '/portfolio-dashboard',
    ),
    _BottomBarItem(
      icon: Icons.currency_bitcoin_outlined,
      activeIcon: Icons.currency_bitcoin,
      label: 'Markets',
      route: '/cryptocurrency-detail',
    ),
    _BottomBarItem(
      icon: Icons.add_circle_outline,
      activeIcon: Icons.add_circle,
      label: 'Add',
      route: '/edit-transaction',
    ),
    _BottomBarItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
      route: '/settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.variant) {
      case CustomBottomBarVariant.floating:
        return _buildFloatingBottomBar(context);
      case CustomBottomBarVariant.minimal:
        return _buildMinimalBottomBar(context);
      case CustomBottomBarVariant.withFab:
        return _buildBottomBarWithFab(context);
      default:
        return _buildStandardBottomBar(context);
    }
  }

  Widget _buildStandardBottomBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ??
            theme.bottomNavigationBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == widget.currentIndex;

              return _buildBottomBarItem(
                context,
                item,
                index,
                isSelected,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBottomBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: widget.margin ?? const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: widget.backgroundColor ??
                theme.bottomNavigationBarTheme.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = index == widget.currentIndex;

                  return _buildBottomBarItem(
                    context,
                    item,
                    index,
                    isSelected,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalBottomBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ??
            theme.bottomNavigationBarTheme.backgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == widget.currentIndex;

              return _buildMinimalBottomBarItem(
                context,
                item,
                index,
                isSelected,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarWithFab(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ??
            theme.bottomNavigationBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ..._items.take(2).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = index == widget.currentIndex;

                return _buildBottomBarItem(
                  context,
                  item,
                  index,
                  isSelected,
                );
              }),
              _buildFabButton(context),
              ..._items.skip(3).toList().asMap().entries.map((entry) {
                final index = entry.key + 3;
                final item = entry.value;
                final isSelected = index == widget.currentIndex;

                return _buildBottomBarItem(
                  context,
                  item,
                  index,
                  isSelected,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarItem(
    BuildContext context,
    _BottomBarItem item,
    int index,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final selectedColor = widget.selectedItemColor ??
        theme.bottomNavigationBarTheme.selectedItemColor;
    final unselectedColor = widget.unselectedItemColor ??
        theme.bottomNavigationBarTheme.unselectedItemColor;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(context, index, item.route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? selectedColor?.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  size: 24,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
              ),
              if (widget.showLabels) ...[
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? selectedColor : unselectedColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalBottomBarItem(
    BuildContext context,
    _BottomBarItem item,
    int index,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final selectedColor = widget.selectedItemColor ??
        theme.bottomNavigationBarTheme.selectedItemColor;
    final unselectedColor = widget.unselectedItemColor ??
        theme.bottomNavigationBarTheme.unselectedItemColor;

    return GestureDetector(
      onTap: () => _onItemTapped(context, index, item.route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor?.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              size: 20,
              color: isSelected ? selectedColor : unselectedColor,
            ),
            if (isSelected && widget.showLabels) ...[
              const SizedBox(width: 8),
              Text(
                item.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selectedColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFabButton(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.secondary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _onItemTapped(context, 2, '/edit-transaction'),
          child: Icon(
            Icons.add,
            size: 28,
            color: theme.colorScheme.onSecondary,
          ),
        ),
      ),
    );
  }

  void _onItemTapped(BuildContext context, int index, String route) {
    if (index == widget.currentIndex) return;

    HapticFeedback.lightImpact();

    // Trigger animation
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Call the onTap callback
    widget.onTap?.call(index);

    // Navigate to the route
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute != route) {
      Navigator.pushReplacementNamed(context, route);
    }
  }
}

class _BottomBarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _BottomBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}