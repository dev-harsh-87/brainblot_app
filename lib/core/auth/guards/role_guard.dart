import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/core/auth/models/permission.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/auth/services/permission_service.dart';

/// Enhanced role-based guard for protecting routes and features
class RoleGuard extends StatelessWidget {
  final Widget child;
  final PermissionService permissionService;
  final UserRole? requiredRole;
  final Permission? requiredPermission;
  final String? moduleAccess;
  final Widget? fallback;
  final String? redirectRoute;
  final String? message;

  const RoleGuard({
    super.key,
    required this.child,
    required this.permissionService,
    this.requiredRole,
    this.requiredPermission,
    this.moduleAccess,
    this.fallback,
    this.redirectRoute,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: Text(
                'Error',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              iconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error checking permissions: ${snapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final hasAccess = snapshot.data ?? false;

        if (!hasAccess) {
          // Handle redirection if specified
          if (redirectRoute != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(redirectRoute!);
            });
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          }

          // Return fallback widget if provided
          if (fallback != null) {
            return fallback!;
          }

          // Default access denied screen
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: Text(
                'Access Denied',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              iconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Access Denied',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      message ?? _getDefaultMessage(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Go Back'),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        icon: const Icon(Icons.home),
                        label: const Text('Home'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return child;
      },
    );
  }

  Future<bool> _checkAccess() async {
    try {
      // Check specific permission if provided
      if (requiredPermission != null) {
        return await permissionService.hasPermission(requiredPermission!);
      }
      
      // Check specific role if provided
      if (requiredRole != null) {
        return await permissionService.hasRole(requiredRole!);
      }
      
      // Check module access if provided
      if (moduleAccess != null) {
        return await permissionService.hasModuleAccess(moduleAccess!);
      }
      
      // Default: allow access
      return true;
    } catch (e) {
      // Log error and deny access
      debugPrint('RoleGuard access check error: $e');
      return false;
    }
  }

  String _getDefaultMessage() {
    if (requiredRole != null) {
      return 'You need ${requiredRole!.displayName} privileges to access this feature.';
    }
    if (requiredPermission != null) {
      return 'You need ${requiredPermission!.displayName} permission to access this feature.';
    }
    if (moduleAccess != null) {
      return 'Your subscription plan does not include access to this module.';
    }
    return 'You do not have permission to access this feature.';
  }
}

/// Widget for role-based feature visibility
class RoleBasedWidget extends StatelessWidget {
  final Widget child;
  final PermissionService permissionService;
  final UserRole? requiredRole;
  final Permission? requiredPermission;
  final String? moduleAccess;
  final Widget? fallback;

  const RoleBasedWidget({
    super.key,
    required this.child,
    required this.permissionService,
    this.requiredRole,
    this.requiredPermission,
    this.moduleAccess,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return fallback ?? const SizedBox.shrink();
        }

        final hasAccess = snapshot.data ?? false;
        
        if (hasAccess) {
          return child;
        }
        
        return fallback ?? const SizedBox.shrink();
      },
    );
  }

  Future<bool> _checkAccess() async {
    try {
      if (requiredPermission != null) {
        return await permissionService.hasPermission(requiredPermission!);
      }
      
      if (requiredRole != null) {
        return await permissionService.hasRole(requiredRole!);
      }
      
      if (moduleAccess != null) {
        return await permissionService.hasModuleAccess(moduleAccess!);
      }
      
      return true;
    } catch (e) {
      debugPrint('RoleBasedWidget access check error: $e');
      return false;
    }
  }
}