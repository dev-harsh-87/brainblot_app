/// User roles for role-based access control
/// Only 2 roles: Admin for system administration, User for regular users
/// Access to modules is controlled by subscription plans, not roles
enum UserRole {
  /// Admin with full system access and management capabilities
  admin('admin', 'Admin', 100),
  
  /// Standard user - access controlled by subscription plan
  user('user', 'User', 10);

  final String value;
  final String displayName;
  final int priority;

  const UserRole(this.value, this.displayName, this.priority);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.user,
    );
  }

  bool hasPermission(UserRole requiredRole) {
    return priority >= requiredRole.priority;
  }

  bool isAdmin() {
    return this == UserRole.admin;
  }

  bool isUser() {
    return this == UserRole.user;
  }
}