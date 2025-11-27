import 'package:flutter/material.dart';
import 'package:spark_app/core/auth/services/comprehensive_permission_service.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Service to handle subscription access checks and show upgrade prompts
class SubscriptionAccessService {
  final ComprehensivePermissionService _permissionService;

  SubscriptionAccessService({
    ComprehensivePermissionService? permissionService,
  }) : _permissionService = permissionService ?? ComprehensivePermissionService();

  /// Check if user has access to admin drills, show snackbar if not
  Future<bool> checkAdminDrillsAccess(BuildContext context) async {
    final hasAccess = await _permissionService.canAccessAdminDrills();
    
    if (!hasAccess) {
      _showUpgradeSnackbar(
        context,
        'Premium Content',
        'Upgrade to access admin-created drills and advanced features',
        'admin_drills',
      );
      return false;
    }
    
    return true;
  }

  /// Check if user has access to admin programs, show snackbar if not
  Future<bool> checkAdminProgramsAccess(BuildContext context) async {
    final hasAccess = await _permissionService.canAccessAdminPrograms();
    
    if (!hasAccess) {
      _showUpgradeSnackbar(
        context,
        'Premium Content',
        'Upgrade to access admin-created programs and training plans',
        'admin_programs',
      );
      return false;
    }
    
    return true;
  }

  /// Check if user has access to multiplayer features, show snackbar if not
  Future<bool> checkMultiplayerAccess(BuildContext context) async {
    final hasAccess = await _permissionService.canAccessMultiplayer();
    
    if (!hasAccess) {
      _showUpgradeSnackbar(
        context,
        'Multiplayer Features',
        'Upgrade to access multiplayer sessions and team training',
        'multiplayer',
      );
      return false;
    }
    
    return true;
  }

  /// Check if user has access to host sessions, show snackbar if not
  Future<bool> checkHostSessionsAccess(BuildContext context) async {
    final hasAccess = await _permissionService.canHostSessions();
    
    if (!hasAccess) {
      _showUpgradeSnackbar(
        context,
        'Host Sessions',
        'Upgrade to host multiplayer sessions and manage teams',
        'multiplayer',
      );
      return false;
    }
    
    return true;
  }

  /// Check if user has access to user management, show snackbar if not
  Future<bool> checkUserManagementAccess(BuildContext context) async {
    final hasAccess = await _permissionService.canManageUsers();
    
    if (!hasAccess) {
      _showUpgradeSnackbar(
        context,
        'User Management',
        'Upgrade to Institute plan to manage users and teams',
        'user_management',
      );
      return false;
    }
    
    return true;
  }

  /// Check if user has access to team management, show snackbar if not
  Future<bool> checkTeamManagementAccess(BuildContext context) async {
    final hasAccess = await _permissionService.canManageTeams();
    
    if (!hasAccess) {
      _showUpgradeSnackbar(
        context,
        'Team Management',
        'Upgrade to manage teams and group training sessions',
        'team_management',
      );
      return false;
    }
    
    return true;
  }

  /// Check if user has access to bulk operations, show snackbar if not
  Future<bool> checkBulkOperationsAccess(BuildContext context) async {
    final hasAccess = await _permissionService.canPerformBulkOperations();
    
    if (!hasAccess) {
      _showUpgradeSnackbar(
        context,
        'Bulk Operations',
        'Upgrade to perform bulk operations and advanced management',
        'bulk_operations',
      );
      return false;
    }
    
    return true;
  }

  /// Generic method to check any module access
  Future<bool> checkModuleAccess(BuildContext context, String module) async {
    final hasAccess = await _permissionService.hasModuleAccess(module);
    
    if (!hasAccess) {
      final moduleInfo = _getModuleInfo(module);
      _showUpgradeSnackbar(
        context,
        moduleInfo['title']!,
        moduleInfo['message']!,
        module,
      );
      return false;
    }
    
    return true;
  }

  /// Show upgrade snackbar with subscription prompt
  void _showUpgradeSnackbar(
    BuildContext context,
    String title,
    String message,
    String requiredModule,
  ) {
    AppLogger.info('Showing upgrade prompt for module: $requiredModule', tag: 'SubscriptionAccess');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Upgrade',
          textColor: Colors.white,
          onPressed: () => _navigateToSubscription(context),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Navigate to subscription screen
  void _navigateToSubscription(BuildContext context) {
    Navigator.of(context).pushNamed('/subscription');
  }

  /// Get module information for display
  Map<String, String> _getModuleInfo(String module) {
    switch (module) {
      case 'admin_drills':
        return {
          'title': 'Premium Drills',
          'message': 'Upgrade to access professional drills created by experts',
        };
      case 'admin_programs':
        return {
          'title': 'Premium Programs',
          'message': 'Upgrade to access professional training programs',
        };
      case 'multiplayer':
        return {
          'title': 'Multiplayer Features',
          'message': 'Upgrade to join multiplayer sessions and team training',
        };
      case 'user_management':
        return {
          'title': 'User Management',
          'message': 'Upgrade to Institute plan to manage users and permissions',
        };
      case 'team_management':
        return {
          'title': 'Team Management',
          'message': 'Upgrade to create and manage training teams',
        };
      case 'bulk_operations':
        return {
          'title': 'Bulk Operations',
          'message': 'Upgrade to perform bulk operations and advanced management',
        };
      default:
        return {
          'title': 'Premium Feature',
          'message': 'Upgrade your subscription to access this feature',
        };
    }
  }

  /// Check if user should see premium content (for UI filtering)
  Future<bool> shouldShowPremiumContent(String contentType) async {
    switch (contentType) {
      case 'admin_drills':
        return await _permissionService.canAccessAdminDrills();
      case 'admin_programs':
        return await _permissionService.canAccessAdminPrograms();
      case 'multiplayer':
        return await _permissionService.canAccessMultiplayer();
      default:
        return false;
    }
  }

  /// Get user's subscription level for UI customization
  Future<String> getUserSubscriptionLevel() async {
    final isAdmin = await _permissionService.isAdmin();
    if (isAdmin) return 'institute';

    final hasMultiplayer = await _permissionService.canAccessMultiplayer();
    if (hasMultiplayer) return 'premium';

    return 'free';
  }
}