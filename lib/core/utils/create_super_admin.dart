import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';
import 'package:brainblot_app/core/auth/models/app_user.dart';

/// Utility to manually create Super Admin account
/// Use this if the automatic initialization didn't create the account
class CreateAdmin {
  static const String _adminEmail = 'admin@brianblot.com';
  static const String _adminPassword = 'Admin@123456';

  /// Create Admin account in Firebase
  static Future<void> create() async {
    try {
      print('🚀 Creating Admin account...');
      
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      // Check if Admin already exists
      final existingUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: _adminEmail)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        print('✅ Admin already exists!');
        print('📧 Email: $_adminEmail');
        print('🔑 Password: $_adminPassword');
        return;
      }

      // Create auth user
      UserCredential userCredential;
      try {
        userCredential = await auth.createUserWithEmailAndPassword(
          email: _adminEmail,
          password: _adminPassword,
        );
        print('✅ Firebase Auth user created');
      } catch (e) {
        // If user exists in auth but not in Firestore, sign in
        print('ℹ️ Auth user exists, signing in...');
        userCredential = await auth.signInWithEmailAndPassword(
          email: _adminEmail,
          password: _adminPassword,
        );
      }

      final userId = userCredential.user!.uid;

      // Create Admin user document
      final admin = AppUser(
        id: userId,
        email: _adminEmail,
        displayName: 'Administrator',
        role: UserRole.admin,
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
          .set(admin.toFirestore());

      print('✅ Admin created successfully!');
      print('=' * 50);
      print('📧 Email: $_adminEmail');
      print('🔑 Password: $_adminPassword');
      print('=' * 50);
      print('⚠️ Please change this password after first login!');
    } catch (e) {
      print('❌ Failed to create Admin: $e');
      rethrow;
    }
  }

  /// Get Admin credentials
  static Map<String, String> getCredentials() {
    return {
      'email': _adminEmail,
      'password': _adminPassword,
    };
  }
}