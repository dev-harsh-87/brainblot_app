import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/core/auth/models/app_user.dart';

/// Service for handling user registration including pre-created profiles
class UserRegistrationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Handles user registration for admin-created profiles
  Future<AppUser> registerExistingUser({
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Check if user profile exists in Firestore
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('No user profile found for this email. Please contact your administrator.');
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      
      // Check if this user was created by admin
      if (userData['requiresFirebaseAuthCreation'] != true) {
        throw Exception('This user profile is not eligible for registration.');
      }

      // Verify the temporary password
      if (userData['tempPassword'] != password) {
        throw Exception('Invalid credentials. Please contact your administrator.');
      }

      // Step 2: Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Failed to create Firebase Auth account');
      }

      // Step 3: Update Firebase Auth profile
      await firebaseUser.updateDisplayName(userData['displayName'] as String);

      // Step 4: Update Firestore document with Firebase Auth UID
      await _firestore.collection('users').doc(userDoc.id).update({
        'id': firebaseUser.uid, // Update with Firebase Auth UID
        'requiresFirebaseAuthCreation': false,
        'authAccountExists': true,
        'firebaseAuthUid': firebaseUser.uid,
        'tempPassword': FieldValue.delete(), // Remove temp password
        'registeredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Step 5: Create new document with Firebase Auth UID as document ID
      final updatedUserData = Map<String, dynamic>.from(userData);
      updatedUserData['id'] = firebaseUser.uid;
      updatedUserData['requiresFirebaseAuthCreation'] = false;
      updatedUserData['authAccountExists'] = true;
      updatedUserData['firebaseAuthUid'] = firebaseUser.uid;
      updatedUserData.remove('tempPassword');
      updatedUserData['registeredAt'] = FieldValue.serverTimestamp();
      updatedUserData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(firebaseUser.uid).set(updatedUserData);

      // Step 6: Delete the old document with generated ID
      await _firestore.collection('users').doc(userDoc.id).delete();

      // Step 7: Get the updated user document and return AppUser
      final newUserDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      return AppUser.fromFirestore(newUserDoc);

    } catch (e) {
      // Clean up if registration failed partway through
      await _cleanupFailedRegistration(email);
      rethrow;
    }
  }

  /// Standard user registration (for users not pre-created by admin)
  Future<AppUser> registerNewUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Failed to create Firebase Auth account');
      }

      await firebaseUser.updateDisplayName(displayName);

      // Create default user profile in Firestore
      final newUser = AppUser(
        id: firebaseUser.uid,
        email: email,
        displayName: displayName,
        subscription: const UserSubscription(
          plan: 'free',
          moduleAccess: ['drills', 'profile', 'stats', 'analysis'],
        ), // Default subscription
        preferences: const UserPreferences(),
        stats: const UserStats(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(firebaseUser.uid).set(newUser.toFirestore());

      return newUser;
    } catch (e) {
      await _cleanupFailedRegistration(email);
      rethrow;
    }
  }

  /// Check if user profile exists for email
  Future<bool> hasExistingProfile(String email) async {
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return userQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if user needs to complete registration
  Future<bool> needsRegistration(String email) async {
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .where('requiresFirebaseAuthCreation', isEqualTo: true)
          .limit(1)
          .get();

      return userQuery.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get user profile by email
  Future<Map<String, dynamic>?> getUserProfileByEmail(String email) async {
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return null;
      
      return userQuery.docs.first.data();
    } catch (e) {
      return null;
    }
  }

  /// Clean up failed registration attempts
  Future<void> _cleanupFailedRegistration(String email) async {
    try {
      // Try to delete any partially created Firebase Auth user
      if (_auth.currentUser?.email == email) {
        await _auth.currentUser?.delete();
      }
    } catch (e) {
      // Ignore cleanup errors
      print('Cleanup error: $e');
    }
  }
}