import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sync_message.g.dart';

/// Represents a synchronization message between devices
@JsonSerializable()
class SyncMessage extends Equatable {
  /// Message type
  final SyncMessageType type;
  
  /// Sender device ID
  final String senderId;
  
  /// Sender display name
  final String senderName;
  
  /// Target device ID (null for broadcast)
  final String? targetId;
  
  /// Message payload data
  final Map<String, dynamic> data;
  
  /// Message timestamp
  final DateTime timestamp;
  
  /// Message ID for tracking
  final String messageId;

  const SyncMessage({
    required this.type,
    required this.senderId,
    required this.senderName,
    this.targetId,
    required this.data,
    required this.timestamp,
    required this.messageId,
  });

  /// Creates a drill start message
  factory SyncMessage.drillStart({
    required String senderId,
    required String senderName,
    required String drillId,
    required Map<String, dynamic> drillData,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.drillStart,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {
        'drillId': drillId,
        'drillData': drillData,
      },
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a drill stop message
  factory SyncMessage.drillStop({
    required String senderId,
    required String senderName,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.drillStop,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {},
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a drill pause message
  factory SyncMessage.drillPause({
    required String senderId,
    required String senderName,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.drillPause,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {},
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a drill resume message
  factory SyncMessage.drillResume({
    required String senderId,
    required String senderName,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.drillResume,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {},
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a participant join message
  factory SyncMessage.participantJoin({
    required String senderId,
    required String senderName,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.participantJoin,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {
        'participantId': senderId,
        'participantName': senderName,
      },
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a participant leave message
  factory SyncMessage.participantLeave({
    required String senderId,
    required String senderName,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.participantLeave,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {
        'participantId': senderId,
        'participantName': senderName,
      },
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a session status message
  factory SyncMessage.sessionStatus({
    required String senderId,
    required String senderName,
    required Map<String, dynamic> sessionData,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.sessionStatus,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: sessionData,
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a heartbeat message
  factory SyncMessage.heartbeat({
    required String senderId,
    required String senderName,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.heartbeat,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a chat message
  factory SyncMessage.chat({
    required String senderId,
    required String senderName,
    required String message,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.chat,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {
        'message': message,
      },
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a drill content message (for syncing visual/audio content)
  factory SyncMessage.drillContent({
    required String senderId,
    required String senderName,
    required Map<String, dynamic> contentData,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.drillContent,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {
        'contentData': contentData,
      },
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a drill stimulus message (for syncing individual stimuli)
  factory SyncMessage.drillStimulus({
    required String senderId,
    required String senderName,
    required Map<String, dynamic> stimulusData,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.drillStimulus,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {
        'stimulusData': stimulusData,
      },
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a score update message
  factory SyncMessage.scoreUpdate({
    required String senderId,
    required String senderName,
    required Map<String, dynamic> scoreData,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.drillScoreUpdate,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {
        'scoreData': scoreData,
      },
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Creates a rep complete message
  factory SyncMessage.repComplete({
    required String senderId,
    required String senderName,
    required Map<String, dynamic> repData,
    String? targetId,
  }) {
    return SyncMessage(
      type: SyncMessageType.drillRepComplete,
      senderId: senderId,
      senderName: senderName,
      targetId: targetId,
      data: {
        'repData': repData,
      },
      timestamp: DateTime.now(),
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Checks if message is a broadcast (no specific target)
  bool get isBroadcast => targetId == null;

  /// Checks if message is targeted to a specific device
  bool isTargetedTo(String deviceId) => targetId == deviceId;

  /// Gets drill ID from data (if applicable)
  String? get drillId => data['drillId'] as String?;

  /// Gets drill data from payload (if applicable)
  Map<String, dynamic>? get drillData => data['drillData'] as Map<String, dynamic>?;

  /// Gets chat message content (if applicable)
  String? get chatMessage => data['message'] as String?;

  /// JSON serialization
  factory SyncMessage.fromJson(Map<String, dynamic> json) =>
      _$SyncMessageFromJson(json);
  
  Map<String, dynamic> toJson() => _$SyncMessageToJson(this);

  @override
  List<Object?> get props => [
        type,
        senderId,
        senderName,
        targetId,
        data,
        timestamp,
        messageId,
      ];
}

/// Synchronization message types
enum SyncMessageType {
  @JsonValue('drill_start')
  drillStart,
  
  @JsonValue('drill_stop')
  drillStop,
  
  @JsonValue('drill_pause')
  drillPause,
  
  @JsonValue('drill_resume')
  drillResume,
  
  @JsonValue('participant_join')
  participantJoin,
  
  @JsonValue('participant_leave')
  participantLeave,
  
  @JsonValue('session_status')
  sessionStatus,
  
  @JsonValue('heartbeat')
  heartbeat,
  
  @JsonValue('chat')
  chat,
  
  @JsonValue('drill_content')
  drillContent,
  
  @JsonValue('drill_stimulus')
  drillStimulus,
  
  @JsonValue('drill_score_update')
  drillScoreUpdate,
  
  @JsonValue('drill_rep_complete')
  drillRepComplete,
}

/// Extension for message type display
extension SyncMessageTypeExtension on SyncMessageType {
  String get displayName {
    switch (this) {
      case SyncMessageType.drillStart:
        return 'Drill Started';
      case SyncMessageType.drillStop:
        return 'Drill Stopped';
      case SyncMessageType.drillPause:
        return 'Drill Paused';
      case SyncMessageType.drillResume:
        return 'Drill Resumed';
      case SyncMessageType.participantJoin:
        return 'Participant Joined';
      case SyncMessageType.participantLeave:
        return 'Participant Left';
      case SyncMessageType.sessionStatus:
        return 'Session Update';
      case SyncMessageType.heartbeat:
        return 'Heartbeat';
      case SyncMessageType.chat:
        return 'Chat Message';
      case SyncMessageType.drillContent:
        return 'Drill Content';
      case SyncMessageType.drillStimulus:
        return 'Drill Stimulus';
      case SyncMessageType.drillScoreUpdate:
        return 'Score Update';
      case SyncMessageType.drillRepComplete:
        return 'Rep Complete';
    }
  }

  bool get isDrillControl {
    return this == SyncMessageType.drillStart ||
           this == SyncMessageType.drillStop ||
           this == SyncMessageType.drillPause ||
           this == SyncMessageType.drillResume;
  }

  bool get isParticipantControl {
    return this == SyncMessageType.participantJoin ||
           this == SyncMessageType.participantLeave;
  }
}
