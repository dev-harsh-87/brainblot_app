import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/auth/domain/device_session.dart';
import 'package:spark_app/core/auth/services/device_session_service.dart';
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
        throw Exception('User must be authenticated to get active sessions');
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
      print('❌ Failed to get active sessions: $e');
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

  /// Logout from all other devices (keep current device)
  Future<void> logoutFromAllOtherDevices() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User must be authenticated to logout from all devices');
      }

      // Get current device info
      final currentDeviceInfo = await _deviceSessionService.getDeviceInfo();
      final currentDeviceId = currentDeviceInfo['deviceId'] as String;

      // Get all active sessions except current device
      final sessions = await getActiveSessions();
      final otherSessions = sessions.where((session) => 
          session.deviceId != currentDeviceId,).toList();

      // Logout from each other device
      for (final session in otherSessions) {
        await logoutFromDevice(session.deviceId);
      }

      print('✅ Successfully logged out from ${otherSessions.length} other devices');
    } catch (e) {
      print('❌ Failed to logout from all other devices: $e');
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