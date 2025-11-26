import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/subscription/domain/subscription_plan.dart';
import 'package:spark_app/features/subscription/data/subscription_plan_repository.dart';
import 'package:spark_app/core/utils/app_logger.dart';
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
          'analysis',
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
      if (plan == null) return;

      final usersSnapshot = await _firestore
          .collection('users')
          .where('subscription.plan', isEqualTo: planId)
          .get();

      for (final userDoc in usersSnapshot.docs) {
        await _updateUserModuleAccess(userDoc.id, plan.moduleAccess);
      }
      
      AppLogger.info('Synced ${usersSnapshot.docs.length} users for plan $planId');
    } catch (e) {
      AppLogger.error('Error syncing users for plan $planId', error: e);
    }
  }

  /// Update a user's module access to match their plan
  Future<void> _updateUserModuleAccess(String userId, List<String> moduleAccess) async {
    try {
      // Get current subscription data first
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final currentSubscription = userData['subscription'] as Map<String, dynamic>? ?? {};

      // Update the entire subscription object with new module access
      final updatedSubscription = Map<String, dynamic>.from(currentSubscription);
      updatedSubscription['moduleAccess'] = moduleAccess;

      await _firestore.collection('users').doc(userId).update({
        'subscription': updatedSubscription,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('🔄 Updated module access for user $userId: $moduleAccess');
    } catch (e) {
      AppLogger.error('Error updating module access for user $userId', error: e);
    }
  }

  /// Sync a user's subscription when they log in or their plan changes
  Future<void> syncUserOnLogin(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      
      if (subscription == null) return;

      final planId = subscription['plan'] as String?;
      if (planId == null) return;

      final plan = await _planRepository.getPlan(planId);
      if (plan == null) return;

      // Check if module access needs updating
      final moduleAccessData = subscription['moduleAccess'];
      final currentModuleAccess = moduleAccessData is List 
          ? List<String>.from(moduleAccessData) 
          : <String>[];

      if (!_listsEqual(currentModuleAccess, plan.moduleAccess)) {
        await _updateUserModuleAccess(userId, plan.moduleAccess);
        AppLogger.info('Synced module access for user $userId on login');
      }
    } catch (e) {
      AppLogger.error('Error syncing user on login', error: e);
    }
  }

  /// Helper method to compare two lists for equality
  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    
    final set1 = Set<String>.from(list1);
    final set2 = Set<String>.from(list2);
    
    return set1.containsAll(set2) && set2.containsAll(set1);
  }

  /// Dispose and cleanup
  Future<void> dispose() async {
    await _planChangeSubscription?.cancel();
    _planChangeSubscription = null;
    isInitialized = false;
  }
}