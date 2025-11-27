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
      // Fallback to all available drills if no category-specific drills found
      return _assignDrillsToDays(program.days, allDrills, program.level);
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
    
    // Final fallback to all drills if no related category drills found
    return drills;
  }

  /// Gets related categories for better drill matching
  /// This provides common fallback categories but is no longer hardcoded to specific sports
  List<String> _getRelatedCategories(String category) {
    // Use a more generic approach - return empty list to use all drills as fallback
    // This allows the system to work with any dynamically added categories
    return [];
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
    // Updated to be more generous and consistent with program creation dialog
    int drillsPerDay;
    if (totalDays <= 30) {
      drillsPerDay = 3; // Programs up to 30 days get 3 drills per day
    } else if (totalDays <= 60) {
      drillsPerDay = 2; // Programs up to 60 days get 2 drills per day
    } else {
      drillsPerDay = 1; // Longer programs get 1 drill per day
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

  /// Assigns drills to program days using the enhanced dayWiseDrillIds format
  /// Returns a Map<int, List<String>> where key is day number and value is list of drill IDs
  Future<Map<int, List<String>>> assignDrillsToProgramEnhanced(Program program) async {
    try {
      // Get all available drills and filter them
      final allDrills = await _drillRepository.fetchAll();
      final categoryDrills = _filterDrillsByCategory(allDrills, program.category);
      final availableDrills = _filterDrillsByLevel(categoryDrills, program.level);
      
      if (availableDrills.isEmpty) {
        print('⚠️ No drills available for category: ${program.category}, level: ${program.level}');
        // Fallback to all drills if no category-specific drills found
        final fallbackDrills = _filterDrillsByLevel(allDrills, program.level);
        if (fallbackDrills.isEmpty) {
          return {};
        }
        return _assignDrillsToEnhancedFormat(program.durationDays, fallbackDrills);
      }

      return _assignDrillsToEnhancedFormat(program.durationDays, availableDrills);
    } catch (e) {
      print('❌ Error in enhanced drill assignment: $e');
      return {};
    }
  }

  /// Helper method to assign drills to the enhanced dayWiseDrillIds format
  Map<int, List<String>> _assignDrillsToEnhancedFormat(int totalDays, List<Drill> availableDrills) {
    final dayWiseDrillIds = <int, List<String>>{};

    // Calculate how many drills to assign per day based on program duration
    // Updated to be more generous and consistent with program creation dialog
    int drillsPerDay;
    if (totalDays <= 30) {
      drillsPerDay = 3; // Programs up to 30 days get 3 drills per day
    } else if (totalDays <= 60) {
      drillsPerDay = 2; // Programs up to 60 days get 2 drills per day
    } else {
      drillsPerDay = 1; // Longer programs get 1 drill per day
    }

    // Shuffle drills for variety
    availableDrills.shuffle();
    
    // Assign drills to each day
    int drillIndex = 0;
    for (int day = 1; day <= totalDays; day++) {
      final dayDrillIds = <String>[];
      
      for (int i = 0; i < drillsPerDay && availableDrills.isNotEmpty; i++) {
        // Get the next drill, cycling back to start if needed
        final drill = availableDrills[drillIndex % availableDrills.length];
        dayDrillIds.add(drill.id);
        drillIndex++;
      }
      
      if (dayDrillIds.isNotEmpty) {
        dayWiseDrillIds[day] = dayDrillIds;
      }
    }
    
    print('✅ Enhanced drill assignment complete: ${dayWiseDrillIds.length} days with drills');
    return dayWiseDrillIds;
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
      .sort((a, b) {
        if (a.isPreset && !b.isPreset) return -1;
        if (!a.isPreset && b.isPreset) return 1;
        return a.name.compareTo(b.name);
      });
    
    return levelDrills.take(limit).toList();
  }
}
