import 'dart:async';

import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/multiplayer/domain/connection_session.dart';

/// Abstract service interface for synchronizing drill sessions across connected devices
/// This interface is implemented by Firebase-based multiplayer service
abstract class SessionSyncService {
  /// Stream of drill synchronization events
  Stream<DrillSyncEvent> get drillEventStream;
  
  /// Stream of sync status updates
  Stream<String> get statusStream;
  
  /// Current drill being synchronized
  Drill? get currentDrill;
  
  /// Whether a drill is currently active
  bool get isDrillActive;
  
  /// Whether the current drill is paused
  bool get isDrillPaused;
  
  /// Whether this device is the host
  bool get isHost;

  /// Initialize the service
  Future<void> initialize();

  /// Start hosting a session
  Future<ConnectionSession> startHostSession({int maxParticipants = 8});

  /// Join an existing session
  Future<ConnectionSession> joinSession(String sessionCode);

  /// Get current session stream
  Stream<ConnectionSession> getSessionStream();

  /// Get current session
  ConnectionSession? getCurrentSession();

  /// Get connection status stream
  Stream<String> getConnectionStatusStream();

  /// Check if permissions are available
  Future<bool> arePermissionsAvailable();

  /// Open permission settings
  Future<void> openPermissionSettings();

  /// Start a drill (host only)
  Future<void> startDrill(Drill drill);

  /// Pause the current drill (host only)
  Future<void> pauseDrill();

  /// Resume the current drill (host only)
  Future<void> resumeDrill();

  /// Stop the current drill (host only)
  Future<void> stopDrill();

  /// Send a chat message
  Future<void> sendChatMessage(String message);

  /// Broadcast stimulus data to participants (host only)
  Future<void> broadcastStimulus(Map<String, dynamic> stimulusData);

  /// Disconnect from the session
  Future<void> disconnect();

  /// Request permissions (no-op for Firebase implementation)
  Future<bool> requestPermissions() async => true;
}

/// Base class for drill synchronization events
abstract class DrillSyncEvent {}

/// Event fired when a drill is started
class DrillStartedEvent extends DrillSyncEvent {
  final Drill drill;
  DrillStartedEvent(this.drill);
}

/// Event fired when a drill is paused
class DrillPausedEvent extends DrillSyncEvent {}

/// Event fired when a drill is resumed
class DrillResumedEvent extends DrillSyncEvent {}

/// Event fired when a drill is stopped
class DrillStoppedEvent extends DrillSyncEvent {}

/// Event fired when a stimulus is received
class StimulusEvent extends DrillSyncEvent {
  final Map<String, dynamic> data;
  StimulusEvent(this.data);
}

/// Event fired when a chat message is received
class ChatReceivedEvent extends DrillSyncEvent {
  final String sender;
  final String message;
  ChatReceivedEvent(this.sender, this.message);
}
