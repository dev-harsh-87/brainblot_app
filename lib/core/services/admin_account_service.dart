import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Service to create and manage admin accounts
class AdminAccountService {
  static const String _tag = 'AdminAccountService';
  
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  
  AdminAccountService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create admin account if it doesn't exist
  Future<AdminAccountResult> createAdminAccountIfNeeded() async {
    try {
      AppLogger.info('🔍 Checking for admin account...', tag: _tag);
      
      // Step 1: Check if admin user already exists in Firestore
      final adminQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: 'admin@gmail.com')
          .where('role', isEqualTo: 'admin')
          .get();
      
      if (adminQuery.docs.isNotEmpty) {
        AppLogger.success('✅ Admin account already exists', tag: _tag);
        final adminDoc = adminQuery.docs.first;
        return AdminAccountResult(
          success: true,
          message: 'Admin account already exists',
          userId: adminDoc.id,
          email: 'admin@gmail.com',
          alreadyExists: true,
        );
      }
      
      AppLogger.info('🚀 Creating admin account...', tag: _tag);
      
      // Step 2: Create Firebase Auth user
      UserCredential? userCredential;
      String? userId;
      
      try {
        // Try to create new user
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: 'admin@gmail.com',
          password: 'Admin@1234',
        );
        userId = userCredential.user!.uid;
        AppLogger.success('✅ Firebase Auth user created: $userId', tag: _tag);
      } catch (authError) {
        if (authError.toString().contains('email-already-in-use')) {
          AppLogger.info('📧 Email already exists in Auth, trying to sign in...', tag: _tag);
          try {
            userCredential = await _auth.signInWithEmailAndPassword(
              email: 'admin@gmail.com',
              password: 'Admin@1234',
            );
            userId = userCredential.user!.uid;
            AppLogger.success('✅ Signed in to existing Firebase Auth user: $userId', tag: _tag);
          } catch (signInError) {
            AppLogger.error('❌ Failed to sign in to existing user', error: signInError, tag: _tag);
            throw Exception('Admin user exists in Auth but password is incorrect: $signInError');
          }
        } else {
          AppLogger.error('❌ Failed to create Firebase Auth user', error: authError, tag: _tag);
          throw Exception('Failed to create Firebase Auth user: $authError');
        }
      }
      
      if (userId == null) {
        throw Exception('Failed to get user ID from Firebase Auth');
      }
      
      // Step 3: Update display name in Firebase Auth
      try {
        await userCredential!.user!.updateDisplayName('Administrator');
        AppLogger.success('✅ Updated Firebase Auth display name', tag: _tag);
      } catch (e) {
        AppLogger.warning('⚠️ Failed to update display name in Auth: $e', tag: _tag);
      }
      
      // Step 4: Create comprehensive Firestore document
      AppLogger.info('📄 Creating Firestore user document...', tag: _tag);
      
      final adminData = {
        'id': userId,
        'email': 'admin@gmail.com',
        'displayName': 'Administrator',
        'role': 'admin',
        'photoUrl': null,
        'subscription': {
          'plan': 'premium',
          'status': 'active',
          'startDate': FieldValue.serverTimestamp(),
          'endDate': null, // No expiry for admin
          'moduleAccess': {
            // Core modules
            'drills': true,
            'profile': true,
            'stats': true,
            'analysis': true,
            // Admin modules
            'admin_drills': true,
            'admin_programs': true,
            'programs': true,
            'multiplayer': true,
            'user_management': true,
            'team_management': true,
            'bulk_operations': true,
            'subscription_management': true,
            'category_management': true,
            'system_analytics': true,
            // All possible modules
            'advanced_analytics': true,
            'export_data': true,
            'api_access': true,
          }
        },
        'preferences': {
          'theme': 'system',
          'notifications': true,
          'soundEnabled': true,
          'language': 'en',
          'timezone': 'UTC',
          'emailNotifications': true,
          'pushNotifications': true,
        },
        'stats': {
          'totalSessions': 0,
          'totalDrillsCompleted': 0,
          'totalProgramsCompleted': 0,
          'averageAccuracy': 0.0,
          'averageReactionTime': 0.0,
          'streakDays': 0,
          'lastSessionAt': null,
          'totalLoginTime': 0,
          'lastLoginAt': null,
        },
        'permissions': {
          'canCreateUsers': true,
          'canDeleteUsers': true,
          'canModifyRoles': true,
          'canAccessAnalytics': true,
          'canManageSubscriptions': true,
          'canManageCategories': true,
          'canExportData': true,
          'canAccessSystemLogs': true,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': {
          'system': true,
          'adminId': 'system',
          'adminName': 'System',
          'adminEmail': 'system@spark.com',
        },
        'isActive': true,
        'emailVerified': true,
      };
      
      // Use set with merge to avoid overwriting if document exists
      await _firestore
          .collection('users')
          .doc(userId)
          .set(adminData, SetOptions(merge: true));
      
      AppLogger.success('✅ Firestore user document created', tag: _tag);
      
      // Step 5: Create admin session document for device management
      try {
        await _firestore
            .collection('userSessions')
            .doc(userId)
            .set({
          'userId': userId,
          'deviceId': 'admin_system',
          'deviceName': 'Admin System',
          'deviceType': 'System',
          'platform': 'System',
          'appVersion': '1.0.0',
          'fcmToken': null,
          'loginTime': FieldValue.serverTimestamp(),
          'lastActiveTime': FieldValue.serverTimestamp(),
          'isActive': true,
        });
        AppLogger.success('✅ Admin session document created', tag: _tag);
      } catch (e) {
        AppLogger.warning('⚠️ Failed to create session document: $e', tag: _tag);
      }
      
      // Step 6: Sign out the admin user to avoid interfering with normal app flow
      await _auth.signOut();
      AppLogger.info('🔓 Signed out admin user', tag: _tag);
      
      AppLogger.success('🎉 ADMIN ACCOUNT CREATED SUCCESSFULLY!', tag: _tag);
      
      return AdminAccountResult(
        success: true,
        message: 'Admin account created successfully',
        userId: userId,
        email: 'admin@gmail.com',
        alreadyExists: false,
      );
      
    } catch (e) {
      AppLogger.error('❌ Failed to create admin account', error: e, tag: _tag);
      return AdminAccountResult(
        success: false,
        message: 'Failed to create admin account: $e',
        error: e.toString(),
      );
    }
  }
  
  /// Verify admin account exists and is properly configured
  Future<bool> verifyAdminAccount() async {
    try {
      AppLogger.info('🔍 Verifying admin account...', tag: _tag);
      
      // Check Firestore document
      final adminQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: 'admin@gmail.com')
          .where('role', isEqualTo: 'admin')
          .get();
      
      if (adminQuery.docs.isEmpty) {
        AppLogger.warning('⚠️ Admin account not found in Firestore', tag: _tag);
        return false;
      }
      
      final adminDoc = adminQuery.docs.first;
      final adminData = adminDoc.data();
      
      // Verify required fields
      final requiredFields = ['email', 'role', 'displayName', 'subscription'];
      for (final field in requiredFields) {
        if (!adminData.containsKey(field)) {
          AppLogger.warning('⚠️ Admin account missing field: $field', tag: _tag);
          return false;
        }
      }
      
      // Verify subscription and permissions
      final subscription = adminData['subscription'] as Map<String, dynamic>?;
      if (subscription == null || subscription['status'] != 'active') {
        AppLogger.warning('⚠️ Admin account subscription not active', tag: _tag);
        return false;
      }
      
      AppLogger.success('✅ Admin account verified successfully', tag: _tag);
      return true;
      
    } catch (e) {
      AppLogger.error('❌ Error verifying admin account', error: e, tag: _tag);
      return false;
    }
  }
  
  /// Get admin account details
  Future<Map<String, dynamic>?> getAdminAccountDetails() async {
    try {
      final adminQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: 'admin@gmail.com')
          .where('role', isEqualTo: 'admin')
          .get();
      
      if (adminQuery.docs.isNotEmpty) {
        final adminDoc = adminQuery.docs.first;
        return {
          'id': adminDoc.id,
          ...adminDoc.data(),
        };
      }
      
      return null;
    } catch (e) {
      AppLogger.error('Error getting admin account details', error: e, tag: _tag);
      return null;
    }
  }
}

/// Result of admin account creation
class AdminAccountResult {
  final bool success;
  final String message;
  final String? userId;
  final String? email;
  final bool alreadyExists;
  final String? error;
  
  AdminAccountResult({
    required this.success,
    required this.message,
    this.userId,
    this.email,
    this.alreadyExists = false,
    this.error,
  });
  
  @override
  String toString() {
    return 'AdminAccountResult(success: $success, message: $message, userId: $userId, alreadyExists: $alreadyExists)';
  }
}