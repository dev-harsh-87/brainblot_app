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
  final String? description; // Made nullable for backward compatibility
  final String category; // sport/goal based
  @JsonKey(name: 'totalDays') // Keep JSON compatibility
  final int durationDays; // renamed from totalDays for clarity
  final List<ProgramDay> days;
  final String level; // Beginner/Intermediate/Advanced
  final DateTime createdAt;
  final String? createdBy; // user ID who created the program
  final List<String> sharedWith; // user IDs who have access to this program
  final bool favorite; // whether program is favorited by current user
  
  // Enhanced features for new program creation
  final Map<int, List<String>> dayWiseDrillIds; // day -> drill IDs
  final List<String> selectedDrillIds; // all selected drill IDs
  
  const Program({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.durationDays,
    required this.days,
    required this.level,
    required this.createdAt,
    this.createdBy,
    this.sharedWith = const [],
    this.favorite = false,
    this.dayWiseDrillIds = const {},
    this.selectedDrillIds = const [],
  });

  // Convenience constructor for enhanced program creation
  const Program.enhanced({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.durationDays,
    required this.createdAt,
    required this.dayWiseDrillIds,
    required this.selectedDrillIds,
    this.createdBy,
    this.sharedWith = const [],
    this.favorite = false,
    this.level = 'Beginner',
  }) : days = const []; // Empty days for enhanced programs

  Program copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    int? durationDays,
    List<ProgramDay>? days,
    String? level,
    DateTime? createdAt,
    String? createdBy,
    List<String>? sharedWith,
    bool? favorite,
    Map<int, List<String>>? dayWiseDrillIds,
    List<String>? selectedDrillIds,
  }) => Program(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        durationDays: durationDays ?? this.durationDays,
        days: days ?? this.days,
        level: level ?? this.level,
        createdAt: createdAt ?? this.createdAt,
        createdBy: createdBy ?? this.createdBy,
        sharedWith: sharedWith ?? this.sharedWith,
        favorite: favorite ?? this.favorite,
        dayWiseDrillIds: dayWiseDrillIds ?? this.dayWiseDrillIds,
        selectedDrillIds: selectedDrillIds ?? this.selectedDrillIds,
      );

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
