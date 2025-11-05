// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
// import 'dart:typed_data';
//
// import 'package:flutter/foundation.dart';
// import 'package:nearby_connections/nearby_connections.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// import 'package:spark_app/features/multiplayer/domain/connection_session.dart';
// import 'package:spark_app/features/multiplayer/domain/sync_message.dart';
//
// /// Service for managing Bluetooth connections and P2P communication
// class BluetoothConnectionService {
//   static const String _serviceId = 'com.brainblot.multiplayer';
//   static const Strategy _strategy = Strategy.P2P_STAR;
//
//   final StreamController<ConnectionSession> _sessionController =
//       StreamController<ConnectionSession>.broadcast();
//   final StreamController<SyncMessage> _messageController =
//       StreamController<SyncMessage>.broadcast();
//   final StreamController<String> _connectionStatusController =
//       StreamController<String>.broadcast();
//
//   ConnectionSession? _currentSession;
//   String? _deviceId;
//   String? _deviceName;
//   bool _isHost = false;
//   bool _isConnected = false;
//   Timer? _heartbeatTimer;
//
//   /// Stream of session updates
//   Stream<ConnectionSession> get sessionStream => _sessionController.stream;
//
//   /// Stream of incoming messages
//   Stream<SyncMessage> get messageStream => _messageController.stream;
//
//   /// Stream of connection status updates
//   Stream<String> get connectionStatusStream => _connectionStatusController.stream;
//
//   /// Current session (if any)
//   ConnectionSession? get currentSession => _currentSession;
//
//   /// Whether this device is the host
//   bool get isHost => _isHost;
//
//   /// Whether device is connected to a session
//   bool get isConnected => _isConnected;
//
//   /// Device ID
//   String? get deviceId => _deviceId;
//
//   /// Initialize the service
//   Future<void> initialize() async {
//     try {
//       // Generate unique device ID
//       _deviceId = _generateDeviceId();
//       _deviceName = await _getDeviceName();
//
//       debugPrint('BluetoothConnectionService initialized: $_deviceId ($_deviceName)');
//     } catch (e) {
//       debugPrint('Failed to initialize BluetoothConnectionService: $e');
//       rethrow;
//     }
//   }
//
//   /// Request necessary permissions for Bluetooth and location
//   Future<bool> requestPermissions() async {
//     try {
//       // Different permissions for iOS vs Android
//       List<Permission> permissions;
//       if (defaultTargetPlatform == TargetPlatform.iOS) {
//         permissions = [
//           Permission.bluetooth,
//           Permission.locationWhenInUse,
//         ];
//       } else {
//         // Android permissions
//         permissions = [
//           Permission.bluetooth,
//           Permission.bluetoothConnect,
//           Permission.bluetoothAdvertise,
//           Permission.bluetoothScan,
//           Permission.location,
//           Permission.locationWhenInUse,
//           Permission.nearbyWifiDevices,
//         ];
//       }
//
//       // First check current status
//       final currentStatuses = await Future.wait(
//         permissions.map((p) => p.status),
//       );
//
//       final permissionStatusMap = Map.fromIterables(permissions, currentStatuses);
//
//       // Check if any are permanently denied
//       final permanentlyDenied = permissions.where(
//         (p) => permissionStatusMap[p] == PermissionStatus.permanentlyDenied,
//       ).toList();
//
//       if (permanentlyDenied.isNotEmpty) {
//         debugPrint('Permanently denied permissions: $permanentlyDenied');
//         if (defaultTargetPlatform == TargetPlatform.iOS) {
//           _connectionStatusController.add('Bluetooth and Location permissions are required. Please enable them in Settings > Privacy & Security.');
//         } else {
//           _connectionStatusController.add('Some permissions are permanently denied. Please enable them in Settings.');
//         }
//         return false;
//       }
//
//       // Request permissions that aren't granted
//       final needsRequest = permissions.where(
//         (p) => permissionStatusMap[p] != PermissionStatus.granted,
//       ).toList();
//
//       if (needsRequest.isNotEmpty) {
//         final statuses = await needsRequest.request();
//
//         // Update the status map
//         statuses.forEach((permission, status) {
//           permissionStatusMap[permission] = status;
//         });
//       }
//
//       bool allGranted = true;
//       for (final permission in permissions) {
//         final status = permissionStatusMap[permission];
//         if (status != PermissionStatus.granted) {
//           debugPrint('Permission denied: $permission - $status');
//           allGranted = false;
//         }
//       }
//
//       if (allGranted) {
//         _connectionStatusController.add('Permissions granted');
//         debugPrint('All required permissions granted for ${defaultTargetPlatform.name}');
//       } else {
//         if (defaultTargetPlatform == TargetPlatform.iOS) {
//           _connectionStatusController.add('iOS requires Bluetooth and Location permissions for multiplayer features');
//         } else {
//           _connectionStatusController.add('Some permissions denied');
//         }
//         debugPrint('Permission status for ${defaultTargetPlatform.name}:');
//         for (final permission in permissions) {
//           debugPrint('  ${permission.toString()}: ${permissionStatusMap[permission]}');
//         }
//       }
//
//       return allGranted;
//     } catch (e) {
//       debugPrint('Error requesting permissions: $e');
//       _connectionStatusController.add('Permission error: $e');
//       return false;
//     }
//   }
//
//   /// Open app settings for user to manually enable permissions
//   Future<void> openPermissionSettings() async {
//     try {
//       await openAppSettings();
//     } catch (e) {
//       debugPrint('Failed to open app settings: $e');
//     }
//   }
//
//   /// Check if permissions are available (not permanently denied)
//   Future<bool> arePermissionsAvailable() async {
//     try {
//       // Different permissions for iOS vs Android
//       List<Permission> permissions;
//       if (defaultTargetPlatform == TargetPlatform.iOS) {
//         permissions = [
//           Permission.bluetooth,
//           Permission.locationWhenInUse,
//         ];
//       } else {
//         // Android permissions
//         permissions = [
//           Permission.bluetooth,
//           Permission.bluetoothConnect,
//           Permission.bluetoothAdvertise,
//           Permission.bluetoothScan,
//           Permission.location,
//           Permission.locationWhenInUse,
//           Permission.nearbyWifiDevices,
//         ];
//       }
//
//       final statuses = await Future.wait(
//         permissions.map((p) => p.status),
//       );
//
//       // Check if any are permanently denied
//       return !statuses.any((status) => status == PermissionStatus.permanentlyDenied);
//     } catch (e) {
//       debugPrint('Error checking permission availability: $e');
//       return false;
//     }
//   }
//
//   /// Create a new host session
//   Future<ConnectionSession> createHostSession({
//     int maxParticipants = 8,
//   }) async {
//     try {
//       if (_deviceId == null || _deviceName == null) {
//         throw Exception('Service not initialized');
//       }
//
//       // Check permissions first
//       final hasPermissions = await requestPermissions();
//       if (!hasPermissions) {
//         throw Exception('Required permissions not granted');
//       }
//
//       // Generate session code
//       final sessionId = _generateSessionCode();
//
//       // Create session
//       _currentSession = ConnectionSession.createHost(
//         sessionId: sessionId,
//         hostId: _deviceId!,
//         hostName: _deviceName!,
//         maxParticipants: maxParticipants,
//       );
//
//       _isHost = true;
//       _isConnected = true;
//
//       // Start advertising
//       await _startAdvertising();
//
//       // Start heartbeat
//       _startHeartbeat();
//
//       _connectionStatusController.add('Hosting session: $sessionId');
//       _sessionController.add(_currentSession!);
//
//       return _currentSession!;
//     } catch (e) {
//       debugPrint('Failed to create host session: $e');
//       _connectionStatusController.add('Failed to host: $e');
//       rethrow;
//     }
//   }
//
//   /// Join an existing session using session code
//   Future<ConnectionSession> joinSession(String sessionCode) async {
//     try {
//       if (_deviceId == null || _deviceName == null) {
//         throw Exception('Service not initialized');
//       }
//
//       // Check permissions first
//       final hasPermissions = await requestPermissions();
//       if (!hasPermissions) {
//         throw Exception('Required permissions not granted');
//       }
//
//       _isHost = false;
//
//       // Start discovery to find the host
//       _connectionStatusController.add('Searching for session: $sessionCode');
//
//       await _startDiscovery(sessionCode);
//
//       return _currentSession!;
//     } catch (e) {
//       debugPrint('Failed to join session: $e');
//       _connectionStatusController.add('Failed to join: $e');
//       rethrow;
//     }
//   }
//
//   /// Send a message to all connected devices or a specific device
//   Future<void> sendMessage(SyncMessage message) async {
//     try {
//       if (!_isConnected || _currentSession == null) {
//         throw Exception('Not connected to a session');
//       }
//
//       final messageJson = jsonEncode(message.toJson());
//
//       if (message.isBroadcast) {
//         // Send to all connected devices
//         if (_isHost) {
//           // Host sends to all participants
//           for (final participantId in _currentSession!.participantIds) {
//             await _sendToDevice(participantId, messageJson);
//           }
//         } else {
//           // Participant sends to host
//           await _sendToDevice(_currentSession!.hostId, messageJson);
//         }
//       } else if (message.targetId != null) {
//         // Send to specific device
//         await _sendToDevice(message.targetId!, messageJson);
//       }
//
//       debugPrint('Message sent: ${message.type.displayName}');
//     } catch (e) {
//       debugPrint('Failed to send message: $e');
//       _connectionStatusController.add('Message send failed: $e');
//     }
//   }
//
//   /// Disconnect from current session
//   Future<void> disconnect() async {
//     try {
//       // Send leave message if connected
//       if (_isConnected && _currentSession != null && _deviceId != null && _deviceName != null) {
//         final leaveMessage = SyncMessage.participantLeave(
//           senderId: _deviceId!,
//           senderName: _deviceName!,
//         );
//         await sendMessage(leaveMessage);
//       }
//
//       // Stop services
//       await _stopServices();
//
//       // Reset state
//       _currentSession = null;
//       _isHost = false;
//       _isConnected = false;
//
//       _connectionStatusController.add('Disconnected');
//     } catch (e) {
//       debugPrint('Error during disconnect: $e');
//     }
//   }
//
//   /// Start a drill for all connected devices
//   Future<void> startDrillForAll(String drillId, Map<String, dynamic> drillData) async {
//     if (!_isHost) {
//       throw Exception('Only host can start drills');
//     }
//
//     final message = SyncMessage.drillStart(
//       senderId: _deviceId!,
//       senderName: _deviceName!,
//       drillId: drillId,
//       drillData: drillData,
//     );
//
//     await sendMessage(message);
//
//     // Update session
//     _currentSession = _currentSession?.setActiveDrill(drillId);
//     if (_currentSession != null) {
//       _sessionController.add(_currentSession!);
//     }
//   }
//
//   /// Stop the current drill for all devices
//   Future<void> stopDrillForAll() async {
//     if (!_isHost) {
//       throw Exception('Only host can stop drills');
//     }
//
//     final message = SyncMessage.drillStop(
//       senderId: _deviceId!,
//       senderName: _deviceName!,
//     );
//
//     await sendMessage(message);
//
//     // Update session
//     _currentSession = _currentSession?.setActiveDrill(null);
//     if (_currentSession != null) {
//       _sessionController.add(_currentSession!);
//     }
//   }
//
//   /// Pause the current drill for all devices
//   Future<void> pauseDrillForAll() async {
//     if (!_isHost) {
//       throw Exception('Only host can pause drills');
//     }
//
//     final message = SyncMessage.drillPause(
//       senderId: _deviceId!,
//       senderName: _deviceName!,
//     );
//
//     await sendMessage(message);
//   }
//
//   /// Resume the current drill for all devices
//   Future<void> resumeDrillForAll() async {
//     if (!_isHost) {
//       throw Exception('Only host can resume drills');
//     }
//
//     final message = SyncMessage.drillResume(
//       senderId: _deviceId!,
//       senderName: _deviceName!,
//     );
//
//     await sendMessage(message);
//   }
//
//   /// Send a chat message
//   Future<void> sendChatMessage(String message) async {
//     final chatMessage = SyncMessage.chat(
//       senderId: _deviceId!,
//       senderName: _deviceName!,
//       message: message,
//     );
//
//     await sendMessage(chatMessage);
//   }
//
//   // Private methods
//
//   Future<void> _startAdvertising() async {
//     try {
//       await Nearby().startAdvertising(
//         _deviceName!,
//         _strategy,
//         onConnectionInitiated: _onConnectionInitiated,
//         onConnectionResult: _onConnectionResult,
//         onDisconnected: _onDisconnected,
//         serviceId: _serviceId,
//       );
//
//       debugPrint('Started advertising as host');
//     } catch (e) {
//       debugPrint('Failed to start advertising: $e');
//       rethrow;
//     }
//   }
//
//   Future<void> _startDiscovery(String sessionCode) async {
//     try {
//       await Nearby().startDiscovery(
//         _deviceName!,
//         _strategy,
//         onEndpointFound: (id, name, serviceId) => _onEndpointFound(id, name, serviceId, sessionCode),
//         onEndpointLost: _onEndpointLost,
//         serviceId: _serviceId,
//       );
//
//       debugPrint('Started discovery for session: $sessionCode');
//     } catch (e) {
//       debugPrint('Failed to start discovery: $e');
//       rethrow;
//     }
//   }
//
//   void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
//     debugPrint('Connection initiated with: $endpointId');
//
//     // Auto-accept connections (in production, you might want to show a dialog)
//     Nearby().acceptConnection(
//       endpointId,
//       onPayLoadRecieved: _onPayloadReceived,
//       onPayloadTransferUpdate: _onPayloadTransferUpdate,
//     );
//   }
//
//   void _onConnectionResult(String endpointId, Status status) {
//     debugPrint('Connection result: $endpointId - ${status.toString()}');
//
//     if (status == Status.CONNECTED) {
//       if (_isHost) {
//         // Add participant to session
//         _addParticipant(endpointId, 'Participant ${_currentSession?.participantIds.length ?? 0 + 1}');
//       } else {
//         _isConnected = true;
//         _connectionStatusController.add('Connected to session');
//       }
//     }
//   }
//
//   void _onDisconnected(String endpointId) {
//     debugPrint('Disconnected from: $endpointId');
//
//     if (_isHost) {
//       _removeParticipant(endpointId);
//     } else {
//       _isConnected = false;
//       _connectionStatusController.add('Disconnected from session');
//     }
//   }
//
//   void _onEndpointFound(String endpointId, String name, String serviceId, String sessionCode) {
//     debugPrint('Found endpoint: $endpointId - $name');
//
//     // Request connection
//     Nearby().requestConnection(
//       _deviceName!,
//       endpointId,
//       onConnectionInitiated: _onConnectionInitiated,
//       onConnectionResult: _onConnectionResult,
//       onDisconnected: _onDisconnected,
//     );
//   }
//
//   void _onEndpointLost(String? endpointId) {
//     debugPrint('Lost endpoint: $endpointId');
//   }
//
//   void _onPayloadReceived(String endpointId, Payload payload) {
//     try {
//       if (payload.type == PayloadType.BYTES) {
//         final messageJson = String.fromCharCodes(payload.bytes!);
//         final messageData = jsonDecode(messageJson) as Map<String, dynamic>;
//         final message = SyncMessage.fromJson(messageData);
//
//         _handleIncomingMessage(message, endpointId);
//       }
//     } catch (e) {
//       debugPrint('Error processing payload: $e');
//     }
//   }
//
//   void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
//     // Handle payload transfer updates if needed
//   }
//
//   void _handleIncomingMessage(SyncMessage message, String fromEndpointId) {
//     debugPrint('Received message: ${message.type.displayName} from ${message.senderName}');
//
//     switch (message.type) {
//       case SyncMessageType.participantJoin:
//         if (_isHost) {
//           _addParticipant(fromEndpointId, message.senderName);
//         }
//         break;
//       case SyncMessageType.participantLeave:
//         if (_isHost) {
//           _removeParticipant(fromEndpointId);
//         }
//         break;
//       case SyncMessageType.drillStart:
//       case SyncMessageType.drillStop:
//       case SyncMessageType.drillPause:
//       case SyncMessageType.drillResume:
//         // Forward drill control messages to UI
//         _messageController.add(message);
//         break;
//       case SyncMessageType.chat:
//         // Forward chat messages to UI
//         _messageController.add(message);
//         break;
//       case SyncMessageType.heartbeat:
//         // Handle heartbeat
//         break;
//       case SyncMessageType.sessionStatus:
//         // Handle session status updates
//         break;
//     }
//   }
//
//   Future<void> _sendToDevice(String deviceId, String message) async {
//     try {
//       final bytes = Uint8List.fromList(message.codeUnits);
//
//       await Nearby().sendBytesPayload(deviceId, bytes);
//     } catch (e) {
//       debugPrint('Failed to send to device $deviceId: $e');
//     }
//   }
//
//   void _addParticipant(String participantId, String participantName) {
//     if (_currentSession != null) {
//       _currentSession = _currentSession!.addParticipant(participantId, participantName);
//       _sessionController.add(_currentSession!);
//
//       // Send join message to other participants
//       final joinMessage = SyncMessage.participantJoin(
//         senderId: participantId,
//         senderName: participantName,
//       );
//       sendMessage(joinMessage);
//     }
//   }
//
//   void _removeParticipant(String participantId) {
//     if (_currentSession != null) {
//       final index = _currentSession!.participantIds.indexOf(participantId);
//       if (index != -1) {
//         final participantName = _currentSession!.participantNames[index];
//         _currentSession = _currentSession!.removeParticipant(participantId);
//         _sessionController.add(_currentSession!);
//
//         // Send leave message to other participants
//         final leaveMessage = SyncMessage.participantLeave(
//           senderId: participantId,
//           senderName: participantName,
//         );
//         sendMessage(leaveMessage);
//       }
//     }
//   }
//
//   void _startHeartbeat() {
//     _heartbeatTimer?.cancel();
//     _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
//       if (_isConnected && _deviceId != null && _deviceName != null) {
//         final heartbeat = SyncMessage.heartbeat(
//           senderId: _deviceId!,
//           senderName: _deviceName!,
//         );
//         sendMessage(heartbeat);
//       }
//     });
//   }
//
//   Future<void> _stopServices() async {
//     try {
//       _heartbeatTimer?.cancel();
//       await Nearby().stopAdvertising();
//       await Nearby().stopDiscovery();
//       await Nearby().stopAllEndpoints();
//     } catch (e) {
//       debugPrint('Error stopping services: $e');
//     }
//   }
//
//   String _generateDeviceId() {
//     final random = Random();
//     final timestamp = DateTime.now().millisecondsSinceEpoch;
//     final randomPart = random.nextInt(999999);
//     return '${timestamp.toString().substring(7)}_$randomPart';
//   }
//
//   String _generateSessionCode() {
//     final random = Random();
//     return (100000 + random.nextInt(900000)).toString();
//   }
//
//   Future<String> _getDeviceName() async {
//     try {
//       // Generate a friendly device name
//       final random = Random();
//       final adjectives = ['Swift', 'Strong', 'Smart', 'Quick', 'Bright', 'Elite', 'Pro', 'Fast'];
//       final nouns = ['Trainer', 'Athlete', 'Player', 'Champion', 'Star', 'Hero', 'Ace', 'Master'];
//
//       final adjective = adjectives[random.nextInt(adjectives.length)];
//       final noun = nouns[random.nextInt(nouns.length)];
//       final number = random.nextInt(99) + 1;
//
//       return '$adjective $noun $number';
//     } catch (e) {
//       return 'Spark User';
//     }
//   }
//
//   /// Dispose resources
//   void dispose() {
//     _heartbeatTimer?.cancel();
//     _sessionController.close();
//     _messageController.close();
//     _connectionStatusController.close();
//     _stopServices();
//   }
// }



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
      {Duration timeout = const Duration(seconds: 20)}) async {
    if (_deviceId == null || _deviceName == null) throw Exception('Service not initialized');

    final hasPermissions = await requestPermissions();
    if (!hasPermissions) throw Exception('Required permissions not granted');

    _isHost = false;
    _joinCompleter = Completer<ConnectionSession>();

    _connectionStatusController.add('Searching for session: $sessionCode');

    // Start discovery and wait for a matching endpoint to connect.
    await _startDiscovery(sessionCode);

    // Fail-fast on timeout.
    final result = await _joinCompleter!.future.timeout(timeout, onTimeout: () async {
      // Stop discovery if timed out
      await Nearby().stopDiscovery();
      if (!_joinCompleter!.isCompleted) {
        _joinCompleter!.completeError(Exception('Timed out searching for session $sessionCode'));
      }
      throw Exception('Timed out searching for session $sessionCode');
    });

    return result;
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

  Future<void> sendChatMessage(String messageText) async {
    final chatMessage = SyncMessage.chat(
      senderId: _deviceId!,
      senderName: _deviceName!,
      message: messageText,
    );

    await sendMessage(chatMessage);
  }

  // ----------------- Private helpers -----------------

  Future<void> _startAdvertising(String sessionCode) async {
    try {
      // advertise endpoint name as "deviceName|sessionCode" so discovery can filter
      final advertiseName = '$_deviceName|$sessionCode';
      // Stop any previous advertising first
      try {
        await Nearby().stopAdvertising();
      } catch (_) {}

      await Nearby().startAdvertising(
        advertiseName,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );

      debugPrint('Started advertising as host with session: $sessionCode');
    } catch (e) {
      debugPrint('Failed to start advertising: $e');
      rethrow;
    }
  }

  Future<void> _startDiscovery(String sessionCode) async {
    try {
      // Stop any previous discovery
      try {
        await Nearby().stopDiscovery();
      } catch (_) {}

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
    debugPrint('Connection initiated with: $endpointId');

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
        // Add participant with a generated friendly name if not provided
        final nextIndex = (_currentSession?.participantIds.length ?? 0) + 1;
        _addParticipant(endpointId, 'Participant $nextIndex');
      } else {
        _isConnected = true;
        // Create a session locally: the host is the endpoint we connected to.
        _currentSession = ConnectionSession.createHost(
          sessionId: _advertisedSessionCode ?? _generateSessionCode(),
          hostId: endpointId,
          hostName: 'Host',
        );
        _sessionController.add(_currentSession!);
        _connectionStatusController.add('Connected to session');

        // If we were waiting to join, complete the completer
        if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
          _joinCompleter!.complete(_currentSession!);
        }
      }
    } else {
      // connection failed
      if (!_isHost && _joinCompleter != null && !_joinCompleter!.isCompleted) {
        _joinCompleter!.completeError(Exception('Failed to connect to host: $status'));
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
    try {
      debugPrint('Found endpoint: $endpointId - $name');

      // Our advertise name format is "deviceName|sessionCode". Only request connection if codes match.
      final parts = name.split('|');
      if (parts.length >= 2) {
        final discoveredSessionCode = parts.last;
        if (discoveredSessionCode != sessionCode) return; // not our session

        // Keep the advertised session code so we can set it as we connect (used in _onConnectionResult)
        _advertisedSessionCode = discoveredSessionCode;

        Nearby().requestConnection(
          _deviceName!,
          endpointId,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: _onConnectionResult,
          onDisconnected: _onDisconnected,
        );
      }
    } catch (e) {
      debugPrint('Error in _onEndpointFound: $e');
    }
  }

  void _onEndpointLost(String? endpointId) {
    debugPrint('Lost endpoint: $endpointId');
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    try {
      if (payload.type == PayloadType.BYTES && payload.bytes != null) {
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
    // Optionally handle progress updates or large payload transfers
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
      case SyncMessageType.chat:
      case SyncMessageType.sessionStatus:
        _messageController.add(message);
        break;
      case SyncMessageType.heartbeat:
      // Could update "last seen" timestamps here for participants
        break;
    }
  }

  Future<void> _sendToDevice(String deviceId, String message) async {
    final bytes = Uint8List.fromList(message.codeUnits);
    try {
      await Nearby().sendBytesPayload(deviceId, bytes);
    } catch (e) {
      debugPrint('Failed to send to device $deviceId: $e');
    }
  }

  void _addParticipant(String participantId, String participantName) {
    if (_currentSession != null) {
      _currentSession = _currentSession!.addParticipant(participantId, participantName);
      _sessionController.add(_currentSession!);

      // Notify others about the new participant
      final joinMessage = SyncMessage.participantJoin(
        senderId: participantId,
        senderName: participantName,
      );

      // best-effort fire-and-forget
      sendMessage(joinMessage).catchError((e) => debugPrint('Failed to broadcast join: $e'));
    }
  }

  void _removeParticipant(String participantId) {
    if (_currentSession != null) {
      final index = _currentSession!.participantIds.indexOf(participantId);
      if (index != -1) {
        final participantName = _currentSession!.participantNames[index];
        _currentSession = _currentSession!.removeParticipant(participantId);
        _sessionController.add(_currentSession!);

        final leaveMessage = SyncMessage.participantLeave(
          senderId: participantId,
          senderName: participantName,
        );

        sendMessage(leaveMessage).catchError((e) => debugPrint('Failed to broadcast leave: $e'));
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
        sendMessage(heartbeat).catchError((e) => debugPrint('Heartbeat send failed: $e'));
      }
    });
  }

  Future<void> _stopServices() async {
    try {
      _heartbeatTimer?.cancel();
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (e) {
      debugPrint('Error stopping services: $e');
    }
  }

  String _generateDeviceId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999);
    return '${timestamp.toString().substring(max(0, timestamp.toString().length - 6))}_$randomPart';
  }

  String _generateSessionCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<String> _getDeviceName() async {
    try {
      final random = Random();
      const adjectives = ['Swift', 'Strong', 'Smart', 'Quick', 'Bright', 'Elite', 'Pro', 'Fast'];
      const nouns = ['Trainer', 'Athlete', 'Player', 'Champion', 'Star', 'Hero', 'Ace', 'Master'];

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


