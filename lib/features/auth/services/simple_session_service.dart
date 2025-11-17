import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'package:spark_app/features/auth/domain/device_session.dart';
import 'package:spark_app/core/auth/services/device_session_service.dart';

/// Simplified session service for reliable session management
/// Focuses on core functionality without complex conflict handling
class SimpleSessionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DeviceSessionService _deviceSessionService;
  
  static const String _deviceSessionsCollection = 'deviceSessions';
  
  SimpleSessionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DeviceSessionService? deviceSessionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _deviceSessionService = deviceSessionService ?? DeviceSessionService();

  /// Check for existing sessions and return them for conflict handling
  Future<List<DeviceSession>> checkForConflicts() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.warning('No authenticated user for conflict check', tag: 'SimpleSession');
        return [];
      }

      // Get current device info
      final currentDeviceInfo = await _deviceSessionService.getDeviceInfo();
      final currentDeviceId = currentDeviceInfo['deviceId'] as String;

      // Query for active sessions
      final sessionsQuery = await _firestore
          .collection(_deviceSessionsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final sessions = <DeviceSession>[];
      
      for (final doc in sessionsQuery.docs) {
        try {
          final session = DeviceSession.fromFirestore(
            doc,
            isCurrentDevice: doc.data()['deviceId'] == currentDeviceId,
          );
          sessions.add(session);
        } catch (e) {
          AppLogger.warning('Failed to parse session document: ${doc.id}', tag: 'SimpleSession');
        }
      }

      // Filter for other devices only
      final otherSessions = sessions.where((s) => !s.isCurrentDevice).toList();
      
      AppLogger.info('Found ${sessions.length} total sessions, ${otherSessions.length} from other devices', tag: 'SimpleSession');
      
      return otherSessions;
    } catch (e) {
      AppLogger.error('Failed to check for session conflicts', error: e, tag: 'SimpleSession');
      return [];
    }
  }

  /// Register current device session
  Future<void> registerCurrentSession() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.warning('No authenticated user for session registration', tag: 'SimpleSession');
        return;
      }

      await _deviceSessionService.registerDeviceSession(userId);
      AppLogger.success('Current device session registered', tag: 'SimpleSession');
    } catch (e) {
      AppLogger.error('Failed to register current session', error: e, tag: 'SimpleSession');
      // Don't rethrow - allow login to continue
    }
  }

  /// Logout from all other devices
  Future<void> logoutOtherDevices() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.warning('No authenticated user for logout operation', tag: 'SimpleSession');
        return;
      }

      // Get current device info
      final currentDeviceInfo = await _deviceSessionService.getDeviceInfo();
      final currentDeviceId = currentDeviceInfo['deviceId'] as String;

      // Get all sessions for this user
      final sessionsQuery = await _firestore
          .collection(_deviceSessionsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      int logoutCount = 0;

      for (final doc in sessionsQuery.docs) {
        final sessionData = doc.data();
        final deviceId = sessionData['deviceId'] as String?;
        
        // Skip current device
        if (deviceId != currentDeviceId) {
          batch.update(doc.reference, {'isActive': false});
          logoutCount++;
        }
      }

      if (logoutCount > 0) {
        await batch.commit();
        AppLogger.success('Logged out from $logoutCount other devices', tag: 'SimpleSession');
      } else {
        AppLogger.info('No other devices to logout from', tag: 'SimpleSession');
      }
    } catch (e) {
      AppLogger.error('Failed to logout other devices', error: e, tag: 'SimpleSession');
      rethrow;
    }
  }

  /// Clean up current session on logout
  Future<void> cleanupCurrentSession() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        AppLogger.warning('No authenticated user for session cleanup', tag: 'SimpleSession');
        return;
      }

      await _deviceSessionService.cleanupSession(userId);
      AppLogger.success('Current session cleaned up', tag: 'SimpleSession');
    } catch (e) {
      AppLogger.warning('Failed to cleanup current session', tag: 'SimpleSession');
      // Don't rethrow - allow logout to continue
    }
  }
}