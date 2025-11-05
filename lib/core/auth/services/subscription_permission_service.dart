import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/subscription/domain/subscription_plan.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'dart:async';

/// Centralized service for subscription-based permission checking
/// Ensures consistent permission logic across the entire app
class SubscriptionPermissionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  // Cache for performance (cleared on user changes)
  final Map<String, bool> _moduleAccessCache = {};
  final Map<String, SubscriptionPlan> _planCache = {};
  String? _currentUserId;
  Timer? _cacheCleanupTimer;

  SubscriptionPermissionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    _initializeService();
  }

  void _initializeService() {
    // Listen to auth changes to clear cache
    _auth.authStateChanges().listen((user) {
      if (user?.uid != _currentUserId) {
        _currentUserId = user?.uid;
        clearCache();
      }
    });

    // Setup periodic cache cleanup (every 5 minutes)
    _cacheCleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => clearCache(),
    );
  }

  /// Clear all caches
  void clearCache() {
    _moduleAccessCache.clear();
    _planCache.clear();
    print('🗑️ SubscriptionPermissionService cache cleared');
  }

  /// Check if current user has access to a specific module
  Future<bool> hasModuleAccess(String module) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check cache first
      final cacheKey = '${user.uid}:$module';
      if (_moduleAccessCache.containsKey(cacheKey)) {
        return _moduleAccessCache[cacheKey]!;
      }

      // Get fresh user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        _moduleAccessCache[cacheKey] = false;
        return false;
      }

      final userData = userDoc.data()!;
      
      // Check if user is admin (admin has access to everything)
      final role = UserRole.fromString(userData['role'] as String? ?? 'user');
      if (role.isAdmin()) {
        _moduleAccessCache[cacheKey] = true;
        return true;
      }

      // Check subscription-based access
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      if (subscription == null) {
        _moduleAccessCache[cacheKey] = false;
        return false;
      }

      // Check if subscription is active
      final status = subscription['status'] as String?;
      if (status != 'active') {
        _moduleAccessCache[cacheKey] = false;
        return false;
      }

      // Check expiration
      final expiresAt = subscription['expiresAt'] as Timestamp?;
      if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
        _moduleAccessCache[cacheKey] = false;
        return false;
      }

      // Check module access
      final moduleAccess = subscription['moduleAccess'] as List<dynamic>?;
      if (moduleAccess == null) {
        _moduleAccessCache[cacheKey] = false;
        return false;
      }

      final hasAccess = moduleAccess.contains(module);
      _moduleAccessCache[cacheKey] = hasAccess;
      return hasAccess;

    } catch (e) {
      print('❌ Error checking module access for $module: $e');
      return false;
    }
  }

  /// Check if user has access to multiple modules (returns map of results)
  Future<Map<String, bool>> hasMultipleModuleAccess(List<String> modules) async {
    final results = <String, bool>{};
    
    for (final module in modules) {
      results[module] = await hasModuleAccess(module);
    }
    
    return results;
  }

  /// Get current user's subscription plan details
  Future<SubscriptionPlan?> getCurrentUserPlan() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      if (subscription == null) return null;

      final planId = subscription['plan'] as String?;
      if (planId == null) return null;

      // Check cache first
      if (_planCache.containsKey(planId)) {
        return _planCache[planId];
      }

      // Get plan from Firestore
      final planDoc = await _firestore.collection('subscription_plans').doc(planId).get();
      if (!planDoc.exists) return null;

      final plan = SubscriptionPlan.fromFirestore(planDoc);
      _planCache[planId] = plan;
      return plan;

    } catch (e) {
      print('❌ Error getting current user plan: $e');
      return null;
    }
  }

  /// Get current user's module access list
  Future<List<String>> getCurrentUserModuleAccess() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      
      // Admin has access to all modules
      final role = UserRole.fromString(userData['role'] as String? ?? 'user');
      if (role.isAdmin()) {
        return [
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
      }

      final subscription = userData['subscription'] as Map<String, dynamic>?;
      if (subscription == null) return [];

      final moduleAccess = subscription['moduleAccess'] as List<dynamic>?;
      if (moduleAccess == null) return [];

      return List<String>.from(moduleAccess);

    } catch (e) {
      print('❌ Error getting user module access: $e');
      return [];
    }
  }

  /// Check if user can access admin content (admin drills/programs)
  Future<bool> canAccessAdminContent() async {
    final hasAdminDrills = await hasModuleAccess('admin_drills');
    final hasAdminPrograms = await hasModuleAccess('admin_programs');
    return hasAdminDrills || hasAdminPrograms;
  }

  /// Check if user can create programs
  Future<bool> canCreatePrograms() async {
    return await hasModuleAccess('programs');
  }

  /// Check if user can manage other users
  Future<bool> canManageUsers() async {
    return await hasModuleAccess('user_management');
  }

  /// Check if user can access multiplayer features
  Future<bool> canAccessMultiplayer() async {
    return await hasModuleAccess('multiplayer');
  }

  /// Check if user can perform bulk operations
  Future<bool> canPerformBulkOperations() async {
    return await hasModuleAccess('bulk_operations');
  }

  /// Check if user can manage teams
  Future<bool> canManageTeams() async {
    return await hasModuleAccess('team_management');
  }

  /// Get user's subscription status summary
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'isLoggedIn': false,
          'plan': null,
          'status': null,
          'moduleAccess': <String>[],
          'expiresAt': null,
          'isActive': false,
        };
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return {
          'isLoggedIn': true,
          'plan': null,
          'status': null,
          'moduleAccess': <String>[],
          'expiresAt': null,
          'isActive': false,
        };
      }

      final userData = userDoc.data()!;
      final role = UserRole.fromString(userData['role'] as String? ?? 'user');
      final subscription = userData['subscription'] as Map<String, dynamic>?;

      if (role.isAdmin()) {
        return {
          'isLoggedIn': true,
          'isAdmin': true,
          'plan': 'admin',
          'status': 'active',
          'moduleAccess': await getCurrentUserModuleAccess(),
          'expiresAt': null,
          'isActive': true,
        };
      }

      if (subscription == null) {
        return {
          'isLoggedIn': true,
          'isAdmin': false,
          'plan': null,
          'status': null,
          'moduleAccess': <String>[],
          'expiresAt': null,
          'isActive': false,
        };
      }

      final expiresAt = subscription['expiresAt'] as Timestamp?;
      final isActive = subscription['status'] == 'active' &&
          (expiresAt == null || DateTime.now().isBefore(expiresAt.toDate()));

      return {
        'isLoggedIn': true,
        'isAdmin': false,
        'plan': subscription['plan'],
        'status': subscription['status'],
        'moduleAccess': subscription['moduleAccess'] is List
            ? List<String>.from(subscription['moduleAccess'] as List)
            : <String>[],
        'expiresAt': expiresAt?.toDate(),
        'isActive': isActive,
      };

    } catch (e) {
      print('❌ Error getting subscription status: $e');
      return {
        'isLoggedIn': false,
        'plan': null,
        'status': null,
        'moduleAccess': <String>[],
        'expiresAt': null,
        'isActive': false,
        'error': e.toString(),
      };
    }
  }

  /// Validate if user's subscription is properly synced with their plan
  Future<bool> validateSubscriptionSync() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      if (subscription == null) return false;

      final planId = subscription['plan'] as String?;
      if (planId == null) return false;

      // Get plan definition
      final planDoc = await _firestore.collection('subscription_plans').doc(planId).get();
      if (!planDoc.exists) {
        print('⚠️ User has plan "$planId" but plan not found in database');
        return false;
      }

      final planData = planDoc.data()!;
      final planModuleAccess = planData['moduleAccess'] is List
          ? List<String>.from(planData['moduleAccess'] as List)
          : <String>[];
      final userModuleAccess = subscription['moduleAccess'] is List
          ? List<String>.from(subscription['moduleAccess'] as List)
          : <String>[];

      // Compare module access
      final planSet = Set<String>.from(planModuleAccess);
      final userSet = Set<String>.from(userModuleAccess);

      if (!planSet.containsAll(userSet) || !userSet.containsAll(planSet)) {
        print('⚠️ User module access out of sync with plan');
        print('   Plan modules: $planModuleAccess');
        print('   User modules: $userModuleAccess');
        return false;
      }

      return true;

    } catch (e) {
      print('❌ Error validating subscription sync: $e');
      return false;
    }
  }

  /// Stream subscription status changes
  Stream<Map<String, dynamic>> watchSubscriptionStatus() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value({
        'isLoggedIn': false,
        'plan': null,
        'status': null,
        'moduleAccess': <String>[],
        'expiresAt': null,
        'isActive': false,
      });
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .asyncMap((_) => getSubscriptionStatus());
  }

  /// Get all available modules for current user's plan
  Future<List<String>> getAvailableModules() async {
    final plan = await getCurrentUserPlan();
    if (plan == null) return [];
    return plan.moduleAccess;
  }

  /// Check if user can upgrade to a specific plan
  Future<bool> canUpgradeToPlan(String planId) async {
    try {
      final currentPlan = await getCurrentUserPlan();
      if (currentPlan == null) return true; // Can upgrade from no plan

      final targetPlanDoc = await _firestore.collection('subscription_plans').doc(planId).get();
      if (!targetPlanDoc.exists) return false;

      final targetPlan = SubscriptionPlan.fromFirestore(targetPlanDoc);
      
      // Can upgrade if target plan has higher priority or different features
      return targetPlan.priority >= currentPlan.priority;

    } catch (e) {
      print('❌ Error checking upgrade eligibility: $e');
      return false;
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _cacheCleanupTimer?.cancel();
    clearCache();
  }
}