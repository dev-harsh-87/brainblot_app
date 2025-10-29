import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'connection_session.g.dart';

/// Represents a multiplayer connection session
@JsonSerializable()
class ConnectionSession extends Equatable {
  /// Unique session identifier (6-digit code)
  final String sessionId;
  
  /// Host device identifier
  final String hostId;
  
  /// Host display name
  final String hostName;
  
  /// List of connected participant device IDs
  final List<String> participantIds;
  
  /// List of connected participant names
  final List<String> participantNames;
  
  /// Current session status
  final SessionStatus status;
  
  /// Currently active drill ID (if any)
  final String? activeDrillId;
  
  /// Session creation timestamp
  final DateTime createdAt;
  
  /// Last activity timestamp
  final DateTime lastActivity;
  
  /// Maximum number of participants allowed
  final int maxParticipants;

  const ConnectionSession({
    required this.sessionId,
    required this.hostId,
    required this.hostName,
    required this.participantIds,
    required this.participantNames,
    required this.status,
    this.activeDrillId,
    required this.createdAt,
    required this.lastActivity,
    this.maxParticipants = 8,
  });

  /// Creates a new host session
  factory ConnectionSession.createHost({
    required String sessionId,
    required String hostId,
    required String hostName,
    int maxParticipants = 8,
  }) {
    final now = DateTime.now();
    return ConnectionSession(
      sessionId: sessionId,
      hostId: hostId,
      hostName: hostName,
      participantIds: [],
      participantNames: [],
      status: SessionStatus.waiting,
      createdAt: now,
      lastActivity: now,
      maxParticipants: maxParticipants,
    );
  }

  /// Creates a copy with updated fields
  ConnectionSession copyWith({
    String? sessionId,
    String? hostId,
    String? hostName,
    List<String>? participantIds,
    List<String>? participantNames,
    SessionStatus? status,
    String? activeDrillId,
    DateTime? createdAt,
    DateTime? lastActivity,
    int? maxParticipants,
  }) {
    return ConnectionSession(
      sessionId: sessionId ?? this.sessionId,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      status: status ?? this.status,
      activeDrillId: activeDrillId ?? this.activeDrillId,
      createdAt: createdAt ?? this.createdAt,
      lastActivity: lastActivity ?? this.lastActivity,
      maxParticipants: maxParticipants ?? this.maxParticipants,
    );
  }

  /// Adds a participant to the session
  ConnectionSession addParticipant(String participantId, String participantName) {
    if (participantIds.contains(participantId)) {
      return this;
    }
    
    return copyWith(
      participantIds: [...participantIds, participantId],
      participantNames: [...participantNames, participantName],
      lastActivity: DateTime.now(),
    );
  }

  /// Removes a participant from the session
  ConnectionSession removeParticipant(String participantId) {
    final index = participantIds.indexOf(participantId);
    if (index == -1) return this;
    
    final newParticipantIds = List<String>.from(participantIds)..removeAt(index);
    final newParticipantNames = List<String>.from(participantNames)..removeAt(index);
    
    return copyWith(
      participantIds: newParticipantIds,
      participantNames: newParticipantNames,
      lastActivity: DateTime.now(),
    );
  }

  /// Updates the active drill
  ConnectionSession setActiveDrill(String? drillId) {
    return copyWith(
      activeDrillId: drillId,
      status: drillId != null ? SessionStatus.active : SessionStatus.waiting,
      lastActivity: DateTime.now(),
    );
  }

  /// Checks if session is full
  bool get isFull => participantIds.length >= maxParticipants;

  /// Gets total participant count (including host)
  int get totalParticipants => participantIds.length + 1;

  /// Checks if session is expired (inactive for more than 30 minutes)
  bool get isExpired {
    final now = DateTime.now();
    return now.difference(lastActivity).inMinutes > 30;
  }

  /// JSON serialization
  factory ConnectionSession.fromJson(Map<String, dynamic> json) =>
      _$ConnectionSessionFromJson(json);
  
  Map<String, dynamic> toJson() => _$ConnectionSessionToJson(this);

  @override
  List<Object?> get props => [
        sessionId,
        hostId,
        hostName,
        participantIds,
        participantNames,
        status,
        activeDrillId,
        createdAt,
        lastActivity,
        maxParticipants,
      ];
}

/// Session status enumeration
enum SessionStatus {
  @JsonValue('waiting')
  waiting,
  
  @JsonValue('active')
  active,
  
  @JsonValue('paused')
  paused,
  
  @JsonValue('completed')
  completed,
  
  @JsonValue('disconnected')
  disconnected,
}

/// Extension for session status display
extension SessionStatusExtension on SessionStatus {
  String get displayName {
    switch (this) {
      case SessionStatus.waiting:
        return 'Waiting for participants';
      case SessionStatus.active:
        return 'Training in progress';
      case SessionStatus.paused:
        return 'Paused';
      case SessionStatus.completed:
        return 'Completed';
      case SessionStatus.disconnected:
        return 'Disconnected';
    }
  }

  String get shortName {
    switch (this) {
      case SessionStatus.waiting:
        return 'Waiting';
      case SessionStatus.active:
        return 'Active';
      case SessionStatus.paused:
        return 'Paused';
      case SessionStatus.completed:
        return 'Done';
      case SessionStatus.disconnected:
        return 'Offline';
    }
  }
}
