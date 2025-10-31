import 'package:brainblot_app/core/auth/models/permission.dart';
import 'package:brainblot_app/core/auth/models/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing subscription-based permissions and access control
class SubscriptionPermissionService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  SubscriptionPermissionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get current app user with subscription details
  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) return null;

      return AppUser.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Check if user has access to a specific module based on subscription
  Future<bool> hasModuleAccess(String module) async {
    final appUser = await getCurrentUser();
    if (appUser == null) return false;

    // Admin always has access to all modules
    if (appUser.role.isAdmin()) return true;

    return appUser.hasModuleAccess(module);
  }

  /// Check if user can access admin-created drills
  Future<bool> canAccessAdminDrills() async {
    final appUser = await getCurrentUser();
    if (appUser == null) return false;

    return appUser.canAccessAdminContent();
  }

  /// Check if user can access admin-created programs
  Future<bool> canAccessAdminPrograms() async {
    final appUser = await getCurrentUser();
    if (appUser == null) return false;

    return appUser.canAccessAdminContent();
  }

  /// Check if user can create programs
  Future<bool> canCreatePrograms() async {
    final appUser = await getCurrentUser();
    if (appUser == null) return false;

    return appUser.canCreatePrograms();
  }

  /// Check if user can manage other users
  Future<bool> canManageUsers() async {
    final appUser = await getCurrentUser();
    if (appUser == null) return false;

    return appUser.canManageUsers();
  }

  /// Check if user is admin
  Future<bool> isAdmin() async {
    final appUser = await getCurrentUser();
    if (appUser == null) return false;

    return appUser.role.isAdmin();
  }

  /// Check if user has specific permission
  Future<bool> hasPermission(Permission permission) async {
    final appUser = await getCurrentUser();
    if (appUser == null) return false;

    return permission.isGrantedTo(appUser.role);
  }

  /// Get user's subscription plan
  Future<String?> getSubscriptionPlan() async {
    final appUser = await getCurrentUser();
    if (appUser == null) return null;

    return appUser.subscription.plan;
  }

  /// Check if user's subscription is active
  Future<bool> isSubscriptionActive() async {
    final appUser = await getCurrentUser();
    if (appUser == null) return false;

    return appUser.subscription.isActive();
  }

  /// Get all module access for current user
  Future<List<String>> getUserModuleAccess() async {
    final appUser = await getCurrentUser();
    if (appUser == null) return [];

    return appUser.subscription.moduleAccess;
  }

  /// Stream user changes
  Stream<AppUser?> watchCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  /// Update user subscription (admin only)
  Future<void> updateUserSubscription({
    required String userId,
    required String plan,
    required List<String> moduleAccess,
    DateTime? expiresAt,
  }) async {
    final currentUser = await getCurrentUser();
    if (currentUser == null || !currentUser.role.isAdmin()) {
      throw Exception('Only admins can update subscriptions');
    }

    await _firestore.collection('users').doc(userId).update({
      'subscription.plan': plan,
      'subscription.moduleAccess': moduleAccess,
      'subscription.expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get subscription features for display
  Future<Map<String, dynamic>> getSubscriptionFeatures() async {
    final appUser = await getCurrentUser();
    if (appUser == null) {
      return {
        'plan': 'none',
        'canAccessAdminDrills': false,
        'canAccessAdminPrograms': false,
        'canCreatePrograms': false,
        'canManageUsers': false,
        'moduleAccess': <String>[],
      };
    }

    return {
      'plan': appUser.subscription.plan,
      'canAccessAdminDrills': appUser.canAccessAdminContent(),
      'canAccessAdminPrograms': appUser.canAccessAdminContent(),
      'canCreatePrograms': appUser.canCreatePrograms(),
      'canManageUsers': appUser.canManageUsers(),
      'moduleAccess': appUser.subscription.moduleAccess,
      'isAdmin': appUser.role.isAdmin(),
    };
  }
}