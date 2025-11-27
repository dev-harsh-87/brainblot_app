import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:spark_app/core/auth/services/comprehensive_permission_service.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'package:spark_app/core/services/auto_refresh_service.dart';

/// Centralized permission manager that stores analyzed permissions
/// This eliminates the need for permission checks throughout the app
class PermissionManager extends ChangeNotifier {
  static PermissionManager? _instance;
  static PermissionManager get instance => _instance ??= PermissionManager._();
  
  PermissionManager._() : _permissionService = ComprehensivePermissionService() {
    _initializePermissionListener();
  }

  final ComprehensivePermissionService _permissionService;
  late final AutoRefreshService _autoRefreshService = AutoRefreshService();
  
  // Cached permission states
  bool _isInitialized = false;
  UserRole _userRole = UserRole.user;
  List<String> _moduleAccess = [];
  Map<String, bool> _featureAccess = {};
  Map<String, dynamic> _permissionSummary = {};
  
  // Stream controller for permission changes
  final StreamController<Map<String, bool>> _permissionStreamController =
      StreamController<Map<String, bool>>.broadcast();
  
  // Stream subscription for user document changes
  StreamSubscription<Map<String, dynamic>>? _permissionSubscription;


  // Getters for cached permissions
  bool get isInitialized => _isInitialized;
  UserRole get userRole => _userRole;
  List<String> get moduleAccess => List.unmodifiable(_moduleAccess);
  Map<String, bool> get featureAccess => Map.unmodifiable(_featureAccess);
  Map<String, dynamic> get permissionSummary => Map.unmodifiable(_permissionSummary);
  
  // Stream for listening to permission changes
  Stream<Map<String, bool>> get permissionStream => _permissionStreamController.stream;

  /// Initialize permission listener to watch for user document changes
  void _initializePermissionListener() {
    // Cancel any existing subscription first
    _permissionSubscription?.cancel();
    
    // Listen to permission changes from the comprehensive service
    _permissionSubscription = _permissionService.watchPermissionChanges().listen(
      (permissionData) {
        AppLogger.info('User permissions changed, refreshing cache...', tag: 'PermissionManager');
        // Refresh permissions when user document changes
        _refreshPermissionsFromData(permissionData);
      },
      onError: (error) {
        AppLogger.error('Error listening to permission changes', error: error, tag: 'PermissionManager');
      },
    );
  }

  /// Refresh permissions from permission data
  void _refreshPermissionsFromData(Map<String, dynamic> permissionData) {
    try {
      AppLogger.info('Refreshing permissions from user document changes...', tag: 'PermissionManager');
      
      // Update cached data from the permission summary
      final authenticated = permissionData['authenticated'] as bool? ?? false;
      
      if (!authenticated) {
        AppLogger.info('User not authenticated, clearing permissions', tag: 'PermissionManager');
        _isInitialized = false;
        _userRole = UserRole.user;
        _moduleAccess.clear();
        _featureAccess.clear();
        _permissionSummary.clear();
        notifyListeners();
        _permissionStreamController.add({});
        return;
      }

      // Store previous state for comparison
      final previousModules = List<String>.from(_moduleAccess);
      final previousFeatures = Map<String, bool>.from(_featureAccess);

      // Update role
      final roleString = permissionData['role'] as String?;
      _userRole = UserRole.fromString(roleString ?? 'user');

      // Update module access
      final modules = permissionData['modules'] as List<dynamic>? ?? [];
      _moduleAccess = modules.map((e) => e.toString()).toList();

      // Update feature access
      final featureAccess = permissionData['featureAccess'] as Map<String, dynamic>? ?? {};
      _featureAccess.clear();
      featureAccess.forEach((key, value) {
        _featureAccess[key] = value as bool? ?? false;
      });

      // Add admin module features
      _featureAccess['admin_user_management'] = _userRole.isAdmin() || _moduleAccess.contains('admin_user_management');
      _featureAccess['admin_subscription_management'] = _userRole.isAdmin() || _moduleAccess.contains('admin_subscription_management');
      _featureAccess['admin_plan_requests'] = _userRole.isAdmin() || _moduleAccess.contains('admin_plan_requests');
      _featureAccess['admin_category_management'] = _userRole.isAdmin() || _moduleAccess.contains('admin_category_management');
      _featureAccess['admin_stimulus_management'] = _userRole.isAdmin() || _moduleAccess.contains('admin_stimulus_management');
      _featureAccess['admin_comprehensive_activity'] = _userRole.isAdmin() || _moduleAccess.contains('admin_comprehensive_activity');

      // Update permission summary
      _permissionSummary = Map.from(permissionData);

      _isInitialized = true;

      // Check if permissions actually changed
      final modulesChanged = !_listsEqual(previousModules, _moduleAccess);
      final featuresChanged = !_mapsEqual(previousFeatures, _featureAccess);

      if (modulesChanged || featuresChanged) {
        AppLogger.success('Permissions changed - modules: $_moduleAccess, notifying listeners', tag: 'PermissionManager');
        
        // Trigger comprehensive auto-refresh for all UI components
        _triggerPermissionBasedAutoRefresh(previousModules, _moduleAccess);
        
        notifyListeners();
        _permissionStreamController.add(_featureAccess);
      } else {
        AppLogger.debug('Permissions unchanged, skipping notification', tag: 'PermissionManager');
      }

      AppLogger.success('Permissions refreshed from user document changes', tag: 'PermissionManager');
    } catch (e) {
      AppLogger.error('Error refreshing permissions from data', error: e, tag: 'PermissionManager');
    }
  }

  /// Initialize and analyze all permissions at startup
  Future<void> initializePermissions() async {
    try {
      AppLogger.info('Starting permission analysis...', tag: 'PermissionManager');
      
      // Restart the permission listener for the new user
      _initializePermissionListener();
      
      // Load user role
      _userRole = await _permissionService.getCurrentUserRole();
      AppLogger.info('User role: ${_userRole.value}', tag: 'PermissionManager');
      
      // Load module access
      _moduleAccess = await _permissionService.getCurrentUserModuleAccess();
      AppLogger.info('Module access: $_moduleAccess', tag: 'PermissionManager');
      
      // Pre-analyze all feature access
      await _analyzeAllFeatureAccess();
      
      // Get comprehensive permission summary
      _permissionSummary = await _permissionService.getPermissionSummary();
      
      _isInitialized = true;
      notifyListeners();
      _permissionStreamController.add(_featureAccess);
      
      AppLogger.success('Permission analysis complete', tag: 'PermissionManager');
      
    } catch (e, stackTrace) {
      AppLogger.error('Permission initialization failed',
          error: e, stackTrace: stackTrace, tag: 'PermissionManager');
      rethrow;
    }
  }

  /// Pre-analyze all feature access and cache results
  Future<void> _analyzeAllFeatureAccess() async {
    final features = {
      // Core Features
      'drills': _permissionService.canAccessDrills(),
      'programs': _permissionService.canAccessPrograms(),
      'profile': _permissionService.canAccessProfile(),
      'stats': _permissionService.canAccessStats(),
      'subscription': _permissionService.canAccessSubscription(),
      
      // Admin Features
      'admin_drills': _permissionService.canAccessAdminDrills(),
      'admin_programs': _permissionService.canAccessAdminPrograms(),
      'is_admin': _permissionService.isAdmin(),
      
      // Advanced Features
      'multiplayer': _permissionService.canAccessMultiplayer(),
      'host_sessions': _permissionService.canHostSessions(),
      'user_management': _permissionService.canManageUsers(),
      'team_management': _permissionService.canManageTeams(),
      'bulk_operations': _permissionService.canPerformBulkOperations(),
      
      // Admin Module Features - check both admin role and specific module access
      'admin_user_management': _permissionService.isAdmin().then((isAdmin) async =>
          isAdmin || _moduleAccess.contains('admin_user_management')),
      'admin_subscription_management': _permissionService.isAdmin().then((isAdmin) async =>
          isAdmin || _moduleAccess.contains('admin_subscription_management')),
      'admin_plan_requests': _permissionService.isAdmin().then((isAdmin) async =>
          isAdmin || _moduleAccess.contains('admin_plan_requests')),
      'admin_category_management': _permissionService.isAdmin().then((isAdmin) async =>
          isAdmin || _moduleAccess.contains('admin_category_management')),
      'admin_stimulus_management': _permissionService.isAdmin().then((isAdmin) async =>
          isAdmin || _moduleAccess.contains('admin_stimulus_management')),
      'admin_comprehensive_activity': _permissionService.isAdmin().then((isAdmin) async =>
          isAdmin || _moduleAccess.contains('admin_comprehensive_activity')),
    };

    // Wait for all feature checks to complete
    final results = await Future.wait(features.values);
    
    // Store results in cache
    int index = 0;
    for (final featureName in features.keys) {
      _featureAccess[featureName] = results[index] as bool;
      index++;
    }
    
    AppLogger.info('Feature access analyzed: $_featureAccess', tag: 'PermissionManager');
  }

  /// Refresh permissions (call when user data changes)
  Future<void> refreshPermissions() async {
    AppLogger.info('Refreshing permissions...', tag: 'PermissionManager');
    
    _isInitialized = false;
    _featureAccess.clear();
    notifyListeners();
    
    await _permissionService.refreshPermissions();
    await initializePermissions();
  }

  /// Clear all cached permissions (call on logout)
  void clearCache() {
    AppLogger.info('Clearing permission cache...', tag: 'PermissionManager');
    
    // Cancel the permission subscription to prevent permission denied errors
    _permissionSubscription?.cancel();
    _permissionSubscription = null;
    
    _isInitialized = false;
    _userRole = UserRole.user;
    _moduleAccess.clear();
    _featureAccess.clear();
    _permissionSummary.clear();
    
    notifyListeners();
    _permissionStreamController.add({});
    
    AppLogger.success('Permission cache cleared and subscription cancelled', tag: 'PermissionManager');
  }


  // ========== QUICK ACCESS METHODS ==========
  // These methods use cached data instead of making async calls

  /// Check if user has access to drills (cached)
  bool get canAccessDrills {
    if (!_isInitialized) {
      _initializePermissionsSilently();
      return false;
    }
    return _featureAccess['drills'] ?? false;
  }

  /// Check if user has access to programs (cached)
  bool get canAccessPrograms => _featureAccess['programs'] ?? false;

  /// Check if user has access to profile (cached)
  bool get canAccessProfile => _featureAccess['profile'] ?? false;

  /// Check if user has access to stats (cached)
  bool get canAccessStats => _featureAccess['stats'] ?? false;

  /// Check if user has access to subscription (cached)
  bool get canAccessSubscription => _featureAccess['subscription'] ?? false;

  /// Check if user has access to admin drills (cached)
  bool get canAccessAdminDrills => _featureAccess['admin_drills'] ?? false;

  /// Check if user has access to admin programs (cached)
  bool get canAccessAdminPrograms => _featureAccess['admin_programs'] ?? false;

  /// Check if user is admin (cached)
  bool get isAdmin {
    if (!_isInitialized) {
      _initializePermissionsSilently();
      return false;
    }
    return _featureAccess['is_admin'] ?? false;
  }

  /// Check if user has access to multiplayer (cached)
  bool get canAccessMultiplayer => _featureAccess['multiplayer'] ?? false;

  /// Check if user can host sessions (cached)
  bool get canHostSessions => _featureAccess['host_sessions'] ?? false;

  /// Check if user can manage users (cached)
  bool get canManageUsers => _featureAccess['user_management'] ?? false;

  /// Check if user can manage teams (cached)
  bool get canManageTeams => _featureAccess['team_management'] ?? false;

  /// Check if user can perform bulk operations (cached)
  bool get canPerformBulkOperations => _featureAccess['bulk_operations'] ?? false;

  /// Check if user has access to admin user management (cached)
  bool get canAccessAdminUserManagement {
    if (!_isInitialized) {
      _initializePermissionsSilently();
      return false;
    }
    return _featureAccess['admin_user_management'] ?? false;
  }

  /// Check if user has access to admin subscription management (cached)
  bool get canAccessAdminSubscriptionManagement {
    if (!_isInitialized) {
      _initializePermissionsSilently();
      return false;
    }
    return _featureAccess['admin_subscription_management'] ?? false;
  }

  /// Check if user has access to admin plan requests (cached)
  bool get canAccessAdminPlanRequests {
    if (!_isInitialized) {
      _initializePermissionsSilently();
      return false;
    }
    return _featureAccess['admin_plan_requests'] ?? false;
  }

  /// Check if user has access to admin category management (cached)
  bool get canAccessAdminCategoryManagement {
    if (!_isInitialized) {
      _initializePermissionsSilently();
      return false;
    }
    return _featureAccess['admin_category_management'] ?? false;
  }

  /// Check if user has access to admin stimulus management (cached)
  bool get canAccessAdminStimulusManagement {
    if (!_isInitialized) {
      _initializePermissionsSilently();
      return false;
    }
    return _featureAccess['admin_stimulus_management'] ?? false;
  }

  /// Check if user has access to admin comprehensive activity (cached)
  bool get canAccessAdminComprehensiveActivity {
    if (!_isInitialized) {
      _initializePermissionsSilently();
      return false;
    }
    return _featureAccess['admin_comprehensive_activity'] ?? false;
  }

  /// Check if user has access to a specific module (cached)
  bool hasModuleAccess(String module) {
    // If not initialized, try to initialize silently
    if (!_isInitialized) {
      _initializePermissionsSilently();
      return false; // Return false for now, will be updated when initialized
    }
    return _moduleAccess.contains(module);
  }

  /// Initialize permissions silently without blocking UI
  void _initializePermissionsSilently() {
    if (!_isInitialized) {
      AppLogger.info('Initializing permissions silently due to access check', tag: 'PermissionManager');
      initializePermissions().catchError((error) {
        AppLogger.warning('Silent permission initialization failed: $error', tag: 'PermissionManager');
      });
    }
  }

  /// Check if user should see admin content (cached)
  bool get shouldShowAdminContent => canAccessAdminDrills || canAccessAdminPrograms;

  /// Check if user has any admin access (cached)
  bool get hasAnyAdminAccess {
    return canAccessAdminUserManagement ||
           canAccessAdminSubscriptionManagement ||
           canAccessAdminPlanRequests ||
           canAccessAdminCategoryManagement ||
           canAccessAdminStimulusManagement ||
           canAccessAdminComprehensiveActivity;
  }

  /// Check if user should see multiplayer options (cached)
  bool get shouldShowMultiplayerOptions => canAccessMultiplayer;

  /// Check if user should see host options (cached)
  bool get shouldShowHostOptions => canHostSessions;

  // ========== CONTENT FILTERING ==========

  /// Get filtered navigation items based on permissions
  List<String> getAvailableNavigationItems() {
    final items = <String>[];
    
    items.add('home'); // Always available
    
    if (canAccessDrills) items.add('drills');
    if (canAccessPrograms) items.add('programs');
    if (canAccessStats) items.add('stats');
    if (canAccessSubscription) items.add('subscription');
    // Show admin if user is admin OR has any admin module access
    if (isAdmin || hasAnyAdminAccess) items.add('admin');
    if (canAccessMultiplayer) items.add('multiplayer');
    
    return items;
  }

  /// Get filtered feature list based on permissions
  Map<String, bool> getAvailableFeatures() {
    return Map.from(_featureAccess);
  }

  /// Get user permission level for UI customization
  String get permissionLevel {
    if (isAdmin) return 'admin';
    if (canAccessMultiplayer || canHostSessions) return 'premium';
    if (canAccessDrills && canAccessPrograms) return 'standard';
    return 'basic';
  }

  /// Get permission status for debugging
  Map<String, dynamic> getDebugInfo() {
    return {
      'initialized': _isInitialized,
      'userRole': _userRole.value,
      'moduleAccess': _moduleAccess,
      'featureAccess': _featureAccess,
      'permissionLevel': permissionLevel,
      'availableNavigation': getAvailableNavigationItems(),
    };
  }

  /// Helper method to compare two maps for equality
  bool _mapsEqual(Map<String, bool> map1, Map<String, bool> map2) {
    if (map1.length != map2.length) return false;
    
    for (final key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    
    return true;
  }

  /// Helper method to compare two lists for equality
  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    
    final set1 = Set<String>.from(list1);
    final set2 = Set<String>.from(list2);
    
    return set1.containsAll(set2) && set2.containsAll(set1);
  }

  /// Trigger comprehensive auto-refresh based on permission changes
  void _triggerPermissionBasedAutoRefresh(List<String> previousModules, List<String> currentModules) {
    final addedModules = currentModules.where((module) => !previousModules.contains(module)).toList();
    final removedModules = previousModules.where((module) => !currentModules.contains(module)).toList();
    
    AppLogger.info('Permission-based auto-refresh: Added modules: $addedModules, Removed modules: $removedModules', tag: 'PermissionManager');
    
    // Always trigger global refresh for permission changes
    _autoRefreshService.triggerGlobalRefresh();
    
    // Trigger specific refreshes based on module changes
    final refreshTriggers = <String>{};
    
    // Check for content-related modules
    if (addedModules.contains('drills') || removedModules.contains('drills') ||
        addedModules.contains('admin_drills') || removedModules.contains('admin_drills')) {
      refreshTriggers.add(AutoRefreshService.drills);
    }
    
    if (addedModules.contains('programs') || removedModules.contains('programs') ||
        addedModules.contains('admin_programs') || removedModules.contains('admin_programs')) {
      refreshTriggers.add(AutoRefreshService.programs);
    }
    
    if (addedModules.contains('profile') || removedModules.contains('profile')) {
      refreshTriggers.add(AutoRefreshService.profile);
    }
    
    if (addedModules.contains('stats') || removedModules.contains('stats')) {
      refreshTriggers.add(AutoRefreshService.stats);
    }
    
    // Always refresh sharing when permissions change
    refreshTriggers.add(AutoRefreshService.sharing);
    
    // Trigger all identified refreshes
    if (refreshTriggers.isNotEmpty) {
      _autoRefreshService.triggerMultipleRefresh(refreshTriggers.toList());
      AppLogger.success('Triggered auto-refresh for: ${refreshTriggers.toList()}', tag: 'PermissionManager');
    }
  }

  @override
  void dispose() {
    _permissionSubscription?.cancel();
    _permissionStreamController.close();
    super.dispose();
  }
}