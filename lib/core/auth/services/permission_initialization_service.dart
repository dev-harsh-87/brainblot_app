import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Centralized service for initializing and caching user permissions at app startup
/// This eliminates the need for individual feature checks throughout the app
class PermissionInitializationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  // Cached user permissions loaded at startup
  UserPermissions? _cachedPermissions;
  String? _cachedUserId;

  PermissionInitializationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Initialize permissions for the current user
  /// Should be called immediately after successful authentication
  Future<UserPermissions> initializePermissions() async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.warning('Cannot initialize permissions: No authenticated user', tag: 'PermissionInit');
      return UserPermissions.guest();
    }

    try {
      AppLogger.info('Initializing permissions for user ${user.uid}', tag: 'PermissionInit');
      
      // Fetch user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        AppLogger.warning('User document not found for ${user.uid}', tag: 'PermissionInit');
        return UserPermissions.guest();
      }

      final userData = userDoc.data()!;
      
      // Extract role
      final role = UserRole.fromString(userData['role'] as String? ?? 'user');
      AppLogger.info('User role: ${role.value}', tag: 'PermissionInit');
      
      // Extract subscription details
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      
      List<String> moduleAccess = [];
      bool isSubscriptionActive = false;
      String? subscriptionPlan;
      DateTime? subscriptionExpiresAt;
      
      if (subscription != null) {
        subscriptionPlan = subscription['plan'] as String?;
        final status = subscription['status'] as String?;
        final expiresAt = subscription['expiresAt'] as Timestamp?;
        
        isSubscriptionActive = status == 'active' &&
            (expiresAt == null || DateTime.now().isBefore(expiresAt.toDate()));
        
        subscriptionExpiresAt = expiresAt?.toDate();
        
        if (isSubscriptionActive) {
          final modules = subscription['moduleAccess'] as List<dynamic>?;
          moduleAccess = modules?.map((e) => e.toString()).toList() ?? [];
        }
        
        AppLogger.info('Subscription: plan=$subscriptionPlan, active=$isSubscriptionActive, modules=$moduleAccess', tag: 'PermissionInit');
      }
      
      // Admin has access to all modules
      if (role.isAdmin()) {
        moduleAccess = [
          'drills',
          'profile',
          'stats',
          'analysis',
          'admin_drills',
          'admin_programs',
          'programs',
          'multiplayer',
          'user_management',
          'team_management',
          'bulk_operations',
        ];
        AppLogger.info('Admin user detected - granted all module access', tag: 'PermissionInit');
      }
      
      final permissions = UserPermissions(
        userId: user.uid,
        role: role,
        moduleAccess: moduleAccess,
        isSubscriptionActive: isSubscriptionActive,
        subscriptionPlan: subscriptionPlan,
        subscriptionExpiresAt: subscriptionExpiresAt,
      );
      
      // Cache the permissions
      _cachedPermissions = permissions;
      _cachedUserId = user.uid;
      
      AppLogger.success('Permissions initialized successfully', tag: 'PermissionInit');
      return permissions;
      
    } catch (e) {
      AppLogger.error('Failed to initialize permissions', error: e, tag: 'PermissionInit');
      return UserPermissions.guest();
    }
  }

  /// Get cached permissions (returns null if not initialized)
  UserPermissions? getCachedPermissions() {
    final currentUser = _auth.currentUser;
    
    // Invalidate cache if user changed
    if (currentUser?.uid != _cachedUserId) {
      _cachedPermissions = null;
      _cachedUserId = null;
    }
    
    return _cachedPermissions;
  }

  /// Clear cached permissions
  void clearCache() {
    AppLogger.info('Clearing permission cache', tag: 'PermissionInit');
    _cachedPermissions = null;
    _cachedUserId = null;
  }

  /// Check if permissions are initialized
  bool isInitialized() {
    return _cachedPermissions != null && _cachedUserId == _auth.currentUser?.uid;
  }
}

/// Data class holding all user permissions loaded at startup
class UserPermissions {
  final String userId;
  final UserRole role;
  final List<String> moduleAccess;
  final bool isSubscriptionActive;
  final String? subscriptionPlan;
  final DateTime? subscriptionExpiresAt;

  const UserPermissions({
    required this.userId,
    required this.role,
    required this.moduleAccess,
    required this.isSubscriptionActive,
    this.subscriptionPlan,
    this.subscriptionExpiresAt,
  });

  /// Create guest permissions (no access)
  factory UserPermissions.guest() {
    return UserPermissions(
      userId: '',
      role: UserRole.user,
      moduleAccess: const [],
      isSubscriptionActive: false,
    );
  }

  /// Check if user has access to a specific module
  bool hasModuleAccess(String module) => moduleAccess.contains(module);

  /// Check if user is admin
  bool get isAdmin => role.isAdmin();

  /// Check if user has drill creation access
  bool get hasDrillAccess => isAdmin || hasModuleAccess('admin_drills');

  /// Check if user has program creation access
  bool get hasProgramAccess => isAdmin || hasModuleAccess('programs') || hasModuleAccess('admin_programs');

  /// Check if user has multiplayer access
  bool get hasMultiplayerAccess => isAdmin || hasModuleAccess('multiplayer');

  /// Check if user has user management access
  bool get hasUserManagementAccess => isAdmin || hasModuleAccess('user_management');

  /// Check if user has team management access
  bool get hasTeamManagementAccess => isAdmin || hasModuleAccess('team_management');

  /// Get a summary for debugging
  Map<String, dynamic> toDebugMap() {
    return {
      'userId': userId,
      'role': role.value,
      'isAdmin': isAdmin,
      'moduleAccess': moduleAccess,
      'isSubscriptionActive': isSubscriptionActive,
      'subscriptionPlan': subscriptionPlan,
      'subscriptionExpiresAt': subscriptionExpiresAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'UserPermissions(userId: $userId, role: ${role.value}, isAdmin: $isAdmin, modules: $moduleAccess)';
  }
}