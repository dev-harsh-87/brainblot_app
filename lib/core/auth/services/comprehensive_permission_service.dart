import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/auth/models/permission.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Comprehensive permission service that handles all access control logic
/// This is the single source of truth for all permission checks in the app
class ComprehensivePermissionService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  
  // Cache for performance optimization
  final Map<String, bool> _moduleAccessCache = {};
  final Map<String, UserRole> _roleCache = {};
  final Map<String, List<String>> _userModulesCache = {};
  String? _currentUserId;
  
  ComprehensivePermissionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _initializeService();
  }

  void _initializeService() {
    // Listen to auth changes to clear cache
    _auth.authStateChanges().listen((user) {
      if (user?.uid != _currentUserId) {
        _currentUserId = user?.uid;
        _clearCache();
      }
    });
  }

  void _clearCache() {
    _moduleAccessCache.clear();
    _roleCache.clear();
    _userModulesCache.clear();
    AppLogger.info('Permission cache cleared', tag: 'ComprehensivePermissionService');
  }

  /// Get current user's role with caching
  Future<UserRole> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return UserRole.user;

    // Check cache first
    if (_roleCache.containsKey(user.uid)) {
      return _roleCache[user.uid]!;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        _roleCache[user.uid] = UserRole.user;
        return UserRole.user;
      }

      final data = doc.data()!;
      final roleString = data['role'] as String?;
      final role = UserRole.fromString(roleString ?? 'user');
      
      _roleCache[user.uid] = role;
      return role;
    } catch (e) {
      AppLogger.error('Error getting user role', error: e, tag: 'ComprehensivePermissionService');
      return UserRole.user;
    }
  }

  /// Get current user's module access list with caching
  Future<List<String>> getCurrentUserModuleAccess() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    // Check cache first
    if (_userModulesCache.containsKey(user.uid)) {
      return _userModulesCache[user.uid]!;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        _userModulesCache[user.uid] = [];
        return [];
      }

      final data = doc.data()!;
      final role = UserRole.fromString(data['role'] as String? ?? 'user');
      
      // Admin has access to all modules
      if (role.isAdmin()) {
        final adminModules = _getAllAvailableModules();
        _userModulesCache[user.uid] = adminModules;
        return adminModules;
      }

      // Get subscription-based access
      final subscription = data['subscription'] as Map<String, dynamic>?;
      if (subscription == null) {
        _userModulesCache[user.uid] = [];
        return [];
      }

      // Check if subscription is active
      final status = subscription['status'] as String?;
      final expiresAt = subscription['expiresAt'] as Timestamp?;
      final isActive = status == 'active' && 
          (expiresAt == null || DateTime.now().isBefore(expiresAt.toDate()));

      if (!isActive) {
        _userModulesCache[user.uid] = [];
        return [];
      }

      final moduleAccess = subscription['moduleAccess'] as List<dynamic>?;
      final modules = moduleAccess?.map((e) => e.toString()).toList() ?? [];
      
      _userModulesCache[user.uid] = modules;
      return modules;
    } catch (e) {
      AppLogger.error('Error getting user module access', error: e, tag: 'ComprehensivePermissionService');
      return [];
    }
  }

  /// Check if user has access to a specific module
  Future<bool> hasModuleAccess(String module) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final cacheKey = '${user.uid}:$module';
    if (_moduleAccessCache.containsKey(cacheKey)) {
      return _moduleAccessCache[cacheKey]!;
    }

    try {
      final role = await getCurrentUserRole();
      
      // Admin always has access
      if (role.isAdmin()) {
        _moduleAccessCache[cacheKey] = true;
        return true;
      }

      final modules = await getCurrentUserModuleAccess();
      final hasAccess = modules.contains(module);
      
      _moduleAccessCache[cacheKey] = hasAccess;
      return hasAccess;
    } catch (e) {
      AppLogger.error('Error checking module access for $module', error: e, tag: 'ComprehensivePermissionService');
      _moduleAccessCache[cacheKey] = false;
      return false;
    }
  }

  /// Check if user has a specific permission
  Future<bool> hasPermission(Permission permission) async {
    final role = await getCurrentUserRole();
    return permission.isGrantedTo(role);
  }

  /// Check if user has required role or higher
  Future<bool> hasRole(UserRole requiredRole) async {
    final role = await getCurrentUserRole();
    return role.hasPermission(requiredRole);
  }

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    final role = await getCurrentUserRole();
    return role.isAdmin();
  }

  // ========== SPECIFIC FEATURE ACCESS CHECKS ==========

  /// Check if user can access basic drill features (view, create, edit own drills)
  Future<bool> canAccessDrills() async {
    return await hasModuleAccess('drills');
  }

  /// Check if user can access admin drills (view/edit all drills)
  Future<bool> canAccessAdminDrills() async {
    final isAdmin = await this.isAdmin();
    if (isAdmin) return true;
    return await hasModuleAccess('admin_drills');
  }

  /// Check if user can access basic program features (view, create, edit own programs)
  Future<bool> canAccessPrograms() async {
    return await hasModuleAccess('programs');
  }

  /// Check if user can access admin programs (view/edit all programs)
  Future<bool> canAccessAdminPrograms() async {
    final isAdmin = await this.isAdmin();
    if (isAdmin) return true;
    return await hasModuleAccess('admin_programs');
  }

  /// Check if user can access profile management
  Future<bool> canAccessProfile() async {
    return await hasModuleAccess('profile');
  }

  /// Check if user can access personal statistics
  Future<bool> canAccessStats() async {
    // Check both 'stats' and legacy 'analysis' for backward compatibility
    return await hasModuleAccess('stats') || await hasModuleAccess('analysis');
  }

  /// Check if user can access subscription management
  Future<bool> canAccessSubscription() async {
    return await hasModuleAccess('subscription');
  }

  /// Check if user can access multiplayer features
  Future<bool> canAccessMultiplayer() async {
    final isAdmin = await this.isAdmin();
    if (isAdmin) return true;
    // Check both 'multiplayer' and legacy 'host_features' for backward compatibility
    return await hasModuleAccess('multiplayer') || await hasModuleAccess('host_features');
  }

  /// Check if user can manage other users (admin or institute plan)
  Future<bool> canManageUsers() async {
    final isAdmin = await this.isAdmin();
    if (isAdmin) return true;
    return await hasModuleAccess('user_management');
  }

  /// Check if user can access host features (create multiplayer sessions)
  Future<bool> canHostSessions() async {
    final isAdmin = await this.isAdmin();
    if (isAdmin) return true;
    // Host features are now part of multiplayer access
    return await hasModuleAccess('multiplayer') || await hasModuleAccess('host_features');
  }

  /// Check if user can perform bulk operations
  Future<bool> canPerformBulkOperations() async {
    final isAdmin = await this.isAdmin();
    if (isAdmin) return true;
    return await hasModuleAccess('bulk_operations');
  }

  /// Check if user can access team management
  Future<bool> canManageTeams() async {
    final isAdmin = await this.isAdmin();
    if (isAdmin) return true;
    return await hasModuleAccess('team_management');
  }

  // ========== CONTENT ACCESS FILTERS ==========

  /// Check if user should see admin content in drill lists
  Future<bool> shouldShowAdminDrills() async {
    return await canAccessAdminDrills();
  }

  /// Check if user should see admin content in program lists
  Future<bool> shouldShowAdminPrograms() async {
    return await canAccessAdminPrograms();
  }

  /// Check if user should see multiplayer options
  Future<bool> shouldShowMultiplayerOptions() async {
    return await canAccessMultiplayer();
  }

  /// Check if user should see host options
  Future<bool> shouldShowHostOptions() async {
    return await canHostSessions();
  }

  // ========== UTILITY METHODS ==========

  /// Get all available modules in the system
  List<String> _getAllAvailableModules() {
    return [
      'drills',
      'programs',
      'profile',
      'stats',
      'subscription',
      'admin_drills',
      'admin_programs',
      'multiplayer',
      'user_management',
      'team_management',
      'bulk_operations',
      'admin_user_management',
      'admin_subscription_management',
      'admin_plan_requests',
      'admin_category_management',
      'admin_stimulus_management',
      'admin_comprehensive_activity',
    ];
  }

  /// Get user's permission summary for debugging
  Future<Map<String, dynamic>> getPermissionSummary() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'authenticated': false,
        'role': 'none',
        'modules': <String>[],
        'permissions': <String>[],
      };
    }

    final role = await getCurrentUserRole();
    final modules = await getCurrentUserModuleAccess();
    final permissions = role.permissions.map((p) => p.value).toList();

    return {
      'authenticated': true,
      'userId': user.uid,
      'email': user.email,
      'role': role.value,
      'isAdmin': role.isAdmin(),
      'modules': modules,
      'permissions': permissions,
      'featureAccess': {
        'drills': await canAccessDrills(),
        'adminDrills': await canAccessAdminDrills(),
        'programs': await canAccessPrograms(),
        'adminPrograms': await canAccessAdminPrograms(),
        'profile': await canAccessProfile(),
        'stats': await canAccessStats(),
        'subscription': await canAccessSubscription(),
        'multiplayer': await canAccessMultiplayer(),
        'userManagement': await canManageUsers(),
        'hostFeatures': await canHostSessions(),
        'bulkOperations': await canPerformBulkOperations(),
        'teamManagement': await canManageTeams(),
      }
    };
  }

  /// Check multiple permissions at once
  Future<Map<String, bool>> checkMultipleModuleAccess(List<String> modules) async {
    final results = <String, bool>{};
    for (final module in modules) {
      results[module] = await hasModuleAccess(module);
    }
    return results;
  }

  /// Stream user permission changes
  Stream<Map<String, dynamic>> watchPermissionChanges() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value({
        'authenticated': false,
        'modules': <String>[],
      });
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .asyncMap((snapshot) async {
          AppLogger.info('User document changed, clearing permission cache and refreshing', tag: 'ComprehensivePermissionService');
          _clearCache(); // Clear cache when user data changes
          
          // Force refresh of all cached data
          await getCurrentUserRole();
          await getCurrentUserModuleAccess();
          
          final permissionSummary = await getPermissionSummary();
          AppLogger.success('Permission summary refreshed: ${permissionSummary['modules']}', tag: 'ComprehensivePermissionService');
          
          return permissionSummary;
        });
  }

  /// Force refresh all cached data
  Future<void> refreshPermissions() async {
    _clearCache();
    // Pre-load essential data
    await getCurrentUserRole();
    await getCurrentUserModuleAccess();
    AppLogger.info('Permissions refreshed', tag: 'ComprehensivePermissionService');
  }

  /// Dispose and cleanup
  void dispose() {
    _clearCache();
  }
}