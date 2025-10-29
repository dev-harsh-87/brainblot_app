import 'package:brainblot_app/core/auth/models/user_role.dart';

/// System permissions for fine-grained access control
/// Note: Module access is now controlled by subscription plans, not permissions
/// Permissions are only for system administration features
enum Permission {
  // Super Admin only permissions
  manageUsers('manage_users', 'Manage Users', [UserRole.superAdmin]),
  manageSubscriptions('manage_subscriptions', 'Manage Subscriptions', [UserRole.superAdmin]),
  managePlans('manage_plans', 'Manage Plans', [UserRole.superAdmin]),
  viewAnalytics('view_analytics', 'View Analytics', [UserRole.superAdmin]),
  manageSettings('manage_settings', 'Manage Settings', [UserRole.superAdmin]),
  
  // System operations (Super Admin only)
  systemConfiguration('system_configuration', 'System Configuration', [UserRole.superAdmin]),
  userRoleManagement('user_role_management', 'User Role Management', [UserRole.superAdmin]),
  databaseAccess('database_access', 'Database Access', [UserRole.superAdmin]);

  final String value;
  final String displayName;
  final List<UserRole> allowedRoles;

  const Permission(this.value, this.displayName, this.allowedRoles);

  static Permission? fromString(String value) {
    try {
      return Permission.values.firstWhere((perm) => perm.value == value);
    } catch (e) {
      return null;
    }
  }

  bool isGrantedTo(UserRole role) {
    return allowedRoles.contains(role);
  }
}

/// Extension to check permissions on UserRole
extension UserRolePermissions on UserRole {
  bool hasPermission(Permission permission) {
    return permission.isGrantedTo(this);
  }

  List<Permission> get permissions {
    return Permission.values.where((perm) => perm.isGrantedTo(this)).toList();
  }
}