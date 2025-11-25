import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/core/auth/models/permission.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/auth/services/comprehensive_permission_service.dart';
import 'package:spark_app/core/widgets/app_loader.dart';

/// Enhanced role-based guard using the comprehensive permission service
/// This is the new standard for protecting routes and features
class EnhancedRoleGuard extends StatelessWidget {
  final Widget child;
  final ComprehensivePermissionService permissionService;
  final UserRole? requiredRole;
  final Permission? requiredPermission;
  final String? requiredModule;
  final Widget? fallback;
  final String? redirectRoute;
  final String? customMessage;
  final bool showLoadingIndicator;

  const EnhancedRoleGuard({
    super.key,
    required this.child,
    required this.permissionService,
    this.requiredRole,
    this.requiredPermission,
    this.requiredModule,
    this.fallback,
    this.redirectRoute,
    this.customMessage,
    this.showLoadingIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (!showLoadingIndicator) {
            return const SizedBox.shrink();
          }
          return AppLoader.fullScreen(
            message: 'Checking permissions...',
          );
        }

        if (snapshot.hasError) {
          return _buildErrorScreen(context, snapshot.error.toString());
        }

        final hasAccess = snapshot.data ?? false;

        if (!hasAccess) {
          // Handle redirection if specified
          if (redirectRoute != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go(redirectRoute!);
              }
            });
            return AppLoader.fullScreen(
              message: 'Redirecting...',
            );
          }

          // Return fallback widget if provided
          if (fallback != null) {
            return fallback!;
          }

          // Default access denied screen
          return _buildAccessDeniedScreen(context);
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
      if (requiredModule != null) {
        return await permissionService.hasModuleAccess(requiredModule!);
      }
      
      // Default: allow access
      return true;
    } catch (e) {
      debugPrint('EnhancedRoleGuard access check error: $e');
      return false;
    }
  }

  Widget _buildAccessDeniedScreen(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Access Restricted',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Access Restricted',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                customMessage ?? _getDefaultMessage(),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      side: BorderSide(
                        color: colorScheme.outline,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.home),
                    label: const Text('Home'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Need access to this feature?',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contact your administrator or upgrade your subscription plan.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, String error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Permission Error',
          style: TextStyle(
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Permission Check Failed',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to verify your permissions: $error',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDefaultMessage() {
    if (requiredRole != null) {
      return 'This feature requires ${requiredRole!.displayName} privileges. Your current account does not have sufficient permissions.';
    }
    if (requiredPermission != null) {
      return 'This feature requires ${requiredPermission!.displayName} permission. Please contact your administrator for access.';
    }
    if (requiredModule != null) {
      return 'This feature requires access to the ${requiredModule!.replaceAll('_', ' ')} module. Please check your subscription plan or contact support.';
    }
    return 'You do not have permission to access this feature. Please contact your administrator or upgrade your subscription.';
  }
}

/// Widget for conditionally showing content based on permissions
class PermissionBasedWidget extends StatelessWidget {
  final Widget child;
  final ComprehensivePermissionService permissionService;
  final UserRole? requiredRole;
  final Permission? requiredPermission;
  final String? requiredModule;
  final Widget? fallback;

  const PermissionBasedWidget({
    super.key,
    required this.child,
    required this.permissionService,
    this.requiredRole,
    this.requiredPermission,
    this.requiredModule,
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
      
      if (requiredModule != null) {
        return await permissionService.hasModuleAccess(requiredModule!);
      }
      
      return true;
    } catch (e) {
      debugPrint('PermissionBasedWidget access check error: $e');
      return false;
    }
  }
}