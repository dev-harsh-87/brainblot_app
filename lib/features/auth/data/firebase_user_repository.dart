import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Professional Firebase implementation for user profile and statistics management
/// Follows the new Firestore schema with proper user data isolation
class FirebaseUserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Collection names following the new schema
  static const String _usersCollection = 'users';

  FirebaseUserRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Create or update user profile
  Future<void> createOrUpdateUserProfile({
    required String userId,
    required String email,
    String? displayName,
    String? profileImageUrl,
    String? role,
  }) async {
    try {
      final userData = {
        'userId': userId,
        'email': email.toLowerCase(),
        'displayName': displayName ?? email.split('@').first,
        'profileImageUrl': profileImageUrl,
        'photoUrl': profileImageUrl, // Alias for compatibility
        'role': role ?? 'user', // Default role is 'user'
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

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .set(userData, SetOptions(merge: true));

    } catch (error) {
      throw Exception('Failed to create/update user profile: $error');
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return doc.data();
    } catch (error) {
      throw Exception('Failed to get user profile: $error');
    }
  }

  /// Watch user profile changes
  Stream<Map<String, dynamic>?> watchUserProfile(String userId) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) {
            return null;
          }
          return doc.data();
        })
        .handleError((Object error) {
          throw Exception('Failed to watch user profile: $error');
        });
  }

  /// Update user preferences
  Future<void> updatePreferences({
    String? theme,
    bool? notifications,
    bool? soundEnabled,
    String? language,
    String? timezone,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to update preferences');
    }

    try {
      final updates = <String, dynamic>{};
      
      if (theme != null) updates['preferences.theme'] = theme;
      if (notifications != null) updates['preferences.notifications'] = notifications;
      if (soundEnabled != null) updates['preferences.soundEnabled'] = soundEnabled;
      if (language != null) updates['preferences.language'] = language;
      if (timezone != null) updates['preferences.timezone'] = timezone;
      
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update(updates);

    } catch (error) {
      throw Exception('Failed to update user preferences: $error');
    }
  }

  /// Update user statistics
  Future<void> updateStatistics({
    int? totalSessions,
    int? totalDrillsCompleted,
    int? totalProgramsCompleted,
    double? averageAccuracy,
    double? averageReactionTime,
    int? streakDays,
    DateTime? lastSessionAt,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to update statistics');
    }

    try {
      final updates = <String, dynamic>{};
      
      if (totalSessions != null) updates['stats.totalSessions'] = totalSessions;
      if (totalDrillsCompleted != null) updates['stats.totalDrillsCompleted'] = totalDrillsCompleted;
      if (totalProgramsCompleted != null) updates['stats.totalProgramsCompleted'] = totalProgramsCompleted;
      if (averageAccuracy != null) updates['stats.averageAccuracy'] = averageAccuracy;
      if (averageReactionTime != null) updates['stats.averageReactionTime'] = averageReactionTime;
      if (streakDays != null) updates['stats.streakDays'] = streakDays;
      if (lastSessionAt != null) updates['stats.lastSessionAt'] = Timestamp.fromDate(lastSessionAt);
      
      updates['lastActiveAt'] = FieldValue.serverTimestamp();
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update(updates);

    } catch (error) {
      throw Exception('Failed to update user statistics: $error');
    }
  }

  /// Increment user statistics
  Future<void> incrementStatistics({
    int sessionsIncrement = 0,
    int drillsIncrement = 0,
    int programsIncrement = 0,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to increment statistics');
    }

    try {
      final updates = <String, dynamic>{
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (sessionsIncrement > 0) {
        updates['stats.totalSessions'] = FieldValue.increment(sessionsIncrement);
      }
      if (drillsIncrement > 0) {
        updates['stats.totalDrillsCompleted'] = FieldValue.increment(drillsIncrement);
      }
      if (programsIncrement > 0) {
        updates['stats.totalProgramsCompleted'] = FieldValue.increment(programsIncrement);
      }

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update(updates);

    } catch (error) {
      throw Exception('Failed to increment user statistics: $error');
    }
  }

  /// Update user subscription
  Future<void> updateSubscription({
    required String plan,
    required String status,
    DateTime? expiresAt,
    List<String>? features,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to update subscription');
    }

    try {
      final updates = <String, dynamic>{
        'subscription.plan': plan,
        'subscription.status': status,
        'subscription.expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'subscription.features': features ?? [],
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update(updates);

    } catch (error) {
      throw Exception('Failed to update user subscription: $error');
    }
  }

  /// Delete user profile and all associated data
  Future<void> deleteUserProfile(String userId) async {
    try {
      // This would typically be done via a Cloud Function for complete data deletion
      // For now, just delete the user profile document
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .delete();

    } catch (error) {
      throw Exception('Failed to delete user profile: $error');
    }
  }

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return {};
      }

      final statsData = doc.data()!['stats'];
      if (statsData is Map) {
        return Map<String, dynamic>.from(statsData);
      }
      return {};
    } catch (error) {
      return {};
    }
  }

  /// Calculate and update streak days
  Future<void> updateStreakDays() async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to update streak');
    }

    try {
      // This would typically involve checking session dates
      // For now, just increment if there was activity today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection(_usersCollection).doc(userId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) return;
        
        final userData = userDoc.data()!;
        final statsData = userData['stats'];
        final stats = statsData is Map ? Map<String, dynamic>.from(statsData) : <String, dynamic>{};
        final lastSessionAt = stats['lastSessionAt'] as Timestamp?;
        
        int streakDays = (stats['streakDays'] as int?) ?? 0;
        
        if (lastSessionAt != null) {
          final lastSessionDate = lastSessionAt.toDate();
          final lastSessionDay = DateTime(lastSessionDate.year, lastSessionDate.month, lastSessionDate.day);
          
          if (lastSessionDay.isAtSameMomentAs(today)) {
            // Already counted today, no change needed
            return;
          } else if (lastSessionDay.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
            // Consecutive day, increment streak
            streakDays++;
          } else {
            // Streak broken, reset to 1
            streakDays = 1;
          }
        } else {
          // First session ever
          streakDays = 1;
        }
        
        transaction.update(userRef, {
          'stats.streakDays': streakDays,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

    } catch (error) {
      // Don't throw here as this is not critical
    }
  }
}
