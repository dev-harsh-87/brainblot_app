import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/features/sharing/domain/user_profile.dart';
import 'package:brainblot_app/core/services/auto_refresh_service.dart';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

class SharingService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AutoRefreshService _autoRefreshService;
  final _uuid = const Uuid();

  SharingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AutoRefreshService? autoRefreshService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _autoRefreshService = autoRefreshService ?? AutoRefreshService();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Search for users by email or display name
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final queryLower = query.toLowerCase().trim();
      
      // FALLBACK: Get all public users and filter in memory
      // This works without indexes but is slower
      final snapshot = await _firestore
          .collection('users')
          .where('isPublic', isEqualTo: true)
          .limit(50) // Limit to prevent too much data
          .get();

      final users = <UserProfile>[];
      final seenIds = <String>{};

      for (final doc in snapshot.docs) {
        try {
          // Skip current user
          if (doc.id == currentUserId) continue;
          
          final data = doc.data();
          final email = (data['email'] as String?)?.toLowerCase() ?? '';
          final displayName = (data['displayName'] as String?)?.toLowerCase() ?? '';
          
          // Filter in memory - check if query matches email or name
          if (email.contains(queryLower) || displayName.contains(queryLower)) {
            if (!seenIds.contains(doc.id)) {
              seenIds.add(doc.id);
              users.add(UserProfile.fromJson({
                'id': doc.id,
                ...data,
              }));
            }
          }
        } catch (e) {
          print('Error parsing user: $e');
          continue;
        }
      }

      // Sort by best match (exact matches first)
      users.sort((a, b) {
        final aEmailMatch = a.email.toLowerCase() == queryLower;
        final bEmailMatch = b.email.toLowerCase() == queryLower;
        if (aEmailMatch && !bEmailMatch) return -1;
        if (!aEmailMatch && bEmailMatch) return 1;
        return a.email.compareTo(b.email);
      });

      return users.take(10).toList(); // Return top 10 results
    } catch (e) {
      print('Search error: $e');
      throw Exception('Failed to search users: $e');
    }
  }

  /// Share a drill with a user
  Future<void> shareDrill(String drillId, String drillName, String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // IMMEDIATELY add user to drill's sharedWith array
      await _firestore
          .collection('drills')
          .doc(drillId)
          .update({
        'sharedWith': FieldValue.arrayUnion([targetUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create share invitation for tracking
      final invitation = ShareInvitation(
        id: _uuid.v4(),
        fromUserId: currentUserId,
        toUserId: targetUserId,
        itemType: 'drill',
        itemId: drillId,
        itemName: drillName,
        status: ShareInvitationStatus.accepted, // Auto-accept
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('shareInvitations')
          .doc(invitation.id)
          .set(invitation.toJson());

      // Create notification for target user
      await _createNotification(
        targetUserId,
        'Drill Shared',
        'Someone shared a drill "$drillName" with you',
        {'type': 'drill_share', 'invitationId': invitation.id},
      );
      
      print('✅ Shared drill $drillId with user $targetUserId');
    } catch (e) {
      print('❌ Share drill error: $e');
      throw Exception('Failed to share drill: $e');
    }
  }

  /// Share a program with a user
  Future<void> shareProgram(String programId, String programName, String targetUserId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // IMMEDIATELY add user to program's sharedWith array
      await _firestore
          .collection('programs')
          .doc(programId)
          .update({
        'sharedWith': FieldValue.arrayUnion([targetUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create share invitation for tracking
      final invitation = ShareInvitation(
        id: _uuid.v4(),
        fromUserId: currentUserId,
        toUserId: targetUserId,
        itemType: 'program',
        itemId: programId,
        itemName: programName,
        status: ShareInvitationStatus.accepted, // Auto-accept
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('shareInvitations')
          .doc(invitation.id)
          .set(invitation.toJson());

      // Create notification for target user
      await _createNotification(
        targetUserId,
        'Program Shared',
        'Someone shared a program "$programName" with you',
        {'type': 'program_share', 'invitationId': invitation.id},
      );
      
      print('✅ Shared program $programId with user $targetUserId');
    } catch (e) {
      print('❌ Share program error: $e');
      throw Exception('Failed to share program: $e');
    }
  }

  /// Get pending invitations for current user
  Future<List<ShareInvitation>> getPendingInvitations() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final query = await _firestore
          .collection('shareInvitations')
          .where('toUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: ShareInvitationStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => ShareInvitation.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to get invitations: $e');
    }
  }

  /// Accept a share invitation
  Future<void> acceptInvitation(String invitationId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      await _firestore.runTransaction((transaction) async {
        // Get invitation
        final invitationRef = _firestore.collection('shareInvitations').doc(invitationId);
        final invitationDoc = await transaction.get(invitationRef);
        
        if (!invitationDoc.exists) {
          throw Exception('Invitation not found');
        }

        final invitation = ShareInvitation.fromJson({
          'id': invitationDoc.id,
          ...invitationDoc.data()!,
        });

        if (invitation.toUserId != currentUserId) {
          throw Exception('Unauthorized');
        }

        // Update invitation status
        transaction.update(invitationRef, {
          'status': ShareInvitationStatus.accepted.name,
          'respondedAt': FieldValue.serverTimestamp(),
        });

        // Add user to shared list
        if (invitation.itemType == 'drill') {
          final drillRef = _firestore.collection('drills').doc(invitation.itemId);
          transaction.update(drillRef, {
            'sharedWith': FieldValue.arrayUnion([currentUserId]),
          });
        } else if (invitation.itemType == 'program') {
          final programRef = _firestore.collection('programs').doc(invitation.itemId);
          transaction.update(programRef, {
            'sharedWith': FieldValue.arrayUnion([currentUserId]),
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to accept invitation: $e');
    }
  }

  /// Decline a share invitation
  Future<void> declineInvitation(String invitationId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('shareInvitations')
          .doc(invitationId)
          .update({
            'status': ShareInvitationStatus.declined.name,
            'respondedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Failed to decline invitation: $e');
    }
  }

  /// Remove user from shared drill/program with comprehensive cleanup
  Future<void> removeUserFromSharing(String itemType, String itemId, String userId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      print('🔄 Starting removal process for user $userId from $itemType $itemId');
      
      // Verify ownership or permission to remove users
      final isOwner = await this.isOwner(itemType, itemId);
      if (!isOwner) {
        throw Exception('Only the owner can remove users from sharing');
      }
      
      await _firestore.runTransaction((transaction) async {
        final collection = itemType == 'drill' ? 'drills' : 'programs';
        final itemRef = _firestore.collection(collection).doc(itemId);
        
        // Remove user from the shared list
        transaction.update(itemRef, {
          'sharedWith': FieldValue.arrayRemove([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update any related share invitations to mark them as revoked
        final invitationsQuery = await _firestore
            .collection('shareInvitations')
            .where('itemType', isEqualTo: itemType)
            .where('itemId', isEqualTo: itemId)
            .where('toUserId', isEqualTo: userId)
            .where('status', isEqualTo: ShareInvitationStatus.accepted.name)
            .get();
        
        for (final doc in invitationsQuery.docs) {
          transaction.update(doc.reference, {
            'status': 'revoked',
            'revokedAt': FieldValue.serverTimestamp(),
            'revokedBy': currentUserId,
          });
        }
      });
      
      // Create notification for the removed user
      await _createNotification(
        userId,
        'Access Removed',
        'Your access to "${await _getItemName(itemType, itemId)}" has been removed',
        {
          'type': 'access_revoked',
          'itemType': itemType,
          'itemId': itemId,
          'revokedBy': currentUserId,
        },
      );
      
      // Track the removal for analytics
      await _trackSharingEvent('user_removed', {
        'item_type': itemType,
        'item_id': itemId,
        'removed_user_id': userId,
        'removed_by': currentUserId,
      });
      
      print('✅ Successfully removed user $userId from $itemType $itemId');
    } catch (e) {
      print('❌ Failed to remove user from sharing: $e');
      throw Exception('Failed to remove user from sharing: $e');
    }
  }
  
  /// Helper method to get item name for notifications
  Future<String> _getItemName(String itemType, String itemId) async {
    try {
      final collection = itemType == 'drill' ? 'drills' : 'programs';
      final doc = await _firestore.collection(collection).doc(itemId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return data['name'] as String? ?? 'Unknown ${itemType}';
      }
      return 'Unknown ${itemType}';
    } catch (e) {
      return 'Unknown ${itemType}';
    }
  }

  /// Get users who have access to an item
  Future<List<UserProfile>> getSharedUsers(String itemType, String itemId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final collection = itemType == 'drill' ? 'drills' : 'programs';
      final itemDoc = await _firestore.collection(collection).doc(itemId).get();
      
      if (!itemDoc.exists) {
        throw Exception('Item not found');
      }

      final data = itemDoc.data();
      final sharedWithData = data?['sharedWith'];
      final sharedWith = sharedWithData != null && sharedWithData is List 
          ? List<String>.from(sharedWithData.cast<String>()) 
          : <String>[];
      
      if (sharedWith.isEmpty) return [];

      // Get user profiles
      final users = <UserProfile>[];
      for (final userId in sharedWith) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            users.add(UserProfile.fromJson({
              'id': userDoc.id,
              ...userDoc.data()!,
            }));
          }
        } catch (e) {
          // Skip users that can't be loaded
          continue;
        }
      }

      return users;
    } catch (e) {
      throw Exception('Failed to get shared users: $e');
    }
  }

  /// Create a notification for a user
  Future<void> _createNotification(
    String userId,
    String title,
    String message,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'data': data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Notification creation failure shouldn't block sharing
      print('Failed to create notification: $e');
    }
  }

  /// Share with email (for users not in the app)
  Future<void> shareViaEmail({
    required String email,
    required String itemType,
    required String itemId,
    required String itemName,
    String? personalMessage,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      // Get current user info
      UserProfile? currentUser;
      String senderName = 'A friend';
      
      try {
        currentUser = await getCurrentUserProfile();
        senderName = currentUser?.displayName ?? _auth.currentUser?.displayName ?? 'A friend';
      } catch (e) {
        // If we can't get user profile, use Firebase Auth info as fallback
        senderName = _auth.currentUser?.displayName ?? _auth.currentUser?.email ?? 'A friend';
      }
      
      // Create email invitation record
      final invitation = {
        'id': _uuid.v4(),
        'fromUserId': currentUserId,
        'fromUserName': senderName,
        'toEmail': email.toLowerCase(),
        'itemType': itemType,
        'itemId': itemId,
        'itemName': itemName,
        'personalMessage': personalMessage,
        'status': 'sent',
        'createdAt': FieldValue.serverTimestamp(),
        'downloadLink': _generateDownloadLink(itemType, itemId),
      };

      await _firestore.collection('emailInvitations').add(invitation);

      // Generate email content
      final emailContent = _generateEmailContent(
        senderName: senderName,
        itemType: itemType,
        itemName: itemName,
        personalMessage: personalMessage,
        downloadLink: invitation['downloadLink'] as String,
      );

      // Launch email client
      try {
        await _launchEmail(
          email: email,
          subject: '$senderName shared a ${itemType} with you on BrainBlot',
          body: emailContent,
        );
      } catch (emailError) {
        // If email launching fails, still record the invitation but throw a user-friendly error
        throw Exception('Could not open email app. Please check if you have an email app installed.');
      }

      // Track sharing analytics
      await _trackSharingEvent('email_share', {
        'item_type': itemType,
        'item_id': itemId,
        'target_email': email,
        'sender_id': currentUserId,
      });
    } catch (e) {
      throw Exception('Failed to share via email: $e');
    }
  }

  /// Generate download link with deep linking
  String _generateDownloadLink(String itemType, String itemId) {
    // This would be your actual app store links with deep linking parameters
    const appStoreUrl = 'https://apps.apple.com/app/brainblot/id123456789';
    const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.tbg.brainblotApp';
    
    // Add deep link parameters
    final deepLinkParams = 'shared_${itemType}_$itemId';
    
    return '''
🍎 iOS: $appStoreUrl?shared=$deepLinkParams
🤖 Android: $playStoreUrl&shared=$deepLinkParams

Or visit our website: https://brainblot.app/shared/$itemType/$itemId
''';
  }

  /// Generate email content with attractive formatting
  String _generateEmailContent({
    required String senderName,
    required String itemType,
    required String itemName,
    String? personalMessage,
    required String downloadLink,
  }) {
    final itemEmoji = itemType == 'drill' ? '🧠' : '🏃‍♂️';
    final actionText = itemType == 'drill' ? 'training drill' : 'training program';
    
    return '''
Hi there! 👋

$senderName has shared an amazing $actionText with you on BrainBlot!

$itemEmoji $itemName

${personalMessage != null ? '\n💬 Personal message:\n"$personalMessage"\n' : ''}

🚀 BrainBlot is the ultimate brain training app that helps improve your reaction time, focus, and cognitive performance through fun, interactive drills and structured training programs.

✨ What you'll get:
• Personalized training programs
• Real-time performance tracking  
• Progress analytics and insights
• Social features to train with friends
• Hundreds of cognitive training drills

📱 Download BrainBlot now to access this shared content:

$downloadLink

Start your brain training journey today! 🧠💪

---
The BrainBlot Team
Making minds sharper, one drill at a time.
''';
  }

  /// Launch email client with pre-filled content
  Future<void> _launchEmail({
    required String email,
    required String subject,
    required String body,
  }) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: Uri.encodeQueryComponent('subject=$subject&body=$body')
          .replaceAll('+', '%20'),
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      throw Exception('Could not launch email client');
    }
  }

  /// Track sharing events for analytics
  Future<void> _trackSharingEvent(String eventType, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('analytics').add({
        'event': eventType,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _currentUserId,
      });
    } catch (e) {
      // Analytics failure shouldn't block sharing
      print('Failed to track sharing event: $e');
    }
  }

  /// Get sharing statistics for user
  Future<Map<String, int>> getSharingStats() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return {};

    try {
      final stats = <String, int>{};
      
      // Count in-app shares
      final inAppShares = await _firestore
          .collection('shareInvitations')
          .where('fromUserId', isEqualTo: currentUserId)
          .get();
      
      // Count email shares
      final emailShares = await _firestore
          .collection('emailInvitations')
          .where('fromUserId', isEqualTo: currentUserId)
          .get();
      
      // Count downloads from shares (if tracking is implemented)
      final downloads = await _firestore
          .collection('analytics')
          .where('event', isEqualTo: 'app_download_from_share')
          .where('data.referrer_id', isEqualTo: currentUserId)
          .get();

      stats['total_shares'] = inAppShares.docs.length + emailShares.docs.length;
      stats['in_app_shares'] = inAppShares.docs.length;
      stats['email_shares'] = emailShares.docs.length;
      stats['downloads_generated'] = downloads.docs.length;
      
      return stats;
    } catch (e) {
      throw Exception('Failed to get sharing stats: $e');
    }
  }

  /// Toggle privacy status of drill or program
  Future<void> togglePrivacy(String itemType, String itemId, bool makePublic) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final collection = itemType == 'drill' ? 'drills' : 'programs';
      final docRef = _firestore.collection(collection).doc(itemId);
      
      // Verify ownership
      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('Item not found');
      }
      
      final data = doc.data()!;
      final createdBy = data['createdBy'] as String?;
      
      if (createdBy != currentUserId) {
        throw Exception('You can only change privacy of your own content');
      }
      
      // Update privacy status
      await docRef.update({
        'isPublic': makePublic,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Track privacy change
      await _trackSharingEvent('privacy_changed', {
        'item_type': itemType,
        'item_id': itemId,
        'made_public': makePublic,
        'user_id': currentUserId,
      });
      
    } catch (e) {
      throw Exception('Failed to update privacy: $e');
    }
  }

  /// Check if user owns the item
  Future<bool> isOwner(String itemType, String itemId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    try {
      final collection = itemType == 'drill' ? 'drills' : 'programs';
      final doc = await _firestore.collection(collection).doc(itemId).get();
      
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      return data['createdBy'] == currentUserId;
    } catch (e) {
      return false;
    }
  }

  /// Get privacy status of item
  Future<bool> isPublic(String itemType, String itemId) async {
    try {
      final collection = itemType == 'drill' ? 'drills' : 'programs';
      final doc = await _firestore.collection(collection).doc(itemId).get();
      
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      return data['isPublic'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get items created by current user (private + public)
  Future<List<Map<String, dynamic>>> getMyItems(String itemType) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];

    try {
      final collection = itemType == 'drill' ? 'drills' : 'programs';
      final querySnapshot = await _firestore
          .collection(collection)
          .where('createdBy', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      throw Exception('Failed to get your items: $e');
    }
  }

  /// Get public items from all users
  Future<List<Map<String, dynamic>>> getPublicItems(String itemType) async {
    try {
      final collection = itemType == 'drill' ? 'drills' : 'programs';
      final querySnapshot = await _firestore
          .collection(collection)
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(50) // Limit to prevent too much data
          .get();

      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      throw Exception('Failed to get public items: $e');
    }
  }

  /// Create or update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .set(profile.toJson(), SetOptions(merge: true));
      
      // Trigger auto-refresh for profile and sharing data
      _autoRefreshService.onProfileChanged();
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(currentUserId).get();
      if (doc.exists) {
        return UserProfile.fromJson({
          'id': doc.id,
          ...doc.data()!,
        });
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }
}
