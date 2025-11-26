import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:spark_app/core/auth/services/comprehensive_permission_service.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Centralized permission manager that stores analyzed permissions
/// This eliminates the need for permission checks throughout the app
class PermissionManager extends ChangeNotifier {
  static PermissionManager? _instance;
  static PermissionManager get instance => _instance ??= PermissionManager._();
  
  PermissionManager._() : _permissionService = ComprehensivePermissionService() {
    _initializePermissionListener();
  }

  final ComprehensivePermissionService _permissionService;
  
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
      // Update cached data from the permission summary
      final authenticated = permissionData['authenticated'] as bool? ?? false;
      
      if (!authenticated) {
        _isInitialized = false;
        _userRole = UserRole.user;
        _moduleAccess.clear();
        _featureAccess.clear();
        _permissionSummary.clear();
        notifyListeners();
        return;
      }

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
      notifyListeners();
      _permissionStreamController.add(_featureAccess);

      AppLogger.success('Permissions refreshed from user document changes', tag: 'PermissionManager');
    } catch (e) {
      AppLogger.error('Error refreshing permissions from data', error: e, tag: 'PermissionManager');
    }
  }

  /// Initialize and analyze all permissions at startup
  Future<void> initializePermissions() async {
    try {
      AppLogger.info('Starting permission analysis...', tag: 'PermissionManager');
      
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
      
      // Admin Module Features
      'admin_user_management': _permissionService.isAdmin(),
      'admin_subscription_management': _permissionService.isAdmin(),
      'admin_plan_requests': _permissionService.isAdmin(),
      'admin_category_management': _permissionService.isAdmin(),
      'admin_stimulus_management': _permissionService.isAdmin(),
      'admin_comprehensive_activity': _permissionService.isAdmin(),
    };

    // Wait for all feature checks to complete
    final results = await Future.wait(features.values);
    
    // Store results in cache
    int index = 0;
    for (final featureName in features.keys) {
      _featureAccess[featureName] = results[index];
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
    
    _isInitialized = false;
    _userRole = UserRole.user;
    _moduleAccess.clear();
    _featureAccess.clear();
    _permissionSummary.clear();
    
    notifyListeners();
    _permissionStreamController.add({});
    
    AppLogger.success('Permission cache cleared', tag: 'PermissionManager');
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
    if (isAdmin) items.add('admin');
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

  @override
  void dispose() {
    _permissionSubscription?.cancel();
    _permissionStreamController.close();
    super.dispose();
  }
}