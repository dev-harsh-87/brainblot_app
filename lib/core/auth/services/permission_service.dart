import 'package:brainblot_app/core/auth/models/user_role.dart';
import 'package:brainblot_app/core/auth/models/permission.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing permissions and role-based access control
class PermissionService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  PermissionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get current user's role from Firestore
  Future<UserRole> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return UserRole.user;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) return UserRole.user;

      final data = doc.data()!;
      final roleString = data['role'] as String?;
      return UserRole.fromString(roleString ?? 'user');
    } catch (e) {
      return UserRole.user;
    }
  }

  /// Get user role by user ID
  Future<UserRole> getUserRole(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) return UserRole.user;

      final data = doc.data()!;
      final roleString = data['role'] as String?;
      return UserRole.fromString(roleString ?? 'user');
    } catch (e) {
      return UserRole.user;
    }
  }

  /// Check if current user has a specific permission
  Future<bool> hasPermission(Permission permission) async {
    final role = await getCurrentUserRole();
    return permission.isGrantedTo(role);
  }

  /// Check if user has required role or higher
  Future<bool> hasRole(UserRole requiredRole) async {
    final role = await getCurrentUserRole();
    return role.hasPermission(requiredRole);
  }

  /// Check if current user is super admin
  Future<bool> isSuperAdmin() async {
    final role = await getCurrentUserRole();
    return role.isSuperAdmin();
  }

  /// Update user role (admin only)
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    final currentRole = await getCurrentUserRole();
    
    if (!currentRole.isSuperAdmin()) {
      throw Exception('Only super admins can update user roles');
    }

    await _firestore.collection('users').doc(userId).update({
      'role': newRole.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all permissions for current user
  Future<List<Permission>> getUserPermissions() async {
    final role = await getCurrentUserRole();
    return role.permissions;
  }

  /// Check if user has access to a specific module based on subscription
  Future<bool> hasModuleAccess(String module) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) return false;

      final data = doc.data()!;
      final subscription = data['subscription'] as Map<String, dynamic>?;
      
      if (subscription == null) return false;

      final features = subscription['features'] as List<dynamic>?;
      if (features == null) return false;

      return features.contains(module);
    } catch (e) {
      return false;
    }
  }

  /// Check if user can access advanced features based on subscription
  Future<bool> canAccessAdvancedFeatures() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) return false;

      final data = doc.data()!;
      final subscription = data['subscription'] as Map<String, dynamic>?;
      
      if (subscription == null) return false;

      final planId = subscription['planId'] as String?;
      // Advanced features available for Player and Institute plans
      return planId == 'player' || planId == 'institute';
    } catch (e) {
      return false;
    }
  }

  /// Check multiple permissions at once
  Future<Map<Permission, bool>> checkPermissions(List<Permission> permissions) async {
    final role = await getCurrentUserRole();
    return {
      for (var permission in permissions)
        permission: permission.isGrantedTo(role)
    };
  }

  /// Stream user role changes
  Stream<UserRole> watchUserRole() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(UserRole.user);

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return UserRole.user;
      
      final data = doc.data()!;
      final roleString = data['role'] as String?;
      return UserRole.fromString(roleString ?? 'user');
    });
  }

  /// Grant specific permissions to user (super admin only)
  Future<void> grantPermissions(String userId, List<String> permissions) async {
    final currentRole = await getCurrentUserRole();
    
    if (!currentRole.isSuperAdmin()) {
      throw Exception('Only super admins can grant permissions');
    }

    await _firestore.collection('users').doc(userId).update({
      'customPermissions': FieldValue.arrayUnion(permissions),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Revoke specific permissions from user (super admin only)
  Future<void> revokePermissions(String userId, List<String> permissions) async {
    final currentRole = await getCurrentUserRole();
    
    if (!currentRole.isSuperAdmin()) {
      throw Exception('Only super admins can revoke permissions');
    }

    await _firestore.collection('users').doc(userId).update({
      'customPermissions': FieldValue.arrayRemove(permissions),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}