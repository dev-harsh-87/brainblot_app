import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/features/subscription/domain/subscription_plan.dart';

/// Repository for managing subscription plans in Firestore
class SubscriptionPlanRepository {
  final FirebaseFirestore _firestore;

  static const String _plansCollection = 'subscription_plans';

  SubscriptionPlanRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a new subscription plan (admin only)
  Future<void> createPlan(SubscriptionPlan plan) async {
    try {
      await _firestore
          .collection(_plansCollection)
          .doc(plan.id)
          .set(plan.toFirestore());
    } catch (e) {
      throw Exception('Failed to create subscription plan: $e');
    }
  }

  /// Update an existing subscription plan (admin only)
  Future<void> updatePlan(SubscriptionPlan plan) async {
    try {
      await _firestore
          .collection(_plansCollection)
          .doc(plan.id)
          .update(plan.toFirestore());
    } catch (e) {
      throw Exception('Failed to update subscription plan: $e');
    }
  }

  /// Delete a subscription plan (admin only)
  Future<void> deletePlan(String planId) async {
    try {
      await _firestore.collection(_plansCollection).doc(planId).delete();
    } catch (e) {
      throw Exception('Failed to delete subscription plan: $e');
    }
  }

  /// Get a specific subscription plan by ID
  Future<SubscriptionPlan?> getPlan(String planId) async {
    try {
      final doc =
          await _firestore.collection(_plansCollection).doc(planId).get();

      if (!doc.exists) return null;

      return SubscriptionPlan.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get subscription plan: $e');
    }
  }

  /// Get all active subscription plans
  Future<List<SubscriptionPlan>> getActivePlans() async {
    try {
      final snapshot = await _firestore
          .collection(_plansCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => SubscriptionPlan.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get active subscription plans: $e');
    }
  }

  /// Get all subscription plans (admin only)
  Future<List<SubscriptionPlan>> getAllPlans() async {
    try {
      final snapshot = await _firestore
          .collection(_plansCollection)
          .orderBy('priority', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => SubscriptionPlan.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all subscription plans: $e');
    }
  }

  /// Watch subscription plans changes
  Stream<List<SubscriptionPlan>> watchActivePlans() {
    return _firestore
        .collection(_plansCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SubscriptionPlan.fromFirestore(doc))
            .toList(),);
  }

  /// Watch all subscription plans changes (admin only)
  Stream<List<SubscriptionPlan>> watchAllPlans() {
    return _firestore
        .collection(_plansCollection)
        .orderBy('priority', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SubscriptionPlan.fromFirestore(doc))
            .toList(),);
  }

  /// Toggle plan active status (admin only)
  Future<void> togglePlanStatus(String planId, bool isActive) async {
    try {
      await _firestore.collection(_plansCollection).doc(planId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to toggle plan status: $e');
    }
  }

  /// Initialize default plans (one-time setup) - REMOVED
  /// Plans should be created dynamically by admins through the admin panel
  /// This ensures complete flexibility and no hardcoded data
  @Deprecated('Use admin panel to create plans dynamically')
  Future<void> initializeDefaultPlans() async {
    // No longer initializes hardcoded plans
    // Admins should create plans through the subscription management screen
    print('⚠️ initializeDefaultPlans is deprecated. Use admin panel to create plans.');
  }
}
