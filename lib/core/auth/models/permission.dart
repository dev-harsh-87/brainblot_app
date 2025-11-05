import 'package:spark_app/core/auth/models/user_role.dart';

/// System permissions for fine-grained access control
/// Note: Module access is now controlled by subscription plans, not permissions
/// Permissions are only for system administration features
enum Permission {
  // Admin only permissions
  manageUsers('manage_users', 'Manage Users', [UserRole.admin]),
  manageSubscriptions('manage_subscriptions', 'Manage Subscriptions', [UserRole.admin]),
  managePlans('manage_plans', 'Manage Plans', [UserRole.admin]),
  viewAnalytics('view_analytics', 'View Analytics', [UserRole.admin]),
  manageSettings('manage_settings', 'Manage Settings', [UserRole.admin]),
  
  // System operations (Admin only)
  systemConfiguration('system_configuration', 'System Configuration', [UserRole.admin]),
  userRoleManagement('user_role_management', 'User Role Management', [UserRole.admin]),
  databaseAccess('database_access', 'Database Access', [UserRole.admin]);

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