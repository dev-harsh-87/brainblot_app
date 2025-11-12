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
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final hasAccess = snapshot.data ?? false;

        if (!hasAccess) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Access Denied'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Access Denied',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You do not have permission to access this page.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
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
          return const Center(child: CircularProgressIndicator());
        }

        final hasPermission = snapshot.data ?? false;

        if (!hasPermission) {
          return fallback ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'This feature requires ${requiredPermission.displayName}',
                      textAlign: TextAlign.center,
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