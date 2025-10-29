// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncMessage _$SyncMessageFromJson(Map<String, dynamic> json) => SyncMessage(
      type: $enumDecode(_$SyncMessageTypeEnumMap, json['type']),
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      targetId: json['targetId'] as String?,
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      messageId: json['messageId'] as String,
    );

Map<String, dynamic> _$SyncMessageToJson(SyncMessage instance) =>
    <String, dynamic>{
      'type': _$SyncMessageTypeEnumMap[instance.type]!,
      'senderId': instance.senderId,
      'senderName': instance.senderName,
      'targetId': instance.targetId,
      'data': instance.data,
      'timestamp': instance.timestamp.toIso8601String(),
      'messageId': instance.messageId,
    };

const _$SyncMessageTypeEnumMap = {
  SyncMessageType.drillStart: 'drill_start',
  SyncMessageType.drillStop: 'drill_stop',
  SyncMessageType.drillPause: 'drill_pause',
  SyncMessageType.drillResume: 'drill_resume',
  SyncMessageType.participantJoin: 'participant_join',
  SyncMessageType.participantLeave: 'participant_leave',
  SyncMessageType.sessionStatus: 'session_status',
  SyncMessageType.heartbeat: 'heartbeat',
  SyncMessageType.chat: 'chat',
};
