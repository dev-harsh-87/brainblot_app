import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to ensure user profiles are created in Firestore
class UserProfileSetupService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserProfileSetupService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Ensure current user has a profile in Firestore
  Future<void> ensureUserProfileExists() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    try {
      print('🔍 Checking if user profile exists for: ${user.uid}');
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        print('📝 Creating user profile for: ${user.email}');
        await createUserProfile(user);
        print('✅ User profile created successfully');
      } else {
        print('✅ User profile already exists');
        // Update lastActiveAt
        await _firestore.collection('users').doc(user.uid).update({
          'lastActiveAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error ensuring user profile: $e');
      rethrow;
    }
  }

  /// Create a user profile in Firestore
  Future<void> createUserProfile(User user) async {
    try {
      final userData = {
        'userId': user.uid,
        'email': user.email?.toLowerCase() ?? '',
        'displayName': user.displayName ?? user.email?.split('@').first ?? 'User',
        'photoUrl': user.photoURL,
        'profileImageUrl': user.photoURL,
        'isPublic': true, // Searchable by default
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'preferences': {
          'theme': 'system',
          'notifications': true,
          'soundEnabled': true,
          'language': 'en',
          'timezone': 'UTC',
        },
        'subscription': {
          'plan': 'free',
          'status': 'active',
          'expiresAt': null,
          'features': ['basic_drills', 'basic_programs'],
        },
        'stats': {
          'totalSessions': 0,
          'totalDrillsCompleted': 0,
          'totalProgramsCompleted': 0,
          'averageAccuracy': 0.0,
          'averageReactionTime': 0.0,
          'streakDays': 0,
          'lastSessionAt': null,
        },
      };

      await _firestore.collection('users').doc(user.uid).set(userData);
      
      print('✅ Created profile for: ${user.email}');
      print('📧 Email: ${userData['email']}');
      print('👤 Display Name: ${userData['displayName']}');
      print('🔓 Is Public: ${userData['isPublic']}');
    } catch (e) {
      print('❌ Failed to create user profile: $e');
      rethrow;
    }
  }

  /// Create profiles for all existing auth users (migration)
  Future<void> migrateExistingUsers() async {
    try {
      print('🔄 Starting user migration...');
      
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in for migration');
        return;
      }

      // Only migrate current user
      await ensureUserProfileExists();
      
      print('✅ Migration complete');
    } catch (e) {
      print('❌ Migration failed: $e');
    }
  }

  /// List all users in Firestore (debug)
  Future<void> debugListUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      
      print('📊 Total users in Firestore: ${snapshot.docs.length}');
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        print('---');
        print('ID: ${doc.id}');
        print('Email: ${data['email']}');
        print('Display Name: ${data['displayName']}');
        print('Is Public: ${data['isPublic']}');
      }
    } catch (e) {
      print('❌ Failed to list users: $e');
    }
  }
}
