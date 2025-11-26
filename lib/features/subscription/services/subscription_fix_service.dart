import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One-time service to fix subscription sync issues
class SubscriptionFixService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fix current user's subscription by syncing with their plan definition
  Future<void> fixCurrentUserSubscription() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('❌ No authenticated user found');
        return;
      }

      print('🔧 Fixing subscription for user: ${currentUser.uid}');

      // Get user document
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        print('❌ User document not found');
        return;
      }

      final userData = userDoc.data()!;
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      
      if (subscription == null) {
        print('❌ No subscription found');
        return;
      }

      final planId = subscription['plan'] as String?;
      if (planId == null) {
        print('❌ No plan ID found');
        return;
      }

      print('📋 Current plan: $planId');

      // Get the plan definition from database
      final planDoc = await _firestore
          .collection('subscription_plans')
          .doc(planId)
          .get();

      if (!planDoc.exists) {
        print('❌ Plan "$planId" not found in database');
        return;
      }

      final planData = planDoc.data()!;
      final planModuleAccess = planData['moduleAccess'];
      final correctModuleAccess = planModuleAccess is List 
          ? List<String>.from(planModuleAccess) 
          : <String>[];

      print('✅ Plan "$planId" found with modules: $correctModuleAccess');

      // Get current user module access
      final currentModuleAccessData = subscription['moduleAccess'];
      final currentModuleAccess = currentModuleAccessData is List 
          ? List<String>.from(currentModuleAccessData) 
          : <String>[];

      print('📊 Current user modules: $currentModuleAccess');

      // Check if they match
      if (_listsEqual(currentModuleAccess, correctModuleAccess)) {
        print('✅ Module access already correct - no fix needed');
        return;
      }

      print('🔄 Updating user module access...');

      // Update the entire subscription object with correct module access
      final updatedSubscription = Map<String, dynamic>.from(subscription);
      updatedSubscription['moduleAccess'] = correctModuleAccess;

      // Update user's subscription with correct module access
      await _firestore.collection('users').doc(currentUser.uid).update({
        'subscription': updatedSubscription,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Successfully updated user subscription!');
      print('   Old modules: $currentModuleAccess');
      print('   New modules: $correctModuleAccess');
      print('🔄 Please restart the app to see changes');

    } catch (e) {
      print('❌ Error fixing subscription: $e');
      rethrow;
    }
  }

  /// Helper method to compare two lists for equality
  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    
    final set1 = Set<String>.from(list1);
    final set2 = Set<String>.from(list2);
    
    return set1.containsAll(set2) && set2.containsAll(set1);
  }

  /// Fix all users' subscriptions (admin only)
  Future<void> fixAllUserSubscriptions() async {
    try {
      print('🔧 Fixing all user subscriptions...');
      
      final usersSnapshot = await _firestore.collection('users').get();
      int fixedCount = 0;
      int errorCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final subscription = userData['subscription'] as Map<String, dynamic>?;
          
          if (subscription == null) continue;

          final planId = subscription['plan'] as String?;
          if (planId == null) continue;

          // Get plan definition
          final planDoc = await _firestore
              .collection('subscription_plans')
              .doc(planId)
              .get();

          if (!planDoc.exists) {
            print('⚠️ Plan "$planId" not found for user ${userDoc.id}');
            continue;
          }

          final planData = planDoc.data()!;
          final planModuleAccess = planData['moduleAccess'];
          final correctModuleAccess = planModuleAccess is List 
              ? List<String>.from(planModuleAccess) 
              : <String>[];

          // Get current user module access
          final currentModuleAccessData = subscription['moduleAccess'];
          final currentModuleAccess = currentModuleAccessData is List 
              ? List<String>.from(currentModuleAccessData) 
              : <String>[];

          // Check if they match
          if (!_listsEqual(currentModuleAccess, correctModuleAccess)) {
            // Get current subscription and update the entire object
            final currentSubscription = subscription as Map<String, dynamic>;
            final updatedSubscription = Map<String, dynamic>.from(currentSubscription);
            updatedSubscription['moduleAccess'] = correctModuleAccess;

            // Update user's subscription
            await _firestore.collection('users').doc(userDoc.id).update({
              'subscription': updatedSubscription,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            print('✅ Fixed user ${userDoc.id} (plan: $planId)');
            fixedCount++;
          }

        } catch (e) {
          print('❌ Error fixing user ${userDoc.id}: $e');
          errorCount++;
        }
      }

      print('✅ Fix completed: $fixedCount users fixed, $errorCount errors');
    } catch (e) {
      print('❌ Error fixing all subscriptions: $e');
      rethrow;
    }
  }
}