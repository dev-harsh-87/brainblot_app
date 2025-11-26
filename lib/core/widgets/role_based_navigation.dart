import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/auth/models/user_role.dart';

/// Role-based navigation widget that adapts based on user permissions
class RoleBasedNavigation extends StatelessWidget {
  final AppUser user;
  final String currentRoute;

  const RoleBasedNavigation({
    super.key,
    required this.user,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigationItems = _getNavigationItems();
    
    return Container(
      decoration: BoxDecoration(
        color: theme.bottomNavigationBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: context.colors.onSurface.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing8,
            vertical: AppTheme.spacing4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: navigationItems.map((item) {
              final isSelected = currentRoute.startsWith(item.route);
              
              return Expanded(
                child: _NavItem(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => context.go(item.route),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<NavigationItem> _getNavigationItems() {
    final List<NavigationItem> items = [
      NavigationItem(
        route: '/home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Home',
      ),
      NavigationItem(
        route: '/drills',
        icon: Icons.fitness_center_outlined,
        selectedIcon: Icons.fitness_center,
        label: 'Drills',
      ),
      NavigationItem(
        route: '/training',
        icon: Icons.play_circle_outline,
        selectedIcon: Icons.play_circle,
        label: 'Training',
      ),
    ];

    // Add subscription-based features
    // Use actual user subscription data instead of hardcoded plans
    
    if (user.subscription.moduleAccess.contains('programs')) {
      items.add(NavigationItem(
        route: '/programs',
        icon: Icons.schedule_outlined,
        selectedIcon: Icons.schedule,
        label: 'Programs',
        requiresSubscription: true,
      ),);
    }

    if (user.subscription.moduleAccess.contains('multiplayer')) {
      items.add(NavigationItem(
        route: '/multiplayer',
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: 'Multiplayer',
        requiresSubscription: true,
      ),);
    }

    // Add stats for all users
    items.add(NavigationItem(
      route: '/stats',
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Stats',
    ),);

    // Add admin navigation if user is admin or has any admin module access
    final hasAnyAdminAccess = user.role.isAdmin() ||
        user.subscription.moduleAccess.any((module) => module.startsWith('admin_'));
    
    if (hasAnyAdminAccess) {
      items.add(NavigationItem(
        route: '/admin',
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings,
        label: 'Admin',
        isAdminOnly: true,
      ),);
    }

    return items;
  }
}

class _NavItem extends StatelessWidget {
  final NavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = item.isAdminOnly 
        ? AppTheme.adminColor 
        : isSelected 
            ? AppTheme.goldPrimary 
            : AppTheme.neutral400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      splashColor: effectiveColor.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing8,
          vertical: AppTheme.spacing12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: isSelected ? BoxDecoration(
                color: effectiveColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ) : null,
              child: Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: effectiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              item.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: effectiveColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.requiresSubscription && !item.isAdminOnly) ...[
              const SizedBox(height: AppTheme.spacing4),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.goldBright,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Navigation item data model
class NavigationItem {
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool requiresSubscription;
  final bool isAdminOnly;

  const NavigationItem({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.requiresSubscription = false,
    this.isAdminOnly = false,
  });
}