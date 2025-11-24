import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/multiplayer/domain/connection_session.dart';
import 'package:spark_app/features/multiplayer/domain/sync_message.dart';
import 'package:spark_app/features/multiplayer/services/session_sync_service.dart';

/// Firebase-based service for synchronizing drill sessions across connected devices
/// Uses Firestore for real-time data sync and FCM for notifications
class FirebaseDrillSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  final StreamController<DrillSyncEvent> _drillEventController = 
      StreamController<DrillSyncEvent>.broadcast();
  final StreamController<String> _statusController = 
      StreamController<String>.broadcast();
  final StreamController<ConnectionSession> _sessionController = 
      StreamController<ConnectionSession>.broadcast();
  
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  
  String? _deviceId;
  String? _deviceName;
  String? _fcmToken;
  ConnectionSession? _currentSession;
  bool _isHost = false;
  bool _isConnected = false;
  
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
  
  /// Stream of session updates
  Stream<ConnectionSession> get sessionStream => _sessionController.stream;
  
  /// Current drill being synchronized
  Drill? get currentDrill => _currentDrill;
  
  /// Whether a drill is currently active
  bool get isDrillActive => _isDrillActive;
  
  /// Whether the current drill is paused
  bool get isDrillPaused => _isDrillPaused;
  
  /// Whether this device is the host
  bool get isHost => _isHost;
  
  /// Whether connected to a session
  bool get isConnected => _isConnected;
  
  /// Current session
  ConnectionSession? get currentSession => _currentSession;

  /// Initialize the sync service
  Future<void> initialize() async {
    try {
      _deviceId = await _generateDeviceId();
      _deviceName = await _getDeviceName();
      _fcmToken = await _messaging.getToken();
      
      // Request FCM permission
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      // Set up FCM message handling
      _setupFCMHandlers();
      
      _statusController.add('Firebase sync service initialized');
      debugPrint('✅ Firebase drill sync service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Firebase sync service: $e');
      _statusController.add('Initialization failed: $e');
      rethrow;
    }
  }

  /// Start hosting a multiplayer session
  Future<ConnectionSession> startHostSession({
    int maxParticipants = 8,
  }) async {
    try {
      if (_deviceId == null || _deviceName == null) {
        throw Exception('Service not initialized');
      }

      final sessionId = _generateSessionCode();
      
      _currentSession = ConnectionSession.createHost(
        sessionId: sessionId,
        hostId: _deviceId!,
        hostName: _deviceName!,
        maxParticipants: maxParticipants,
      );

      // Create session document in Firestore with proper timestamp handling
      final now = DateTime.now();
      await _firestore
          .collection('multiplayer_sessions')
          .doc(sessionId)
          .set({
        ...(_currentSession!.toJson()),
        'fcmTokens': {_deviceId!: _fcmToken},
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
        // Add client timestamp as backup
        'clientCreatedAt': now.toIso8601String(),
        'clientLastActivity': now.toIso8601String(),
      });

      _isHost = true;
      _isConnected = true;
      
      // Listen for session updates
      _setupSessionListener(sessionId);
      
      _statusController.add('Hosting session: $sessionId');
      _sessionController.add(_currentSession!);
      
      debugPrint('✅ Host session created: $sessionId');
      return _currentSession!;
    } catch (e) {
      debugPrint('❌ Failed to start host session: $e');
      _statusController.add('Failed to host session: $e');
      rethrow;
    }
  }

  /// Join an existing multiplayer session
  Future<ConnectionSession> joinSession(String sessionCode) async {
    try {
      if (_deviceId == null || _deviceName == null) {
        throw Exception('Service not initialized');
      }

      // Validate session code format
      if (sessionCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(sessionCode)) {
        throw Exception('Invalid session code format');
      }

      _statusController.add('Searching for session: $sessionCode...');

      // Check if session exists
      final sessionDoc = await _firestore
          .collection('multiplayer_sessions')
          .doc(sessionCode)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Session $sessionCode not found');
      }

      final sessionData = sessionDoc.data()!;
      _currentSession = ConnectionSession.fromJson(_convertTimestampsForJson(sessionData));

      // Check if session is full
      if (_currentSession!.isFull) {
        throw Exception('Session is full');
      }

      // Add participant to session with proper timestamp handling
      await _firestore
          .collection('multiplayer_sessions')
          .doc(sessionCode)
          .update({
        'participantIds': FieldValue.arrayUnion([_deviceId!]),
        'participantNames': FieldValue.arrayUnion([_deviceName!]),
        'fcmTokens.${_deviceId!}': _fcmToken,
        'lastActivity': FieldValue.serverTimestamp(),
        'clientLastActivity': DateTime.now().toIso8601String(),
      });

      _isHost = false;
      _isConnected = true;
      
      // Listen for session updates
      _setupSessionListener(sessionCode);
      
      // Send join message
      await _sendMessage(SyncMessage.participantJoin(
        senderId: _deviceId!,
        senderName: _deviceName!,
      ));
      
      _statusController.add('Joined session: $sessionCode');
      
      debugPrint('✅ Successfully joined session: $sessionCode');
      return _currentSession!;
    } catch (e) {
      debugPrint('❌ Failed to join session: $e');
      _statusController.add('Failed to join session: $e');
      rethrow;
    }
  }

  /// Start a drill for all connected devices (host only)
  Future<void> startDrillForAll(Drill drill) async {
    if (!_isHost) {
      throw Exception('Only the host can start drills');
    }

    try {
      debugPrint('🚀 Starting drill for all devices: ${drill.name}');
      
      _currentDrill = drill;
      _isDrillActive = true;
      _isDrillPaused = false;
      _drillStartTime = DateTime.now();
      _totalPausedDuration = Duration.zero;
      
      debugPrint('📊 Drill state set: active=$_isDrillActive, paused=$_isDrillPaused');

      // Update session with active drill
      await _updateSessionDrillState(drill.id, SessionStatus.active);

      // Prepare drill data for synchronization
      final drillData = {
        'id': drill.id,
        'name': drill.name,
        'category': drill.category,
        'difficulty': drill.difficulty.name,
        'durationSec': drill.durationSec,
        'restSec': drill.restSec,
        'reps': drill.reps,
        'sets': drill.sets,
        'stimulusTypes': drill.stimulusTypes.map((e) => e.name).toList(),
        'numberOfStimuli': drill.numberOfStimuli,
        'zones': drill.zones.map((e) => e.name).toList(),
        'colors': drill.colors.map((c) => c.value).toList(),
        'startTime': _drillStartTime!.millisecondsSinceEpoch,
        'drillMode': drill.drillMode.name,
        'presentationMode': drill.presentationMode.name,
        'stimulusLengthMs': drill.stimulusLengthMs,
        'delayBetweenStimuliMs': drill.delayBetweenStimuliMs,
        'customStimuliIds': drill.customStimuliIds,
        // Add custom stimuli metadata for proper sync
        'hasCustomStimuli': drill.customStimuliIds.isNotEmpty,
        'customStimuliCount': drill.customStimuliIds.length,
      };

      // Send drill start message
      await _sendMessage(SyncMessage.drillStart(
        senderId: _deviceId!,
        senderName: _deviceName!,
        drillId: drill.id,
        drillData: drillData,
      ));

      // Emit local event
      _drillEventController.add(DrillStartedEvent(drill));
      _statusController.add('Started drill: ${drill.name}');
      
      debugPrint('✅ Started drill for all devices: ${drill.name}');
    } catch (e) {
      debugPrint('❌ Failed to start drill for all: $e');
      _statusController.add('Failed to start drill: $e');
      rethrow;
    }
  }

  /// Stop the current drill for all devices (host only)
  Future<void> stopDrillForAll() async {
    if (!_isHost) {
      throw Exception('Only the host can stop drills');
    }

    try {
      // Update session to remove active drill
      await _updateSessionDrillState(null, SessionStatus.waiting);

      // Send drill stop message
      await _sendMessage(SyncMessage.drillStop(
        senderId: _deviceId!,
        senderName: _deviceName!,
      ));

      // Calculate session duration
      Duration? sessionDuration;
      if (_drillStartTime != null) {
        final endTime = DateTime.now();
        sessionDuration = endTime.difference(_drillStartTime!) - _totalPausedDuration;
      }

      // Emit local event
      _drillEventController.add(DrillStoppedEvent());
      
      _resetDrillState();
      _statusController.add('Stopped drill for all devices');
      
      debugPrint('✅ Stopped drill for all devices');
    } catch (e) {
      debugPrint('❌ Failed to stop drill for all: $e');
      _statusController.add('Failed to stop drill: $e');
      rethrow;
    }
  }

  /// Pause the current drill for all devices (host only)
  Future<void> pauseDrillForAll({
    int? currentTimeMs,
    int? currentIndex,
  }) async {
    if (!_isHost) {
      throw Exception('Only the host can pause drills');
    }

    if (!_isDrillActive) {
      debugPrint('⚠️ Cannot pause drill: drill is not active (active=$_isDrillActive)');
      return;
    }
    
    if (_isDrillPaused) {
      debugPrint('⚠️ Drill is already paused (paused=$_isDrillPaused)');
      return;
    }

    try {
      debugPrint('🔄 Host pausing drill for all devices...');
      debugPrint('📊 Before pause: active=$_isDrillActive, paused=$_isDrillPaused');
      
      _isDrillPaused = true;
      _drillPauseTime = DateTime.now();
      
      debugPrint('📊 After pause state change: active=$_isDrillActive, paused=$_isDrillPaused');

      // Update session status first
      await _updateSessionDrillState(_currentDrill?.id, SessionStatus.paused);

      // Send drill pause message with high priority and timing data
      await _sendMessage(SyncMessage.drillPause(
        senderId: _deviceId!,
        senderName: _deviceName!,
        currentTimeMs: currentTimeMs,
        currentIndex: currentIndex,
      ));
      
      // Emit local event
      _drillEventController.add(DrillPausedEvent());
      _statusController.add('Paused drill for all devices');
      
      debugPrint('✅ Successfully paused drill for all devices');
    } catch (e) {
      debugPrint('❌ Failed to pause drill for all: $e');
      _statusController.add('Failed to pause drill: $e');
      rethrow;
    }
  }

  /// Resume the current drill for all devices (host only)
  Future<void> resumeDrillForAll({
    int? currentTimeMs,
    int? currentIndex,
  }) async {
    if (!_isHost) {
      throw Exception('Only the host can resume drills');
    }

    if (!_isDrillActive) {
      debugPrint('⚠️ Cannot resume drill: drill is not active (active=$_isDrillActive)');
      return;
    }
    
    if (!_isDrillPaused) {
      debugPrint('⚠️ Cannot resume drill: drill is not paused (paused=$_isDrillPaused)');
      return;
    }

    try {
      debugPrint('🔄 Host resuming drill for all devices...');
      debugPrint('📊 Before resume: active=$_isDrillActive, paused=$_isDrillPaused');
      
      // Calculate paused duration
      if (_drillPauseTime != null) {
        final pauseDuration = DateTime.now().difference(_drillPauseTime!);
        _totalPausedDuration += pauseDuration;
        debugPrint('📊 Pause duration: ${pauseDuration.inMilliseconds}ms');
      }

      _isDrillPaused = false;
      _drillPauseTime = null;
      
      debugPrint('📊 After resume state change: active=$_isDrillActive, paused=$_isDrillPaused');

      // Update session status first
      await _updateSessionDrillState(_currentDrill?.id, SessionStatus.active);

      // Send drill resume message with high priority and timing data
      await _sendMessage(SyncMessage.drillResume(
        senderId: _deviceId!,
        senderName: _deviceName!,
        currentTimeMs: currentTimeMs,
        currentIndex: currentIndex,
      ));
      
      // Emit local event
      _drillEventController.add(DrillResumedEvent());
      _statusController.add('Resumed drill for all devices');
      
      debugPrint('✅ Successfully resumed drill for all devices');
    } catch (e) {
      debugPrint('❌ Failed to resume drill for all: $e');
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
    String? customStimulusItemId,
  }) async {
    if (!_isHost) {
      return; // Only host can broadcast stimuli
    }

    try {
      final stimulusData = {
        'stimulusType': stimulusType, // Fixed field name to match drill runner
        'label': label,
        'colorValue': colorValue,
        'timeMs': timeMs,
        'index': index,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'priority': 'high', // Mark stimulus messages as high priority
      };
      
      // Include custom stimulus item ID if provided
      if (customStimulusItemId != null) {
        stimulusData['customStimulusItemId'] = customStimulusItemId;
      }

      // Send stimulus message with high priority
      final message = SyncMessage.drillStimulus(
        senderId: _deviceId!,
        senderName: _deviceName!,
        stimulusData: stimulusData,
      );
      
      // Send immediately for better performance
      _sendMessage(message);
      
      debugPrint('✅ Broadcasted stimulus: $stimulusType (${label}) color=${colorValue.toRadixString(16)} at $timeMs ms${customStimulusItemId != null ? ' customItemId=$customStimulusItemId' : ''}');
    } catch (e) {
      debugPrint('❌ Failed to broadcast stimulus: $e');
    }
  }

  /// Send a chat message to all participants
  Future<void> sendChatMessage(String message) async {
    try {
      await _sendMessage(SyncMessage.chat(
        senderId: _deviceId!,
        senderName: _deviceName!,
        message: message,
      ));
      _statusController.add('Chat message sent');
    } catch (e) {
      debugPrint('❌ Failed to send chat message: $e');
      _statusController.add('Failed to send chat: $e');
    }
  }

  /// Disconnect from the current session
  Future<void> disconnect() async {
    try {
      if (_isConnected && _currentSession != null && _deviceId != null) {
        // Send leave message
        await _sendMessage(SyncMessage.participantLeave(
          senderId: _deviceId!,
          senderName: _deviceName!,
        ));

        if (_isHost) {
          // Delete session if host
          await _firestore
              .collection('multiplayer_sessions')
              .doc(_currentSession!.sessionId)
              .delete();
        } else {
          // Remove participant from session
          await _firestore
              .collection('multiplayer_sessions')
              .doc(_currentSession!.sessionId)
              .update({
            'participantIds': FieldValue.arrayRemove([_deviceId!]),
            'participantNames': FieldValue.arrayRemove([_deviceName!]),
            'fcmTokens.${_deviceId!}': FieldValue.delete(),
            'lastActivity': FieldValue.serverTimestamp(),
          });
        }
      }

      _cleanup();
      _statusController.add('Disconnected');
    } catch (e) {
      debugPrint('❌ Error during disconnect: $e');
      _cleanup();
    }
  }

  // Private methods

  void _setupFCMHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📱 FCM foreground message: ${message.data}');
      _handleFCMMessage(message.data);
    });

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 FCM background message: ${message.data}');
      _handleFCMMessage(message.data);
    });
  }

  void _handleFCMMessage(Map<String, dynamic> data) {
    try {
      if (data.containsKey('syncMessage')) {
        final messageData = jsonDecode(data['syncMessage'] as String);
        final message = SyncMessage.fromJson(messageData as Map<String, dynamic>);
        _handleIncomingMessage(message);
      }
    } catch (e) {
      debugPrint('❌ Error handling FCM message: $e');
    }
  }

  void _setupSessionListener(String sessionId) {
    _sessionSubscription = _firestore
        .collection('multiplayer_sessions')
        .doc(sessionId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        try {
          final data = snapshot.data()!;
          
          // Validate essential required fields before parsing
          if (data['sessionId'] == null ||
              data['hostId'] == null ||
              data['hostName'] == null ||
              data['createdAt'] == null) {
            debugPrint('❌ Session data missing essential required fields: $data');
            return;
          }
          
          // lastActivity can be null initially, so we'll handle it gracefully
          if (data['lastActivity'] == null) {
            debugPrint('⚠️ Session lastActivity is null, using createdAt as fallback');
            data['lastActivity'] = data['createdAt'];
          }
          
          final convertedData = _convertTimestampsForJson(data);
          _currentSession = ConnectionSession.fromJson(convertedData);
          _sessionController.add(_currentSession!);
          
          // Check for drill state changes
          _checkDrillStateFromSession(data);
        } catch (e) {
          debugPrint('❌ Error parsing session data: $e');
          debugPrint('❌ Raw session data: ${snapshot.data()}');
        }
      }
    });

    // Listen for messages
    _messagesSubscription = _firestore
        .collection('multiplayer_sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          try {
            final messageData = change.doc.data()!;
            
            // Validate essential required fields before parsing
            if (messageData['senderId'] == null ||
                messageData['senderName'] == null ||
                messageData['messageId'] == null) {
              debugPrint('❌ Message data missing essential required fields: $messageData');
              continue;
            }
            
            // Handle timestamp - can be null when using FieldValue.serverTimestamp()
            if (messageData['timestamp'] == null) {
              // Use clientTimestamp as fallback or current time
              final clientTime = messageData['clientTimestamp'];
              final fallbackTime = (clientTime is int) ? clientTime : DateTime.now().millisecondsSinceEpoch;
              messageData['timestamp'] = Timestamp.fromMillisecondsSinceEpoch(fallbackTime);
              debugPrint('⚠️ Message timestamp was null, using fallback: $fallbackTime');
            }
            
            // Convert timestamps if needed
            final convertedData = _convertTimestampsForJson(messageData);
            
            try {
              final message = SyncMessage.fromJson(convertedData);
              
              // Don't process our own messages
              if (message.senderId != _deviceId) {
                debugPrint('📨 Processing message: ${message.type.displayName} from ${message.senderName}');
                _handleIncomingMessage(message);
              } else {
                debugPrint('🔄 Skipping own message: ${message.type.displayName}');
              }
            } catch (e) {
              debugPrint('❌ Error parsing SyncMessage: $e');
              debugPrint('❌ Raw converted data: $convertedData');
            }
          } catch (e) {
            debugPrint('❌ Error processing message: $e');
            debugPrint('❌ Raw message data: ${change.doc.data()}');
          }
        }
      }
    });
  }

  void _checkDrillStateFromSession(Map<String, dynamic> sessionData) {
    final activeDrillId = sessionData['activeDrillId'] as String?;
    final status = SessionStatus.values.firstWhere(
      (s) => s.name == sessionData['status'],
      orElse: () => SessionStatus.waiting,
    );

    // Handle drill state changes for participants
    if (!_isHost) {
      if (activeDrillId != null && !_isDrillActive) {
        // Drill started by host - need to catch up
        _handleDrillCatchUp(sessionData);
      } else if (activeDrillId == null && _isDrillActive) {
        // Drill stopped by host
        _handleDrillStop();
      } else if (status == SessionStatus.paused && !_isDrillPaused) {
        // Drill paused by host - create a synthetic message for session status changes
        final syntheticPauseMessage = SyncMessage.drillPause(
          senderId: 'session',
          senderName: 'Session',
        );
        _handleDrillPause(syntheticPauseMessage);
      } else if (status == SessionStatus.active && _isDrillPaused) {
        // Drill resumed by host - create a synthetic message for session status changes
        final syntheticResumeMessage = SyncMessage.drillResume(
          senderId: 'session',
          senderName: 'Session',
        );
        _handleDrillResume(syntheticResumeMessage);
      }
    }
  }

  void _handleDrillCatchUp(Map<String, dynamic> sessionData) {
    try {
      // This handles late joiners catching up to an active drill
      final drillData = sessionData['drillData'] as Map<String, dynamic>?;
      if (drillData != null) {
        _currentDrill = _reconstructDrillFromData(drillData);
        _isDrillActive = true;
        _isDrillPaused = sessionData['status'] == 'paused';
        
        if (drillData['startTime'] != null) {
          _drillStartTime = DateTime.fromMillisecondsSinceEpoch(drillData['startTime'] as int);
        }
        
        _totalPausedDuration = Duration.zero;

        // Emit event for UI to catch up
        _drillEventController.add(DrillStartedEvent(_currentDrill!));
        _statusController.add('Caught up to active drill: ${_currentDrill!.name}');
        
        debugPrint('✅ Caught up to active drill: ${_currentDrill!.name}');
      }
    } catch (e) {
      debugPrint('❌ Error handling drill catch-up: $e');
    }
  }

  Future<void> _sendMessage(SyncMessage message) async {
    if (_currentSession == null) return;

    try {
      // Add client timestamp for better synchronization with retry logic
      final clientTimestamp = DateTime.now().millisecondsSinceEpoch;
      final messageData = {
        ...message.toJson(),
        'clientTimestamp': clientTimestamp,
        'timestamp': FieldValue.serverTimestamp(),
        'priority': message.type.isDrillControl ? 'high' : 'normal',
      };
      
      // Store message in Firestore
      await _firestore
          .collection('multiplayer_sessions')
          .doc(_currentSession!.sessionId)
          .collection('messages')
          .add(messageData);

      // Send FCM notifications to all participants for immediate delivery
      await _sendFCMNotifications(message);
      
      debugPrint('✅ Sent message: ${message.type.name} with timestamp');
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');
      throw e;
    }
  }

  Future<void> _sendFCMNotifications(SyncMessage message) async {
    if (_currentSession == null) return;

    try {
      // Get FCM tokens from session
      final sessionDoc = await _firestore
          .collection('multiplayer_sessions')
          .doc(_currentSession!.sessionId)
          .get();

      if (!sessionDoc.exists) return;

      final fcmTokens = sessionDoc.data()!['fcmTokens'] as Map<String, dynamic>?;
      if (fcmTokens == null) return;

      // Send to all participants except sender
      for (final entry in fcmTokens.entries) {
        if (entry.key != _deviceId && entry.value != null) {
          // Handle both String tokens and Map objects with token field
          String? token;
          if (entry.value is String) {
            token = entry.value as String;
          } else if (entry.value is Map<String, dynamic>) {
            token = (entry.value as Map<String, dynamic>)['token'] as String?;
          }
          
          if (token != null && token.isNotEmpty) {
            await _sendFCMToToken(token, message);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to send FCM notifications: $e');
    }
  }

  Future<void> _sendFCMToToken(String token, SyncMessage message) async {
    // Note: In a production app, you would use Firebase Cloud Functions
    // to send FCM messages. For the free tier, we rely on Firestore listeners
    // and local FCM handling. This is a placeholder for the FCM sending logic.
    debugPrint('📤 Would send FCM to token: $token for message: ${message.type.displayName}');
  }

  void _handleIncomingMessage(SyncMessage message) {
    debugPrint('📨 Handling sync message: ${message.type.displayName}');
    
    switch (message.type) {
      case SyncMessageType.drillStart:
        _handleDrillStart(message);
        break;
      case SyncMessageType.drillStop:
        _handleDrillStop();
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
        break;
    }
  }

  void _handleDrillStart(SyncMessage message) {
    if (_isHost) return; // Host doesn't need to handle their own messages
    
    try {
      final drillData = message.drillData;
      if (drillData == null) return;

      _currentDrill = _reconstructDrillFromData(drillData);
      _isDrillActive = true;
      _isDrillPaused = false;
      
      if (drillData['startTime'] != null) {
        _drillStartTime = DateTime.fromMillisecondsSinceEpoch(drillData['startTime'] as int);
      }
      
      _totalPausedDuration = Duration.zero;

      _drillEventController.add(DrillStartedEvent(_currentDrill!));
      _statusController.add('Drill started: ${_currentDrill!.name}');
      
      debugPrint('✅ Received drill start: ${_currentDrill!.name}');
    } catch (e) {
      debugPrint('❌ Error handling drill start: $e');
      _statusController.add('Error starting drill: $e');
    }
  }

  void _handleDrillStop() {
    if (_isHost) return;
    
    try {
      Duration? sessionDuration;
      if (_drillStartTime != null) {
        final endTime = DateTime.now();
        sessionDuration = endTime.difference(_drillStartTime!) - _totalPausedDuration;
      }

      _drillEventController.add(DrillStoppedEvent());
      
      _resetDrillState();
      _statusController.add('Drill stopped by host');
      
      debugPrint('✅ Received drill stop');
    } catch (e) {
      debugPrint('❌ Error handling drill stop: $e');
      _statusController.add('Error stopping drill: $e');
    }
  }

  void _handleDrillPause(SyncMessage message) {
    if (_isHost) return;
    
    try {
      _isDrillPaused = true;
      _drillPauseTime = DateTime.now();

      // Extract timing data from message
      final currentTimeMs = message.data['currentTimeMs'] as int?;
      final currentIndex = message.data['currentIndex'] as int?;

      _drillEventController.add(DrillPausedEvent(
        currentTimeMs: currentTimeMs,
        currentIndex: currentIndex,
      ));
      _statusController.add('Drill paused by host');
      
      debugPrint('✅ Received drill pause${currentTimeMs != null ? ' at ${currentTimeMs}ms' : ''}${currentIndex != null ? ' index $currentIndex' : ''}');
    } catch (e) {
      debugPrint('❌ Error handling drill pause: $e');
      _statusController.add('Error pausing drill: $e');
    }
  }

  void _handleDrillResume(SyncMessage message) {
    if (_isHost) return;
    
    try {
      if (_drillPauseTime != null) {
        final pauseDuration = DateTime.now().difference(_drillPauseTime!);
        _totalPausedDuration += pauseDuration;
      }

      _isDrillPaused = false;
      _drillPauseTime = null;

      // Extract timing data from message
      final currentTimeMs = message.data['currentTimeMs'] as int?;
      final currentIndex = message.data['currentIndex'] as int?;

      _drillEventController.add(DrillResumedEvent(
        currentTimeMs: currentTimeMs,
        currentIndex: currentIndex,
      ));
      _statusController.add('Drill resumed by host');
      
      debugPrint('✅ Received drill resume${currentTimeMs != null ? ' at ${currentTimeMs}ms' : ''}${currentIndex != null ? ' index $currentIndex' : ''}');
    } catch (e) {
      debugPrint('❌ Error handling drill resume: $e');
      _statusController.add('Error resuming drill: $e');
    }
  }

  void _handleDrillStimulus(SyncMessage message) {
    try {
      final stimulusData = message.data['stimulusData'] as Map<String, dynamic>?;
      if (stimulusData == null) return;

      _drillEventController.add(StimulusEvent(stimulusData));
      
      debugPrint('✅ Received stimulus: ${stimulusData['type']} at ${stimulusData['timeMs']}ms');
    } catch (e) {
      debugPrint('❌ Error handling drill stimulus: $e');
    }
  }

  void _handleChatMessage(SyncMessage message) {
    final chatText = message.chatMessage;
    if (chatText != null) {
      _drillEventController.add(ChatReceivedEvent(
        message.senderName,
        chatText,
      ));
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
      sets: data['sets'] as int? ?? 1,
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
      drillMode: DrillMode.values.firstWhere(
        (m) => m.name == data['drillMode'],
        orElse: () => DrillMode.timed,
      ),
      presentationMode: PresentationMode.values.firstWhere(
        (m) => m.name == data['presentationMode'],
        orElse: () => PresentationMode.visual,
      ),
      stimulusLengthMs: data['stimulusLengthMs'] as int? ?? 1000,
      delayBetweenStimuliMs: data['delayBetweenStimuliMs'] as int? ?? 2000,
      customStimuliIds: (data['customStimuliIds'] as List<dynamic>?)?.cast<String>() ?? [],
      sharedWith: [],
      createdAt: DateTime.now(),
    );
  }

  Future<void> _updateSessionDrillState(String? drillId, SessionStatus status) async {
    if (_currentSession == null) return;

    try {
      final now = DateTime.now();
      final updateData = <String, dynamic>{
        'activeDrillId': drillId,
        'status': status.name,
        'lastActivity': FieldValue.serverTimestamp(),
        'clientLastActivity': now.toIso8601String(),
        'statusUpdatedAt': now.millisecondsSinceEpoch,
      };

      // Include drill data if starting a drill
      if (drillId != null && _currentDrill != null) {
        updateData['drillData'] = {
          'id': _currentDrill!.id,
          'name': _currentDrill!.name,
          'category': _currentDrill!.category,
          'difficulty': _currentDrill!.difficulty.name,
          'durationSec': _currentDrill!.durationSec,
          'restSec': _currentDrill!.restSec,
          'reps': _currentDrill!.reps,
          'sets': _currentDrill!.sets,
          'stimulusTypes': _currentDrill!.stimulusTypes.map((e) => e.name).toList(),
          'numberOfStimuli': _currentDrill!.numberOfStimuli,
          'zones': _currentDrill!.zones.map((e) => e.name).toList(),
          'colors': _currentDrill!.colors.map((c) => c.value).toList(),
          'drillMode': _currentDrill!.drillMode.name,
          'presentationMode': _currentDrill!.presentationMode.name,
          'stimulusLengthMs': _currentDrill!.stimulusLengthMs,
          'delayBetweenStimuliMs': _currentDrill!.delayBetweenStimuliMs,
          'customStimuliIds': _currentDrill!.customStimuliIds,
          'startTime': _drillStartTime?.millisecondsSinceEpoch,
          // Add custom stimuli metadata for proper participant sync
          'hasCustomStimuli': _currentDrill!.customStimuliIds.isNotEmpty,
          'customStimuliCount': _currentDrill!.customStimuliIds.length,
        };
      }

      await _firestore
          .collection('multiplayer_sessions')
          .doc(_currentSession!.sessionId)
          .update(updateData);
    } catch (e) {
      debugPrint('❌ Failed to update session drill state: $e');
      throw e;
    }
  }

  String _generateSessionCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'android_${androidInfo.id}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'ios_${iosInfo.identifierForVendor}';
      }
    } catch (e) {
      debugPrint('❌ Failed to get device ID: $e');
    }
    // Fallback to random ID
    return 'device_${Random().nextInt(999999).toString().padLeft(6, '0')}';
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name}';
      }
    } catch (e) {
      debugPrint('❌ Failed to get device name: $e');
    }
    return 'Unknown Device';
  }

  void _resetDrillState() {
    _currentDrill = null;
    _isDrillActive = false;
    _isDrillPaused = false;
    _drillStartTime = null;
    _drillPauseTime = null;
    _totalPausedDuration = Duration.zero;
  }

  void _cleanup() {
    _sessionSubscription?.cancel();
    _messagesSubscription?.cancel();
    _currentSession = null;
    _isHost = false;
    _isConnected = false;
    _resetDrillState();
  }

  /// Helper method to convert Firestore Timestamps to ISO strings for JSON parsing
  Map<String, dynamic> _convertTimestampsForJson(Map<String, dynamic> data) {
    final convertedData = Map<String, dynamic>.from(data);
    
    // Recursively convert all Timestamp fields to ISO strings
    _convertTimestampsRecursively(convertedData);
    
    return convertedData;
  }
  
  /// Recursively converts Timestamp objects to ISO strings in nested maps and lists
  void _convertTimestampsRecursively(dynamic data) {
    if (data is Map<String, dynamic>) {
      data.forEach((key, value) {
        if (value is Timestamp) {
          try {
            data[key] = value.toDate().toIso8601String();
          } catch (e) {
            debugPrint('⚠️ Error converting timestamp for key $key: $e');
            // Use current time as fallback
            data[key] = DateTime.now().toIso8601String();
          }
        } else if (value == null && key == 'timestamp') {
          // Only handle null timestamp for message data, not drill or session data
          debugPrint('⚠️ Null timestamp field detected, using current time');
          data[key] = DateTime.now().toIso8601String();
        } else if (value is Map<String, dynamic>) {
          _convertTimestampsRecursively(value);
        } else if (value is List) {
         _convertTimestampsRecursively(value);
       }
      });
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        if (data[i] is Timestamp) {
          data[i] = (data[i] as Timestamp).toDate().toIso8601String();
        } else if (data[i] is Map<String, dynamic>) {
          _convertTimestampsRecursively(data[i]);
        } else if (data[i] is List) {
          _convertTimestampsRecursively(data[i]);
        }
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _cleanup();
    _drillEventController.close();
    _statusController.close();
    _sessionController.close();
  }
}