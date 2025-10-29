// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionSession _$ConnectionSessionFromJson(Map<String, dynamic> json) =>
    ConnectionSession(
      sessionId: json['sessionId'] as String,
      hostId: json['hostId'] as String,
      hostName: json['hostName'] as String,
      participantIds: (json['participantIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      participantNames: (json['participantNames'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      status: $enumDecode(_$SessionStatusEnumMap, json['status']),
      activeDrillId: json['activeDrillId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActivity: DateTime.parse(json['lastActivity'] as String),
      maxParticipants: (json['maxParticipants'] as num?)?.toInt() ?? 8,
    );

Map<String, dynamic> _$ConnectionSessionToJson(ConnectionSession instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'hostId': instance.hostId,
      'hostName': instance.hostName,
      'participantIds': instance.participantIds,
      'participantNames': instance.participantNames,
      'status': _$SessionStatusEnumMap[instance.status]!,
      'activeDrillId': instance.activeDrillId,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastActivity': instance.lastActivity.toIso8601String(),
      'maxParticipants': instance.maxParticipants,
    };

const _$SessionStatusEnumMap = {
  SessionStatus.waiting: 'waiting',
  SessionStatus.active: 'active',
  SessionStatus.paused: 'paused',
  SessionStatus.completed: 'completed',
  SessionStatus.disconnected: 'disconnected',
};
