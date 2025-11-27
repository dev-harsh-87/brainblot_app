import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/subscription/domain/subscription_plan.dart';
import 'package:spark_app/features/subscription/data/subscription_plan_repository.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'package:spark_app/core/auth/services/permission_manager.dart';
import 'dart:async';

/// Automatic subscription synchronization service
/// Ensures user subscriptions always match their plan definitions
class SubscriptionSyncService {
  final FirebaseFirestore _firestore;
  final SubscriptionPlanRepository _planRepository;
  StreamSubscription<QuerySnapshot>? _planChangeSubscription;
  bool isInitialized = false;

  SubscriptionSyncService({
    FirebaseFirestore? firestore,
    SubscriptionPlanRepository? planRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _planRepository = planRepository ?? SubscriptionPlanRepository();

  /// Initialize the service and start automatic synchronization
  /// Only initializes if a user is authenticated
  Future<void> initialize() async {
    if (isInitialized) return;
    
    try {
      AppLogger.debug('Initializing subscription sync service');
      
      // Check if user is authenticated before accessing Firestore
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.debug('No authenticated user - skipping subscription sync initialization');
        return;
      }
      
      // Initialize default plans if they don't exist (only when authenticated)
      await _ensureDefaultPlansExist();
      
      // Start listening for plan changes
      _startPlanChangeListener();
      
      isInitialized = true;
      AppLogger.info('Subscription sync service initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize subscription sync service', error: e);
      // Don't rethrow - let the app continue without subscription sync
      AppLogger.warning('Continuing without subscription sync - it will be initialized when user authenticates');
    }
  }

  /// Ensure default plans exist in Firestore
  Future<void> _ensureDefaultPlansExist() async {
    try {
      final plans = await _planRepository.getAllPlans();
      if (plans.isEmpty) {
        AppLogger.debug('Creating default subscription plans');
        await _createDefaultPlans();
        AppLogger.info('Default plans created');
      }
    } catch (e) {
      AppLogger.error('Error ensuring default plans', error: e);
      // Don't rethrow - this is not critical for app startup
      AppLogger.warning('Continuing without default plans - they can be created via admin panel');
    }
  }

  /// Create default subscription plans
  Future<void> _createDefaultPlans() async {
    final defaultPlans = [
      SubscriptionPlan(
        id: 'free',
        name: 'Free Plan',
        description: 'Basic access to core features',
        price: 0.0,
        billingPeriod: 'lifetime',
        features: [
          'Basic drills',
          'Basic programs',
          'Progress tracking',
        ],
        moduleAccess: [
          'drills',
          'programs',
          'profile',
          'stats',
          'subscription',
        ],
        maxDrills: 10,
        maxPrograms: 3,
        priority: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      SubscriptionPlan(
        id: 'institute',
        name: 'Institute Plan',
        description: 'Full access for educational institutions',
        price: 99.99,
        features: [
          'All drills and programs',
          'Advanced analytics',
          'Multiplayer sessions',
          'Admin dashboard',
          'User management',
          'Custom branding',
        ],
        moduleAccess: [
          'drills',
          'profile',
          'stats',
          'admin_drills',
          'admin_programs',
          'programs',
          'multiplayer',
          'user_management',
          'team_management',
          'bulk_operations',
        ],
        priority: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      SubscriptionPlan(
        id: 'premium',
        name: 'Premium Plan',
        description: 'Advanced features for serious trainers',
        price: 19.99,
        features: [
          'All drills and programs',
          'Advanced analytics',
          'Multiplayer sessions',
          'Priority support',
        ],
        moduleAccess: [
          'drills',
          'programs',
          'profile',
          'stats',
          'subscription',
          'admin_drills',
          'admin_programs',
          'multiplayer',
        ],
        priority: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final plan in defaultPlans) {
      try {
        await _planRepository.createPlan(plan);
        AppLogger.info('Created plan: ${plan.name}');
      } catch (e) {
        AppLogger.error('Failed to create plan ${plan.name}', error: e);
      }
    }
  }

  /// Start listening for plan changes and auto-sync users
  void _startPlanChangeListener() {
    _planChangeSubscription = _firestore
        .collection('subscription_plans')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final planId = change.doc.id;
          AppLogger.debug('Plan $planId was modified, syncing affected users');
          _syncUsersForPlan(planId);
        }
      }
    });
  }

  /// Sync all users with a specific plan when the plan changes
  Future<void> _syncUsersForPlan(String planId) async {
    try {
      final plan = await _planRepository.getPlan(planId);
      if (plan == null) {
        AppLogger.warning('Plan $planId not found, skipping sync');
        return;
      }

      AppLogger.debug('Syncing users for plan $planId with moduleAccess: ${plan.moduleAccess}');

      // Query users with this plan
      final usersSnapshot = await _firestore
          .collection('users')
          .where('subscription.plan', isEqualTo: planId)
          .get();

      AppLogger.debug('Found ${usersSnapshot.docs.length} users with plan $planId');

      // If no users found with direct query, try alternative approach
      if (usersSnapshot.docs.isEmpty) {
        AppLogger.debug('No users found with direct query, trying alternative approach...');
        
        // Get all users and filter manually (less efficient but more reliable)
        final allUsersSnapshot = await _firestore.collection('users').get();
        final matchingUsers = <String>[];
        
        for (final userDoc in allUsersSnapshot.docs) {
          final userData = userDoc.data();
          final subscription = userData['subscription'] as Map<String, dynamic>?;
          if (subscription != null && subscription['plan'] == planId) {
            matchingUsers.add(userDoc.id);
            await _updateUserModuleAccess(userDoc.id, plan.moduleAccess);
          }
        }
        
        AppLogger.info('Alternative sync found and updated ${matchingUsers.length} users for plan $planId: $matchingUsers');
      } else {
        // Process users found with direct query
        for (final userDoc in usersSnapshot.docs) {
          await _updateUserModuleAccess(userDoc.id, plan.moduleAccess);
        }
        
        AppLogger.info('Direct sync updated ${usersSnapshot.docs.length} users for plan $planId');
      }

      // Force refresh permissions for all currently authenticated users
      await _refreshAllActiveUserPermissions();
      
    } catch (e) {
      AppLogger.error('Error syncing users for plan $planId', error: e);
    }
  }

  /// Refresh permissions for all currently active users
  Future<void> _refreshAllActiveUserPermissions() async {
    try {
      // Force refresh current user's permissions if they're authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        AppLogger.debug('Forcing permission refresh for current authenticated user');
        await PermissionManager.instance.refreshPermissions();
        AppLogger.success('Current user permissions refreshed after plan update');
      }
    } catch (e) {
      AppLogger.error('Error refreshing active user permissions', error: e);
    }
  }

  /// Update a user's module access to match their plan
  Future<void> _updateUserModuleAccess(String userId, List<String> moduleAccess) async {
    try {
      // Get current subscription data first
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        AppLogger.warning('User document $userId not found, skipping module access update');
        return;
      }

      final userData = userDoc.data()!;
      final currentSubscription = userData['subscription'] as Map<String, dynamic>? ?? {};
      final currentModuleAccess = currentSubscription['moduleAccess'] as List<dynamic>? ?? [];
      
      // Convert to string list for comparison
      final currentModules = currentModuleAccess.map((e) => e.toString()).toList();
      
      // Check if module access actually changed
      if (_listsEqual(currentModules, moduleAccess)) {
        AppLogger.debug('Module access unchanged for user $userId, skipping update');
        return;
      }

      // Update the entire subscription object with new module access
      final updatedSubscription = Map<String, dynamic>.from(currentSubscription);
      updatedSubscription['moduleAccess'] = moduleAccess;

      await _firestore.collection('users').doc(userId).update({
        'subscription': updatedSubscription,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('Updated module access for user $userId: $moduleAccess (was: $currentModules)');
      
      // If this is the current user, force a permission refresh with delay
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        try {
          AppLogger.debug('Scheduling permission refresh for current user after sync...');
          // Add a small delay to ensure Firestore update is propagated
          await Future.delayed(const Duration(milliseconds: 500));
          await PermissionManager.instance.refreshPermissions();
          AppLogger.success('Current user permissions refreshed after sync');
        } catch (e) {
          AppLogger.error('Failed to refresh current user permissions after sync', error: e);
        }
      }
    } catch (e) {
      AppLogger.error('Error updating module access for user $userId', error: e);
    }
  }

  /// Helper method to compare two lists for equality
  bool _listsEqual<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  /// Sync a user's subscription when they log in or their plan changes
  Future<void> syncUserOnLogin(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      
      // If user has no subscription, don't create a default one - let them keep their existing permissions
      if (subscription == null) {
        AppLogger.info('User $userId has no subscription data, preserving existing state', tag: 'SubscriptionSync');
        return;
      }

      final planId = subscription['plan'] as String?;
      if (planId == null) {
        AppLogger.info('User $userId has subscription but no plan ID, preserving existing state', tag: 'SubscriptionSync');
        return;
      }

      final plan = await _planRepository.getPlan(planId);
      if (plan == null) {
        AppLogger.warning('Plan $planId not found for user $userId, preserving existing permissions', tag: 'SubscriptionSync');
        return;
      }

      // Check if module access needs updating
      final moduleAccessData = subscription['moduleAccess'];
      final currentModuleAccess = moduleAccessData is List
          ? List<String>.from(moduleAccessData)
          : <String>[];

      if (!_listsEqual(currentModuleAccess, plan.moduleAccess)) {
        AppLogger.info('Module access mismatch for user $userId, updating from $currentModuleAccess to ${plan.moduleAccess}', tag: 'SubscriptionSync');
        await _updateUserModuleAccess(userId, plan.moduleAccess);
        AppLogger.info('Synced module access for user $userId on login');
      } else {
        AppLogger.info('Module access already up to date for user $userId: $currentModuleAccess', tag: 'SubscriptionSync');
      }
    } catch (e) {
      AppLogger.error('Error syncing user on login', error: e);
    }
  }


  /// Force sync all users with their current plans (admin function)
  Future<void> forceSyncAllUsers() async {
    try {
      AppLogger.info('Starting force sync of all users with their plans');
      
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      int syncedCount = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final subscription = userData['subscription'] as Map<String, dynamic>?;
        
        if (subscription != null && subscription['plan'] != null) {
          final planId = subscription['plan'] as String;
          final plan = await _planRepository.getPlan(planId);
          
          if (plan != null) {
            await _updateUserModuleAccess(userDoc.id, plan.moduleAccess);
            syncedCount++;
          }
        }
      }
      
      AppLogger.success('Force sync completed: $syncedCount users synced');
      
      // Refresh current user permissions
      await _refreshAllActiveUserPermissions();
      
    } catch (e) {
      AppLogger.error('Error during force sync of all users', error: e);
    }
  }

  /// Consolidate duplicate permissions across the system
  Future<void> consolidateDuplicatePermissions() async {
    try {
      AppLogger.info('Starting permission consolidation to fix duplicates');
      
      // Step 1: Consolidate user permissions
      await _consolidateUserPermissions();
      
      // Step 2: Consolidate subscription plan permissions
      await _consolidateSubscriptionPlanPermissions();
      
      AppLogger.success('Permission consolidation completed successfully');
    } catch (e) {
      AppLogger.error('Error during permission consolidation', error: e);
    }
  }

  /// Consolidate permissions in user documents
  Future<void> _consolidateUserPermissions() async {
    try {
      AppLogger.info('Consolidating user permissions');
      
      final usersSnapshot = await _firestore.collection('users').get();
      int updatedUsers = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        bool needsUpdate = false;
        
        // Update subscription moduleAccess
        final subscription = userData['subscription'] as Map<String, dynamic>?;
        if (subscription != null) {
          final moduleAccess = subscription['moduleAccess'] as List<dynamic>? ?? [];
          final currentModules = moduleAccess.map((e) => e.toString()).toList();
          final consolidatedModules = _consolidateModuleList(currentModules);
          
          if (!_listsEqual(currentModules, consolidatedModules)) {
            subscription['moduleAccess'] = consolidatedModules;
            needsUpdate = true;
            AppLogger.debug('User ${userDoc.id}: $currentModules → $consolidatedModules');
          }
        }
        
        if (needsUpdate) {
          await _firestore.collection('users').doc(userDoc.id).update({
            'subscription': subscription,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          updatedUsers++;
        }
      }
      
      AppLogger.success('Updated permissions for $updatedUsers users');
    } catch (e) {
      AppLogger.error('Error consolidating user permissions', error: e);
    }
  }

  /// Consolidate permissions in subscription plan documents
  Future<void> _consolidateSubscriptionPlanPermissions() async {
    try {
      AppLogger.info('Consolidating subscription plan permissions');
      
      final plansSnapshot = await _firestore.collection('subscription_plans').get();
      int updatedPlans = 0;
      
      for (final planDoc in plansSnapshot.docs) {
        final planData = planDoc.data();
        bool needsUpdate = false;
        
        // Update moduleAccess
        final moduleAccess = planData['moduleAccess'] as List<dynamic>? ?? [];
        final currentModules = moduleAccess.map((e) => e.toString()).toList();
        final consolidatedModules = _consolidateModuleList(currentModules);
        
        if (!_listsEqual(currentModules, consolidatedModules)) {
          needsUpdate = true;
          AppLogger.debug('Plan ${planDoc.id}: $currentModules → $consolidatedModules');
        }
        
        if (needsUpdate) {
          await _firestore.collection('subscription_plans').doc(planDoc.id).update({
            'moduleAccess': consolidatedModules,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          updatedPlans++;
        }
      }
      
      AppLogger.success('Updated permissions for $updatedPlans subscription plans');
    } catch (e) {
      AppLogger.error('Error consolidating subscription plan permissions', error: e);
    }
  }

  /// Consolidate a list of modules by removing duplicates
  List<String> _consolidateModuleList(List<String> modules) {
    final consolidatedModules = <String>[];
    
    for (final module in modules) {
      switch (module) {
        case 'analysis':
          // Replace 'analysis' with 'stats' if 'stats' is not already present
          if (!consolidatedModules.contains('stats')) {
            consolidatedModules.add('stats');
          }
          break;
        case 'host_features':
          // Replace 'host_features' with 'multiplayer' if 'multiplayer' is not already present
          if (!consolidatedModules.contains('multiplayer')) {
            consolidatedModules.add('multiplayer');
          }
          break;
        default:
          // Add module if not already present
          if (!consolidatedModules.contains(module)) {
            consolidatedModules.add(module);
          }
          break;
      }
    }
    
    return consolidatedModules;
  }

  /// Dispose and cleanup
  Future<void> dispose() async {
    await _planChangeSubscription?.cancel();
    _planChangeSubscription = null;
    isInitialized = false;
  }
}