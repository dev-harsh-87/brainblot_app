import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spark_app/core/services/auto_refresh_service.dart';

/// Wrapper widget that automatically refreshes BLoC events when data changes
class AutoRefreshWrapper<B extends BlocBase<S>, S> extends StatefulWidget {
  final Widget child;
  final List<String> refreshTriggers;
  final void Function()? onRefresh;
  final B? bloc;
  final Duration refreshDelay;

  const AutoRefreshWrapper({
    super.key,
    required this.child,
    required this.refreshTriggers,
    this.onRefresh,
    this.bloc,
    this.refreshDelay = const Duration(milliseconds: 300),
  });

  @override
  State<AutoRefreshWrapper<B, S>> createState() => _AutoRefreshWrapperState<B, S>();
}

class _AutoRefreshWrapperState<B extends BlocBase<S>, S> extends State<AutoRefreshWrapper<B, S>> 
    with AutoRefreshMixin {

  @override
  void initState() {
    super.initState();
    
    // Setup auto-refresh listeners for all specified triggers
    for (final trigger in widget.refreshTriggers) {
      listenToAutoRefresh(trigger, _handleRefresh);
    }
  }

  void _handleRefresh() async {
    if (!mounted) return;
    
    // Add delay to prevent rapid successive refreshes
    await Future<void>.delayed(widget.refreshDelay);
    
    if (!mounted) return;
    
    if (widget.onRefresh != null) {
      widget.onRefresh!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Specific wrapper for drill-related screens
class DrillAutoRefreshWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRefresh;

  const DrillAutoRefreshWrapper({
    super.key,
    required this.child,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AutoRefreshWrapper(
      refreshTriggers: [
        AutoRefreshService.drills,
        AutoRefreshService.sharing,
        AutoRefreshService.sessions,
      ],
      onRefresh: onRefresh,
      child: child,
    );
  }
}

/// Specific wrapper for program-related screens
class ProgramAutoRefreshWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRefresh;

  const ProgramAutoRefreshWrapper({
    super.key,
    required this.child,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AutoRefreshWrapper(
      refreshTriggers: [
        AutoRefreshService.programs,
        AutoRefreshService.sharing,
        AutoRefreshService.sessions,
      ],
      onRefresh: onRefresh,
      child: child,
    );
  }
}

/// Specific wrapper for profile-related screens
class ProfileAutoRefreshWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRefresh;

  const ProfileAutoRefreshWrapper({
    super.key,
    required this.child,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AutoRefreshWrapper(
      refreshTriggers: [
        AutoRefreshService.profile,
        AutoRefreshService.stats,
        AutoRefreshService.sessions,
      ],
      onRefresh: onRefresh,
      child: child,
    );
  }
}

/// Specific wrapper for stats-related screens
class StatsAutoRefreshWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRefresh;

  const StatsAutoRefreshWrapper({
    super.key,
    required this.child,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AutoRefreshWrapper(
      refreshTriggers: [
        AutoRefreshService.stats,
        AutoRefreshService.sessions,
        AutoRefreshService.drills,
        AutoRefreshService.programs,
      ],
      onRefresh: onRefresh,
      child: child,
    );
  }
}

/// Specific wrapper for sharing-related screens
class SharingAutoRefreshWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRefresh;

  const SharingAutoRefreshWrapper({
    super.key,
    required this.child,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AutoRefreshWrapper(
      refreshTriggers: [
        AutoRefreshService.sharing,
        AutoRefreshService.drills,
        AutoRefreshService.programs,
        AutoRefreshService.profile,
      ],
      onRefresh: onRefresh,
      child: child,
    );
  }
}

/// Extension to easily wrap widgets with auto-refresh
extension AutoRefreshExtension on Widget {
  /// Wrap with drill auto-refresh
  Widget withDrillAutoRefresh({VoidCallback? onRefresh}) {
    return DrillAutoRefreshWrapper(
      onRefresh: onRefresh,
      child: this,
    );
  }

  /// Wrap with program auto-refresh
  Widget withProgramAutoRefresh({VoidCallback? onRefresh}) {
    return ProgramAutoRefreshWrapper(
      onRefresh: onRefresh,
      child: this,
    );
  }

  /// Wrap with profile auto-refresh
  Widget withProfileAutoRefresh({VoidCallback? onRefresh}) {
    return ProfileAutoRefreshWrapper(
      onRefresh: onRefresh,
      child: this,
    );
  }

  /// Wrap with stats auto-refresh
  Widget withStatsAutoRefresh({VoidCallback? onRefresh}) {
    return StatsAutoRefreshWrapper(
      onRefresh: onRefresh,
      child: this,
    );
  }

  /// Wrap with sharing auto-refresh
  Widget withSharingAutoRefresh({VoidCallback? onRefresh}) {
    return SharingAutoRefreshWrapper(
      onRefresh: onRefresh,
      child: this,
    );
  }

  /// Wrap with custom auto-refresh triggers
  Widget withAutoRefresh({
    required List<String> triggers,
    VoidCallback? onRefresh,
    Duration refreshDelay = const Duration(milliseconds: 300),
  }) {
    return AutoRefreshWrapper(
      refreshTriggers: triggers,
      onRefresh: onRefresh,
      refreshDelay: refreshDelay,
      child: this,
    );
  }
}
