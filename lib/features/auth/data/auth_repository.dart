import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class AuthRepository {
  Future<UserCredential> signInWithEmailPassword({required String email, required String password});
  Future<UserCredential> registerWithEmailPassword({required String email, required String password});
  Future<void> signOut();
  Stream<User?> authState();
  Future<void> sendPasswordResetEmail({required String email});
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  FirebaseAuthRepository(this._auth);

  @override
  Future<UserCredential> signInWithEmailPassword({required String email, required String password}) async {
    try {
      // First try normal login
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // Check if this is an admin-created user that needs Firebase Auth account
        final adminCreatedUser = await _checkForAdminCreatedUser(email, password);
        if (adminCreatedUser != null) {
          // Create Firebase Auth account for admin-created user
          return await _createAuthAccountForAdminUser(email, password, adminCreatedUser);
        }
      } else if (e.code == 'wrong-password') {
        // For admin account, also check if it's an admin-created user with temp password
        final adminCreatedUser = await _checkForAdminCreatedUser(email, password);
        if (adminCreatedUser != null) {
          // Create Firebase Auth account for admin-created user
          return await _createAuthAccountForAdminUser(email, password, adminCreatedUser);
        }
      }
      rethrow;
    }
  }

  @override
  Future<UserCredential> registerWithEmailPassword({required String email, required String password}) async {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  /// Check if user was created by admin and needs Firebase Auth account
  Future<Map<String, dynamic>?> _checkForAdminCreatedUser(String email, String password) async {
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .where('requiresFirebaseAuthCreation', isEqualTo: true)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userData = userQuery.docs.first.data();
        final storedTempPassword = userData['tempPassword'] as String?;
        
        // Verify the password matches the temporary password set by admin
        if (storedTempPassword != null && storedTempPassword == password) {
          print('✅ Admin-created user found with matching password: $email');
          return {
            'docId': userQuery.docs.first.id,
            'userData': userData,
          };
        } else {
          print('❌ Admin-created user found but password mismatch: $email');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('Error checking for admin-created user: $e');
      return null;
    }
  }

  /// Create Firebase Auth account for admin-created user
  Future<UserCredential> _createAuthAccountForAdminUser(
    String email,
    String password,
    Map<String, dynamic> adminUserData
  ) async {
    try {
      print('🔄 Creating Firebase Auth account for admin-created user: $email');
      
      // Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Failed to create Firebase Auth account');
      }

      // Update user profile
      await firebaseUser.updateDisplayName(adminUserData['userData']['displayName'] as String);

      final docId = adminUserData['docId'] as String;
      final userData = adminUserData['userData'] as Map<String, dynamic>;

      // Update Firestore document
      await _firestore.collection('users').doc(docId).update({
        'id': firebaseUser.uid,
        'requiresFirebaseAuthCreation': false,
        'authAccountExists': true,
        'firebaseAuthUid': firebaseUser.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create new document with Firebase Auth UID as document ID
      final updatedUserData = Map<String, dynamic>.from(userData);
      updatedUserData['id'] = firebaseUser.uid;
      updatedUserData['requiresFirebaseAuthCreation'] = false;
      updatedUserData['authAccountExists'] = true;
      updatedUserData['firebaseAuthUid'] = firebaseUser.uid;
      updatedUserData['updatedAt'] = FieldValue.serverTimestamp();
      
      // Remove temporary password for security
      updatedUserData.remove('tempPassword');

      await _firestore.collection('users').doc(firebaseUser.uid).set(updatedUserData);

      // Delete the old document with generated ID
      await _firestore.collection('users').doc(docId).delete();

      print('✅ Firebase Auth account created successfully for admin-created user');
      return userCredential;

    } catch (e) {
      print('❌ Failed to create Firebase Auth account for admin-created user: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Stream<User?> authState() => _auth.authStateChanges();

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    return _auth.sendPasswordResetEmail(email: email);
  }
}
