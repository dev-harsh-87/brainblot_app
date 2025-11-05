import 'dart:async';

import 'package:spark_app/features/drills/data/drill_repository.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/programs/domain/program.dart';

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

  /// Assigns drills to program days based on program duration and available drills
  Future<List<ProgramDay>> _assignDrillsToDays(
    List<ProgramDay> programDays,
    List<Drill> availableDrills,
    String programLevel,
  ) async {
    if (availableDrills.isEmpty) {
      // Return empty days if no drills available
      return List<ProgramDay>.generate(
        programDays.length,
        (index) => ProgramDay(
          dayNumber: index + 1,
          title: 'Day ${index + 1}',
          description: 'No drills available',
        ),
      );
    }

    final List<ProgramDay> days = [];
    final int totalDays = programDays.length;
    
    // Calculate how many drills to assign per day based on program duration
    int drillsPerDay;
    if (totalDays <= 7) {
      drillsPerDay = 3; // Shorter programs get more drills per day
    } else if (totalDays <= 14) {
      drillsPerDay = 2;
    } else {
      drillsPerDay = 1; // Longer programs get fewer drills per day
    }

    // Shuffle drills for variety
    availableDrills.shuffle();
    
    // Assign drills to each day
    int drillIndex = 0;
    for (int day = 1; day <= totalDays; day++) {
      // Select drills for this day
      final List<Drill> dayDrills = [];
      for (int i = 0; i < drillsPerDay && availableDrills.isNotEmpty; i++) {
        // Get the next drill, cycling back to start if needed
        final drill = availableDrills[drillIndex % availableDrills.length];
        dayDrills.add(drill);
        drillIndex++;
      }

      // Create the program day
      if (dayDrills.isNotEmpty) {
        // Use the first drill's details for the day
        final mainDrill = dayDrills.first;
        days.add(ProgramDay(
          dayNumber: day,
          title: 'Day $day: ${mainDrill.name}',
          description: 'Complete ${dayDrills.length} drill${dayDrills.length > 1 ? 's' : ''} for today',
          drillId: mainDrill.id,
        ),);
      } else {
        // Fallback if no drills could be assigned
        days.add(ProgramDay(
          dayNumber: day,
          title: 'Day $day',
          description: 'Rest day',
        ),);
      }
    }
    
    return days;
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
    levelDrills
      ..sort((a, b) {
        if (a.isPreset && !b.isPreset) return -1;
        if (!a.isPreset && b.isPreset) return 1;
        return a.name.compareTo(b.name);
      });
    
    return levelDrills.take(limit).toList();
  }
}
