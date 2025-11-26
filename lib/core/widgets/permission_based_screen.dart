import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/core/auth/services/permission_manager.dart';

/// Simple widget that shows content based on cached permissions
/// No async calls needed since permissions are pre-analyzed
class PermissionBasedScreen extends StatelessWidget {
  final Widget child;
  final String? requiredModule;
  final bool requireAdmin;
  final String? customMessage;

  const PermissionBasedScreen({
    super.key,
    required this.child,
    this.requiredModule,
    this.requireAdmin = false,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final permissionManager = PermissionManager.instance;
    
    // Check if permissions are initialized
    if (!permissionManager.isInitialized) {
      // Instead of redirecting to splash, show loading indicator
      // This prevents navigation loops and app restarts
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading permissions...'),
            ],
          ),
        ),
      );
    }

    // Check admin requirement
    if (requireAdmin && !permissionManager.isAdmin) {
      return _buildAccessDeniedScreen(context, 'Admin access required');
    }

    // Check module requirement
    if (requiredModule != null && !permissionManager.hasModuleAccess(requiredModule!)) {
      return _buildAccessDeniedScreen(context, 
          customMessage ?? 'Access to ${requiredModule!.replaceAll('_', ' ')} module required');
    }

    return child;
  }

  Widget _buildAccessDeniedScreen(BuildContext context, String message) {
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
                message,
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
                    onPressed: () => context.go('/home'),
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
}

/// Simple widget for conditionally showing UI elements based on cached permissions
class PermissionBasedWidget extends StatelessWidget {
  final Widget child;
  final String? requiredModule;
  final bool requireAdmin;
  final Widget? fallback;

  const PermissionBasedWidget({
    super.key,
    required this.child,
    this.requiredModule,
    this.requireAdmin = false,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final permissionManager = PermissionManager.instance;
    
    // Check if permissions are initialized
    if (!permissionManager.isInitialized) {
      return fallback ?? const SizedBox.shrink();
    }

    // Check admin requirement
    if (requireAdmin && !permissionManager.isAdmin) {
      return fallback ?? const SizedBox.shrink();
    }

    // Check module requirement
    if (requiredModule != null && !permissionManager.hasModuleAccess(requiredModule!)) {
      return fallback ?? const SizedBox.shrink();
    }

    return child;
  }
}