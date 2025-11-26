import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/auth/services/permission_manager.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/features/admin/ui/user_management_screen.dart';
import 'package:spark_app/features/admin/ui/subscription_management_screen.dart';
import 'package:spark_app/features/admin/ui/plan_requests_screen.dart';
import 'package:spark_app/features/admin/ui/category_management_screen.dart';
import 'package:spark_app/features/admin/ui/stimulus_management_screen.dart';
import 'package:spark_app/features/admin/ui/screens/comprehensive_activity_screen.dart';
import 'package:spark_app/core/widgets/feature_not_available_dialog.dart';

/// User-accessible admin dashboard that shows only modules they have access to
class UserAdminDashboardScreen extends StatelessWidget {
  const UserAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Admin Tools'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildAdminModulesGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.goldPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.admin_panel_settings,
                color: AppTheme.goldPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Tools',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Access administrative features based on your permissions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminModulesGrid(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Define all admin modules with their details
    final adminModules = [
      _AdminModule(
        title: 'User Management',
        description: 'Manage users, roles & permissions',
        icon: Icons.people_outline,
        color: AppTheme.infoColor,
        permission: 'admin_user_management',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserManagementScreen(),
          ),
        ),
      ),
      _AdminModule(
        title: 'Subscriptions',
        description: 'Manage plans & pricing',
        icon: Icons.card_membership_outlined,
        color: AppTheme.successColor,
        permission: 'admin_subscription_management',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SubscriptionManagementScreen(),
          ),
        ),
      ),
      _AdminModule(
        title: 'Plan Requests',
        description: 'Review subscription requests',
        icon: Icons.receipt_long_outlined,
        color: AppTheme.warningColor,
        permission: 'admin_plan_requests',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlanRequestsScreen(),
          ),
        ),
      ),
      _AdminModule(
        title: 'Drill Categories',
        description: 'Manage drill categories',
        icon: Icons.category_outlined,
        color: AppTheme.infoColor,
        permission: 'admin_category_management',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CategoryManagementScreen(),
          ),
        ),
      ),
      _AdminModule(
        title: 'Stimulus Management',
        description: 'Manage custom stimuli',
        icon: Icons.auto_awesome_outlined,
        color: AppTheme.instituteColor,
        permission: 'admin_stimulus_management',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StimulusManagementScreen(),
          ),
        ),
      ),
      _AdminModule(
        title: 'Activity Monitor',
        description: 'View system activities',
        icon: Icons.timeline,
        color: Colors.red,
        permission: 'admin_comprehensive_activity',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ComprehensiveActivityScreen(),
          ),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Admin Modules',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: adminModules.length,
          itemBuilder: (context, index) {
            final module = adminModules[index];
            return _buildAdminModuleCard(context, module);
          },
        ),
      ],
    );
  }

  Widget _buildAdminModuleCard(BuildContext context, _AdminModule module) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final permissionManager = PermissionManager.instance;

    // Check if user has access to this module
    final hasAccess = permissionManager.isAdmin || 
                     permissionManager.hasModuleAccess(module.permission);

    return InkWell(
      onTap: () {
        if (hasAccess) {
          // User has access, navigate to the module
          module.onTap();
        } else {
          // User doesn't have access, show upgrade dialog
          FeatureNotAvailableDialog.show(
            context,
            featureName: module.title,
            description: module.description,
            onUpgradePressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/subscription');
            },
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasAccess 
                ? module.color.withOpacity(0.3)
                : colorScheme.outline.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: hasAccess 
                  ? module.color.withOpacity(0.1)
                  : Colors.transparent,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and access indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasAccess 
                        ? module.color.withOpacity(0.15)
                        : colorScheme.outline.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    module.icon,
                    color: hasAccess 
                        ? module.color
                        : colorScheme.outline,
                    size: 20,
                  ),
                ),
                // Access indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasAccess 
                        ? AppTheme.successColor.withOpacity(0.1)
                        : AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasAccess 
                          ? AppTheme.successColor.withOpacity(0.3)
                          : AppTheme.warningColor.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    hasAccess ? Icons.check : Icons.lock,
                    size: 12,
                    color: hasAccess 
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Title
            Text(
              module.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: hasAccess 
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            // Description
            Text(
              module.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasAccess 
                    ? colorScheme.onSurface.withOpacity(0.7)
                    : colorScheme.onSurface.withOpacity(0.5),
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 8),
            
            // Access status
            Row(
              children: [
                Icon(
                  hasAccess ? Icons.check_circle : Icons.upgrade,
                  size: 14,
                  color: hasAccess 
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hasAccess ? 'Available' : 'Upgrade Required',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: hasAccess 
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminModule {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String permission;
  final VoidCallback onTap;

  const _AdminModule({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.permission,
    required this.onTap,
  });
}