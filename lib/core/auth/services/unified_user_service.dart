import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Unified service for all user creation and management operations
/// This is the single source of truth for user creation logic
class UnifiedUserService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  FirebaseApp? _secondaryApp;
  FirebaseAuth? _secondaryAuth;

  UnifiedUserService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get default module access based on user role
  static List<String> getDefaultModuleAccess(UserRole role) {
    switch (role) {
      case UserRole.admin:
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
      case UserRole.user:
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

  /// Create a new user with Firebase Auth and Firestore profile
  /// This is the main method for user creation
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String displayName,
    UserRole role = UserRole.user,
    Map<String, dynamic>? customSubscriptionData,
    bool useSecondaryAuth = false,
  }) async {
    try {
      AppLogger.info('Creating user: $email with role: ${role.value}', tag: 'UnifiedUserService');

      UserCredential userCredential;

      if (useSecondaryAuth) {
        // Initialize secondary auth for admin user creation
        await _initializeSecondaryApp();
        userCredential = await _secondaryAuth!.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await _secondaryAuth!.signOut();
      } else {
        // Standard user creation
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Failed to create Firebase Auth user');
      }

      // Update Firebase Auth profile
      await firebaseUser.updateDisplayName(displayName);

      // Create AppUser with proper default configuration
      final appUser = _createAppUserObject(
        firebaseUser: firebaseUser,
        email: email,
        displayName: displayName,
        role: role,
        customSubscriptionData: customSubscriptionData,
      );

      // Save to Firestore
      await _firestore.collection('users').doc(firebaseUser.uid).set(appUser.toFirestore());

      AppLogger.success('User created successfully: $email', tag: 'UnifiedUserService');
      return appUser;

    } catch (e) {
      AppLogger.error('Failed to create user: $email', error: e, tag: 'UnifiedUserService');
      await _cleanupFailedUserCreation(email);
      rethrow;
    }
  }

  /// Create user profile for existing Firebase Auth user (login scenario)
  Future<AppUser> createUserProfile(User firebaseUser) async {
    try {
      AppLogger.info('Creating profile for existing user: ${firebaseUser.email}', tag: 'UnifiedUserService');

      final role = _determineUserRole(firebaseUser.email);
      final appUser = _createAppUserObject(
        firebaseUser: firebaseUser,
        email: firebaseUser.email?.toLowerCase() ?? '',
        displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
        role: role,
      );

      await _firestore.collection('users').doc(firebaseUser.uid).set(appUser.toFirestore());

      AppLogger.success('User profile created: ${firebaseUser.email}', tag: 'UnifiedUserService');
      return appUser;

    } catch (e) {
      AppLogger.error('Failed to create user profile', error: e, tag: 'UnifiedUserService');
      rethrow;
    }
  }

  /// Register user for admin-created profiles
  Future<AppUser> registerExistingUser({
    required String email,
    required String password,
  }) async {
    try {
      // Check if user profile exists in Firestore
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

      // Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Failed to create Firebase Auth account');
      }

      // Update Firebase Auth profile
      await firebaseUser.updateDisplayName(userData['displayName'] as String);

      // Update Firestore document with Firebase Auth UID
      await _firestore.collection('users').doc(userDoc.id).update({
        'id': firebaseUser.uid,
        'requiresFirebaseAuthCreation': false,
        'authAccountExists': true,
        'firebaseAuthUid': firebaseUser.uid,
        'tempPassword': FieldValue.delete(),
        'registeredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create new document with Firebase Auth UID as document ID
      final updatedUserData = Map<String, dynamic>.from(userData);
      updatedUserData['id'] = firebaseUser.uid;
      updatedUserData['requiresFirebaseAuthCreation'] = false;
      updatedUserData['authAccountExists'] = true;
      updatedUserData['firebaseAuthUid'] = firebaseUser.uid;
      updatedUserData.remove('tempPassword');
      updatedUserData['registeredAt'] = FieldValue.serverTimestamp();
      updatedUserData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(firebaseUser.uid).set(updatedUserData);

      // Delete the old document with generated ID
      await _firestore.collection('users').doc(userDoc.id).delete();

      // Get the updated user document and return AppUser
      final newUserDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      return AppUser.fromFirestore(newUserDoc);

    } catch (e) {
      await _cleanupFailedUserCreation(email);
      rethrow;
    }
  }

  /// Create AppUser object with consistent configuration
  AppUser _createAppUserObject({
    required User firebaseUser,
    required String email,
    required String displayName,
    required UserRole role,
    Map<String, dynamic>? customSubscriptionData,
  }) {
    final moduleAccess = getDefaultModuleAccess(role);
    
    return AppUser(
      id: firebaseUser.uid,
      email: email.toLowerCase(),
      displayName: displayName,
      profileImageUrl: firebaseUser.photoURL,
      role: role,
      subscription: customSubscriptionData != null
          ? UserSubscription.fromJson(customSubscriptionData)
          : UserSubscription(
              plan: role.isAdmin() ? 'institute' : 'free',
              status: 'active',
              moduleAccess: moduleAccess,
            ),
      preferences: const UserPreferences(
        theme: 'system',
        notifications: true,
        soundEnabled: true,
        language: 'en',
        timezone: 'UTC',
      ),
      stats: const UserStats(
        totalSessions: 0,
        totalDrillsCompleted: 0,
        totalProgramsCompleted: 0,
        averageAccuracy: 0.0,
        averageReactionTime: 0.0,
        streakDays: 0,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
  }

  /// Determine user role based on email
  UserRole _determineUserRole(String? email) {
    if (email == null) return UserRole.user;
    
    // Admin emails
    const adminEmails = [
      'admin@gmail.com',
      'admin@sparkapp.com',
      'harsh@sparkapp.com',
    ];
    
    return adminEmails.contains(email.toLowerCase()) ? UserRole.admin : UserRole.user;
  }

  /// Initialize secondary Firebase app for admin user creation
  Future<void> _initializeSecondaryApp() async {
    if (_secondaryApp != null && _secondaryAuth != null) return;

    try {
      _secondaryApp = await Firebase.initializeApp(
        name: 'secondary',
        options: Firebase.app().options,
      );
      _secondaryAuth = FirebaseAuth.instanceFor(app: _secondaryApp!);
      AppLogger.info('Secondary Firebase app initialized', tag: 'UnifiedUserService');
    } catch (e) {
      AppLogger.error('Failed to initialize secondary app', error: e, tag: 'UnifiedUserService');
      rethrow;
    }
  }

  /// Clean up failed user creation attempts
  Future<void> _cleanupFailedUserCreation(String email) async {
    try {
      // Try to delete any partially created Firebase Auth user
      if (_auth.currentUser?.email == email) {
        await _auth.currentUser?.delete();
      }
    } catch (e) {
      AppLogger.debug('Cleanup error (ignored): $e', tag: 'UnifiedUserService');
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

  /// Dispose resources
  void dispose() {
    _secondaryApp?.delete();
  }
}