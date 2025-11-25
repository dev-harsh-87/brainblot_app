import 'package:flutter/material.dart';
import 'package:spark_app/core/auth/services/session_management_service.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/core/theme/app_theme.dart';

/// Widget that guards content based on session permissions
/// Automatically updates when session changes (login/logout/role changes)
class SessionGuard extends StatefulWidget {
  final Widget child;
  final Widget? fallback;
  final bool requireAdmin;
  final List<String>? requiredModules;
  final bool requireLogin;
  final String? errorMessage;

  const SessionGuard({
    super.key,
    required this.child,
    this.fallback,
    this.requireAdmin = false,
    this.requiredModules,
    this.requireLogin = true,
    this.errorMessage,
  });

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  late final SessionManagementService _sessionService;
  AppUser? _currentSession;

  @override
  void initState() {
    super.initState();
    _sessionService = getIt<SessionManagementService>();
    _currentSession = _sessionService.getCurrentSession();
    
    // Listen to session changes
    _sessionService.addSessionListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _sessionService.removeSessionListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged(AppUser? session) {
    if (mounted) {
      setState(() {
        _currentSession = session;
      });
    }
  }

  bool _hasAccess() {
    // Check login requirement
    if (widget.requireLogin && _currentSession == null) {
      return false;
    }

    // Check admin requirement
    if (widget.requireAdmin) {
      if (_currentSession == null || !_currentSession!.role.isAdmin()) {
        return false;
      }
    }

    // Check module access requirements
    if (widget.requiredModules != null && widget.requiredModules!.isNotEmpty) {
      if (_currentSession == null) return false;
      
      for (final module in widget.requiredModules!) {
        if (!_sessionService.hasModuleAccess(module)) {
          return false;
        }
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasAccess()) {
      return widget.child;
    }

    // Show fallback or default access denied widget
    return widget.fallback ?? _buildAccessDenied(context);
  }

  Widget _buildAccessDenied(BuildContext context) {
    String message = widget.errorMessage ?? 'Access denied';
    
    if (widget.requireAdmin) {
      message = 'Admin access required';
    } else if (widget.requiredModules != null && widget.requiredModules!.isNotEmpty) {
      message = 'Subscription upgrade required';
    } else if (widget.requireLogin) {
      message = 'Please log in to continue';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
              message,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "You don't have permission to access this content",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Builder variant for more control
class SessionGuardBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, AppUser? session, bool hasAccess) builder;
  final bool requireAdmin;
  final List<String>? requiredModules;
  final bool requireLogin;

  const SessionGuardBuilder({
    super.key,
    required this.builder,
    this.requireAdmin = false,
    this.requiredModules,
    this.requireLogin = true,
  });

  @override
  State<SessionGuardBuilder> createState() => _SessionGuardBuilderState();
}

class _SessionGuardBuilderState extends State<SessionGuardBuilder> {
  late final SessionManagementService _sessionService;
  AppUser? _currentSession;

  @override
  void initState() {
    super.initState();
    _sessionService = getIt<SessionManagementService>();
    _currentSession = _sessionService.getCurrentSession();
    
    // Listen to session changes
    _sessionService.addSessionListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _sessionService.removeSessionListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged(AppUser? session) {
    if (mounted) {
      setState(() {
        _currentSession = session;
      });
    }
  }

  bool _hasAccess() {
    // Check login requirement
    if (widget.requireLogin && _currentSession == null) {
      return false;
    }

    // Check admin requirement
    if (widget.requireAdmin) {
      if (_currentSession == null || !_currentSession!.role.isAdmin()) {
        return false;
      }
    }

    // Check module access requirements
    if (widget.requiredModules != null && widget.requiredModules!.isNotEmpty) {
      if (_currentSession == null) return false;
      
      for (final module in widget.requiredModules!) {
        if (!_sessionService.hasModuleAccess(module)) {
          return false;
        }
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentSession, _hasAccess());
  }
}