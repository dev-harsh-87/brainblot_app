import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:spark_app/features/multiplayer/domain/connection_session.dart';
import 'package:spark_app/features/multiplayer/domain/sync_message.dart';
import 'package:spark_app/features/multiplayer/services/professional_permission_manager.dart';

/// Robust, null-safe and more predictable Bluetooth P2P manager for Spark.
///
/// Changes and improvements made:
/// * Better permission handling and clearer status messages.
/// * Advertising includes the session code so discovery can filter endpoints.
/// * `joinSession` returns a Future that completes when connected (or fails).
/// * Concurrency when sending messages to multiple devices (uses Future.wait).
/// * Safer lifecycle handling and improved error logging.
/// * Fixed several small logic/precedence bugs.
class BluetoothConnectionService {
  static const String _serviceId = 'com.brainblot.multiplayer';
  static const Strategy _strategy = Strategy.P2P_STAR;

  final StreamController<ConnectionSession> _sessionController =
  StreamController<ConnectionSession>.broadcast();
  final StreamController<SyncMessage> _messageController =
  StreamController<SyncMessage>.broadcast();
  final StreamController<String> _connectionStatusController =
  StreamController<String>.broadcast();

  ConnectionSession? _currentSession;
  String? _deviceId;
  String? _deviceName;
  bool _isHost = false;
  bool _isConnected = false;
  Timer? _heartbeatTimer;

  Completer<ConnectionSession>? _joinCompleter;
  String? _advertisedSessionCode;

  /// Streams
  Stream<ConnectionSession> get sessionStream => _sessionController.stream;
  Stream<SyncMessage> get messageStream => _messageController.stream;
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;

  ConnectionSession? get currentSession => _currentSession;
  bool get isHost => _isHost;
  bool get isConnected => _isConnected;
  String? get deviceId => _deviceId;

  /// Initialize the service. MUST be called before starting or joining sessions.
  Future<void> initialize() async {
    try {
      _deviceId = _generateDeviceId();
      _deviceName = await _getDeviceName();
      debugPrint('BluetoothConnectionService initialized: $_deviceId ($_deviceName)');
      
      // Don't automatically request permissions during initialization
      // Let the user trigger permission requests when they actually need multiplayer features
      debugPrint('🔄 Service initialized - permissions will be requested when needed');
      _connectionStatusController.add('Bluetooth service ready - permissions required for multiplayer');
      
    } catch (e) {
      debugPrint('Failed to initialize BluetoothConnectionService: $e');
      // Still allow the service to be created, just mark it as not ready
      _connectionStatusController.add('Bluetooth service initialization failed');
    }
  }

  /// Request necessary permissions for Bluetooth and location.
  /// Returns true if all required permissions are granted.
  Future<bool> requestPermissions() async {
    try {
      debugPrint('🔐 Using Professional Permission Manager');
      
      final result = await ProfessionalPermissionManager.requestPermissions();
      
      _connectionStatusController.add(result.message);
      
      if (result.success) {
        debugPrint('✅ All permissions granted via Professional Permission Manager');
      } else {
        debugPrint('❌ Permission request failed: ${result.message}');
        
        if (result.needsSettings) {
          _connectionStatusController.add(
            'Some permissions are permanently denied. Please enable them in Settings.',
          );
        }
      }
      
      return result.success;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      _connectionStatusController.add('Permission error: $e. Please try again or enable permissions manually.');
      return false;
    }
  }


  Future<void> openPermissionSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('Failed to open app settings: $e');
    }
  }

  Future<bool> arePermissionsAvailable() async {
    try {
      final List<Permission> permissions = [];
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        permissions.addAll([
          Permission.bluetooth,
          Permission.locationWhenInUse,
        ]);
      } else {
        permissions.addAll([
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.locationWhenInUse,
          Permission.nearbyWifiDevices,
        ]);
      }

      final statuses = await Future.wait(permissions.map((p) => p.status));
      return !statuses.any((s) => s == PermissionStatus.permanentlyDenied);
    } catch (e) {
      debugPrint('Error checking permission availability: $e');
      return false;
    }
  }

  /// Host a new session. Returns the created session object.
  Future<ConnectionSession> createHostSession({
    int maxParticipants = 8,
  }) async {
    debugPrint('🔗 Creating host session...');
    
    if (_deviceId == null || _deviceName == null) {
      debugPrint('🔗 ❌ Service not initialized');
      throw Exception('Bluetooth service not initialized. Please restart the app.');
    }

    debugPrint('🔗 Checking permissions...');
    final hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      debugPrint('🔗 ❌ Permissions not granted');
      throw Exception('Required permissions not granted. Please enable Bluetooth and Location permissions.');
    }

    debugPrint('🔗 Generating session code...');
    final sessionId = _generateSessionCode();
    
    // Validate session code format
    if (sessionId.length != 6 || !RegExp(r'^\d{6}$').hasMatch(sessionId)) {
      debugPrint('🔗 ❌ Invalid session code generated: $sessionId');
      throw Exception('Failed to generate valid session code');
    }
    
    debugPrint('🔗 ✅ Session code generated: $sessionId');

    _currentSession = ConnectionSession.createHost(
      sessionId: sessionId,
      hostId: _deviceId!,
      hostName: _deviceName!,
      maxParticipants: maxParticipants,
    );

    _isHost = true;
    _isConnected = true;
    _advertisedSessionCode = sessionId;

    try {
      debugPrint('🔗 Starting advertising...');
      await _startAdvertising(sessionId);
      _startHeartbeat();
      
      debugPrint('🔗 ✅ Host session created successfully: $sessionId');
      _connectionStatusController.add('Hosting session: $sessionId');
      _sessionController.add(_currentSession!);

      return _currentSession!;
    } catch (e) {
      debugPrint('🔗 ❌ Failed to start advertising: $e');
      // Clean up on failure
      _isHost = false;
      _isConnected = false;
      _advertisedSessionCode = null;
      _currentSession = null;
      throw Exception('Failed to start hosting session: $e');
    }
  }

  /// Join an existing session by session code. Completes when connected or throws.
  Future<ConnectionSession> joinSession(String sessionCode,
      {Duration timeout = const Duration(seconds: 30),}) async {
    if (_deviceId == null || _deviceName == null) {
      throw Exception('Service not initialized. Please restart the app.');
    }

    // Validate session code format
    if (sessionCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(sessionCode)) {
      throw Exception('Invalid session code format. Please enter a 6-digit code.');
    }

    debugPrint('🔗 Attempting to join session: $sessionCode');
    
    final hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      throw Exception('Required permissions not granted. Please enable Bluetooth and Location permissions.');
    }

    // Clean up any previous state
    await _cleanupPreviousConnection();

    _isHost = false;
    _joinCompleter = Completer<ConnectionSession>();

    _connectionStatusController.add('Searching for session: $sessionCode...');
    debugPrint('🔍 Starting discovery for session: $sessionCode');

    try {
      // Start discovery and wait for a matching endpoint to connect.
      await _startDiscovery(sessionCode);

      // Fail-fast on timeout with better error message.
      final result = await _joinCompleter!.future.timeout(timeout, onTimeout: () async {
        debugPrint('⏰ Join session timeout for: $sessionCode');
        
        // Stop discovery if timed out
        try {
          await Nearby().stopDiscovery();
          debugPrint('🛑 Discovery stopped due to timeout');
        } catch (e) {
          debugPrint('❌ Error stopping discovery on timeout: $e');
        }
        
        if (!_joinCompleter!.isCompleted) {
          _joinCompleter!.completeError(Exception('Session $sessionCode not found. Make sure:\n• The host is nearby and advertising\n• The session code is correct\n• Both devices have Bluetooth enabled'));
        }
        throw Exception('Session $sessionCode not found. Make sure:\n• The host is nearby and advertising\n• The session code is correct\n• Both devices have Bluetooth enabled');
      },);

      debugPrint('✅ Successfully joined session: $sessionCode');
      return result;
    } catch (e) {
      debugPrint('❌ Failed to join session $sessionCode: $e');
      
      // Clean up on any error
      try {
        await Nearby().stopDiscovery();
      } catch (cleanupError) {
        debugPrint('❌ Error during cleanup: $cleanupError');
      }
      
      // Reset state
      _isHost = false;
      _isConnected = false;
      _joinCompleter = null;
      
      rethrow;
    }
  }

  /// Clean up any previous connection state
  Future<void> _cleanupPreviousConnection() async {
    try {
      if (_isConnected) {
        await disconnect();
      }
      await Nearby().stopDiscovery();
      await Nearby().stopAdvertising();
    } catch (e) {
      debugPrint('Cleanup error (non-critical): $e');
    }
  }

  Future<void> sendMessage(SyncMessage message) async {
    if (!_isConnected || _currentSession == null) throw Exception('Not connected to a session');

    final messageJson = jsonEncode(message.toJson());
    final bytes = Uint8List.fromList(messageJson.codeUnits);

    try {
      if (message.isBroadcast) {
        if (_isHost) {
          // Host -> all participants
          final futures = <Future>[];
          for (final participantId in _currentSession!.participantIds) {
            futures.add(Nearby().sendBytesPayload(participantId, bytes));
          }
          await Future.wait(futures);
        } else {
          // Participant -> host
          await Nearby().sendBytesPayload(_currentSession!.hostId, bytes);
        }
      } else if (message.targetId != null) {
        await Nearby().sendBytesPayload(message.targetId!, bytes);
      }

      debugPrint('Message sent: ${message.type.displayName}');
    } catch (e) {
      debugPrint('Failed to send message: $e');
      _connectionStatusController.add('Message send failed: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      if (_isConnected && _currentSession != null && _deviceId != null && _deviceName != null) {
        final leaveMessage = SyncMessage.participantLeave(
          senderId: _deviceId!,
          senderName: _deviceName!,
        );
        // best-effort send
        try {
          await sendMessage(leaveMessage);
        } catch (_) {}
      }

      await _stopServices();

      _currentSession = null;
      _isHost = false;
      _isConnected = false;

      _connectionStatusController.add('Disconnected');
    } catch (e) {
      debugPrint('Error during disconnect: $e');
    }
  }

  Future<void> startDrillForAll(String drillId, Map<String, dynamic> drillData) async {
    _validateDrillControlPermissions('start');

    try {
      // Update local session state first
      _currentSession = _currentSession?.setActiveDrill(drillId);
      if (_currentSession != null) {
        _sessionController.add(_currentSession!);
      }

      final message = SyncMessage.drillStart(
        senderId: _deviceId!,
        senderName: _deviceName!,
        drillId: drillId,
        drillData: drillData,
      );

      // Send to all participants
      await sendMessage(message);

      _connectionStatusController.add('Drill "$drillId" started for all participants');
      debugPrint('✅ Drill started for all participants: $drillId');
      
      // Send a follow-up session status update to ensure synchronization
      await _sendSessionStatusUpdate();
      
    } catch (e) {
      debugPrint('❌ Failed to start drill for all: $e');
      _connectionStatusController.add('Failed to start drill: $e');
      // Revert local state on failure
      _currentSession = _currentSession?.setActiveDrill(null);
      if (_currentSession != null) {
        _sessionController.add(_currentSession!);
      }
      rethrow;
    }
  }

  Future<void> stopDrillForAll() async {
    _validateDrillControlPermissions('stop');

    try {
      // Update local session state first
      final previousDrillId = _currentSession!.activeDrillId;
      _currentSession = _currentSession?.setActiveDrill(null);
      if (_currentSession != null) {
        _sessionController.add(_currentSession!);
      }

      final message = SyncMessage.drillStop(
        senderId: _deviceId!,
        senderName: _deviceName!,
      );

      // Send to all participants
      await sendMessage(message);

      _connectionStatusController.add('Drill stopped for all participants');
      debugPrint('✅ Drill stopped for all participants: $previousDrillId');
      
      // Send a follow-up session status update to ensure synchronization
      await _sendSessionStatusUpdate();
      
    } catch (e) {
      debugPrint('❌ Failed to stop drill for all: $e');
      _connectionStatusController.add('Failed to stop drill: $e');
      rethrow;
    }
  }

  Future<void> pauseDrillForAll() async {
    _validateDrillControlPermissions('pause');

    try {
      final message = SyncMessage.drillPause(
        senderId: _deviceId!,
        senderName: _deviceName!,
      );

      await sendMessage(message);
      _connectionStatusController.add('Drill paused for all participants');
      
      debugPrint('✅ Drill paused for all participants');
    } catch (e) {
      debugPrint('❌ Failed to pause drill for all: $e');
      _connectionStatusController.add('Failed to pause drill: $e');
      rethrow;
    }
  }

  Future<void> resumeDrillForAll() async {
    _validateDrillControlPermissions('resume');

    try {
      final message = SyncMessage.drillResume(
        senderId: _deviceId!,
        senderName: _deviceName!,
      );

      await sendMessage(message);
      _connectionStatusController.add('Drill resumed for all participants');
      
      debugPrint('✅ Drill resumed for all participants');
    } catch (e) {
      debugPrint('❌ Failed to resume drill for all: $e');
      _connectionStatusController.add('Failed to resume drill: $e');
      rethrow;
    }
  }

  Future<void> sendChatMessage(String message) async {
    final chatMessage = SyncMessage.chat(
      senderId: _deviceId!,
      senderName: _deviceName!,
      message: message,
    );

    await sendMessage(chatMessage);
  }

  /// Checks if the current device can control drills (only host can)
  bool get canControlDrills => _isHost;

  /// Helper method to validate drill control permissions
  void _validateDrillControlPermissions(String action) {
    if (!_isHost) {
      throw Exception('Access denied: Only the session host can $action drills. Participants automatically follow the host\'s drill state.');
    }
    if (!_isConnected || _currentSession == null) {
      throw Exception('Not connected to a session. Please join or create a session first.');
    }
  }

  /// Debug method to print current connection state
  void debugConnectionState() {
    debugPrint('🔍 CONNECTION STATE DEBUG:');
    debugPrint('   Device ID: $_deviceId');
    debugPrint('   Device Name: $_deviceName');
    debugPrint('   Is Host: $_isHost');
    debugPrint('   Is Connected: $_isConnected');
    debugPrint('   Current Session: ${_currentSession?.sessionId ?? 'null'}');
    debugPrint('   Join Completer: ${_joinCompleter != null ? 'active' : 'null'}');
    debugPrint('   Advertised Session Code: $_advertisedSessionCode');
    debugPrint('   Service ID: $_serviceId');
    debugPrint('   Strategy: $_strategy');
  }

  // Private methods

  Future<void> _startAdvertising(String sessionCode) async {
    try {
      // Include session code in the advertised name so participants can find the right session
      final advertisingName = '$_deviceName-$sessionCode';
      
      await Nearby().startAdvertising(
        advertisingName,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );

      debugPrint('Started advertising as host with session code: $sessionCode');
    } catch (e) {
      debugPrint('Failed to start advertising: $e');
      rethrow;
    }
  }

  Future<void> _startDiscovery(String sessionCode) async {
    try {
      debugPrint('🔍 Starting discovery with:');
      debugPrint('   Device Name: $_deviceName');
      debugPrint('   Strategy: $_strategy');
      debugPrint('   Service ID: $_serviceId');
      debugPrint('   Looking for session: $sessionCode');
      debugPrint('   Expected advertised name format: DeviceName-$sessionCode');
      
      await Nearby().startDiscovery(
        _deviceName!,
        _strategy,
        onEndpointFound: (id, name, serviceId) => _onEndpointFound(id, name, serviceId, sessionCode),
        onEndpointLost: _onEndpointLost,
        serviceId: _serviceId,
      );

      debugPrint('✅ Discovery started successfully for session: $sessionCode');
      _connectionStatusController.add('Scanning for nearby sessions...');
      
      // Add a timer to provide periodic updates about discovery status
      Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!_isConnected && _joinCompleter != null && !_joinCompleter!.isCompleted) {
          debugPrint('🔍 Still searching for session $sessionCode... (${timer.tick * 5}s elapsed)');
          _connectionStatusController.add('Still searching for session $sessionCode... Make sure the host is nearby and advertising.');
        } else {
          timer.cancel();
        }
      });
      
    } catch (e) {
      debugPrint('❌ Failed to start discovery: $e');
      _connectionStatusController.add('Failed to start scanning: $e');
      rethrow;
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    debugPrint('Connection initiated with: $endpointId (${info.endpointName})');

    // Auto-accept connections for now (in production, you might want to show a dialog)
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    debugPrint('🔗 Connection result: $endpointId - ${status.toString()}');

    if (status == Status.CONNECTED) {
      debugPrint('✅ Successfully connected to endpoint: $endpointId');
      
      if (_isHost) {
        // Add participant to session
        final nextIndex = (_currentSession?.participantIds.length ?? 0) + 1;
        _addParticipant(endpointId, 'Participant $nextIndex');
        debugPrint('👥 Added participant $nextIndex to session');
      } else {
        _isConnected = true;
        
        // Stop discovery since we're now connected
        try {
          Nearby().stopDiscovery();
          debugPrint('🛑 Discovery stopped after successful connection');
        } catch (e) {
          debugPrint('⚠️ Error stopping discovery: $e');
        }
        
        // Create a participant session
        _currentSession = ConnectionSession.createHost(
          sessionId: _advertisedSessionCode ?? _generateSessionCode(),
          hostId: endpointId, // Use the host's endpoint ID
          hostName: 'Host',
        );
        _sessionController.add(_currentSession!);
        _connectionStatusController.add('✅ Connected to session $_advertisedSessionCode');
        
        // Complete the join operation
        if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
          debugPrint('✅ Join operation completed successfully');
          _joinCompleter!.complete(_currentSession!);
        }
      }
    } else {
      // Connection failed
      debugPrint('❌ Connection failed: ${status.toString()}');
      
      if (!_isHost && _joinCompleter != null && !_joinCompleter!.isCompleted) {
        String errorMessage = 'Failed to connect to session';
        
        // Provide user-friendly error messages based on status
        if (status.toString().contains('REJECTED')) {
          errorMessage = 'Connection was rejected by the host';
        } else if (status.toString().contains('ALREADY_CONNECTED')) {
          errorMessage = 'Already connected to this session';
        } else if (status.toString().contains('BLUETOOTH')) {
          errorMessage = 'Bluetooth error occurred. Please check your Bluetooth settings';
        } else if (status.toString().contains('TIMEOUT')) {
          errorMessage = 'Connection timed out. Please try again';
        } else {
          errorMessage = 'Connection failed: ${status.toString()}. Please try again';
        }
        
        _connectionStatusController.add('❌ $errorMessage');
        _joinCompleter!.completeError(Exception(errorMessage));
      }
    }
  }

  void _onDisconnected(String endpointId) {
    debugPrint('Disconnected from: $endpointId');

    if (_isHost) {
      _removeParticipant(endpointId);
    } else {
      _isConnected = false;
      _connectionStatusController.add('Disconnected from session');
    }
  }

  void _onEndpointFound(String endpointId, String name, String serviceId, String sessionCode) {
    debugPrint('🔍 Found endpoint: $endpointId - $name (serviceId: $serviceId)');

    // Validate service ID first
    if (serviceId != _serviceId) {
      debugPrint('❌ Service ID mismatch: expected $_serviceId, got $serviceId');
      return;
    }

    // Check if this endpoint matches our target session code
    // The advertised name format is: "DeviceName-SessionCode"
    if (name.contains('-$sessionCode')) {
      debugPrint('✅ Found matching session: $name for code $sessionCode');
      _advertisedSessionCode = sessionCode;
      
      _connectionStatusController.add('Found session $sessionCode, connecting...');
      
      // Request connection
      try {
        Nearby().requestConnection(
          _deviceName!,
          endpointId,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: _onConnectionResult,
          onDisconnected: _onDisconnected,
        );
        debugPrint('🔗 Connection requested to endpoint: $endpointId');
      } catch (e) {
        debugPrint('❌ Failed to request connection: $e');
        if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
          _joinCompleter!.completeError(Exception('Failed to connect to session: $e'));
        }
      }
    } else {
      debugPrint('❌ Session code mismatch: looking for $sessionCode, found $name');
      debugPrint('   Expected format: DeviceName-$sessionCode');
    }
  }

  void _onEndpointLost(String? endpointId) {
    debugPrint('📡 Lost endpoint: $endpointId');
    if (!_isConnected && _joinCompleter != null && !_joinCompleter!.isCompleted) {
      _connectionStatusController.add('Lost connection to a nearby device. Still searching...');
    }
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    try {
      if (payload.type == PayloadType.BYTES) {
        final messageJson = String.fromCharCodes(payload.bytes!);
        final messageData = jsonDecode(messageJson) as Map<String, dynamic>;
        final message = SyncMessage.fromJson(messageData);

        _handleIncomingMessage(message, endpointId);
      }
    } catch (e) {
      debugPrint('Error processing payload: $e');
    }
  }

  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    // Handle payload transfer updates if needed
    debugPrint('Payload transfer update: $endpointId - ${update.status}');
  }

  void _handleIncomingMessage(SyncMessage message, String fromEndpointId) {
    debugPrint('Received message: ${message.type.displayName} from ${message.senderName}');

    switch (message.type) {
      case SyncMessageType.participantJoin:
        if (_isHost) _addParticipant(fromEndpointId, message.senderName);
        break;
      case SyncMessageType.participantLeave:
        if (_isHost) _removeParticipant(fromEndpointId);
        break;
      case SyncMessageType.drillStart:
        // Handle drill start - update session state and forward to UI
        if (message.data.containsKey('drillId')) {
          final drillId = message.data['drillId'] as String?;
          if (drillId != null) {
            _currentSession = _currentSession?.setActiveDrill(drillId);
            if (_currentSession != null) {
              _sessionController.add(_currentSession!);
            }
          }
        }
        _messageController.add(message);
        _connectionStatusController.add('Drill started: ${message.data['drillId'] ?? 'Unknown'}');
        break;
      case SyncMessageType.drillStop:
        // Handle drill stop - clear active drill and forward to UI
        _currentSession = _currentSession?.setActiveDrill(null);
        if (_currentSession != null) {
          _sessionController.add(_currentSession!);
        }
        _messageController.add(message);
        _connectionStatusController.add('Drill stopped');
        break;
      case SyncMessageType.drillPause:
        // Forward drill pause messages to UI
        _messageController.add(message);
        _connectionStatusController.add('Drill paused');
        break;
      case SyncMessageType.drillResume:
        // Forward drill resume messages to UI
        _messageController.add(message);
        _connectionStatusController.add('Drill resumed');
        break;
      case SyncMessageType.drillContent:
        // Forward drill content messages to UI
        _messageController.add(message);
        break;
      case SyncMessageType.drillStimulus:
        // Forward drill stimulus messages to UI
        _messageController.add(message);
        break;
      case SyncMessageType.drillScoreUpdate:
        // Forward drill score update messages to UI
        _messageController.add(message);
        break;
      case SyncMessageType.drillRepComplete:
        // Forward drill rep complete messages to UI
        _messageController.add(message);
        break;
      case SyncMessageType.chat:
        // Forward chat messages to UI
        _messageController.add(message);
        break;
      case SyncMessageType.heartbeat:
        // Handle heartbeat - update last activity
        if (_currentSession != null) {
          _currentSession = _currentSession!.copyWith(lastActivity: DateTime.now());
          _sessionController.add(_currentSession!);
        }
        break;
      case SyncMessageType.sessionStatus:
        // Handle session status updates from host
        if (!_isHost) {
          try {
            final sessionData = message.data;
            if (sessionData.isNotEmpty) {
              // Update session from received data
              _updateSessionFromData(sessionData);
              debugPrint('✅ Session status updated from host');
            }
          } catch (e) {
            debugPrint('❌ Error handling session status: $e');
          }
        }
        break;
    }
  }

  void _updateSessionFromData(Map<String, dynamic> sessionData) {
    try {
      if (_currentSession != null) {
        // Extract data from the session update
        final activeDrillId = sessionData['activeDrillId'] as String?;
        final participantCount = sessionData['participantCount'] as int?;
        
        // Update session with new data
        _currentSession = _currentSession!.copyWith(
          activeDrillId: activeDrillId,
          lastActivity: DateTime.now(),
          status: activeDrillId != null ? SessionStatus.active : SessionStatus.waiting,
        );
        
        _sessionController.add(_currentSession!);
        
        // Update connection status based on drill state
        if (activeDrillId != null) {
          _connectionStatusController.add('Drill "$activeDrillId" is active');
        } else {
          _connectionStatusController.add('No active drill - waiting');
        }
        
        debugPrint('✅ Session updated: activeDrill=$activeDrillId, participants=$participantCount');
      }
    } catch (e) {
      debugPrint('❌ Error updating session from data: $e');
    }
  }

  void _addParticipant(String participantId, String participantName) {
    if (_currentSession != null && !_currentSession!.participantIds.contains(participantId)) {
      _currentSession = _currentSession!.addParticipant(participantId, participantName);
      _sessionController.add(_currentSession!);

      // Send join message to other participants
      final joinMessage = SyncMessage.participantJoin(
        senderId: participantId,
        senderName: participantName,
      );
      // Fire and forget - don't await to avoid blocking
      sendMessage(joinMessage).catchError((e) {
        debugPrint('Failed to send join message: $e');
      });
      
      _connectionStatusController.add('$participantName joined the session');
    }
  }

  void _removeParticipant(String participantId) {
    if (_currentSession != null) {
      final index = _currentSession!.participantIds.indexOf(participantId);
      if (index != -1) {
        final participantName = _currentSession!.participantNames[index];
        _currentSession = _currentSession!.removeParticipant(participantId);
        _sessionController.add(_currentSession!);

        // Send leave message to other participants
        final leaveMessage = SyncMessage.participantLeave(
          senderId: participantId,
          senderName: participantName,
        );
        // Fire and forget - don't await to avoid blocking
        sendMessage(leaveMessage).catchError((e) {
          debugPrint('Failed to send leave message: $e');
        });
        
        _connectionStatusController.add('$participantName left the session');
      }
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _deviceId != null && _deviceName != null) {
        final heartbeat = SyncMessage.heartbeat(
          senderId: _deviceId!,
          senderName: _deviceName!,
        );
        // Fire and forget - don't await to avoid blocking the timer
        sendMessage(heartbeat).catchError((e) {
          debugPrint('Failed to send heartbeat: $e');
        });
      }
    });
  }

  Future<void> _sendSessionStatusUpdate() async {
    if (!_isHost || _currentSession == null || _deviceId == null || _deviceName == null) {
      return;
    }

    try {
      final sessionData = <String, dynamic>{
        'sessionId': _currentSession!.sessionId,
        'activeDrillId': _currentSession!.activeDrillId,
        'participantCount': _currentSession!.participantIds.length,
        'lastActivity': _currentSession!.lastActivity.toIso8601String(),
      };

      final message = SyncMessage.sessionStatus(
        senderId: _deviceId!,
        senderName: _deviceName!,
        sessionData: sessionData,
      );

      await sendMessage(message);
      debugPrint('✅ Session status update sent');
    } catch (e) {
      debugPrint('❌ Failed to send session status update: $e');
    }
  }

  Future<void> _stopServices() async {
    try {
      _heartbeatTimer?.cancel();
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
      debugPrint('All Nearby services stopped');
    } catch (e) {
      debugPrint('Error stopping services: $e');
    }
  }

  String _generateDeviceId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999);
    return '${timestamp.toString().substring(7)}_$randomPart';
  }

  String _generateSessionCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<String> _getDeviceName() async {
    try {
      // Generate a friendly device name
      final random = Random();
      final adjectives = ['Swift', 'Strong', 'Smart', 'Quick', 'Bright', 'Elite', 'Pro', 'Fast'];
      final nouns = ['Trainer', 'Athlete', 'Player', 'Champion', 'Star', 'Hero', 'Ace', 'Master'];

      final adjective = adjectives[random.nextInt(adjectives.length)];
      final noun = nouns[random.nextInt(nouns.length)];
      final number = random.nextInt(99) + 1;

      return '$adjective $noun $number';
    } catch (e) {
      return 'Spark User';
    }
  }

  /// Dispose resources
  void dispose() {
    _heartbeatTimer?.cancel();
    _sessionController.close();
    _messageController.close();
    _connectionStatusController.close();
    _stopServices();
  }
}
