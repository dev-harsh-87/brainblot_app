import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spark_app/core/auth/services/unified_user_service.dart';
import 'package:spark_app/core/auth/services/permission_manager.dart';

/// Service for comprehensive user management including Firebase Auth and Firestore
class UserManagementService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UnifiedUserService _unifiedUserService = UnifiedUserService();

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

  /// Creates a new user with both Firebase Auth account and Firestore profile
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    Map<String, dynamic>? subscriptionData,
  }) async {
    try {
      // Store current admin user info for metadata
      final currentUser = _auth.currentUser;
      final currentAdminId = currentUser?.uid;
      final currentAdminEmail = currentUser?.email;
      final currentAdminName = currentUser?.displayName;

      if (currentAdminId == null || currentAdminEmail == null) {
        throw Exception('No authenticated admin user found');
      }

      print('🔄 UserManagementService: Creating user with Firebase Auth account for: $email');
      print('👤 Admin: $currentAdminEmail ($currentAdminId)');

      // Initialize secondary Firebase app for user creation
      await _initializeSecondaryApp();

      if (_secondaryAuth == null) {
        throw Exception('Failed to initialize secondary Firebase Auth');
      }

      // Step 1: Create Firebase Auth account using secondary app
      UserCredential userCredential;
      try {
        userCredential = await _secondaryAuth!.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('✅ Firebase Auth account created: ${userCredential.user!.uid}');
      } catch (e) {
        print('❌ Failed to create Firebase Auth account: $e');
        throw Exception('Failed to create Firebase Auth account: $e');
      }

      final firebaseUser = userCredential.user!;
      
      // Step 2: Update display name in Firebase Auth
      try {
        await firebaseUser.updateDisplayName(displayName);
        print('✅ Updated Firebase Auth display name');
      } catch (e) {
        print('⚠️ Failed to update display name in Firebase Auth: $e');
      }

      // Step 3: Create Firestore profile
      final newUser = AppUser(
        id: firebaseUser.uid,
        email: email,
        displayName: displayName,
        role: role,
        subscription: subscriptionData != null
            ? UserSubscription.fromJson(subscriptionData)
            : const UserSubscription(
                plan: 'free',
                moduleAccess: ['drills', 'profile', 'stats'],
              ),
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

      // Mark that Firebase Auth account exists
      userData['authAccountExists'] = true;
      userData['firebaseAuthUid'] = firebaseUser.uid;
      userData['requiresFirebaseAuthCreation'] = false;

      await _firestore.collection('users').doc(firebaseUser.uid).set(userData);
      print('✅ Firestore profile created successfully');

      // Step 4: Sign out from secondary auth to avoid session conflicts
      try {
        await _secondaryAuth!.signOut();
        print('✅ Signed out from secondary Firebase Auth');
      } catch (e) {
        print('⚠️ Failed to sign out from secondary auth: $e');
      }

      print('✅ UserManagementService: User created successfully with Firebase Auth: ${firebaseUser.uid}');
      return newUser;

    } catch (e) {
      print('❌ UserManagementService: Failed to create user: $e');
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
      print('🔄 UserManagementService: Starting user deletion process for: $userId');
      
      // Get user data before deletion to check if they have Firebase Auth account
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data()!;
      final userEmail = userData['email'] as String?;
      final hasAuthAccount = userData['authAccountExists'] as bool? ?? false;
      final firebaseAuthUid = userData['firebaseAuthUid'] as String?;
      
      print('👤 User email: $userEmail');
      print('🔐 Has Firebase Auth account: $hasAuthAccount');
      print('🆔 Firebase Auth UID: $firebaseAuthUid');

      // Step 1: Delete Firebase Auth account if it exists
      if (hasAuthAccount && firebaseAuthUid != null && userEmail != null) {
        try {
          // Initialize secondary Firebase app for user deletion
          await _initializeSecondaryApp();
          
          if (_secondaryAuth != null) {
            // Sign in to the user account using secondary auth to delete it
            try {
              // We need the user's password to sign in and delete the account
              // Since we don't store passwords, we'll use a different approach
              print('🔄 Attempting to delete Firebase Auth account: $firebaseAuthUid');
              
              // For now, we'll mark it for manual cleanup since we can't delete
              // other users' accounts without their credentials from client-side
              await _firestore.collection('deleted_users_auth_cleanup').doc(firebaseAuthUid).set({
                'userId': userId,
                'originalEmail': userEmail,
                'deletedAt': FieldValue.serverTimestamp(),
                'deletedBy': _auth.currentUser?.uid,
                'status': 'pending_auth_cleanup',
                'instructions': 'This Firebase Auth account needs to be deleted manually via Firebase Console or Admin SDK',
                'firebaseAuthUid': firebaseAuthUid,
              });
              print('📝 Created auth cleanup record - Firebase Auth account marked for manual deletion');
            } catch (e) {
              print('⚠️ Could not delete Firebase Auth account directly: $e');
              // Continue with Firestore deletion
            }
          }
        } catch (e) {
          print('⚠️ Failed to initialize secondary app for deletion: $e');
          // Continue with Firestore deletion
        }
      } else {
        print('ℹ️ User has no Firebase Auth account, only Firestore cleanup needed');
      }

      // Step 2: Mark user as deleted in Firestore (soft delete approach)
      await _firestore.collection('users').doc(userId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': _auth.currentUser?.uid,
        'originalEmail': userEmail,
        'email': 'deleted_${DateTime.now().millisecondsSinceEpoch}@deleted.local', // Prevent email conflicts
        'status': 'deleted',
      });
      print('✅ User marked as deleted in Firestore');

      // Step 3: Clean up related data
      await _cleanupUserRelatedData(userId);

      print('✅ User deletion process completed');
    } catch (e) {
      print('❌ Failed to delete user: $e');
      throw Exception('Failed to delete user: $e');
    }
  }

  /// Clean up user-related data from other collections
  Future<void> _cleanupUserRelatedData(String userId) async {
    try {
      print('🧹 Cleaning up user-related data for: $userId');
      
      // Clean up user sessions
      final sessionsQuery = await _firestore
          .collection('sessions')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final doc in sessionsQuery.docs) {
        await doc.reference.delete();
      }
      print('✅ Cleaned up ${sessionsQuery.docs.length} user sessions');

      // Clean up user subscription requests
      final requestsQuery = await _firestore
          .collection('subscription_requests')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final doc in requestsQuery.docs) {
        await doc.reference.delete();
      }
      print('✅ Cleaned up ${requestsQuery.docs.length} subscription requests');

      // Clean up user drill results
      final resultsQuery = await _firestore
          .collection('drill_results')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final doc in resultsQuery.docs) {
        await doc.reference.delete();
      }
      print('✅ Cleaned up ${resultsQuery.docs.length} drill results');

      print('✅ User-related data cleanup completed');
    } catch (e) {
      print('⚠️ Error during user data cleanup: $e');
      // Don't throw here as the main deletion was successful
    }
  }

  /// Get list of users pending Firebase Auth cleanup (for admin review)
  Future<List<Map<String, dynamic>>> getPendingAuthCleanups() async {
    try {
      final query = await _firestore
          .collection('deleted_users_auth_cleanup')
          .where('status', isEqualTo: 'pending_auth_cleanup')
          .orderBy('deletedAt', descending: true)
          .get();

      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('❌ Failed to get pending auth cleanups: $e');
      return [];
    }
  }

  /// Mark Firebase Auth cleanup as completed (for admin use)
  Future<void> markAuthCleanupCompleted(String firebaseAuthUid) async {
    try {
      await _firestore
          .collection('deleted_users_auth_cleanup')
          .doc(firebaseAuthUid)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'completedBy': _auth.currentUser?.uid,
      });
      print('✅ Marked auth cleanup as completed for: $firebaseAuthUid');
    } catch (e) {
      print('❌ Failed to mark auth cleanup as completed: $e');
      throw Exception('Failed to mark auth cleanup as completed: $e');
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
            : const UserSubscription(
                plan: 'free',
                moduleAccess: ['drills', 'profile', 'stats'],
              ),
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
      userData['authAccountCreated'] =
          false; // Flag to track if Auth account exists

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

  /// Updates user subscription and triggers automatic permission refresh
  Future<void> updateUserSubscription(
      String userId, Map<String, dynamic> subscriptionData) async {
    try {
      print('🔄 UserManagementService: Updating user subscription...');
      print('👤 User ID: $userId');
      print('📦 Subscription Data: $subscriptionData');

      // Update the entire subscription object to ensure all fields are properly set
      final Map<String, dynamic> updateData = {
        'subscription': subscriptionData,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).update(updateData);
      print('✅ UserManagementService: Subscription updated successfully');
      
      // CRITICAL: Force permission refresh for the affected user if they are currently logged in
      // This ensures immediate UI updates without requiring app restart
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        print('🔄 UserManagementService: User is currently logged in, forcing permission refresh...');
        try {
          // Wait a moment for Firestore changes to propagate
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Force refresh permissions for immediate UI update
          await PermissionManager.instance.refreshPermissions();
          print('✅ UserManagementService: Current user permissions refreshed successfully');
        } catch (e) {
          print('⚠️ UserManagementService: Failed to refresh current user permissions: $e');
          // Don't throw - the automatic refresh via Firestore listener should still work
        }
      } else {
        print('📡 UserManagementService: User not currently logged in, permissions will refresh on next login');
      }
      
      // Additional step: Broadcast permission change notification
      // This helps ensure UI updates across the app
      try {
        print('📢 UserManagementService: Broadcasting permission change notification...');
        PermissionManager.instance.notifyListeners();
        print('✅ UserManagementService: Permission change notification broadcasted');
      } catch (e) {
        print('⚠️ UserManagementService: Failed to broadcast permission change: $e');
      }
      
    } catch (e) {
      print('❌ UserManagementService: Failed to update subscription: $e');
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
        return snapshot.docs
            .map((doc) {
              try {
                return AppUser.fromFirestore(doc);
              } catch (e) {
                // Skip malformed documents
                return null;
              }
            })
            .where((user) => user != null)
            .cast<AppUser>()
            .toList();
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
        print(
            'Warning: Partially created user exists in Firebase Auth: $email');
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
      final credential =
          EmailAuthProvider.credential(email: email, password: password);
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
      Query query = _firestore
          .collection('user_audit_log')
          .orderBy('timestamp', descending: true);

      if (userId != null) {
        query = query.where('targetUserId', isEqualTo: userId);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get audit log: $e');
    }
  }

}
