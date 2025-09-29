class ProgramDay {
  final int dayNumber;
  final String title;
  final String description;
  final String? drillId; // optional link to a drill
  const ProgramDay({required this.dayNumber, required this.title, required this.description, this.drillId});
}

class Program {
  final String id;
  final String name;
  final String category; // sport/goal based
  final int totalDays;
  final List<ProgramDay> days;
  final String level; // Beginner/Intermediate/Advanced
  const Program({
    required this.id,
    required this.name,
    required this.category,
    required this.totalDays,
    required this.days,
    required this.level,
  });
}

class ActiveProgram {
  final String programId;
  final int currentDay;
  const ActiveProgram({required this.programId, required this.currentDay});

  ActiveProgram copyWith({String? programId, int? currentDay}) => ActiveProgram(
        programId: programId ?? this.programId,
        currentDay: currentDay ?? this.currentDay,
      );
}
