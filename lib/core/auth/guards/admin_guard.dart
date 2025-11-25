import 'package:flutter/material.dart';
import 'package:spark_app/core/auth/models/permission.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/auth/services/permission_service.dart';

/// Guard widget for admin-only routes
class AdminGuard extends StatelessWidget {
  final Widget child;
  final PermissionService permissionService;
  final UserRole? requiredRole;
  final Permission? requiredPermission;

  const AdminGuard({
    super.key,
    required this.child,
    required this.permissionService,
    this.requiredRole,
    this.requiredPermission,
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
                    'Error: ${snapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final hasAccess = snapshot.data ?? false;

        if (!hasAccess) {
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
                    Icons.lock_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You do not have permission to access this page.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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

        return child;
      },
    );
  }

  Future<bool> _checkAccess() async {
    if (requiredPermission != null) {
      return await permissionService.hasPermission(requiredPermission!);
    }
    
    if (requiredRole != null) {
      return await permissionService.hasRole(requiredRole!);
    }
    
    // Default to checking if user is admin
    return await permissionService.isAdmin();
  }
}

/// Permission-based route guard
class PermissionGuard extends StatelessWidget {
  final Widget child;
  final PermissionService permissionService;
  final Permission requiredPermission;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.child,
    required this.permissionService,
    required this.requiredPermission,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: permissionService.hasPermission(requiredPermission),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        final hasPermission = snapshot.data ?? false;

        if (!hasPermission) {
          return fallback ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This feature requires ${requiredPermission.displayName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
        }

        return child;
      },
    );
  }
}