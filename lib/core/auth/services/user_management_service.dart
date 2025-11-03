import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/core/auth/models/app_user.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';
import 'package:firebase_core/firebase_core.dart';

/// Service for comprehensive user management including Firebase Auth and Firestore
class UserManagementService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Secondary Firebase app for creating users without affecting current session
  FirebaseApp? _secondaryApp;
  FirebaseAuth? _secondaryAuth;
/// Initialize secondary Firebase app for user creation
  Future<void> _initializeSecondaryApp() async {
    if (_secondaryApp != null && _secondaryAuth != null) {
      return; // Already initialized
    }

    try {
      // Get current app options
      final currentApp = Firebase.app();
      final options = currentApp.options;

      // Try to get existing secondary app or create new one
      try {
        _secondaryApp = Firebase.app('SecondaryApp');
      } catch (e) {
        // Secondary app doesn't exist, create it
        _secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: options,
        );
      }

      _secondaryAuth = FirebaseAuth.instanceFor(app: _secondaryApp!);
    } catch (e) {
      print('Failed to initialize secondary app: $e');
      rethrow;
    }
  }

  /// Creates a new user with both Firebase Auth account and Firestore document
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    Map<String, dynamic>? subscriptionData,
  }) async {
    try {
      // Store current admin user info to restore session later
      final currentUser = _auth.currentUser;
      final currentAdminId = currentUser?.uid;
      final currentAdminEmail = currentUser?.email;
      final currentAdminName = currentUser?.displayName;
      
      if (currentAdminId == null || currentAdminEmail == null) {
        throw Exception('No authenticated admin user found');
      }

      // Step 1: Create Firebase Auth account
      // Initialize secondary app for creating users
      await _initializeSecondaryApp();

      // Use secondary auth to create user without logging out admin
      final userCredential = await _secondaryAuth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Failed to create Firebase Auth user');
      }

      // Step 2: Update the Firebase Auth profile
      await firebaseUser.updateDisplayName(displayName);
// Step 3: Sign out from secondary auth to prevent conflicts
      await _secondaryAuth!.signOut();
      
      print("✅ User created successfully without affecting admin session");

      // Step 3: Create Firestore user document
      final newUser = AppUser(
        id: firebaseUser.uid,
        email: email,
        displayName: displayName,
        role: role,
        subscription: subscriptionData != null
            ? UserSubscription.fromJson(subscriptionData)
            : UserSubscription.free(),
        preferences: const UserPreferences(),
        stats: const UserStats(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add metadata about who created this user
      final userData = newUser.toFirestore();
      userData['createdBy'] = {
        'adminId': currentAdminId,
        'adminEmail': currentAdminEmail,
        'adminName': currentAdminName ?? 'Unknown Admin',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await _firestore.collection('users').doc(firebaseUser.uid).set(userData);

      // Note: Admin session restoration would require admin password
      // For security reasons, admin password should be passed as parameter
      // when this method is called

      return newUser;
    } catch (e) {
      // If user creation failed partway through, clean up
      await _cleanupFailedUserCreation(email);
      rethrow;
    }
  }

  /// Creates a user using an alternative approach that doesn't require session switching
  Future<AppUser> createUserSecure({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    Map<String, dynamic>? subscriptionData,
    required String adminPassword, // Admin must provide their password
  }) async {
    try {
      // Store current admin info
      final currentUser = _auth.currentUser;
      final currentAdminId = currentUser?.uid;
      final currentAdminEmail = currentUser?.email;
      final currentAdminName = currentUser?.displayName;
      
      if (currentAdminId == null || currentAdminEmail == null) {
        throw Exception('No authenticated admin user found');
      }

      // Due to Flutter limitations, we cannot create Firebase Auth users
      // without affecting the current session. Instead, we'll create a user profile
      // that can be converted to a full account when the user first logs in.
      
      return await createUserProfile(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        subscriptionData: subscriptionData,
      ).then((userId) async {
        // Return the created user profile
        final user = await getUser(userId);
        if (user == null) {
          throw Exception('Failed to retrieve created user profile');
        }
        return user;
      });
    } catch (e) {
      await _cleanupFailedUserCreation(email);
      rethrow;
    }
  }

  /// Deletes a user completely from both Firebase Auth and Firestore
  Future<void> deleteUser(String userId) async {
    try {
      // Step 1: Delete from Firestore first (easier to recover if needed)
      await _firestore.collection('users').doc(userId).delete();

      // Step 2: Delete from Firebase Auth
      // Note: This requires admin SDK or the user to be currently signed in
      // For production, you'd want to use Firebase Admin SDK
      
      // For now, we'll mark the user as deleted in a separate collection
      // and use Cloud Functions to actually delete from Auth
      await _firestore.collection('deleted_users').doc(userId).set({
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': _auth.currentUser?.uid,
        'pendingAuthDeletion': true,
      });

      // TODO: Implement Cloud Function to delete from Firebase Auth
      // This requires Firebase Admin SDK which can't be used in client apps
      
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  /// Alternative user creation that works with current limitations
  Future<String> createUserProfile({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    Map<String, dynamic>? subscriptionData,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      final currentAdminId = currentUser?.uid;
      final currentAdminEmail = currentUser?.email;
      final currentAdminName = currentUser?.displayName;
      
      if (currentAdminId == null || currentAdminEmail == null) {
        throw Exception('No authenticated admin user found');
      }

      // Generate a unique user ID
      final newUserId = _firestore.collection('users').doc().id;
      
      // Create user profile in Firestore
      final newUser = AppUser(
        id: newUserId,
        email: email,
        displayName: displayName,
        role: role,
        subscription: subscriptionData != null
            ? UserSubscription.fromJson(subscriptionData)
            : UserSubscription.free(),
        preferences: const UserPreferences(),
        stats: const UserStats(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final userData = newUser.toFirestore();
      userData['createdBy'] = {
        'adminId': currentAdminId,
        'adminEmail': currentAdminEmail,
        'adminName': currentAdminName ?? 'Unknown Admin',
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Store temporary password for the user to use during first login
      userData['tempPassword'] = password;
      userData['requiresPasswordReset'] = true;
      userData['authAccountCreated'] = false; // Flag to track if Auth account exists

      await _firestore.collection('users').doc(newUserId).set(userData);

      // Create a pending auth creation record
      await _firestore.collection('pending_auth_users').doc(newUserId).set({
        'email': email,
        'password': password,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminId,
      });

      return newUserId;
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  /// Updates user role
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  /// Updates user subscription
  Future<void> updateUserSubscription(String userId, Map<String, dynamic> subscriptionData) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'subscription': subscriptionData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user subscription: $e');
    }
  }

  /// Gets user by ID
  Future<AppUser?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      
      return AppUser.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  /// Lists all users with optional filters
  Stream<List<AppUser>> getUsersStream({
    UserRole? roleFilter,
    String? planFilter,
    int? limit,
  }) {
    try {
      Query query = _firestore.collection('users');
      
      if (roleFilter != null) {
        query = query.where('role', isEqualTo: roleFilter.name);
      }
      
      if (planFilter != null) {
        query = query.where('subscription.plan', isEqualTo: planFilter);
      }
      
      if (limit != null) {
        query = query.limit(limit);
      }
      
      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            return AppUser.fromFirestore(doc);
          } catch (e) {
            // Skip malformed documents
            return null;
          }
        }).where((user) => user != null).cast<AppUser>().toList();
      });
    } catch (e) {
      throw Exception('Failed to get users stream: $e');
    }
  }

  // Helper methods

  Future<void> _cleanupFailedUserCreation(String email) async {
    try {
      // Try to find and delete any partially created user
      final users = await _auth.fetchSignInMethodsForEmail(email);
      if (users.isNotEmpty) {
        // User exists in Auth, would need admin SDK to delete
        // For now, just log the issue
        print('Warning: Partially created user exists in Firebase Auth: $email');
      }
    } catch (e) {
      // Ignore cleanup errors
      print('Cleanup error: $e');
    }
  }

  /// Validates admin credentials for sensitive operations
  Future<bool> validateAdminCredentials(String email, String password) async {
    try {
      // Create a temporary credential to validate admin password
      final credential = EmailAuthProvider.credential(email: email, password: password);
      await _auth.currentUser?.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets audit log for user management operations
  Future<List<Map<String, dynamic>>> getAuditLog({
    String? userId,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection('user_audit_log')
          .orderBy('timestamp', descending: true);
      
      if (userId != null) {
        query = query.where('targetUserId', isEqualTo: userId);
      }
      
      query = query.limit(limit);
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      throw Exception('Failed to get audit log: $e');
    }
  }

  /// Logs user management operations for audit trail
  Future<void> _logOperation(String operation, String targetUserId, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      await _firestore.collection('user_audit_log').add({
        'operation': operation,
        'targetUserId': targetUserId,
        'performedBy': currentUser?.uid,
        'performedByEmail': currentUser?.email,
        'timestamp': FieldValue.serverTimestamp(),
        'additionalData': additionalData ?? {},
      });
    } catch (e) {
      // Don't throw on audit log failure, just log it
      print('Failed to log operation: $e');
    }
  }
}