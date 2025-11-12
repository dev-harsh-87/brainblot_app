import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/features/subscription/domain/subscription_plan.dart';
import 'package:spark_app/features/subscription/data/subscription_plan_repository.dart';
import 'dart:async';

/// Automatic subscription synchronization service
/// Ensures user subscriptions always match their plan definitions
class SubscriptionSyncService {
  final FirebaseFirestore _firestore;
  final SubscriptionPlanRepository _planRepository;
  StreamSubscription<QuerySnapshot>? _planChangeSubscription;
  bool _isInitialized = false;

  SubscriptionSyncService({
    FirebaseFirestore? firestore,
    SubscriptionPlanRepository? planRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _planRepository = planRepository ?? SubscriptionPlanRepository();

  /// Initialize the service and start automatic synchronization
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🔄 Initializing subscription sync service...');
      
      // Initialize default plans if they don't exist
      await _ensureDefaultPlansExist();
      
      // Start listening for plan changes
      _startPlanChangeListener();
      
      _isInitialized = true;
      print('✅ Subscription sync service initialized');
    } catch (e) {
      print('❌ Failed to initialize subscription sync service: $e');
      rethrow;
    }
  }

  /// Ensure default plans exist in Firestore
  Future<void> _ensureDefaultPlansExist() async {
    try {
      final plans = await _planRepository.getAllPlans();
      if (plans.isEmpty) {
        print('📦 Creating default subscription plans...');
        await _createDefaultPlans();
        print('✅ Default plans created');
      }
    } catch (e) {
      print('❌ Error ensuring default plans: $e');
      // Don't rethrow - this is not critical for app startup
      print('⚠️ Continuing without default plans - they can be created via admin panel');
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
        currency: 'USD',
        billingPeriod: 'lifetime',
        features: [
          'Basic drills',
          'Basic programs',
          'Progress tracking',
        ],
        moduleAccess: [
          'basic_drills',
          'basic_programs',
          'stats',
        ],
        maxDrills: 10,
        maxPrograms: 3,
        isActive: true,
        priority: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      SubscriptionPlan(
        id: 'institute',
        name: 'Institute Plan',
        description: 'Full access for educational institutions',
        price: 99.99,
        currency: 'USD',
        billingPeriod: 'monthly',
        features: [
          'All drills and programs',
          'Advanced analytics',
          'Multiplayer sessions',
          'Admin dashboard',
          'User management',
          'Custom branding',
        ],
        moduleAccess: [
          'all_drills',
          'all_programs',
          'advanced_stats',
          'multiplayer',
          'admin',
          'analytics',
          'user_management',
        ],
        maxDrills: -1, // unlimited
        maxPrograms: -1, // unlimited
        isActive: true,
        priority: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      SubscriptionPlan(
        id: 'premium',
        name: 'Premium Plan',
        description: 'Advanced features for serious trainers',
        price: 19.99,
        currency: 'USD',
        billingPeriod: 'monthly',
        features: [
          'All drills and programs',
          'Advanced analytics',
          'Multiplayer sessions',
          'Priority support',
        ],
        moduleAccess: [
          'all_drills',
          'all_programs',
          'advanced_stats',
          'multiplayer',
        ],
        maxDrills: -1, // unlimited
        maxPrograms: -1, // unlimited
        isActive: true,
        priority: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final plan in defaultPlans) {
      try {
        await _planRepository.createPlan(plan);
        print('✅ Created plan: ${plan.name}');
      } catch (e) {
        print('❌ Failed to create plan ${plan.name}: $e');
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
          print('📡 Plan $planId was modified, syncing affected users...');
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
      
      print('✅ Synced ${usersSnapshot.docs.length} users for plan $planId');
    } catch (e) {
      print('❌ Error syncing users for plan $planId: $e');
    }
  }

  /// Update a user's module access to match their plan
  Future<void> _updateUserModuleAccess(String userId, List<String> moduleAccess) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'subscription.moduleAccess': moduleAccess,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating module access for user $userId: $e');
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
        print('✅ Synced module access for user $userId on login');
      }
    } catch (e) {
      print('❌ Error syncing user on login: $e');
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
    _isInitialized = false;
  }
}