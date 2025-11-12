import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service to manage auto-refresh functionality across the app
class AutoRefreshService {
  static final AutoRefreshService _instance = AutoRefreshService._internal();
  factory AutoRefreshService() => _instance;
  AutoRefreshService._internal();

  final Map<String, StreamController<void>> _refreshControllers = {};
  final Map<String, Timer?> _refreshTimers = {};
  
  // Refresh events for different data types
  static const String drills = 'drills';
  static const String programs = 'programs';
  static const String sessions = 'sessions';
  static const String profile = 'profile';
  static const String stats = 'stats';
  static const String sharing = 'sharing';
  static const String leaderboard = 'leaderboard';

  /// Get refresh stream for a specific data type
  Stream<void> getRefreshStream(String dataType) {
    if (!_refreshControllers.containsKey(dataType)) {
      _refreshControllers[dataType] = StreamController<void>.broadcast();
    }
    return _refreshControllers[dataType]!.stream;
  }

  /// Trigger immediate refresh for specific data type
  void triggerRefresh(String dataType) {
    if (_refreshControllers.containsKey(dataType)) {
      _refreshControllers[dataType]!.add(null);
      if (kDebugMode) {
        print('🔄 Auto-refresh triggered for: $dataType');
      }
    }
  }

  /// Trigger refresh for multiple data types
  void triggerMultipleRefresh(List<String> dataTypes) {
    for (final dataType in dataTypes) {
      triggerRefresh(dataType);
    }
  }

  /// Trigger refresh for all data types
  void triggerGlobalRefresh() {
    final allTypes = [drills, programs, sessions, profile, stats, sharing, leaderboard];
    triggerMultipleRefresh(allTypes);
  }

  /// Schedule delayed refresh (useful for after create/update operations)
  void scheduleRefresh(String dataType, {Duration delay = const Duration(milliseconds: 500)}) {
    _refreshTimers[dataType]?.cancel();
    _refreshTimers[dataType] = Timer(delay, () {
      triggerRefresh(dataType);
    });
  }

  /// Schedule refresh for multiple data types with delay
  void scheduleMultipleRefresh(
    List<String> dataTypes, 
    {Duration delay = const Duration(milliseconds: 500),}
  ) {
    for (final dataType in dataTypes) {
      scheduleRefresh(dataType, delay: delay);
    }
  }

  /// Auto-refresh when drill is created/updated/deleted
  void onDrillChanged() {
    scheduleMultipleRefresh([drills, stats, profile]);
  }

  /// Auto-refresh when program is created/updated/deleted
  void onProgramChanged() {
    scheduleMultipleRefresh([programs, stats, profile]);
  }

  /// Auto-refresh when session is completed
  void onSessionCompleted() {
    scheduleMultipleRefresh([sessions, stats, profile, leaderboard]);
  }

  /// Auto-refresh when profile is updated
  void onProfileChanged() {
    scheduleMultipleRefresh([profile, sharing]);
  }

  /// Auto-refresh when sharing settings change
  void onSharingChanged() {
    scheduleMultipleRefresh([sharing, drills, programs]);
  }

  /// Auto-refresh when user joins/leaves shared content
  void onSharingMembershipChanged() {
    scheduleMultipleRefresh([sharing, drills, programs, stats]);
  }

  /// Start periodic refresh for specific data type - DISABLED
  /// This method is now disabled to prevent automatic refreshing
  /// Data will only refresh when manually triggered or when relevant actions occur
  void startPeriodicRefresh(
    String dataType,
    {Duration interval = const Duration(minutes: 5),}
  ) {
    // Periodic refresh disabled - data refreshes only when needed
    // No automatic background refreshing every few minutes
  }

  /// Stop periodic refresh for specific data type - DISABLED
  /// This method is now disabled as periodic refresh is not used
  void stopPeriodicRefresh(String dataType) {
    // Periodic refresh disabled - no timers to cancel
    _refreshTimers['${dataType}_periodic']?.cancel();
    _refreshTimers.remove('${dataType}_periodic');
  }

  /// Dispose all resources
  void dispose() {
    for (final controller in _refreshControllers.values) {
      controller.close();
    }
    for (final timer in _refreshTimers.values) {
      timer?.cancel();
    }
    _refreshControllers.clear();
    _refreshTimers.clear();
  }
}

/// Mixin to add auto-refresh capability to widgets
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription<void>> _refreshSubscriptions = [];

  /// Listen to auto-refresh for specific data type
  void listenToAutoRefresh(String dataType, VoidCallback onRefresh) {
    final subscription = AutoRefreshService()
        .getRefreshStream(dataType)
        .listen((_) => onRefresh());
    _refreshSubscriptions.add(subscription);
  }

  /// Listen to multiple auto-refresh streams
  void listenToMultipleAutoRefresh(
    Map<String, VoidCallback> refreshCallbacks,
  ) {
    for (final entry in refreshCallbacks.entries) {
      listenToAutoRefresh(entry.key, entry.value);
    }
  }

  @override
  void dispose() {
    for (final subscription in _refreshSubscriptions) {
      subscription.cancel();
    }
    _refreshSubscriptions.clear();
    super.dispose();
  }
}

/// Widget that automatically refreshes when data changes
class AutoRefreshBuilder extends StatefulWidget {
  final String dataType;
  final Widget Function(BuildContext context, bool isRefreshing) builder;
  final Future<void> Function()? onRefresh;
  final Duration refreshDelay;

  const AutoRefreshBuilder({
    super.key,
    required this.dataType,
    required this.builder,
    this.onRefresh,
    this.refreshDelay = const Duration(milliseconds: 300),
  });

  @override
  State<AutoRefreshBuilder> createState() => _AutoRefreshBuilderState();
}

class _AutoRefreshBuilderState extends State<AutoRefreshBuilder> 
    with AutoRefreshMixin {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    listenToAutoRefresh(widget.dataType, _handleRefresh);
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing || widget.onRefresh == null) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await Future<void>.delayed(widget.refreshDelay);
      await widget.onRefresh!();
    } catch (e) {
      if (kDebugMode) {
        print('Auto-refresh error for ${widget.dataType}: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _isRefreshing);
  }
}

/// Extension to easily trigger auto-refresh from anywhere
extension AutoRefreshExtension on BuildContext {
  /// Trigger refresh for specific data type
  void triggerAutoRefresh(String dataType) {
    AutoRefreshService().triggerRefresh(dataType);
  }

  /// Trigger refresh for multiple data types
  void triggerMultipleAutoRefresh(List<String> dataTypes) {
    AutoRefreshService().triggerMultipleRefresh(dataTypes);
  }

  /// Trigger global refresh
  void triggerGlobalAutoRefresh() {
    AutoRefreshService().triggerGlobalRefresh();
  }

  /// Schedule delayed refresh
  void scheduleAutoRefresh(
    String dataType, 
    {Duration delay = const Duration(milliseconds: 500),}
  ) {
    AutoRefreshService().scheduleRefresh(dataType, delay: delay);
  }
}
