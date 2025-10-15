import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum CustomAppBarVariant {
  standard,
  centered,
  minimal,
  withSearch,
  withProfile,
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final CustomAppBarVariant variant;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool centerTitle;
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;
  final String? profileImageUrl;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    this.title,
    this.variant = CustomAppBarVariant.standard,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle = false,
    this.onSearchTap,
    this.onProfileTap,
    this.profileImageUrl,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      title: _buildTitle(context),
      centerTitle: _getCenterTitle(),
      leading: _buildLeading(context),
      actions: _buildActions(context),
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? theme.appBarTheme.backgroundColor,
      foregroundColor: foregroundColor ?? theme.appBarTheme.foregroundColor,
      elevation: elevation ?? 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      titleTextStyle: GoogleFonts.inter(
        fontSize: _getTitleFontSize(),
        fontWeight: FontWeight.w600,
        color: foregroundColor ?? theme.appBarTheme.foregroundColor,
      ),
    );
  }

  Widget? _buildTitle(BuildContext context) {
    switch (variant) {
      case CustomAppBarVariant.minimal:
        return null;
      case CustomAppBarVariant.withProfile:
        return Row(
          children: [
            Text(
              title ?? 'Portfolio',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _buildProfileButton(context),
          ],
        );
      default:
        return title != null ? Text(title!) : null;
    }
  }

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading;

    if (showBackButton ||
        (automaticallyImplyLeading && Navigator.canPop(context))) {
      return IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed: onBackPressed ?? () => Navigator.pop(context),
        tooltip: 'Back',
      );
    }

    return null;
  }

  List<Widget>? _buildActions(BuildContext context) {
    final theme = Theme.of(context);
    List<Widget> actionWidgets = [];

    switch (variant) {
      case CustomAppBarVariant.withSearch:
        actionWidgets.add(
          IconButton(
            icon: const Icon(Icons.search, size: 24),
            onPressed: onSearchTap ?? () => _navigateToSearch(context),
            tooltip: 'Search',
          ),
        );
        break;
      case CustomAppBarVariant.withProfile:
        // Profile is handled in title for this variant
        break;
      default:
        break;
    }

    // Add custom actions if provided
    if (actions != null) {
      actionWidgets.addAll(actions!);
    }

    // Add default actions based on current route
    final currentRoute = ModalRoute.of(context)?.settings.name;

    if (currentRoute == '/portfolio-dashboard') {
      actionWidgets.addAll([
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 24),
          onPressed: () => _showNotifications(context),
          tooltip: 'Notifications',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 24),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          tooltip: 'Settings',
        ),
      ]);
    } else if (currentRoute == '/cryptocurrency-detail') {
      actionWidgets.addAll([
        IconButton(
          icon: const Icon(Icons.star_border, size: 24),
          onPressed: () => _toggleFavorite(context),
          tooltip: 'Add to favorites',
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, size: 24),
          onPressed: () => _shareAsset(context),
          tooltip: 'Share',
        ),
      ]);
    } else if (currentRoute == '/edit-transaction') {
      actionWidgets.add(
        TextButton(
          onPressed: () => _saveTransaction(context),
          child: Text(
            'Save',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }

    return actionWidgets.isNotEmpty ? actionWidgets : null;
  }

  Widget _buildProfileButton(BuildContext context) {
    return GestureDetector(
      onTap: onProfileTap ?? () => _navigateToProfile(context),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: profileImageUrl != null
            ? ClipOval(
                child: Image.network(
                  profileImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildDefaultAvatar(context),
                ),
              )
            : _buildDefaultAvatar(context),
      ),
    );
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return Icon(
      Icons.person_outline,
      size: 18,
      color: Theme.of(context).colorScheme.primary,
    );
  }

  bool _getCenterTitle() {
    switch (variant) {
      case CustomAppBarVariant.centered:
        return true;
      case CustomAppBarVariant.minimal:
        return false;
      default:
        return centerTitle;
    }
  }

  double _getTitleFontSize() {
    switch (variant) {
      case CustomAppBarVariant.minimal:
        return 16;
      case CustomAppBarVariant.withProfile:
        return 20;
      default:
        return 18;
    }
  }

  // Navigation methods
  void _navigateToSearch(BuildContext context) {
    // Implement search functionality
    showSearch(
      context: context,
      delegate: _CryptoSearchDelegate(),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.pushNamed(context, '/settings');
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationBottomSheet(),
    );
  }

  void _toggleFavorite(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to favorites'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareAsset(BuildContext context) {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _saveTransaction(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction saved successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Search delegate for cryptocurrency search
class _CryptoSearchDelegate extends SearchDelegate<String> {
  final List<String> _cryptos = [
    'Bitcoin (BTC)',
    'Ethereum (ETH)',
    'Cardano (ADA)',
    'Polkadot (DOT)',
    'Chainlink (LINK)',
  ];

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = _cryptos
        .where((crypto) => crypto.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.currency_bitcoin),
          title: Text(results[index]),
          onTap: () {
            close(context, results[index]);
          },
        );
      },
    );
  }
}

// Notification bottom sheet
class _NotificationBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Mark all read',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.trending_up,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Bitcoin price alert',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'BTC has increased by 5% in the last hour',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: Text(
                    '2m ago',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
