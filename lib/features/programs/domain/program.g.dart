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
      description: json['description'] as String?,
      category: json['category'] as String,
      durationDays: (json['totalDays'] as num).toInt(),
      days: (json['days'] as List<dynamic>)
          .map((e) => ProgramDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      level: json['level'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String?,
      createdByRole: json['createdByRole'] as String?,
      sharedWith: (json['sharedWith'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      favorite: json['favorite'] as bool? ?? false,
      dayWiseDrillIds: (json['dayWiseDrillIds'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(int.parse(k),
                (e as List<dynamic>).map((e) => e as String).toList()),
          ) ??
          const {},
      selectedDrillIds: (json['selectedDrillIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ProgramToJson(Program instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'totalDays': instance.durationDays,
      'days': instance.days.map((e) => e.toJson()).toList(),
      'level': instance.level,
      'createdAt': instance.createdAt.toIso8601String(),
      'createdBy': instance.createdBy,
      'createdByRole': instance.createdByRole,
      'sharedWith': instance.sharedWith,
      'favorite': instance.favorite,
      'dayWiseDrillIds':
          instance.dayWiseDrillIds.map((k, e) => MapEntry(k.toString(), e)),
      'selectedDrillIds': instance.selectedDrillIds,
    };

ActiveProgram _$ActiveProgramFromJson(Map<String, dynamic> json) =>
    ActiveProgram(
      programId: json['programId'] as String,
      currentDay: (json['currentDay'] as num).toInt(),
      startedAt: DateTime.parse(json['startedAt'] as String),
      userId: json['userId'] as String?,
      dayCompletionTimes:
          (json['dayCompletionTimes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(int.parse(k), DateTime.parse(e as String)),
      ),
      lastDayCompletedAt: json['lastDayCompletedAt'] == null
          ? null
          : DateTime.parse(json['lastDayCompletedAt'] as String),
    );

Map<String, dynamic> _$ActiveProgramToJson(ActiveProgram instance) =>
    <String, dynamic>{
      'programId': instance.programId,
      'currentDay': instance.currentDay,
      'startedAt': instance.startedAt.toIso8601String(),
      'userId': instance.userId,
      'dayCompletionTimes': instance.dayCompletionTimes
          ?.map((k, e) => MapEntry(k.toString(), e.toIso8601String())),
      'lastDayCompletedAt': instance.lastDayCompletedAt?.toIso8601String(),
    };
