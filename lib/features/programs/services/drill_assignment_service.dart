import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/programs/domain/program.dart';

class DrillAssignmentService {
  final DrillRepository _drillRepository;

  DrillAssignmentService(this._drillRepository);

  /// Assigns appropriate drills to program days based on category, level, and progression
  Future<List<ProgramDay>> assignDrillsToProgram(Program program) async {
    final allDrills = await _drillRepository.fetchAll();
    final categoryDrills = _filterDrillsByCategory(allDrills, program.category);
    final levelDrills = _filterDrillsByLevel(categoryDrills, program.level);
    
    if (levelDrills.isEmpty) {
      // Fallback to general fitness drills if no category-specific drills found
      final fallbackDrills = _filterDrillsByCategory(allDrills, 'fitness');
      return _assignDrillsToDays(program.days, fallbackDrills, program.level);
    }
    
    return _assignDrillsToDays(program.days, levelDrills, program.level);
  }

  /// Filters drills by category, with fallbacks for similar categories
  List<Drill> _filterDrillsByCategory(List<Drill> drills, String category) {
    // Direct category match
    var categoryDrills = drills.where((drill) => drill.category.toLowerCase() == category.toLowerCase()).toList();
    
    if (categoryDrills.isNotEmpty) {
      return categoryDrills;
    }
    
    // Fallback to related categories
    final relatedCategories = _getRelatedCategories(category);
    for (final relatedCategory in relatedCategories) {
      categoryDrills = drills.where((drill) => drill.category.toLowerCase() == relatedCategory.toLowerCase()).toList();
      if (categoryDrills.isNotEmpty) {
        return categoryDrills;
      }
    }
    
    // Final fallback to general fitness
    return drills.where((drill) => drill.category.toLowerCase() == 'fitness').toList();
  }

  /// Gets related categories for better drill matching
  List<String> _getRelatedCategories(String category) {
    switch (category.toLowerCase()) {
      case 'soccer':
        return ['football', 'agility', 'fitness'];
      case 'basketball':
        return ['agility', 'fitness'];
      case 'tennis':
        return ['agility', 'fitness'];
      case 'football':
        return ['soccer', 'agility', 'fitness'];
      case 'hockey':
        return ['agility', 'fitness'];
      case 'agility':
        return ['fitness'];
      case 'general':
        return ['fitness', 'agility'];
      default:
        return ['fitness', 'agility'];
    }
  }

  /// Filters drills by difficulty level with progressive difficulty
  List<Drill> _filterDrillsByLevel(List<Drill> drills, String level) {
    final targetDifficulty = _mapLevelToDifficulty(level);
    
    // Get drills of target difficulty and one level below for variety
    final suitableDrills = drills.where((drill) {
      switch (targetDifficulty) {
        case Difficulty.beginner:
          return drill.difficulty == Difficulty.beginner;
        case Difficulty.intermediate:
          return drill.difficulty == Difficulty.beginner || drill.difficulty == Difficulty.intermediate;
        case Difficulty.advanced:
          return drill.difficulty == Difficulty.intermediate || drill.difficulty == Difficulty.advanced;
      }
    }).toList();
    
    return suitableDrills;
  }

  /// Maps program level string to drill difficulty enum
  Difficulty _mapLevelToDifficulty(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return Difficulty.beginner;
      case 'intermediate':
        return Difficulty.intermediate;
      case 'advanced':
        return Difficulty.advanced;
      default:
        return Difficulty.beginner;
    }
  }

  /// Assigns drills to program days with progressive difficulty
  List<ProgramDay> _assignDrillsToDays(List<ProgramDay> days, List<Drill> availableDrills, String programLevel) {
    if (availableDrills.isEmpty) {
      return days; // Return original days if no drills available
    }

    final totalDays = days.length;
    final assignedDays = <ProgramDay>[];
    
    for (int i = 0; i < totalDays; i++) {
      final day = days[i];
      final progressRatio = i / (totalDays - 1); // 0.0 to 1.0
      
      // Select drill based on progression through program
      final drill = _selectDrillForDay(availableDrills, progressRatio, programLevel, i);
      
      assignedDays.add(ProgramDay(
        dayNumber: day.dayNumber,
        title: day.title,
        description: drill != null 
            ? '${day.description}\n\nAssigned Drill: ${drill.name}'
            : day.description,
        drillId: drill?.id,
      ));
    }
    
    return assignedDays;
  }

  /// Selects appropriate drill for a specific day based on progression
  Drill? _selectDrillForDay(List<Drill> drills, double progressRatio, String programLevel, int dayIndex) {
    if (drills.isEmpty) return null;
    
    // Group drills by difficulty
    final beginnerDrills = drills.where((d) => d.difficulty == Difficulty.beginner).toList();
    final intermediateDrills = drills.where((d) => d.difficulty == Difficulty.intermediate).toList();
    final advancedDrills = drills.where((d) => d.difficulty == Difficulty.advanced).toList();
    
    // Progressive difficulty selection based on program progression
    List<Drill> candidateDrills;
    
    if (programLevel.toLowerCase() == 'beginner') {
      // Beginner programs: mostly beginner drills, some intermediate later
      candidateDrills = progressRatio < 0.7 ? beginnerDrills : 
                       (intermediateDrills.isNotEmpty ? intermediateDrills : beginnerDrills);
    } else if (programLevel.toLowerCase() == 'intermediate') {
      // Intermediate programs: mix of beginner and intermediate, some advanced later
      if (progressRatio < 0.3) {
        candidateDrills = beginnerDrills.isNotEmpty ? beginnerDrills : intermediateDrills;
      } else if (progressRatio < 0.8) {
        candidateDrills = intermediateDrills.isNotEmpty ? intermediateDrills : beginnerDrills;
      } else {
        candidateDrills = advancedDrills.isNotEmpty ? advancedDrills : intermediateDrills;
      }
    } else {
      // Advanced programs: mix of intermediate and advanced
      candidateDrills = progressRatio < 0.4 ? 
                       (intermediateDrills.isNotEmpty ? intermediateDrills : advancedDrills) :
                       (advancedDrills.isNotEmpty ? advancedDrills : intermediateDrills);
    }
    
    if (candidateDrills.isEmpty) {
      candidateDrills = drills; // Fallback to all available drills
    }
    
    // Select drill with some variety (not always the same drill)
    final drillIndex = dayIndex % candidateDrills.length;
    return candidateDrills[drillIndex];
  }

  /// Gets a specific drill by ID
  Future<Drill?> getDrillById(String drillId) async {
    final allDrills = await _drillRepository.fetchAll();
    try {
      return allDrills.firstWhere((drill) => drill.id == drillId);
    } catch (e) {
      return null;
    }
  }

  /// Gets recommended drills for a specific category and level
  Future<List<Drill>> getRecommendedDrills(String category, String level, {int limit = 10}) async {
    final allDrills = await _drillRepository.fetchAll();
    final categoryDrills = _filterDrillsByCategory(allDrills, category);
    final levelDrills = _filterDrillsByLevel(categoryDrills, level);
    
    // Sort by preset drills first, then by name
    levelDrills.sort((a, b) {
      if (a.isPreset && !b.isPreset) return -1;
      if (!a.isPreset && b.isPreset) return 1;
      return a.name.compareTo(b.name);
    });
    
    return levelDrills.take(limit).toList();
  }
}
