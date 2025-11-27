import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/core/auth/services/permission_manager.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Widget that shows content based on permissions with real-time updates
/// Listens to permission changes and updates UI accordingly
class PermissionBasedScreen extends StatefulWidget {
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
  State<PermissionBasedScreen> createState() => _PermissionBasedScreenState();
}

class _PermissionBasedScreenState extends State<PermissionBasedScreen> {
  @override
  void initState() {
    super.initState();
    // Listen to permission changes for real-time updates
    PermissionManager.instance.addListener(_onPermissionChanged);
  }

  @override
  void dispose() {
    PermissionManager.instance.removeListener(_onPermissionChanged);
    super.dispose();
  }

  void _onPermissionChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild when permissions change
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionManager = PermissionManager.instance;
    
    // Check if permissions are initialized
    if (!permissionManager.isInitialized) {
      // For admin-only features, show access denied immediately
      if (widget.requireAdmin) {
        return _buildAccessDeniedScreen(context, 'Admin access required');
      }
      
      // For regular modules, allow access by default and initialize permissions silently
      // This prevents the "Loading permissions..." screen during navigation
      _initializePermissionsSilently();
      return widget.child;
    }

    // Check admin requirement
    if (widget.requireAdmin && !permissionManager.isAdmin) {
      return _buildAccessDeniedScreen(context, 'Admin access required');
    }

    // Check module requirement
    if (widget.requiredModule != null && !permissionManager.hasModuleAccess(widget.requiredModule!)) {
      return _buildAccessDeniedScreen(context,
          widget.customMessage ?? 'Access to ${widget.requiredModule!.replaceAll('_', ' ')} module required');
    }

    return widget.child;
  }

  /// Initialize permissions silently in the background without blocking UI
  void _initializePermissionsSilently() {
    // Only initialize once to avoid multiple calls
    if (!PermissionManager.instance.isInitialized) {
      AppLogger.info('Initializing permissions silently in background', tag: 'PermissionBasedScreen');
      PermissionManager.instance.initializePermissions().catchError((error) {
        // Log error but don't block UI
        AppLogger.warning('Silent permission initialization failed: $error', tag: 'PermissionBasedScreen');
      });
    }
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

/// Widget for conditionally showing UI elements based on permissions with real-time updates
/// Listens to permission changes and updates UI accordingly
class PermissionBasedWidget extends StatefulWidget {
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
  State<PermissionBasedWidget> createState() => _PermissionBasedWidgetState();
}

class _PermissionBasedWidgetState extends State<PermissionBasedWidget> {
  @override
  void initState() {
    super.initState();
    // Listen to permission changes for real-time updates
    PermissionManager.instance.addListener(_onPermissionChanged);
  }

  @override
  void dispose() {
    PermissionManager.instance.removeListener(_onPermissionChanged);
    super.dispose();
  }

  void _onPermissionChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild when permissions change
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionManager = PermissionManager.instance;
    
    // Check if permissions are initialized
    if (!permissionManager.isInitialized) {
      // For admin-only widgets, hide by default
      if (widget.requireAdmin) {
        return widget.fallback ?? const SizedBox.shrink();
      }
      
      // For regular module widgets, show by default and initialize permissions silently
      _initializePermissionsSilently();
      return widget.child;
    }

    // Check admin requirement
    if (widget.requireAdmin && !permissionManager.isAdmin) {
      return widget.fallback ?? const SizedBox.shrink();
    }

    // Check module requirement
    if (widget.requiredModule != null && !permissionManager.hasModuleAccess(widget.requiredModule!)) {
      return widget.fallback ?? const SizedBox.shrink();
    }

    return widget.child;
  }

  /// Initialize permissions silently in the background without blocking UI
  void _initializePermissionsSilently() {
    // Only initialize once to avoid multiple calls
    if (!PermissionManager.instance.isInitialized) {
      AppLogger.info('Initializing permissions silently in background', tag: 'PermissionBasedWidget');
      PermissionManager.instance.initializePermissions().catchError((error) {
        // Log error but don't block UI
        AppLogger.warning('Silent permission initialization failed: $error', tag: 'PermissionBasedWidget');
      });
    }
  }
}