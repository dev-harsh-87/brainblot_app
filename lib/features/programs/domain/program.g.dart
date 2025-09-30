// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProgramDay _$ProgramDayFromJson(Map<String, dynamic> json) => ProgramDay(
      dayNumber: (json['dayNumber'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String,
      drillId: json['drillId'] as String?,
    );

Map<String, dynamic> _$ProgramDayToJson(ProgramDay instance) =>
    <String, dynamic>{
      'dayNumber': instance.dayNumber,
      'title': instance.title,
      'description': instance.description,
      'drillId': instance.drillId,
    };

Program _$ProgramFromJson(Map<String, dynamic> json) => Program(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      totalDays: (json['totalDays'] as num).toInt(),
      days: (json['days'] as List<dynamic>)
          .map((e) => ProgramDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      level: json['level'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String?,
    );

Map<String, dynamic> _$ProgramToJson(Program instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'category': instance.category,
      'totalDays': instance.totalDays,
      'days': instance.days.map((e) => e.toJson()).toList(),
      'level': instance.level,
      'createdAt': instance.createdAt.toIso8601String(),
      'createdBy': instance.createdBy,
    };

ActiveProgram _$ActiveProgramFromJson(Map<String, dynamic> json) =>
    ActiveProgram(
      programId: json['programId'] as String,
      currentDay: (json['currentDay'] as num).toInt(),
      startedAt: DateTime.parse(json['startedAt'] as String),
      userId: json['userId'] as String?,
    );

Map<String, dynamic> _$ActiveProgramToJson(ActiveProgram instance) =>
    <String, dynamic>{
      'programId': instance.programId,
      'currentDay': instance.currentDay,
      'startedAt': instance.startedAt.toIso8601String(),
      'userId': instance.userId,
    };
