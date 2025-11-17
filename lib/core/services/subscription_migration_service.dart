import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Service to migrate existing users to the new consistent module access system
class SubscriptionMigrationService {
  final FirebaseFirestore _firestore;

  SubscriptionMigrationService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Migrate all users to use consistent module access names
  Future<void> migrateAllUsers() async {
    try {
      AppLogger.info('Starting subscription migration for all users');

      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      int migratedCount = 0;
      int errorCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final subscription = userData['subscription'] as Map<String, dynamic>?;
          
          if (subscription == null) {
            AppLogger.debug('User ${userDoc.id} has no subscription, skipping');
            continue;
          }

          final planId = subscription['plan'] as String?;
          if (planId == null) {
            AppLogger.debug('User ${userDoc.id} has no plan ID, skipping');
            continue;
          }

          // Get the correct module access for this plan
          final correctModuleAccess = _getCorrectModuleAccessForPlan(planId, userData);
          final currentModuleAccess = subscription['moduleAccess'] as List<dynamic>?;
          final currentModuleAccessList = currentModuleAccess != null 
              ? List<String>.from(currentModuleAccess) 
              : <String>[];

          // Check if migration is needed
          if (!_listsEqual(currentModuleAccessList, correctModuleAccess)) {
            await _firestore.collection('users').doc(userDoc.id).update({
              'subscription.moduleAccess': correctModuleAccess,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
            AppLogger.info('Migrated user ${userDoc.id} from $currentModuleAccessList to $correctModuleAccess');
            migratedCount++;
          } else {
            AppLogger.debug('User ${userDoc.id} already has correct module access');
          }
        } catch (e) {
          AppLogger.error('Error migrating user ${userDoc.id}', error: e);
          errorCount++;
        }
      }

      AppLogger.success('Migration completed: $migratedCount users migrated, $errorCount errors');
    } catch (e) {
      AppLogger.error('Error during subscription migration', error: e);
      rethrow;
    }
  }

  /// Get the correct module access for a plan based on plan ID and user role
  List<String> _getCorrectModuleAccessForPlan(String planId, Map<String, dynamic> userData) {
    final role = userData['role'] as String? ?? 'user';
    
    // Admin users get full access regardless of plan
    if (role == 'admin') {
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

    // Regular users get access based on their plan
    switch (planId) {
      case 'free':
        return [
          'drills',
          'profile',
          'stats',
          'analysis',
        ];
      case 'premium':
        return [
          'drills',
          'profile',
          'stats',
          'analysis',
          'admin_drills',
          'admin_programs',
          'programs',
          'multiplayer',
        ];
      case 'institute':
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
      default:
        // Unknown plan, give basic access
        return [
          'drills',
          'profile',
          'stats',
          'analysis',
        ];
    }
  }

  /// Helper method to compare two lists for equality
  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    
    final set1 = Set<String>.from(list1);
    final set2 = Set<String>.from(list2);
    
    return set1.containsAll(set2) && set2.containsAll(set1);
  }

  /// Migrate a specific user by user ID
  Future<void> migrateUser(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        AppLogger.warning('User $userId not found');
        return;
      }

      final userData = userDoc.data()!;
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      
      if (subscription == null) {
        AppLogger.debug('User $userId has no subscription, skipping');
        return;
      }

      final planId = subscription['plan'] as String?;
      if (planId == null) {
        AppLogger.debug('User $userId has no plan ID, skipping');
        return;
      }

      // Get the correct module access for this plan
      final correctModuleAccess = _getCorrectModuleAccessForPlan(planId, userData);
      final currentModuleAccess = subscription['moduleAccess'] as List<dynamic>?;
      final currentModuleAccessList = currentModuleAccess != null 
          ? List<String>.from(currentModuleAccess) 
          : <String>[];

      // Check if migration is needed
      if (!_listsEqual(currentModuleAccessList, correctModuleAccess)) {
        await _firestore.collection('users').doc(userId).update({
          'subscription.moduleAccess': correctModuleAccess,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        AppLogger.info('Migrated user $userId from $currentModuleAccessList to $correctModuleAccess');
      } else {
        AppLogger.debug('User $userId already has correct module access');
      }
    } catch (e) {
      AppLogger.error('Error migrating user $userId', error: e);
      rethrow;
    }
  }

  /// Update subscription plans in Firestore to use consistent module names
  Future<void> updateSubscriptionPlans() async {
    try {
      AppLogger.info('Updating subscription plans with consistent module names');

      final plans = {
        'free': [
          'drills',
          'profile',
          'stats',
          'analysis',
        ],
        'premium': [
          'drills',
          'profile',
          'stats',
          'analysis',
          'admin_drills',
          'admin_programs',
          'programs',
          'multiplayer',
        ],
        'institute': [
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
      };

      for (final entry in plans.entries) {
        final planId = entry.key;
        final moduleAccess = entry.value;

        try {
          await _firestore.collection('subscription_plans').doc(planId).update({
            'moduleAccess': moduleAccess,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          AppLogger.info('Updated plan $planId with modules: $moduleAccess');
        } catch (e) {
          AppLogger.error('Error updating plan $planId', error: e);
        }
      }

      AppLogger.success('Subscription plans updated successfully');
    } catch (e) {
      AppLogger.error('Error updating subscription plans', error: e);
      rethrow;
    }
  }
}