import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/multiplayer/domain/connection_session.dart';
import 'package:spark_app/features/multiplayer/services/firebase_drill_sync_service.dart';
import 'package:spark_app/features/multiplayer/services/session_sync_service.dart';


/// Enhanced Firebase-based implementation of SessionSyncService
/// This replaces the Bluetooth-based implementation with Firebase Firestore + FCM
/// Includes enhanced custom stimuli support and improved synchronization
class FirebaseSessionSyncService implements SessionSyncService {
  final FirebaseDrillSyncService _firebaseService = FirebaseDrillSyncService();
  
  @override
  Stream<DrillSyncEvent> get drillEventStream => _firebaseService.drillEventStream;
  
  @override
  Stream<String> get statusStream => _firebaseService.statusStream;
  
  @override
  Drill? get currentDrill => _firebaseService.currentDrill;
  
  @override
  bool get isDrillActive => _firebaseService.isDrillActive;
  
  @override
  bool get isDrillPaused => _firebaseService.isDrillPaused;
  
  @override
  bool get isHost => _firebaseService.isHost;

  @override
  Future<void> initialize() async {
    try {
      await _firebaseService.initialize();
      debugPrint('✅ Firebase session sync service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Firebase session sync service: $e');
      rethrow;
    }
  }

  @override
  Future<ConnectionSession> startHostSession({
    int maxParticipants = 8,
  }) async {
    try {
      return await _firebaseService.startHostSession(
        maxParticipants: maxParticipants,
      );
    } catch (e) {
      debugPrint('❌ Failed to start host session: $e');
      rethrow;
    }
  }

  @override
  Future<ConnectionSession> joinSession(String sessionCode) async {
    try {
      return await _firebaseService.joinSession(sessionCode);
    } catch (e) {
      debugPrint('❌ Failed to join session: $e');
      rethrow;
    }
  }

  @override
  Future<void> startDrill(Drill drill) async {
    try {
      // Enhanced drill start with custom stimuli support
      await _firebaseService.startDrillForAll(drill);
      debugPrint('✅ Enhanced drill started: ${drill.name} with ${drill.customStimuliIds.length} custom stimuli');
    } catch (e) {
      debugPrint('❌ Failed to start enhanced drill: $e');
      rethrow;
    }
  }

  @override
  Future<void> pauseDrill({
    int? currentTimeMs,
    int? currentIndex,
  }) async {
    try {
      await _firebaseService.pauseDrillForAll(
        currentTimeMs: currentTimeMs,
        currentIndex: currentIndex,
      );
    } catch (e) {
      debugPrint('❌ Failed to pause drill: $e');
      rethrow;
    }
  }

  @override
  Future<void> resumeDrill({
    int? currentTimeMs,
    int? currentIndex,
  }) async {
    try {
      await _firebaseService.resumeDrillForAll(
        currentTimeMs: currentTimeMs,
        currentIndex: currentIndex,
      );
    } catch (e) {
      debugPrint('❌ Failed to resume drill: $e');
      rethrow;
    }
  }

  @override
  Future<void> stopDrill() async {
    try {
      await _firebaseService.stopDrillForAll();
    } catch (e) {
      debugPrint('❌ Failed to stop drill: $e');
      rethrow;
    }
  }

  // Legacy method names for backward compatibility
  Future<void> startDrillForAll(Drill drill) => startDrill(drill);

  Future<void> stopDrillForAll() => stopDrill();

  Future<void> pauseDrillForAll() => pauseDrill();
  Future<void> resumeDrillForAll() => resumeDrill();

  @override
  Future<void> broadcastStimulus(Map<String, dynamic> stimulusData) async {
    try {
      // Enhanced stimulus broadcasting with comprehensive custom stimuli data
      await _firebaseService.broadcastStimulus(
        stimulusType: stimulusData['stimulusType'] as String,
        label: stimulusData['label'] as String,
        colorValue: stimulusData['colorValue'] as int,
        timeMs: stimulusData['timeMs'] as int,
        index: stimulusData['index'] as int,
        customStimulusItemId: stimulusData['customStimulusItemId'] as String?,
      );
      
      debugPrint('✅ Enhanced stimulus broadcast: ${stimulusData['stimulusType']} with custom data');
    } catch (e) {
      debugPrint('❌ Failed to broadcast enhanced stimulus: $e');
    }
  }

  @override
  Future<void> sendChatMessage(String message) async {
    try {
      await _firebaseService.sendChatMessage(message);
    } catch (e) {
      debugPrint('❌ Failed to send chat message: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _firebaseService.disconnect();
    } catch (e) {
      debugPrint('❌ Error during disconnect: $e');
    }
  }

  @override
  ConnectionSession? getCurrentSession() {
    return _firebaseService.currentSession;
  }

  @override
  Stream<ConnectionSession> getSessionStream() {
    return _firebaseService.sessionStream;
  }

  @override
  Stream<String> getConnectionStatusStream() {
    return _firebaseService.statusStream;
  }

  @override
  Future<void> openPermissionSettings() async {
    // Firebase doesn't require special permissions like Bluetooth
    // This is a no-op for Firebase implementation
    debugPrint('ℹ️ Firebase implementation doesn\'t require special permissions');
  }

  @override
  Future<bool> arePermissionsAvailable() async {
    // Firebase doesn't require special permissions like Bluetooth
    // Always return true for Firebase implementation
    return true;
  }

  @override
  Future<bool> requestPermissions() async {
    // Firebase doesn't require special permissions like Bluetooth
    // Always return true for Firebase implementation
    return true;
  }

  // Additional methods for compatibility with existing code
  
  /// Get the underlying Firebase service for direct access
  FirebaseDrillSyncService getFirebaseService() {
    return _firebaseService;
  }


  /// Dispose resources
  void dispose() {
    _firebaseService.dispose();
  }
}