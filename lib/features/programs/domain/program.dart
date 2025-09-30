import 'package:json_annotation/json_annotation.dart';

part 'program.g.dart';

@JsonSerializable()
class ProgramDay {
  final int dayNumber;
  final String title;
  final String description;
  final String? drillId; // optional link to a drill
  
  const ProgramDay({
    required this.dayNumber, 
    required this.title, 
    required this.description, 
    this.drillId
  });

  factory ProgramDay.fromJson(Map<String, dynamic> json) => _$ProgramDayFromJson(json);
  Map<String, dynamic> toJson() => _$ProgramDayToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Program {
  final String id;
  final String name;
  final String category; // sport/goal based
  final int totalDays;
  final List<ProgramDay> days;
  final String level; // Beginner/Intermediate/Advanced
  final DateTime createdAt;
  final String? createdBy; // user ID who created the program
  
  const Program({
    required this.id,
    required this.name,
    required this.category,
    required this.totalDays,
    required this.days,
    required this.level,
    required this.createdAt,
    this.createdBy,
  });

  factory Program.fromJson(Map<String, dynamic> json) => _$ProgramFromJson(json);
  Map<String, dynamic> toJson() => _$ProgramToJson(this);
}

@JsonSerializable()
class ActiveProgram {
  final String programId;
  final int currentDay;
  final DateTime startedAt;
  final String? userId;
  
  const ActiveProgram({
    required this.programId, 
    required this.currentDay,
    required this.startedAt,
    this.userId,
  });

  ActiveProgram copyWith({String? programId, int? currentDay, DateTime? startedAt, String? userId}) => ActiveProgram(
        programId: programId ?? this.programId,
        currentDay: currentDay ?? this.currentDay,
        startedAt: startedAt ?? this.startedAt,
        userId: userId ?? this.userId,
      );

  factory ActiveProgram.fromJson(Map<String, dynamic> json) => _$ActiveProgramFromJson(json);
  Map<String, dynamic> toJson() => _$ActiveProgramToJson(this);
}
