/// Helper class for drill validation constants and utilities
class DrillValidationHelper {
  // Duration constants (in seconds)
  static const int minDurationSeconds = 60; // 1 minute minimum
  static const int maxDurationSeconds = 86400; // 24 hours maximum
  
  // Name validation constants
  static const int minNameLength = 3;
  static const int maxNameLength = 100;
  
  // Description validation constants
  static const int maxDescriptionLength = 500;
  
  // Instructions validation constants
  static const int maxInstructionsLength = 1000;
  
  // Memory drill constants
  static const int minMemorySequenceLength = 2;
  static const int maxMemorySequenceLength = 20;
  static const int minMemoryShowTime = 500; // milliseconds
  
  // Attention drill constants
  static const int minAttentionTargetCount = 1;
  static const int maxAttentionTargetCount = 50;
  static const int minAttentionDistractorCount = 0;
  
  // Reaction drill constants
  static const int minReactionInterval = 500; // milliseconds
  static const int maxReactionInterval = 10000; // 10 seconds
  
  // Cognitive drill constants
  static const int minCognitiveComplexity = 1;
  static const int maxCognitiveComplexity = 10;
  
  // Visual drill constants
  static const int minVisualGridSize = 2;
  static const int maxVisualGridSize = 10;
  
  /// Supported drill types
  static const List<String> supportedDrillTypes = [
    'memory',
    'attention', 
    'reaction',
    'cognitive',
    'visual',
  ];
  
  /// Convert seconds to human-readable duration
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '$minutes minute${minutes != 1 ? 's' : ''}';
      } else {
        return '$minutes minute${minutes != 1 ? 's' : ''} $remainingSeconds second${remainingSeconds != 1 ? 's' : ''}';
      }
    } else {
      final hours = seconds ~/ 3600;
      final remainingMinutes = (seconds % 3600) ~/ 60;
      if (remainingMinutes == 0) {
        return '$hours hour${hours != 1 ? 's' : ''}';
      } else {
        return '$hours hour${hours != 1 ? 's' : ''} $remainingMinutes minute${remainingMinutes != 1 ? 's' : ''}';
      }
    }
  }
  
  /// Validate drill name
  static String? validateDrillName(String name) {
    final trimmedName = name.trim();
    
    if (trimmedName.isEmpty) {
      return 'Drill name cannot be empty';
    }
    
    if (trimmedName.length < minNameLength) {
      return 'Drill name must be at least $minNameLength characters long';
    }
    
    if (trimmedName.length > maxNameLength) {
      return 'Drill name cannot exceed $maxNameLength characters';
    }
    
    // Check for invalid characters
    if (trimmedName.contains(RegExp(r'[<>:"/\\|?*]'))) {
      return 'Drill name contains invalid characters';
    }
    
    return null; // Valid
  }
  
  /// Validate drill rest duration
  static String? validateRestDuration(int restSec) {
    if (restSec < 0) {
      return 'Rest duration cannot be negative';
    }
    
    if (restSec > 300) { // 5 minutes
      return 'Rest duration cannot exceed 5 minutes (300 seconds)';
    }
    
    return null; // Valid
  }

  /// Validate drill repetitions
  static String? validateRepetitions(int reps) {
    if (reps < 1) {
      return 'Number of repetitions must be at least 1';
    }
    
    if (reps > 100) {
      return 'Number of repetitions cannot exceed 100';
    }
    
    return null; // Valid
  }

  /// Validate number of stimuli
  static String? validateNumberOfStimuli(int numberOfStimuli) {
    if (numberOfStimuli < 1) {
      return 'Number of stimuli must be at least 1';
    }
    
    if (numberOfStimuli > 50) {
      return 'Number of stimuli cannot exceed 50';
    }
    
    return null; // Valid
  }
  
  /// Validate drill duration
  static String? validateDrillDuration(int duration) {
    if (duration < minDurationSeconds) {
      return 'Drill duration must be at least ${formatDuration(minDurationSeconds)}';
    }
    
    if (duration > maxDurationSeconds) {
      return 'Drill duration cannot exceed ${formatDuration(maxDurationSeconds)}';
    }
    
    return null; // Valid
  }
  
  /// Validate drill category
  static String? validateDrillCategory(String category) {
    final trimmedCategory = category.trim();
    
    if (trimmedCategory.isEmpty) {
      return 'Drill category cannot be empty';
    }
    
    if (trimmedCategory.length > 50) {
      return 'Drill category cannot exceed 50 characters';
    }
    
    return null; // Valid
  }
  
  /// Check if drill type is supported
  static bool isDrillTypeSupported(String drillType) {
    return supportedDrillTypes.contains(drillType.toLowerCase());
  }
  
  /// Get drill type display name
  static String getDrillTypeDisplayName(String drillType) {
    switch (drillType.toLowerCase()) {
      case 'memory':
        return 'Memory Training';
      case 'attention':
        return 'Attention Focus';
      case 'reaction':
        return 'Reaction Time';
      case 'cognitive':
        return 'Cognitive Skills';
      case 'visual':
        return 'Visual Processing';
      default:
        return drillType.toUpperCase();
    }
  }
  
  /// Get recommended duration for drill type
  static int getRecommendedDuration(String drillType) {
    switch (drillType.toLowerCase()) {
      case 'memory':
        return 120; // 2 minutes
      case 'attention':
        return 180; // 3 minutes
      case 'reaction':
        return 90; // 1.5 minutes
      case 'cognitive':
        return 300; // 5 minutes
      case 'visual':
        return 150; // 2.5 minutes
      default:
        return minDurationSeconds; // 1 minute default
    }
  }
  
  /// Get drill difficulty levels
  static List<String> getDifficultyLevels() {
    return ['Beginner', 'Intermediate', 'Advanced', 'Expert'];
  }
  
  /// Get drill categories
  static List<String> getDrillCategories() {
    return [
      'Memory',
      'Attention',
      'Reaction Time',
      'Problem Solving',
      'Visual Processing',
      'Executive Function',
      'Working Memory',
      'Processing Speed',
      'Cognitive Flexibility',
      'Custom',
    ];
  }
}
