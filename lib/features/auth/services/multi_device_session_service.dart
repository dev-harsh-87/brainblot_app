import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/auth/domain/device_session.dart';
import 'package:spark_app/core/auth/services/device_session_service.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'dart:async';

/// Service to manage multiple device sessions for a user
/// Provides functionality to view and manage active sessions across devices
class MultiDeviceSessionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DeviceSessionService _deviceSessionService;
  
  static const String _userSessionsCollection = 'userSessions';
  static const String _deviceSessionsCollection = 'deviceSessions';
  static const String _logoutNotificationsCollection = 'logoutNotifications';
  
  MultiDeviceSessionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DeviceSessionService? deviceSessionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _deviceSessionService = deviceSessionService ?? DeviceSessionService();

  /// Get all active sessions for the current user
  Future<List<DeviceSession>> getActiveSessions() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.warning('User not authenticated when checking sessions', tag: 'MultiDeviceSession');
        return [];
      }

      // Get current device info to identify current session
      final currentDeviceInfo = await _deviceSessionService.getDeviceInfo();
      final currentDeviceId = currentDeviceInfo['deviceId'] as String;

      // Get all device sessions for this user
      final deviceSessionsQuery = await _firestore
          .collection(_deviceSessionsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('lastActiveTime', descending: true)
          .get();

      final sessions = <DeviceSession>[];
      
      for (final doc in deviceSessionsQuery.docs) {
        final session = DeviceSession.fromFirestore(
          doc,
          isCurrentDevice: doc.data()['deviceId'] == currentDeviceId,
        );
        sessions.add(session);
      }

      return sessions;
    } catch (e) {
      AppLogger.error('Failed to get active sessions', error: e, tag: 'MultiDeviceSession');
      return [];
    }
  }

  /// Get active sessions as a stream for real-time updates
  Stream<List<DeviceSession>> watchActiveSessions() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_deviceSessionsCollection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('lastActiveTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        // Get current device info to identify current session
        final currentDeviceInfo = await _deviceSessionService.getDeviceInfo();
        final currentDeviceId = currentDeviceInfo['deviceId'] as String;

        final sessions = <DeviceSession>[];
        
        for (final doc in snapshot.docs) {
          final session = DeviceSession.fromFirestore(
            doc,
            isCurrentDevice: doc.data()['deviceId'] == currentDeviceId,
          );
          sessions.add(session);
        }

        return sessions;
      } catch (e) {
        print('❌ Failed to watch active sessions: $e');
        return <DeviceSession>[];
      }
    });
  }

  /// Logout from a specific device
  Future<void> logoutFromDevice(String deviceId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User must be authenticated to logout from device');
      }

      // Get the session to logout
      final sessionDoc = await _firestore
          .collection(_deviceSessionsCollection)
          .doc('${userId}_$deviceId')
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final sessionData = sessionDoc.data()!;
      final fcmToken = sessionData['fcmToken'] as String?;

      // Send logout notification if FCM token is available
      if (fcmToken != null) {
        await _sendLogoutNotification(fcmToken, sessionData);
      }

      // Remove the device session
      await _removeDeviceSession(userId, deviceId);

      print('✅ Successfully logged out device: $deviceId');
    } catch (e) {
      print('❌ Failed to logout from device: $e');
      rethrow;
    }
  }

  /// Logout from all other devices (keep current device) - Optimized batch operation
  Future<void> logoutFromAllOtherDevices() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User must be authenticated to logout from all devices');
      }

      // Get current device info
      final currentDeviceInfo = await _deviceSessionService.getDeviceInfo();
      final currentDeviceId = currentDeviceInfo['deviceId'] as String;

      AppLogger.info('Starting batch logout from all other devices', tag: 'MultiDeviceSession');

      // Get all active sessions except current device in a single query
      final otherSessionsQuery = await _firestore
          .collection(_deviceSessionsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final otherSessions = otherSessionsQuery.docs
          .where((doc) => doc.data()['deviceId'] != currentDeviceId)
          .toList();

      if (otherSessions.isEmpty) {
        AppLogger.info('No other devices to logout from', tag: 'MultiDeviceSession');
        return;
      }

      // Prepare batch operations for better performance
      final batch = _firestore.batch();
      final logoutNotifications = <Map<String, dynamic>>[];

      // Process each session for batch operations
      for (final sessionDoc in otherSessions) {
        final sessionData = sessionDoc.data();
        final deviceId = sessionData['deviceId'] as String;
        final fcmToken = sessionData['fcmToken'] as String?;

        // Add to batch delete
        batch.delete(sessionDoc.reference);

        // Prepare logout notification if FCM token exists
        if (fcmToken != null) {
          logoutNotifications.add({
            'fcmToken': fcmToken,
            'userId': userId,
            'deviceId': deviceId,
            'message': 'You have been logged out because your account was accessed from another device.',
            'timestamp': FieldValue.serverTimestamp(),
            'processed': false,
          });
        }

        AppLogger.debug('Prepared logout for device: $deviceId', tag: 'MultiDeviceSession');
      }

      // Execute batch delete operations
      await batch.commit();
      AppLogger.info('Batch deleted ${otherSessions.length} device sessions', tag: 'MultiDeviceSession');

      // Send logout notifications in parallel for better performance
      if (logoutNotifications.isNotEmpty) {
        final notificationFutures = logoutNotifications.map((notification) =>
            _firestore.collection(_logoutNotificationsCollection).add(notification));
        
        await Future.wait(notificationFutures);
        AppLogger.info('Sent ${logoutNotifications.length} logout notifications', tag: 'MultiDeviceSession');
      }

      // Clean up user session if needed (check if any of the deleted sessions was the active one)
      await _cleanupUserSessionIfNeeded(userId, otherSessions);

      AppLogger.info('Successfully logged out from ${otherSessions.length} other devices', tag: 'MultiDeviceSession');
    } catch (e) {
      AppLogger.error('Failed to logout from all other devices', error: e, tag: 'MultiDeviceSession');
      rethrow;
    }
  }

  /// Check if there are other active sessions
  Future<bool> hasOtherActiveSessions() async {
    try {
      final sessions = await getActiveSessions();
      final otherSessions = sessions.where((session) => !session.isCurrentDevice);
      return otherSessions.isNotEmpty;
    } catch (e) {
      print('❌ Failed to check other active sessions: $e');
      return false;
    }
  }

  /// Get session count for current user
  Future<int> getActiveSessionCount() async {
    try {
      final sessions = await getActiveSessions();
      return sessions.length;
    } catch (e) {
      print('❌ Failed to get session count: $e');
      return 0;
    }
  }

  /// Send logout notification to a device
  Future<void> _sendLogoutNotification(String fcmToken, Map<String, dynamic> sessionData) async {
    try {
      await _firestore.collection(_logoutNotificationsCollection).add({
        'fcmToken': fcmToken,
        'userId': sessionData['userId'],
        'deviceId': sessionData['deviceId'],
        'message': 'You have been logged out because your account was accessed from another device.',
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
      });
      
      print('📱 Logout notification sent to device: ${sessionData['deviceId']}');
    } catch (e) {
      print('⚠️ Failed to send logout notification: $e');
    }
  }

  /// Remove device session
  Future<void> _removeDeviceSession(String userId, String deviceId) async {
    try {
      // Remove device-specific session
      await _firestore
          .collection(_deviceSessionsCollection)
          .doc('${userId}_$deviceId')
          .delete();
      
      // Update user session if this was the active one
      final userSessionDoc = await _firestore
          .collection(_userSessionsCollection)
          .doc(userId)
          .get();
      
      if (userSessionDoc.exists) {
        final userData = userSessionDoc.data()!;
        if (userData['deviceId'] == deviceId) {
          await _firestore
              .collection(_userSessionsCollection)
              .doc(userId)
              .delete();
        }
      }
      
      print('✅ Device session removed: $deviceId');
    } catch (e) {
      print('⚠️ Failed to remove device session: $e');
    }
  
  }

  /// Clean up user session if any of the deleted sessions was the active one
  Future<void> _cleanupUserSessionIfNeeded(String userId, List<QueryDocumentSnapshot> deletedSessions) async {
    try {
      final userSessionDoc = await _firestore
          .collection(_userSessionsCollection)
          .doc(userId)
          .get();
      
      if (!userSessionDoc.exists) return;
      
      final userData = userSessionDoc.data()!;
      final activeDeviceId = userData['deviceId'] as String?;
      
      if (activeDeviceId == null) return;
      
      // Check if the active device was among the deleted sessions
      final wasActiveDeviceDeleted = deletedSessions.any((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return data != null && data['deviceId'] == activeDeviceId;
      });
      
      if (wasActiveDeviceDeleted) {
        await _firestore
            .collection(_userSessionsCollection)
            .doc(userId)
            .delete();
        
        AppLogger.info('Cleaned up user session for deleted active device: $activeDeviceId', tag: 'MultiDeviceSession');
      }
    } catch (e) {
      AppLogger.warning('Failed to cleanup user session: $e', tag: 'MultiDeviceSession');
      // Don't rethrow as this is cleanup operation
    }
  }

  /// Clean up expired sessions (older than 30 days)
  Future<void> cleanupExpiredSessions() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final expiredSessions = await _firestore
          .collection(_deviceSessionsCollection)
          .where('userId', isEqualTo: userId)
          .where('lastActiveTime', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      for (final doc in expiredSessions.docs) {
        await doc.reference.delete();
      }

      if (expiredSessions.docs.isNotEmpty) {
        print('✅ Cleaned up ${expiredSessions.docs.length} expired sessions');
      }
    } catch (e) {
      print('⚠️ Failed to cleanup expired sessions: $e');
    }
  }

  /// Get session details for a specific device
  Future<DeviceSession?> getSessionForDevice(String deviceId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final sessionDoc = await _firestore
          .collection(_deviceSessionsCollection)
          .doc('${userId}_$deviceId')
          .get();

      if (!sessionDoc.exists) return null;

      // Get current device info to check if it's current device
      final currentDeviceInfo = await _deviceSessionService.getDeviceInfo();
      final currentDeviceId = currentDeviceInfo['deviceId'] as String;

      return DeviceSession.fromFirestore(
        sessionDoc,
        isCurrentDevice: deviceId == currentDeviceId,
      );
    } catch (e) {
      print('❌ Failed to get session for device: $e');
      return null;
    }
  }
}