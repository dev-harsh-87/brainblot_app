import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:brainblot_app/features/sharing/domain/user_profile.dart';

class ProfileService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;
  User? get currentUser => _auth.currentUser;

  /// Get current user's profile data
  Future<UserProfile?> getCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final doc = await _firestore
          .collection('user_profiles')
          .doc(userId)
          .get();

      if (!doc.exists) {
        // Create profile if it doesn't exist
        return await _createUserProfileFromAuth();
      }

      final data = doc.data()!;
      return UserProfile.fromJson({
        'id': userId,
        ...data,
      });
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// Create user profile from Firebase Auth data
  Future<UserProfile?> _createUserProfileFromAuth() async {
    final user = currentUser;
    if (user == null) return null;

    final profile = UserProfile(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    await _firestore
        .collection('user_profiles')
        .doc(user.uid)
        .set(profile.toJson());

    return profile;
  }

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final updates = <String, dynamic>{
      'lastActiveAt': DateTime.now().toIso8601String(),
    };

    if (displayName != null) {
      updates['displayName'] = displayName;
      // Also update Firebase Auth display name
      await currentUser?.updateDisplayName(displayName);
    }


    await _firestore
        .collection('user_profiles')
        .doc(userId)
        .update(updates);
  }

  /// Generate user initials from display name
  String getUserInitials(String displayName) {
    if (displayName.isEmpty) return 'U';
    
    final words = displayName.trim().split(' ');
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    } else {
      return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'.toUpperCase();
    }
  }

  /// Delete user profile and all associated data
  Future<void> deleteProfile() async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final batch = _firestore.batch();

      // Delete user profile
      batch.delete(_firestore.collection('user_profiles').doc(userId));

      // Delete user's drills
      final userDrills = await _firestore
          .collection('drills')
          .where('createdBy', isEqualTo: userId)
          .get();
      
      for (final doc in userDrills.docs) {
        batch.delete(doc.reference);
      }

      // Delete user's programs
      final userPrograms = await _firestore
          .collection('programs')
          .where('createdBy', isEqualTo: userId)
          .get();
      
      for (final doc in userPrograms.docs) {
        batch.delete(doc.reference);
      }

      // Delete user's sessions
      final userSessions = await _firestore
          .collection('sessions')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final doc in userSessions.docs) {
        batch.delete(doc.reference);
      }

      // Delete active programs
      batch.delete(_firestore.collection('active_programs').doc(userId));

      // Delete user programs collection
      final userProgramsCollection = await _firestore
          .collection('user_programs')
          .doc(userId)
          .collection('programs')
          .get();
      
      for (final doc in userProgramsCollection.docs) {
        batch.delete(doc.reference);
      }

      // Delete user programs document
      batch.delete(_firestore.collection('user_programs').doc(userId));

      // Delete share invitations
      final shareInvitations = await _firestore
          .collection('share_invitations')
          .where('fromUserId', isEqualTo: userId)
          .get();
      
      for (final doc in shareInvitations.docs) {
        batch.delete(doc.reference);
      }

      final receivedInvitations = await _firestore
          .collection('share_invitations')
          .where('toUserId', isEqualTo: userId)
          .get();
      
      for (final doc in receivedInvitations.docs) {
        batch.delete(doc.reference);
      }

      // Remove user from shared items
      await _removeUserFromSharedItems(userId);

      // Commit all deletions
      await batch.commit();

      // Finally, delete the Firebase Auth user
      await currentUser?.delete();

    } catch (e) {
      throw Exception('Failed to delete profile: $e');
    }
  }

  /// Remove user from all shared items
  Future<void> _removeUserFromSharedItems(String userId) async {
    // Remove from drills
    final sharedDrills = await _firestore
        .collection('drills')
        .where('sharedWith', arrayContains: userId)
        .get();
    
    for (final doc in sharedDrills.docs) {
      await doc.reference.update({
        'sharedWith': FieldValue.arrayRemove([userId])
      });
    }

    // Remove from programs
    final sharedPrograms = await _firestore
        .collection('programs')
        .where('sharedWith', arrayContains: userId)
        .get();
    
    for (final doc in sharedPrograms.docs) {
      await doc.reference.update({
        'sharedWith': FieldValue.arrayRemove([userId])
      });
    }
  }

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    final userId = currentUserId;
    if (userId == null) return {};

    try {
      // Get sessions count
      final sessionsQuery = await _firestore
          .collection('sessions')
          .where('userId', isEqualTo: userId)
          .get();

      // Get drills count
      final drillsQuery = await _firestore
          .collection('drills')
          .where('createdBy', isEqualTo: userId)
          .get();

      // Get programs count
      final programsQuery = await _firestore
          .collection('programs')
          .where('createdBy', isEqualTo: userId)
          .get();

      // Get account creation date
      final profile = await getCurrentUserProfile();

      return {
        'totalSessions': sessionsQuery.docs.length,
        'totalDrills': drillsQuery.docs.length,
        'totalPrograms': programsQuery.docs.length,
        'memberSince': profile?.createdAt ?? DateTime.now(),
        'lastActive': profile?.lastActiveAt ?? DateTime.now(),
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {};
    }
  }

  /// Update email address
  Future<void> updateEmail(String newEmail, String currentPassword) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Re-authenticate user before email change
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update email in Firebase Auth
      await user.updateEmail(newEmail);

      // Update email in user profile
      await _firestore
          .collection('user_profiles')
          .doc(user.uid)
          .update({
            'email': newEmail,
            'lastActiveAt': DateTime.now().toIso8601String(),
          });

    } catch (e) {
      throw Exception('Failed to update email: $e');
    }
  }

  /// Update password
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Re-authenticate user before password change
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }
}
