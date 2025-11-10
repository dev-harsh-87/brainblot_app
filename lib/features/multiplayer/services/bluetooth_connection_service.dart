import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:spark_app/features/multiplayer/domain/connection_session.dart';
import 'package:spark_app/features/multiplayer/domain/sync_message.dart';

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
    } catch (e) {
      debugPrint('Failed to initialize BluetoothConnectionService: $e');
      rethrow;
    }
  }

  /// Request necessary permissions for Bluetooth and location.
  /// Returns true if all required permissions are granted.
  Future<bool> requestPermissions() async {
    try {
      // Build list depending on platform requirements.
      final List<Permission> permissions = [];

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        permissions.addAll([
          Permission.bluetooth,
          Permission.locationWhenInUse,
        ]);
      } else {
        // Android: include fine-grained Bluetooth permissions where available.
        permissions.addAll([
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.locationWhenInUse,
        ]);

        // Some Android versions expose nearbyWifiDevices permission in permission_handler; add defensively.
        try {
          permissions.add(Permission.nearbyWifiDevices);
        } catch (_) {
          // ignore if not available in the permission handler version used.
        }
      }

      // Query statuses
      final statuses = <Permission, PermissionStatus>{};
      for (final p in permissions) {
        statuses[p] = await p.status;
      }

      // If any permanently denied -> inform user and return false.
      final permanentlyDenied = statuses.entries
          .where((e) => e.value == PermissionStatus.permanentlyDenied)
          .map((e) => e.key)
          .toList();

      if (permanentlyDenied.isNotEmpty) {
        debugPrint('Permanently denied permissions: $permanentlyDenied');
        _connectionStatusController.add(
          defaultTargetPlatform == TargetPlatform.iOS
              ? 'Bluetooth and Location permissions are required. Please enable them in Settings > Privacy.'
              : 'Some permissions are permanently denied. Please enable them in Settings.',
        );
        return false;
      }

      // Request any that aren't granted
      final toRequest = statuses.entries
          .where((e) => e.value != PermissionStatus.granted)
          .map((e) => e.key)
          .toList();

      if (toRequest.isNotEmpty) {
        final results = await toRequest.request();
        results.forEach((permission, status) {
          statuses[permission] = status;
        });
      }

      final allGranted = statuses.values.every((s) => s == PermissionStatus.granted);

      if (allGranted) {
        _connectionStatusController.add('Permissions granted');
        debugPrint('All required permissions granted for ${defaultTargetPlatform.name}');
      } else {
        _connectionStatusController.add('Some permissions denied');
        debugPrint('Permission results:');
        statuses.forEach((p, s) => debugPrint('  $p: $s'));
      }

      return allGranted;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      _connectionStatusController.add('Permission error: $e');
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
        ]);
        try {
          permissions.add(Permission.nearbyWifiDevices);
        } catch (_) {}
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
    if (_deviceId == null || _deviceName == null) {
      throw Exception('Service not initialized');
    }

    final hasPermissions = await requestPermissions();
    if (!hasPermissions) throw Exception('Required permissions not granted');

    final sessionId = _generateSessionCode();

    _currentSession = ConnectionSession.createHost(
      sessionId: sessionId,
      hostId: _deviceId!,
      hostName: _deviceName!,
      maxParticipants: maxParticipants,
    );

    _isHost = true;
    _isConnected = true;
    _advertisedSessionCode = sessionId;

    await _startAdvertising(sessionId);
    _startHeartbeat();

    _connectionStatusController.add('Hosting session: $sessionId');
    _sessionController.add(_currentSession!);

    return _currentSession!;
  }

  /// Join an existing session by session code. Completes when connected or throws.
  Future<ConnectionSession> joinSession(String sessionCode,
      {Duration timeout = const Duration(seconds: 30)}) async {
    if (_deviceId == null || _deviceName == null) throw Exception('Service not initialized');

    final hasPermissions = await requestPermissions();
    if (!hasPermissions) throw Exception('Required permissions not granted');

    _isHost = false;
    _joinCompleter = Completer<ConnectionSession>();

    _connectionStatusController.add('Searching for session: $sessionCode');

    try {
      // Start discovery and wait for a matching endpoint to connect.
      await _startDiscovery(sessionCode);

      // Fail-fast on timeout with better error message.
      final result = await _joinCompleter!.future.timeout(timeout, onTimeout: () async {
        // Stop discovery if timed out
        try {
          await Nearby().stopDiscovery();
        } catch (e) {
          debugPrint('Error stopping discovery on timeout: $e');
        }
        
        if (!_joinCompleter!.isCompleted) {
          _joinCompleter!.completeError(Exception('Session $sessionCode not found. Make sure the host is nearby and the session code is correct.'));
        }
        throw Exception('Session $sessionCode not found. Make sure the host is nearby and the session code is correct.');
      });

      return result;
    } catch (e) {
      // Clean up on any error
      try {
        await Nearby().stopDiscovery();
      } catch (cleanupError) {
        debugPrint('Error during cleanup: $cleanupError');
      }
      
      // Reset state
      _isHost = false;
      _isConnected = false;
      _joinCompleter = null;
      
      rethrow;
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
    if (!_isHost) throw Exception('Only host can start drills');

    final message = SyncMessage.drillStart(
      senderId: _deviceId!,
      senderName: _deviceName!,
      drillId: drillId,
      drillData: drillData,
    );

    await sendMessage(message);

    _currentSession = _currentSession?.setActiveDrill(drillId);
    if (_currentSession != null) _sessionController.add(_currentSession!);
  }

  Future<void> stopDrillForAll() async {
    if (!_isHost) throw Exception('Only host can stop drills');

    final message = SyncMessage.drillStop(
      senderId: _deviceId!,
      senderName: _deviceName!,
    );

    await sendMessage(message);

    _currentSession = _currentSession?.setActiveDrill(null);
    if (_currentSession != null) _sessionController.add(_currentSession!);
  }

  Future<void> pauseDrillForAll() async {
    if (!_isHost) throw Exception('Only host can pause drills');

    final message = SyncMessage.drillPause(
      senderId: _deviceId!,
      senderName: _deviceName!,
    );

    await sendMessage(message);
  }

  Future<void> resumeDrillForAll() async {
    if (!_isHost) throw Exception('Only host can resume drills');

    final message = SyncMessage.drillResume(
      senderId: _deviceId!,
      senderName: _deviceName!,
    );

    await sendMessage(message);
  }

  Future<void> sendChatMessage(String message) async {
    final chatMessage = SyncMessage.chat(
      senderId: _deviceId!,
      senderName: _deviceName!,
      message: message,
    );

    await sendMessage(chatMessage);
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
      await Nearby().startDiscovery(
        _deviceName!,
        _strategy,
        onEndpointFound: (id, name, serviceId) => _onEndpointFound(id, name, serviceId, sessionCode),
        onEndpointLost: _onEndpointLost,
        serviceId: _serviceId,
      );

      debugPrint('Started discovery for session: $sessionCode');
    } catch (e) {
      debugPrint('Failed to start discovery: $e');
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
    debugPrint('Connection result: $endpointId - ${status.toString()}');

    if (status == Status.CONNECTED) {
      if (_isHost) {
        // Add participant to session
        final nextIndex = (_currentSession?.participantIds.length ?? 0) + 1;
        _addParticipant(endpointId, 'Participant $nextIndex');
      } else {
        _isConnected = true;
        // Create a basic session for the participant
        _currentSession = ConnectionSession.createHost(
          sessionId: _advertisedSessionCode ?? _generateSessionCode(),
          hostId: 'host',
          hostName: 'Host',
        );
        _sessionController.add(_currentSession!);
        _connectionStatusController.add('Connected to session');
        
        // Complete the join operation
        if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
          _joinCompleter!.complete(_currentSession!);
        }
      }
    } else {
      // Connection failed
      if (!_isHost && _joinCompleter != null && !_joinCompleter!.isCompleted) {
        _joinCompleter!.completeError(Exception('Failed to connect: ${status.toString()}'));
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
    debugPrint('Found endpoint: $endpointId - $name');

    // Check if this endpoint matches our target session code
    if (name.contains(sessionCode)) {
      debugPrint('Found matching session: $name');
      _advertisedSessionCode = sessionCode;
      
      // Request connection
      Nearby().requestConnection(
        _deviceName!,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } else {
      debugPrint('Session code mismatch: looking for $sessionCode, found $name');
    }
  }

  void _onEndpointLost(String? endpointId) {
    debugPrint('Lost endpoint: $endpointId');
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
      case SyncMessageType.drillStop:
      case SyncMessageType.drillPause:
      case SyncMessageType.drillResume:
        // Forward drill control messages to UI
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
        // Handle session status updates
        try {
          final sessionData = message.data;
          if (sessionData.isNotEmpty) {
            // Update session from received data
            _updateSessionFromData(sessionData);
          }
        } catch (e) {
          debugPrint('Error handling session status: $e');
        }
        break;
    }
  }

  void _updateSessionFromData(Map<String, dynamic> sessionData) {
    try {
      if (_currentSession != null) {
        _currentSession = _currentSession!.copyWith(
          lastActivity: DateTime.now(),
          // Add other fields as needed
        );
        _sessionController.add(_currentSession!);
      }
    } catch (e) {
      debugPrint('Error updating session from data: $e');
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
      sendMessage(joinMessage);
      
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
        sendMessage(leaveMessage);
        
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
        sendMessage(heartbeat);
      }
    });
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
