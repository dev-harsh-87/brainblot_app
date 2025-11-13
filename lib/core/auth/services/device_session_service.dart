import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spark_app/core/storage/app_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:spark_app/core/utils/app_logger.dart';
import 'dart:async';

/// Service to manage single device login sessions
/// Ensures only one device can be logged in per user at a time
class DeviceSessionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseMessaging _messaging;
  
  static const String _deviceSessionsCollection = 'deviceSessions';
  static const String _userSessionsCollection = 'userSessions';
  
  DeviceSessionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseMessaging? messaging,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;
 
  /// Register a new device session for the current user
  /// Returns existing sessions if any, without automatically logging them out
  Future<List<Map<String, dynamic>>> registerDeviceSession(String userId, {bool isAdmin = false, bool forceLogoutOthers = false}) async {
    try {
      // Get device information
      final deviceInfo = await getDeviceInfo();
      
      // Try to get FCM token, but don't fail if it's not available
      String? fcmToken;
      try {
        fcmToken = await _messaging.getToken();
      } catch (e) {
        AppLogger.warning('FCM token not available', tag: 'DeviceSession');
        fcmToken = null; // Continue without FCM token
      }
      
      // Check if user has an existing active session on another device
      List<Map<String, dynamic>> existingSessions = [];
      if (!isAdmin) {
        existingSessions = await _checkForExistingSessions(userId, deviceInfo['deviceId'] as String);
        
        // If forceLogoutOthers is true, logout existing sessions
        if (forceLogoutOthers && existingSessions.isNotEmpty) {
          await _logoutExistingSessions(userId, deviceInfo['deviceId'] as String);
        }
      }
      
      // Register new device session
      await _createDeviceSession(userId, deviceInfo, fcmToken);
      
      AppLogger.success('Device session registered successfully', tag: 'DeviceSession');
      return existingSessions;
    } catch (e) {
      AppLogger.error('Failed to register device session', error: e, tag: 'DeviceSession');
      rethrow;
    }
  }

  /// Check for existing sessions without logging them out
  Future<List<Map<String, dynamic>>> _checkForExistingSessions(String userId, String currentDeviceId) async {
    try {
      // Get all active sessions for this user
      final existingSessionsQuery = await _firestore
          .collection(_deviceSessionsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final existingSessions = <Map<String, dynamic>>[];
      
      for (final doc in existingSessionsQuery.docs) {
        final sessionData = doc.data();
        final existingDeviceId = sessionData['deviceId'] as String?;
        
        // Skip current device
        if (existingDeviceId != currentDeviceId) {
          existingSessions.add(sessionData);
        }
      }
      
      return existingSessions;
    } catch (e) {
      AppLogger.warning('Error checking existing sessions', tag: 'DeviceSession');
      return [];
    }
  }

  /// Logout existing sessions (the old behavior)
  Future<void> _logoutExistingSessions(String userId, String currentDeviceId) async {
    try {
      final existingSessions = await _checkForExistingSessions(userId, currentDeviceId);
      
      for (final sessionData in existingSessions) {
        final existingDeviceId = sessionData['deviceId'] as String?;
        final existingFcmToken = sessionData['fcmToken'] as String?;
        
        AppLogger.info('Logging out existing device: $existingDeviceId', tag: 'DeviceSession');
        
        if (existingFcmToken != null) {
          await _sendLogoutNotification(existingFcmToken, sessionData);
        }
        
        // Remove the device session
        await _removeDeviceSession(userId, existingDeviceId);
      }
    } catch (e) {
      AppLogger.warning('Error logging out existing sessions', tag: 'DeviceSession');
    }
  }

  /// Check for existing sessions and handle device conflicts (DEPRECATED - kept for compatibility)
  Future<void> _checkAndHandleExistingSession(String userId, String currentDeviceId) async {
    try {
      // Get current active session for this user
      final existingSessionQuery = await _firestore
          .collection(_userSessionsCollection)
          .doc(userId)
          .get();

      if (existingSessionQuery.exists) {
        final sessionData = existingSessionQuery.data()!;
        final existingDeviceId = sessionData['deviceId'] as String?;
        final existingFcmToken = sessionData['fcmToken'] as String?;
        
        // If same device, just update timestamp
        if (existingDeviceId == currentDeviceId) {
          await _updateSessionTimestamp(userId);
          return;
        }
        
        // Different device detected - force logout the previous device
        AppLogger.info('Different device detected, logging out previous session...', tag: 'DeviceSession');
        
        if (existingFcmToken != null) {
          await _sendLogoutNotification(existingFcmToken, sessionData);
        }
        
        // Remove the previous device session
        await _removeDeviceSession(userId, existingDeviceId);
      }
    } catch (e) {
      AppLogger.warning('Error checking existing session', tag: 'DeviceSession');
      // Continue with registration even if check fails
    }
  }

  /// Create a new device session
  Future<void> _createDeviceSession(String userId, Map<String, dynamic> deviceInfo, String? fcmToken) async {
    final sessionData = {
      'userId': userId,
      'deviceId': deviceInfo['deviceId'],
      'deviceName': deviceInfo['deviceName'],
      'deviceType': deviceInfo['deviceType'],
      'platform': deviceInfo['platform'],
      'appVersion': deviceInfo['appVersion'],
      'fcmToken': fcmToken,
      'loginTime': FieldValue.serverTimestamp(),
      'lastActiveTime': FieldValue.serverTimestamp(),
      'isActive': true,
    };

    // Create/update user session document
    await _firestore.collection(_userSessionsCollection).doc(userId).set(sessionData);
    
    // Create device-specific session document
    await _firestore
        .collection(_deviceSessionsCollection)
        .doc('${userId}_${deviceInfo['deviceId']}')
        .set(sessionData);
  }

  /// Update session timestamp for activity tracking
  Future<void> _updateSessionTimestamp(String userId) async {
    try {
      await _firestore.collection(_userSessionsCollection).doc(userId).update({
        'lastActiveTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.warning('Failed to update session timestamp', tag: 'DeviceSession');
    }
  }

  /// Remove device session
  Future<void> _removeDeviceSession(String userId, String? deviceId) async {
    try {
      // Remove user session
      await _firestore.collection(_userSessionsCollection).doc(userId).delete();
      
      // Remove device-specific session if deviceId is available
      if (deviceId != null) {
        await _firestore
            .collection(_deviceSessionsCollection)
            .doc('${userId}_$deviceId')
            .delete();
      }
    } catch (e) {
      AppLogger.warning('Failed to remove device session', tag: 'DeviceSession');
    }
  }

  /// Send logout notification to the previous device
  Future<void> _sendLogoutNotification(String fcmToken, Map<String, dynamic> sessionData) async {
    try {
      // In a real implementation, you would send this via your backend
      // For now, we'll create a Firestore document that the other device can listen to
      await _firestore.collection('logoutNotifications').add({
        'fcmToken': fcmToken,
        'userId': sessionData['userId'],
        'deviceId': sessionData['deviceId'],
        'message': 'You have been logged out because your account was accessed from another device.',
        'timestamp': FieldValue.serverTimestamp(),
        'processed': false,
      });
      
      AppLogger.info('Logout notification sent to previous device', tag: 'DeviceSession');
    } catch (e) {
      AppLogger.warning('Failed to send logout notification', tag: 'DeviceSession');
    }
  }

  /// Listen for logout notifications for current device
  Stream<DocumentSnapshot> listenForLogoutNotifications() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('logoutNotifications')
        .where('userId', isEqualTo: userId)
        .where('processed', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first : throw StateError('No notifications'));
  }

  /// Mark logout notification as processed
  Future<void> markNotificationProcessed(String notificationId) async {
    try {
      await _firestore.collection('logoutNotifications').doc(notificationId).update({
        'processed': true,
        'processedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.warning('Failed to mark notification as processed', tag: 'DeviceSession');
    }
  }

  /// Get device information with persistent device ID
  Future<Map<String, dynamic>> getDeviceInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfoPlugin = DeviceInfoPlugin();
    
    String deviceId = '';
    String deviceName = '';
    String deviceType = '';
    String platform = '';

    // Try to get stored device ID first
    const deviceIdKey = 'persistent_device_id';
    String? storedDeviceId = AppStorage.getString(deviceIdKey);

    if (Platform.isAndroid) {
      platform = 'Android';
      deviceType = 'Mobile';
      
      try {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
        
        // Use Android ID as device identifier
        if (storedDeviceId != null) {
          deviceId = storedDeviceId;
        } else {
          // Generate a persistent device ID based on Android ID
          deviceId = 'android_${androidInfo.id}';
          await AppStorage.setString(deviceIdKey, deviceId);
        }
      } catch (e) {
        AppLogger.warning('Failed to get Android device info', tag: 'DeviceSession');
        deviceName = 'Android Device';
        // Fallback to stored ID or generate new one
        if (storedDeviceId != null) {
          deviceId = storedDeviceId;
        } else {
          deviceId = 'android_${DateTime.now().millisecondsSinceEpoch}';
          await AppStorage.setString(deviceIdKey, deviceId);
        }
      }
    } else if (Platform.isIOS) {
      platform = 'iOS';
      deviceType = 'Mobile';
      
      try {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceName = '${iosInfo.name} (${iosInfo.model})';
        
        // Use identifierForVendor as device identifier
        if (storedDeviceId != null) {
          deviceId = storedDeviceId;
        } else {
          // Use iOS identifierForVendor
          deviceId = 'ios_${iosInfo.identifierForVendor ?? DateTime.now().millisecondsSinceEpoch}';
          await AppStorage.setString(deviceIdKey, deviceId);
        }
      } catch (e) {
        AppLogger.warning('Failed to get iOS device info', tag: 'DeviceSession');
        deviceName = 'iPhone';
        // Fallback to stored ID or generate new one
        if (storedDeviceId != null) {
          deviceId = storedDeviceId;
        } else {
          deviceId = 'ios_${DateTime.now().millisecondsSinceEpoch}';
          await AppStorage.setString(deviceIdKey, deviceId);
        }
      }
    }

    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'platform': platform,
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
    };
  }

  /// Cleanup session on logout
  Future<void> cleanupSession(String userId) async {
    try {
      final deviceInfo = await getDeviceInfo();
      await _removeDeviceSession(userId, deviceInfo['deviceId'] as String?);
      AppLogger.success('Device session cleaned up', tag: 'DeviceSession');
    } catch (e) {
      AppLogger.warning('Failed to cleanup device session', tag: 'DeviceSession');
    }
  }

  /// Check if current device session is valid
  Future<bool> isCurrentSessionValid() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final deviceInfo = await getDeviceInfo();
      final sessionDoc = await _firestore
          .collection(_userSessionsCollection)
          .doc(userId)
          .get();

      if (!sessionDoc.exists) return false;

      final sessionData = sessionDoc.data()!;
      final sessionDeviceId = sessionData['deviceId'] as String?;
      
      return sessionDeviceId == deviceInfo['deviceId'];
    } catch (e) {
      AppLogger.warning('Failed to validate session', tag: 'DeviceSession');
      return false;
    }
  }

  /// Get all active sessions for debugging (admin only)
  Future<List<Map<String, dynamic>>> getAllActiveSessions() async {
    try {
      final snapshot = await _firestore.collection(_userSessionsCollection).get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      },).toList();
    } catch (e) {
      AppLogger.error('Failed to get active sessions', error: e, tag: 'DeviceSession');
      return [];
    }
  }
}