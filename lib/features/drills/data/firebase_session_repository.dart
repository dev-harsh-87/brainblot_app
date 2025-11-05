import 'dart:async';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/drills/domain/session_result.dart';
import 'package:spark_app/features/drills/data/session_repository.dart';
import 'package:uuid/uuid.dart';

/// Professional Firebase implementation of SessionRepository
/// Follows the new Firestore schema with proper user data isolation and performance optimization
class FirebaseSessionRepository implements SessionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _uuid = const Uuid();

  // Collection names following the new schema
  static const String _userSessionsCollection = 'user_sessions';
  static const String _sessionsSubcollection = 'sessions';

  FirebaseSessionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  @override
  Stream<List<SessionResult>> watchAll() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_userSessionsCollection)
        .doc(userId)
        .collection(_sessionsSubcollection)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => _mapSnapshotToSessions(snapshot))
        .handleError((error) {
          print('❌ Error watching all sessions: $error');
          throw Exception('Failed to load sessions: $error');
        });
  }

  @override
  Stream<List<SessionResult>> watchByDrill(String drillId) {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_userSessionsCollection)
        .doc(userId)
        .collection(_sessionsSubcollection)
        .where('drillId', isEqualTo: drillId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => _mapSnapshotToSessions(snapshot))
        .handleError((error) {
          print('❌ Error watching sessions by drill: $error');
          throw Exception('Failed to load sessions for drill $drillId: $error');
        });
  }

  @override
  Stream<List<SessionResult>> watchByProgram(String programId) {
    // For now, return empty since SessionResult doesn't have programId
    // This would need to be implemented when program support is added
    return Stream.value(<SessionResult>[]);
  }

  @override
  Stream<List<SessionResult>> watchRecent({int limit = 10}) {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_userSessionsCollection)
        .doc(userId)
        .collection(_sessionsSubcollection)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => _mapSnapshotToSessions(snapshot))
        .handleError((error) {
          print('❌ Error watching recent sessions: $error');
          throw Exception('Failed to load recent sessions: $error');
        });
  }

  @override
  Future<List<SessionResult>> fetchAll() async {
    final userId = _currentUserId;
    if (userId == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection(_userSessionsCollection)
          .doc(userId)
          .collection(_sessionsSubcollection)
          .orderBy('startedAt', descending: true)
          .get();

      return _mapSnapshotToSessions(snapshot);
    } catch (error) {
      print('❌ Error fetching all sessions: $error');
      throw Exception('Failed to fetch sessions: $error');
    }
  }

  @override
  Future<List<SessionResult>> fetchByDrill(String drillId) async {
    final userId = _currentUserId;
    if (userId == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection(_userSessionsCollection)
          .doc(userId)
          .collection(_sessionsSubcollection)
          .where('drillId', isEqualTo: drillId)
          .orderBy('startedAt', descending: true)
          .get();

      return _mapSnapshotToSessions(snapshot);
    } catch (error) {
      print('❌ Error fetching sessions by drill: $error');
      throw Exception('Failed to fetch sessions for drill $drillId: $error');
    }
  }

  @override
  Future<List<SessionResult>> fetchByDateRange(DateTime start, DateTime end) async {
    final userId = _currentUserId;
    if (userId == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection(_userSessionsCollection)
          .doc(userId)
          .collection(_sessionsSubcollection)
          .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('startedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('startedAt', descending: true)
          .get();

      return _mapSnapshotToSessions(snapshot);
    } catch (error) {
      print('❌ Error fetching sessions by date range: $error');
      throw Exception('Failed to fetch sessions for date range: $error');
    }
  }

  @override
  Future<SessionResult?> fetchById(String id) async {
    final userId = _currentUserId;
    if (userId == null) {
      return null;
    }

    try {
      final doc = await _firestore
          .collection(_userSessionsCollection)
          .doc(userId)
          .collection(_sessionsSubcollection)
          .doc(id)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return _mapDocumentToSession(doc);
    } catch (error) {
      print('❌ Error fetching session by ID: $error');
      throw Exception('Failed to fetch session: $error');
    }
  }

  @override
  Future<SessionResult> save(SessionResult session) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to save sessions');
    }

    try {
      final sessionWithId = session.id.isEmpty 
          ? SessionResult(
              id: _uuid.v4(),
              drill: session.drill,
              startedAt: session.startedAt,
              endedAt: session.endedAt,
              events: session.events,
            )
          : session;

      final sessionData = _sessionToFirestoreData(sessionWithId);

      await _firestore
          .collection(_userSessionsCollection)
          .doc(userId)
          .collection(_sessionsSubcollection)
          .doc(sessionWithId.id)
          .set(sessionData);

      // Update user statistics
      await _updateUserStatistics(sessionWithId);

      print('✅ Session saved successfully: ${sessionWithId.id}');
      return sessionWithId;
    } catch (error) {
      print('❌ Error saving session: $error');
      throw Exception('Failed to save session: $error');
    }
  }

  @override
  Future<void> delete(String id) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to delete sessions');
    }

    try {
      await _firestore
          .collection(_userSessionsCollection)
          .doc(userId)
          .collection(_sessionsSubcollection)
          .doc(id)
          .delete();

      print('✅ Session deleted successfully: $id');
    } catch (error) {
      print('❌ Error deleting session: $error');
      throw Exception('Failed to delete session: $error');
    }
  }

  @override
  Future<void> deleteAll() async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to delete sessions');
    }

    try {
      // Get all session documents
      final snapshot = await _firestore
          .collection(_userSessionsCollection)
          .doc(userId)
          .collection(_sessionsSubcollection)
          .get();

      // Delete in batches (Firestore batch limit is 500)
      final batches = <WriteBatch>[];
      var currentBatch = _firestore.batch();
      var operationCount = 0;

      for (final doc in snapshot.docs) {
        currentBatch.delete(doc.reference);
        operationCount++;

        if (operationCount == 500) {
          batches.add(currentBatch);
          currentBatch = _firestore.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        batches.add(currentBatch);
      }

      // Commit all batches
      for (final batch in batches) {
        await batch.commit();
      }

      print('✅ All sessions deleted successfully');
    } catch (error) {
      print('❌ Error deleting all sessions: $error');
      throw Exception('Failed to delete all sessions: $error');
    }
  }

  /// Get session statistics for a specific drill
  Future<Map<String, dynamic>> getSessionStats(String drillId) async {
    final userId = _currentUserId;
    if (userId == null) {
      return {};
    }

    try {
      final sessions = await fetchByDrill(drillId);
      
      if (sessions.isEmpty) {
        return {
          'totalSessions': 0,
          'averageAccuracy': 0.0,
          'averageReactionTime': 0.0,
          'bestAccuracy': 0.0,
          'bestReactionTime': 0.0,
          'improvement': 0.0,
        };
      }

      final totalSessions = sessions.length;
      final accuracies = sessions.map((s) => s.accuracy).toList();
      final reactionTimes = sessions.map((s) => s.avgReactionMs).where((rt) => rt > 0).toList();

      final averageAccuracy = accuracies.reduce((a, b) => a + b) / accuracies.length;
      final averageReactionTime = reactionTimes.isEmpty 
          ? 0.0 
          : reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;
      
      final bestAccuracy = accuracies.reduce((a, b) => a > b ? a : b);
      final bestReactionTime = reactionTimes.isEmpty 
          ? 0.0 
          : reactionTimes.reduce((a, b) => a < b ? a : b);

      // Calculate improvement (compare first 3 sessions with last 3 sessions)
      double improvement = 0.0;
      if (sessions.length >= 6) {
        final firstThree = sessions.skip(sessions.length - 3).take(3).toList();
        final lastThree = sessions.take(3).toList();
        
        final firstAvg = firstThree.map((s) => s.accuracy).reduce((a, b) => a + b) / 3;
        final lastAvg = lastThree.map((s) => s.accuracy).reduce((a, b) => a + b) / 3;
        
        improvement = ((lastAvg - firstAvg) / firstAvg) * 100;
      }

      return {
        'totalSessions': totalSessions,
        'averageAccuracy': averageAccuracy,
        'averageReactionTime': averageReactionTime,
        'bestAccuracy': bestAccuracy,
        'bestReactionTime': bestReactionTime,
        'improvement': improvement,
      };
    } catch (error) {
      print('❌ Error getting session stats: $error');
      return {};
    }
  }

  // Helper methods

  List<SessionResult> _mapSnapshotToSessions(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => _mapDocumentToSession(doc))
        .where((session) => session != null)
        .cast<SessionResult>()
        .toList();
  }

  SessionResult? _mapDocumentToSession(DocumentSnapshot doc) {
    try {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      return _firestoreDataToSession(doc.id, data);
    } catch (error) {
      print('❌ Error mapping document to session: $error');
      return null;
    }
  }

  Map<String, dynamic> _sessionToFirestoreData(SessionResult session) {
    return {
      'id': session.id,
      'drillId': session.drill.id,
      'drill': session.drill.toMap(), // Store drill data for historical purposes
      'startedAt': Timestamp.fromDate(session.startedAt),
      'endedAt': Timestamp.fromDate(session.endedAt),
      'durationMs': session.durationMs,
      'events': session.events.map((e) => e.toMap()).toList(),
      'results': {
        'totalStimuli': session.totalStimuli,
        'hits': session.hits,
        'misses': session.misses,
        'accuracy': session.accuracy,
        'averageReactionTime': session.avgReactionMs,
        'fastestReactionTime': session.events
            .where((e) => e.reactionTimeMs != null && e.correct)
            .map((e) => e.reactionTimeMs!)
            .fold<int?>(null, (min, rt) => min == null || rt < min ? rt : min) ?? 0,
        'slowestReactionTime': session.events
            .where((e) => e.reactionTimeMs != null && e.correct)
            .map((e) => e.reactionTimeMs!)
            .fold<int?>(null, (max, rt) => max == null || rt > max ? rt : max) ?? 0,
      },
      'metadata': {
        'deviceInfo': {
          'platform': 'mobile', // Could be enhanced to detect actual platform
          'screenSize': 'unknown',
          'deviceModel': 'unknown',
        },
        'environment': {
          'lighting': 'normal',
          'noise': 'normal',
          'distractions': 'none',
        },
      },
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  SessionResult _firestoreDataToSession(String id, Map<String, dynamic> data) {
    final drillData = Map<String, dynamic>.from(data['drill'] as Map);
    final drill = Drill.fromMap(drillData);

    final eventsData = data['events'] as List;
    final events = eventsData
        .map((e) => ReactionEvent.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return SessionResult(
      id: id,
      drill: drill,
      startedAt: (data['startedAt'] as Timestamp).toDate(),
      endedAt: (data['endedAt'] as Timestamp).toDate(),
      events: events,
    );
  }

  Future<void> _updateUserStatistics(SessionResult session) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        
        Map<String, dynamic> stats = {};
        if (userDoc.exists && userDoc.data() != null) {
          final statsData = userDoc.data()!['stats'];
          if (statsData is Map) {
            stats = Map<String, dynamic>.from(statsData);
          }
        }

        // Update statistics
        stats['totalSessions'] = (stats['totalSessions'] ?? 0) + 1;
        stats['totalDrillsCompleted'] = (stats['totalDrillsCompleted'] ?? 0) + 1;
        stats['lastSessionAt'] = Timestamp.fromDate(session.endedAt);

        // Update averages (simple moving average)
        final totalSessions = stats['totalSessions'] as int;
        final currentAvgAccuracy = stats['averageAccuracy'] ?? 0.0;
        final currentAvgReactionTime = stats['averageReactionTime'] ?? 0.0;

        stats['averageAccuracy'] = ((currentAvgAccuracy * (totalSessions - 1)) + session.accuracy) / totalSessions;
        if (session.avgReactionMs > 0) {
          stats['averageReactionTime'] = ((currentAvgReactionTime * (totalSessions - 1)) + session.avgReactionMs) / totalSessions;
        }

        transaction.set(userRef, {
          'stats': stats,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (error) {
      print('❌ Error updating user statistics: $error');
      // Don't throw here as session save should still succeed
    }
  }
}
