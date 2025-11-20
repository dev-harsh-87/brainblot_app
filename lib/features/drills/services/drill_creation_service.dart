import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/core/services/auto_refresh_service.dart';
import 'package:spark_app/features/drills/data/drill_repository.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/services/drill_validation_helper.dart';

/// Service to handle drill creation with auto-refresh integration
class DrillCreationService {
  final DrillRepository _drillRepository;
  final AutoRefreshService _autoRefreshService;

  DrillCreationService({
    DrillRepository? drillRepository,
    AutoRefreshService? autoRefreshService,
  }) : _drillRepository = drillRepository ?? getIt<DrillRepository>(),
        _autoRefreshService = autoRefreshService ?? AutoRefreshService();

  /// Create a new drill and trigger auto-refresh
  Future<String> createDrill(Drill drill) async {
    try {
      // Debug logging
      print('🔷 Spark 🔍 [DrillCreationService] Creating drill: ${drill.name}');
      print('🔷 Spark 🔍 [DrillCreationService] Stimulus types: ${drill.stimulusTypes}');
      print('🔷 Spark 🔍 [DrillCreationService] Custom stimulus IDs: ${drill.customStimuliIds}');
      
      // Validate drill configuration
      _validateDrillConfiguration(drill);
      
      // Create the drill using upsert
      final createdDrill = await _drillRepository.upsert(drill);
      
      // Debug logging after creation
      print('🔷 Spark 🔍 [DrillCreationService] Created drill ID: ${createdDrill.id}');
      print('🔷 Spark 🔍 [DrillCreationService] Created drill custom stimulus IDs: ${createdDrill.customStimuliIds}');
      
      // Trigger auto-refresh for related data
      _autoRefreshService.onDrillChanged();
      
      return createdDrill.id;
    } catch (e) {
      print('🔷 Spark ❌ [DrillCreationService] Error creating drill: $e');
      rethrow;
    }
  }

  /// Update an existing drill and trigger auto-refresh
  Future<void> updateDrill(Drill drill) async {
    try {
      // Validate drill configuration
      _validateDrillConfiguration(drill);
      
      // Update the drill using upsert
      await _drillRepository.upsert(drill);
      
      // Trigger auto-refresh for related data
      _autoRefreshService.onDrillChanged();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a drill and trigger auto-refresh
  Future<void> deleteDrill(String drillId) async {
    try {
      // Delete the drill
      await _drillRepository.delete(drillId);
      
      // Trigger auto-refresh for related data
      _autoRefreshService.onDrillChanged();
    } catch (e) {
      rethrow;
    }
  }

  /// Toggle drill favorite status and trigger auto-refresh
  Future<void> toggleFavorite(String drillId) async {
    try {
      // Toggle favorite (repository method takes only drillId)
      await _drillRepository.toggleFavorite(drillId);
      
      // Trigger auto-refresh for drill data
      _autoRefreshService.triggerRefresh(AutoRefreshService.drills);
    } catch (e) {
      rethrow;
    }
  }

  /// Complete a drill session and trigger auto-refresh
  Future<void> completeDrillSession({
    required String drillId,
    required Map<String, dynamic> sessionData,
  }) async {
    try {
      // Record session completion (implement based on your session tracking)
      // This would typically save to a sessions collection
      
      // Trigger auto-refresh for sessions, stats, and profile
      _autoRefreshService.onSessionCompleted();
    } catch (e) {
      rethrow;
    }
  }

  /// Validate drill configuration before creation/update
  void _validateDrillConfiguration(Drill drill) {
    // Validate drill name using helper
    final nameError = DrillValidationHelper.validateDrillName(drill.name);
    if (nameError != null) {
      throw ArgumentError(nameError);
    }

    // Validate drill duration using helper - enforces minimum 60 seconds
    final durationError = DrillValidationHelper.validateDrillDuration(drill.durationSec);
    if (durationError != null) {
      throw ArgumentError(durationError);
    }

    // Validate drill category using helper
    final categoryError = DrillValidationHelper.validateDrillCategory(drill.category);
    if (categoryError != null) {
      throw ArgumentError(categoryError);
    }

    // Validate drill difficulty is specified (enum can't be null)
    // No need to check for null since it's a required enum

    // Validate drill-specific properties
    _validateDrillProperties(drill);
  }

  /// Validate drill properties based on the actual Drill class
  void _validateDrillProperties(Drill drill) {
    // Validate rest seconds using helper
    final restError = DrillValidationHelper.validateRestDuration(drill.restSec);
    if (restError != null) {
      throw ArgumentError(restError);
    }

    // Validate repetitions using helper
    final repsError = DrillValidationHelper.validateRepetitions(drill.reps);
    if (repsError != null) {
      throw ArgumentError(repsError);
    }

    // Validate number of stimuli using helper
    final stimuliError = DrillValidationHelper.validateNumberOfStimuli(drill.numberOfStimuli);
    if (stimuliError != null) {
      throw ArgumentError(stimuliError);
    }

    // Validate stimulus types
    if (drill.stimulusTypes.isEmpty) {
      throw ArgumentError('At least one stimulus type must be selected');
    }

    // Validate reaction zones
    if (drill.zones.isEmpty) {
      throw ArgumentError('At least one reaction zone must be selected');
    }

    // Validate colors for color stimulus
    if (drill.stimulusTypes.contains(StimulusType.color) && drill.colors.isEmpty) {
      throw ArgumentError('Colors must be specified when using color stimulus');
    }

    if (drill.colors.length > 10) {
      throw ArgumentError('Cannot have more than 10 colors');
    }

    // Validate custom stimuli
    if (drill.stimulusTypes.contains(StimulusType.custom) && drill.customStimuliIds.isEmpty) {
      throw ArgumentError('Custom stimulus items must be specified when using custom stimulus');
    }

    if (drill.customStimuliIds.length > 20) {
      throw ArgumentError('Cannot have more than 20 custom stimulus items');
    }
  }

}
