import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/core/auth/services/comprehensive_permission_service.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Service to fix module access naming issues
/// Converts old module names (basic_drills, basic_programs) to new names (drills, programs)
class ModuleAccessFixService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ComprehensivePermissionService? _permissionService;

  ModuleAccessFixService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ComprehensivePermissionService? permissionService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _permissionService = permissionService;

  /// Fix current user's module access
  Future<void> fixCurrentUserModuleAccess() async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.warning('No authenticated user to fix', tag: 'ModuleAccessFix');
      return;
    }

    await fixUserModuleAccess(user.uid);
  }

  /// Fix specific user's module access
  Future<void> fixUserModuleAccess(String userId) async {
    try {
      AppLogger.info('Fixing module access for user: $userId', tag: 'ModuleAccessFix');

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        AppLogger.warning('User document not found: $userId', tag: 'ModuleAccessFix');
        return;
      }

      final userData = userDoc.data()!;
      final subscription = userData['subscription'] as Map<String, dynamic>?;
      
      if (subscription == null) {
        AppLogger.warning('No subscription data found for user: $userId', tag: 'ModuleAccessFix');
        return;
      }

      final moduleAccessData = subscription['moduleAccess'];
      if (moduleAccessData == null) {
        AppLogger.warning('No moduleAccess found for user: $userId', tag: 'ModuleAccessFix');
        return;
      }

      final currentModules = moduleAccessData is List
          ? List<String>.from(moduleAccessData)
          : <String>[];
      final fixedModules = _fixModuleNames(currentModules);

      if (_hasChanges(currentModules, fixedModules)) {
        await _firestore.collection('users').doc(userId).update({
          'subscription.moduleAccess': fixedModules,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        AppLogger.success(
          'Fixed module access for user $userId: $currentModules -> $fixedModules',
          tag: 'ModuleAccessFix'
        );

        // Clear permission cache to ensure updated modules are reflected immediately
        _permissionService?.refreshPermissions();
      } else {
        AppLogger.info('No module access fixes needed for user: $userId', tag: 'ModuleAccessFix');
      }

    } catch (e) {
      AppLogger.error('Error fixing module access for user $userId', error: e, tag: 'ModuleAccessFix');
    }
  }

  /// Fix all users' module access
  Future<void> fixAllUsersModuleAccess() async {
    try {
      AppLogger.info('Starting bulk module access fix for all users', tag: 'ModuleAccessFix');

      final usersSnapshot = await _firestore.collection('users').get();
      int fixedCount = 0;
      int totalCount = usersSnapshot.docs.length;

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final subscription = userData['subscription'] as Map<String, dynamic>?;
        
        if (subscription == null) continue;

        final moduleAccessData = subscription['moduleAccess'];
        if (moduleAccessData == null) continue;

        final currentModules = moduleAccessData is List
            ? List<String>.from(moduleAccessData)
            : <String>[];
        final fixedModules = _fixModuleNames(currentModules);

        if (_hasChanges(currentModules, fixedModules)) {
          await _firestore.collection('users').doc(userDoc.id).update({
            'subscription.moduleAccess': fixedModules,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          fixedCount++;
          
          AppLogger.info(
            'Fixed user ${userDoc.id}: $currentModules -> $fixedModules',
            tag: 'ModuleAccessFix'
          );
        }
      }

      AppLogger.success(
        'Bulk module access fix complete: $fixedCount/$totalCount users updated',
        tag: 'ModuleAccessFix'
      );

    } catch (e) {
      AppLogger.error('Error in bulk module access fix', error: e, tag: 'ModuleAccessFix');
    }
  }

  /// Convert old module names to new ones
  List<String> _fixModuleNames(List<String> modules) {
    return modules.map((module) {
      switch (module) {
        case 'basic_drills':
          return 'drills';
        case 'basic_programs':
          return 'programs';
        default:
          return module;
      }
    }).toList();
  }

  /// Check if there are any changes needed
  bool _hasChanges(List<String> original, List<String> fixed) {
    if (original.length != fixed.length) return true;
    
    for (int i = 0; i < original.length; i++) {
      if (original[i] != fixed[i]) return true;
    }
    
    return false;
  }

  /// Get default module access for a user role
  static List<String> getDefaultModuleAccess(String role) {
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

  /// Reset user to default module access based on their role
  Future<void> resetUserToDefaultModules(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final role = userData['role'] as String? ?? 'user';
      final defaultModules = getDefaultModuleAccess(role);

      await _firestore.collection('users').doc(userId).update({
        'subscription.moduleAccess': defaultModules,
        'subscription.plan': role == 'admin' ? 'institute' : 'free',
        'subscription.status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success(
        'Reset user $userId to default modules for role $role: $defaultModules',
        tag: 'ModuleAccessFix'
      );

    } catch (e) {
      AppLogger.error('Error resetting user to default modules', error: e, tag: 'ModuleAccessFix');
    }
  }
}