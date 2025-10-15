import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';
import '../routes/app_routes.dart';

class NavigationDropdownWidget extends StatefulWidget {
  final String currentRoute;
  final VoidCallback? onMenuToggle;

  const NavigationDropdownWidget({
    super.key,
    required this.currentRoute,
    this.onMenuToggle,
  });

  @override
  State<NavigationDropdownWidget> createState() =>
      _NavigationDropdownWidgetState();
}

class _NavigationDropdownWidgetState extends State<NavigationDropdownWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isMenuOpen = false;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      title: 'Portfolio Dashboard',
      subtitle: 'View your crypto holdings',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      route: AppRoutes.portfolioDashboard,
    ),
    NavigationItem(
      title: 'Add Transaction',
      subtitle: 'Record new purchases/sales',
      icon: Icons.add_circle_outline,
      activeIcon: Icons.add_circle,
      route: AppRoutes.addTransaction,
    ),
    NavigationItem(
      title: 'Crypto Details',
      subtitle: 'View cryptocurrency information',
      icon: Icons.currency_bitcoin_outlined,
      activeIcon: Icons.currency_bitcoin,
      route: AppRoutes.cryptocurrencyDetail,
    ),
    NavigationItem(
      title: 'Crypto Selector',
      subtitle: 'Browse available cryptocurrencies',
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      route: AppRoutes.cryptoSelector,
    ),
    NavigationItem(
      title: 'Edit Transaction',
      subtitle: 'Modify existing transactions',
      icon: Icons.edit_outlined,
      activeIcon: Icons.edit,
      route: AppRoutes.editTransaction,
    ),
    NavigationItem(
      title: 'Settings',
      subtitle: 'App preferences and configuration',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      route: AppRoutes.settings,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });

    if (_isMenuOpen) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    HapticFeedback.lightImpact();
    widget.onMenuToggle?.call();
  }

  void _navigateToRoute(String route) {
    if (route == widget.currentRoute) {
      _toggleMenu();
      return;
    }

    HapticFeedback.selectionClick();
    _toggleMenu();

    // Delay navigation slightly for smooth animation
    Future.delayed(const Duration(milliseconds: 100), () {
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (Route<dynamic> route) => false,
      );
    });
  }

  NavigationItem get _currentItem {
    return _navigationItems.firstWhere(
      (item) => item.route == widget.currentRoute,
      orElse: () => _navigationItems.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentItem = _currentItem;

    return Stack(
      children: [
        // Menu backdrop
        if (_isMenuOpen)
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value * 0.3,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black,
                ),
              );
            },
          ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Menu trigger button
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 4.w,
                  vertical: 2.h,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isMenuOpen ? currentItem.activeIcon : currentItem.icon,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentItem.title,
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            currentItem.subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w400,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isMenuOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dropdown menu
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  alignment: Alignment.topLeft,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: _isMenuOpen ? child : const SizedBox.shrink(),
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.only(top: 1.h),
                constraints: BoxConstraints(
                  maxWidth: 85.w,
                  maxHeight: 60.h,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Menu header
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.05),
                          border: Border(
                            bottom: BorderSide(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.menu,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              'Navigation Menu',
                              style: GoogleFonts.inter(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_navigationItems.length} screens',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Menu items
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.symmetric(vertical: 2.w),
                          itemCount: _navigationItems.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.1),
                            indent: 4.w,
                            endIndent: 4.w,
                          ),
                          itemBuilder: (context, index) {
                            final item = _navigationItems[index];
                            final isActive = item.route == widget.currentRoute;

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _navigateToRoute(item.route),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4.w,
                                    vertical: 3.w,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? theme.colorScheme.primary
                                            .withValues(alpha: 0.08)
                                        : Colors.transparent,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? theme.colorScheme.primary
                                                  .withValues(alpha: 0.15)
                                              : theme.colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: isActive
                                              ? null
                                              : Border.all(
                                                  color: theme
                                                      .colorScheme.outline
                                                      .withValues(alpha: 0.2),
                                                ),
                                        ),
                                        child: Icon(
                                          isActive
                                              ? item.activeIcon
                                              : item.icon,
                                          color: isActive
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                          size: 18,
                                        ),
                                      ),
                                      SizedBox(width: 3.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: GoogleFonts.inter(
                                                fontSize: 14.sp,
                                                fontWeight: isActive
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: isActive
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                        .colorScheme.onSurface,
                                              ),
                                            ),
                                            SizedBox(height: 0.5.w),
                                            Text(
                                              item.subtitle,
                                              style: GoogleFonts.inter(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w400,
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isActive)
                                        Icon(
                                          Icons.check_circle,
                                          color: theme.colorScheme.primary,
                                          size: 16,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class NavigationItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const NavigationItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}
