import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/multiplayer/domain/connection_session.dart';
import 'package:spark_app/features/multiplayer/domain/sync_message.dart';
import 'package:spark_app/features/multiplayer/services/bluetooth_connection_service.dart';

/// Service for synchronizing drill sessions across connected devices
class SessionSyncService {
  final BluetoothConnectionService _bluetoothService;
  
  final StreamController<DrillSyncEvent> _drillEventController = 
      StreamController<DrillSyncEvent>.broadcast();
  final StreamController<String> _statusController = 
      StreamController<String>.broadcast();
  
  StreamSubscription<SyncMessage>? _messageSubscription;
  
  Drill? _currentDrill;
  bool _isDrillActive = false;
  bool _isDrillPaused = false;
  DateTime? _drillStartTime;
  DateTime? _drillPauseTime;
  Duration _totalPausedDuration = Duration.zero;

  /// Stream of drill synchronization events
  Stream<DrillSyncEvent> get drillEventStream => _drillEventController.stream;
  
  /// Stream of sync status updates
  Stream<String> get statusStream => _statusController.stream;
  
  /// Current drill being synchronized
  Drill? get currentDrill => _currentDrill;
  
  /// Whether a drill is currently active
  bool get isDrillActive => _isDrillActive;
  
  /// Whether the current drill is paused
  bool get isDrillPaused => _isDrillPaused;
  
  /// Whether this device is the host
  bool get isHost => _bluetoothService.isHost;

  SessionSyncService(this._bluetoothService) {
    _setupMessageListener();
  }

  /// Initialize the sync service
  Future<void> initialize() async {
    try {
      await _bluetoothService.initialize();
      _statusController.add('Session sync service initialized');
    } catch (e) {
      debugPrint('Failed to initialize SessionSyncService: $e');
      _statusController.add('Initialization failed: $e');
      rethrow;
    }
  }

  /// Start hosting a multiplayer session
  Future<ConnectionSession> startHostSession({
    int maxParticipants = 8,
  }) async {
    try {
      final session = await _bluetoothService.createHostSession(
        maxParticipants: maxParticipants,
      );
      
      _statusController.add('Hosting session: ${session.sessionId}');
      return session;
    } catch (e) {
      debugPrint('Failed to start host session: $e');
      _statusController.add('Failed to host session: $e');
      rethrow;
    }
  }

  /// Join an existing multiplayer session
  Future<ConnectionSession> joinSession(String sessionCode) async {
    try {
      final session = await _bluetoothService.joinSession(sessionCode);
      
      _statusController.add('Joined session: ${session.sessionId}');
      return session;
    } catch (e) {
      debugPrint('Failed to join session: $e');
      _statusController.add('Failed to join session: $e');
      rethrow;
    }
  }

  /// Start a drill for all connected devices (host only)
  Future<void> startDrillForAll(Drill drill) async {
    if (!_bluetoothService.isHost) {
      throw Exception('Only the host can start drills');
    }

    try {
      _currentDrill = drill;
      _isDrillActive = true;
      _isDrillPaused = false;
      _drillStartTime = DateTime.now();
      _totalPausedDuration = Duration.zero;

      // Prepare drill data for synchronization
      final drillData = {
        'id': drill.id,
        'name': drill.name,
        'category': drill.category,
        'difficulty': drill.difficulty.name,
        'durationSec': drill.durationSec,
        'restSec': drill.restSec,
        'reps': drill.reps,
        'stimulusTypes': drill.stimulusTypes.map((e) => e.name).toList(),
        'numberOfStimuli': drill.numberOfStimuli,
        'zones': drill.zones.map((e) => e.name).toList(),
        'colors': drill.colors.map((c) => c.value).toList(),
        'startTime': _drillStartTime!.millisecondsSinceEpoch,
      };

      await _bluetoothService.startDrillForAll(drill.id, drillData);
      
      // Emit local event
      _drillEventController.add(DrillSyncEvent.started(drill));
      _statusController.add('Started drill: ${drill.name}');
      
      debugPrint('Started drill for all devices: ${drill.name}');
    } catch (e) {
      debugPrint('Failed to start drill for all: $e');
      _statusController.add('Failed to start drill: $e');
      rethrow;
    }
  }

  /// Stop the current drill for all devices (host only)
  Future<void> stopDrillForAll() async {
    if (!_bluetoothService.isHost) {
      throw Exception('Only the host can stop drills');
    }

    try {
      await _bluetoothService.stopDrillForAll();
      
      // Calculate session duration
      Duration? sessionDuration;
      if (_drillStartTime != null) {
        final endTime = DateTime.now();
        sessionDuration = endTime.difference(_drillStartTime!) - _totalPausedDuration;
      }

      // Emit local event
      _drillEventController.add(DrillSyncEvent.stopped(_currentDrill, sessionDuration));
      
      _resetDrillState();
      _statusController.add('Stopped drill for all devices');
      
      debugPrint('Stopped drill for all devices');
    } catch (e) {
      debugPrint('Failed to stop drill for all: $e');
      _statusController.add('Failed to stop drill: $e');
      rethrow;
    }
  }

  /// Pause the current drill for all devices (host only)
  Future<void> pauseDrillForAll() async {
    if (!_bluetoothService.isHost) {
      throw Exception('Only the host can pause drills');
    }

    if (!_isDrillActive || _isDrillPaused) {
      return;
    }

    try {
      _isDrillPaused = true;
      _drillPauseTime = DateTime.now();

      await _bluetoothService.pauseDrillForAll();
      
      // Emit local event
      _drillEventController.add(DrillSyncEvent.paused(_currentDrill));
      _statusController.add('Paused drill for all devices');
      
      debugPrint('Paused drill for all devices');
    } catch (e) {
      debugPrint('Failed to pause drill for all: $e');
      _statusController.add('Failed to pause drill: $e');
      rethrow;
    }
  }

  /// Resume the current drill for all devices (host only)
  Future<void> resumeDrillForAll() async {
    if (!_bluetoothService.isHost) {
      throw Exception('Only the host can resume drills');
    }

    if (!_isDrillActive || !_isDrillPaused) {
      return;
    }

    try {
      // Calculate paused duration
      if (_drillPauseTime != null) {
        final pauseDuration = DateTime.now().difference(_drillPauseTime!);
        _totalPausedDuration += pauseDuration;
      }

      _isDrillPaused = false;
      _drillPauseTime = null;

      await _bluetoothService.resumeDrillForAll();
      
      // Emit local event
      _drillEventController.add(DrillSyncEvent.resumed(_currentDrill));
      _statusController.add('Resumed drill for all devices');
      
      debugPrint('Resumed drill for all devices');
    } catch (e) {
      debugPrint('Failed to resume drill for all: $e');
      _statusController.add('Failed to resume drill: $e');
      rethrow;
    }
  }

  /// Broadcast stimulus data to all participants (host only)
  Future<void> broadcastStimulus({
    required String stimulusType,
    required String label,
    required int colorValue,
    required int timeMs,
    required int index,
  }) async {
    if (!_bluetoothService.isHost) {
      return; // Only host can broadcast stimuli
    }

    try {
      final stimulusData = {
        'type': stimulusType,
        'label': label,
        'colorValue': colorValue,
        'timeMs': timeMs,
        'index': index,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _bluetoothService.broadcastStimulus(stimulusData);
      debugPrint('Broadcasted stimulus: $stimulusType at $timeMs ms');
    } catch (e) {
      debugPrint('Failed to broadcast stimulus: $e');
    }
  }

  /// Send a chat message to all participants
  Future<void> sendChatMessage(String message) async {
    try {
      await _bluetoothService.sendChatMessage(message);
      _statusController.add('Chat message sent');
    } catch (e) {
      debugPrint('Failed to send chat message: $e');
      _statusController.add('Failed to send chat: $e');
    }
  }

  /// Disconnect from the current session
  Future<void> disconnect() async {
    try {
      await _bluetoothService.disconnect();
      _resetDrillState();
      _statusController.add('Disconnected from session');
    } catch (e) {
      debugPrint('Error during disconnect: $e');
      _statusController.add('Disconnect error: $e');
    }
  }

  /// Get the current session
  ConnectionSession? getCurrentSession() {
    return _bluetoothService.currentSession;
  }

  /// Get session stream
  Stream<ConnectionSession> getSessionStream() {
    return _bluetoothService.sessionStream;
  }

  /// Get connection status stream
  Stream<String> getConnectionStatusStream() {
    return _bluetoothService.connectionStatusStream;
  }

  /// Open permission settings for user to enable required permissions
  Future<void> openPermissionSettings() async {
    await _bluetoothService.openPermissionSettings();
  }

  /// Check if permissions are available (not permanently denied)
  Future<bool> arePermissionsAvailable() async {
    return await _bluetoothService.arePermissionsAvailable();
  }

  /// Get the underlying bluetooth service for direct access
  BluetoothConnectionService getBluetoothService() {
    return _bluetoothService;
  }

  /// Request permissions through the bluetooth service
  Future<bool> requestPermissions() async {
    return await _bluetoothService.requestPermissions();
  }

  // Private methods

  void _setupMessageListener() {
    _messageSubscription = _bluetoothService.messageStream.listen(
      _handleIncomingMessage,
      onError: (error) {
        debugPrint('Error in message stream: $error');
        _statusController.add('Message error: $error');
      },
    );
  }

  void _handleIncomingMessage(SyncMessage message) {
    debugPrint('Handling sync message: ${message.type.displayName}');
    
    switch (message.type) {
      case SyncMessageType.drillStart:
        _handleDrillStart(message);
        break;
      case SyncMessageType.drillStop:
        _handleDrillStop(message);
        break;
      case SyncMessageType.drillPause:
        _handleDrillPause(message);
        break;
      case SyncMessageType.drillResume:
        _handleDrillResume(message);
        break;
      case SyncMessageType.drillStimulus:
        _handleDrillStimulus(message);
        break;
      case SyncMessageType.chat:
        _handleChatMessage(message);
        break;
      case SyncMessageType.participantJoin:
        _statusController.add('${message.senderName} joined the session');
        break;
      case SyncMessageType.participantLeave:
        _statusController.add('${message.senderName} left the session');
        break;
      default:
        // Handle other message types as needed
        break;
    }
  }

  void _handleDrillStart(SyncMessage message) {
    try {
      final drillData = message.drillData;
      if (drillData == null) return;

      // Reconstruct drill from data
      _currentDrill = _reconstructDrillFromData(drillData);
      _isDrillActive = true;
      _isDrillPaused = false;
      
      if (drillData['startTime'] != null) {
        _drillStartTime = DateTime.fromMillisecondsSinceEpoch(drillData['startTime'] as int);
      }
      
      _totalPausedDuration = Duration.zero;

      // Emit event for UI
      _drillEventController.add(DrillSyncEvent.started(_currentDrill!));
      _statusController.add('Drill started: ${_currentDrill!.name}');
      
      debugPrint('Received drill start: ${_currentDrill!.name}');
    } catch (e) {
      debugPrint('Error handling drill start: $e');
      _statusController.add('Error starting drill: $e');
    }
  }

  void _handleDrillStop(SyncMessage message) {
    try {
      // Calculate session duration
      Duration? sessionDuration;
      if (_drillStartTime != null) {
        final endTime = DateTime.now();
        sessionDuration = endTime.difference(_drillStartTime!) - _totalPausedDuration;
      }

      // Emit event for UI
      _drillEventController.add(DrillSyncEvent.stopped(_currentDrill, sessionDuration));
      
      _resetDrillState();
      _statusController.add('Drill stopped by host');
      
      debugPrint('Received drill stop');
    } catch (e) {
      debugPrint('Error handling drill stop: $e');
      _statusController.add('Error stopping drill: $e');
    }
  }

  void _handleDrillPause(SyncMessage message) {
    try {
      _isDrillPaused = true;
      _drillPauseTime = DateTime.now();

      // Emit event for UI
      _drillEventController.add(DrillSyncEvent.paused(_currentDrill));
      _statusController.add('Drill paused by host');
      
      debugPrint('Received drill pause');
    } catch (e) {
      debugPrint('Error handling drill pause: $e');
      _statusController.add('Error pausing drill: $e');
    }
  }

  void _handleDrillResume(SyncMessage message) {
    try {
      // Calculate paused duration
      if (_drillPauseTime != null) {
        final pauseDuration = DateTime.now().difference(_drillPauseTime!);
        _totalPausedDuration += pauseDuration;
      }

      _isDrillPaused = false;
      _drillPauseTime = null;

      // Emit event for UI
      _drillEventController.add(DrillSyncEvent.resumed(_currentDrill));
      _statusController.add('Drill resumed by host');
      
      debugPrint('Received drill resume');
    } catch (e) {
      debugPrint('Error handling drill resume: $e');
      _statusController.add('Error resuming drill: $e');
    }
  }

  void _handleDrillStimulus(SyncMessage message) {
    try {
      final stimulusData = message.data['stimulusData'] as Map<String, dynamic>?;
      if (stimulusData == null) return;

      // Emit event for drill runner to display the stimulus
      _drillEventController.add(DrillSyncEvent.stimulus(stimulusData));
      
      debugPrint('Received stimulus: ${stimulusData['type']} at ${stimulusData['timeMs']}ms');
    } catch (e) {
      debugPrint('Error handling drill stimulus: $e');
    }
  }

  void _handleChatMessage(SyncMessage message) {
    final chatText = message.chatMessage;
    if (chatText != null) {
      _drillEventController.add(DrillSyncEvent.chatReceived(
        message.senderName,
        chatText,
      ),);
      _statusController.add('${message.senderName}: $chatText');
    }
  }

  Drill _reconstructDrillFromData(Map<String, dynamic> data) {
    return Drill(
      id: data['id'] as String,
      name: data['name'] as String,
      category: data['category'] as String,
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name == data['difficulty'],
        orElse: () => Difficulty.beginner,
      ),
      durationSec: data['durationSec'] as int,
      restSec: data['restSec'] as int,
      reps: data['reps'] as int,
      stimulusTypes: (data['stimulusTypes'] as List<dynamic>)
          .map((e) => StimulusType.values.firstWhere((s) => s.name == e))
          .toList(),
      numberOfStimuli: data['numberOfStimuli'] as int,
      zones: (data['zones'] as List<dynamic>)
          .map((e) => ReactionZone.values.firstWhere((z) => z.name == e))
          .toList(),
      colors: (data['colors'] as List<dynamic>)
          .map((c) => Color(c as int))
          .toList(),
      sharedWith: [],
      createdAt: DateTime.now(),
    );
  }

  void _resetDrillState() {
    _currentDrill = null;
    _isDrillActive = false;
    _isDrillPaused = false;
    _drillStartTime = null;
    _drillPauseTime = null;
    _totalPausedDuration = Duration.zero;
  }

  /// Dispose resources
  void dispose() {
    _messageSubscription?.cancel();
    _drillEventController.close();
    _statusController.close();
    _bluetoothService.dispose();
  }
}

/// Events emitted by the session sync service
abstract class DrillSyncEvent {
  const DrillSyncEvent();

  factory DrillSyncEvent.started(Drill drill) = DrillStartedEvent;
  factory DrillSyncEvent.stopped(Drill? drill, Duration? duration) = DrillStoppedEvent;
  factory DrillSyncEvent.paused(Drill? drill) = DrillPausedEvent;
  factory DrillSyncEvent.resumed(Drill? drill) = DrillResumedEvent;
  factory DrillSyncEvent.chatReceived(String sender, String message) = ChatReceivedEvent;
  factory DrillSyncEvent.stimulus(Map<String, dynamic> data) = StimulusEvent;
}

class DrillStartedEvent extends DrillSyncEvent {
  final Drill drill;
  const DrillStartedEvent(this.drill);
}

class DrillStoppedEvent extends DrillSyncEvent {
  final Drill? drill;
  final Duration? duration;
  const DrillStoppedEvent(this.drill, this.duration);
}

class DrillPausedEvent extends DrillSyncEvent {
  final Drill? drill;
  const DrillPausedEvent(this.drill);
}

class DrillResumedEvent extends DrillSyncEvent {
  final Drill? drill;
  const DrillResumedEvent(this.drill);
}

class StimulusEvent extends DrillSyncEvent {
  final Map<String, dynamic> data;
  const StimulusEvent(this.data);
}

class ChatReceivedEvent extends DrillSyncEvent {
  final String sender;
  final String message;
  const ChatReceivedEvent(this.sender, this.message);
}
