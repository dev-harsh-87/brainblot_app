import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';
import 'package:brainblot_app/core/auth/models/app_user.dart';

/// Utility to manually create Super Admin account
/// Use this if the automatic initialization didn't create the account
class CreateSuperAdmin {
  static const String _superAdminEmail = 'superadmin@brainblot.com';
  static const String _superAdminPassword = 'SuperAdmin@123456';

  /// Create Super Admin account in Firebase
  static Future<void> create() async {
    try {
      print('🚀 Creating Super Admin account...');
      
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      // Check if Super Admin already exists
      final existingUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: _superAdminEmail)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        print('✅ Super Admin already exists!');
        print('📧 Email: $_superAdminEmail');
        print('🔑 Password: $_superAdminPassword');
        return;
      }

      // Create auth user
      UserCredential userCredential;
      try {
        userCredential = await auth.createUserWithEmailAndPassword(
          email: _superAdminEmail,
          password: _superAdminPassword,
        );
        print('✅ Firebase Auth user created');
      } catch (e) {
        // If user exists in auth but not in Firestore, sign in
        print('ℹ️ Auth user exists, signing in...');
        userCredential = await auth.signInWithEmailAndPassword(
          email: _superAdminEmail,
          password: _superAdminPassword,
        );
      }

      final userId = userCredential.user!.uid;

      // Create Super Admin user document
      final superAdmin = AppUser(
        id: userId,
        email: _superAdminEmail,
        displayName: 'Super Administrator',
        role: UserRole.superAdmin,
        subscription: UserSubscription.institute(),
        preferences: const UserPreferences(),
        stats: const UserStats(),
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestore
          .collection('users')
          .doc(userId)
          .set(superAdmin.toFirestore());

      print('✅ Super Admin created successfully!');
      print('=' * 50);
      print('📧 Email: $_superAdminEmail');
      print('🔑 Password: $_superAdminPassword');
      print('=' * 50);
      print('⚠️ Please change this password after first login!');
    } catch (e) {
      print('❌ Failed to create Super Admin: $e');
      rethrow;
    }
  }

  /// Get Super Admin credentials
  static Map<String, String> getCredentials() {
    return {
      'email': _superAdminEmail,
      'password': _superAdminPassword,
    };
  }
}