import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// One-time service to force update all users to the new module access
class ForceModuleUpdateService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ForceModuleUpdateService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Force update current user to new module access
  Future<void> forceUpdateCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await forceUpdateUser(user.uid);
  }

  /// Force update specific user to new module access
  Future<void> forceUpdateUser(String userId) async {
    try {
      AppLogger.info('Force updating user $userId to new module access', tag: 'ForceModuleUpdate');

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final role = userData['role'] as String? ?? 'user';
      
      // Get the correct default modules based on role
      final newModules = _getDefaultModulesForRole(role);

      await _firestore.collection('users').doc(userId).update({
        'subscription.moduleAccess': newModules,
        'subscription.plan': role == 'admin' ? 'institute' : 'free',
        'subscription.status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success(
        'Force updated user $userId to modules: $newModules',
        tag: 'ForceModuleUpdate'
      );

    } catch (e) {
      AppLogger.error('Error force updating user $userId', error: e, tag: 'ForceModuleUpdate');
    }
  }

  /// Get default modules for a role
  List<String> _getDefaultModulesForRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
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
          'host_features',
          'bulk_operations',
        ];
      case 'user':
      default:
        return [
          'drills',
          'programs',
          'profile',
          'stats',
          'subscription',
        ];
    }
  }

  /// Force update all users in the system
  Future<void> forceUpdateAllUsers() async {
    try {
      AppLogger.info('Starting force update for all users', tag: 'ForceModuleUpdate');

      final usersSnapshot = await _firestore.collection('users').get();
      int updatedCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final role = userData['role'] as String? ?? 'user';
        final newModules = _getDefaultModulesForRole(role);

        await _firestore.collection('users').doc(userDoc.id).update({
          'subscription.moduleAccess': newModules,
          'subscription.plan': role == 'admin' ? 'institute' : 'free',
          'subscription.status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        updatedCount++;
        AppLogger.info(
          'Updated user ${userDoc.id} ($role) to modules: $newModules',
          tag: 'ForceModuleUpdate'
        );
      }

      AppLogger.success(
        'Force update complete: $updatedCount users updated',
        tag: 'ForceModuleUpdate'
      );

    } catch (e) {
      AppLogger.error('Error in force update all users', error: e, tag: 'ForceModuleUpdate');
    }
  }
}