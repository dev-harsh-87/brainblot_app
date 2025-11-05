import 'package:spark_app/core/services/auto_refresh_service.dart';
import 'package:spark_app/features/programs/data/program_repository.dart';
import 'package:spark_app/features/programs/domain/program.dart';
import 'package:spark_app/core/di/injection.dart';

/// Service to handle program creation with auto-refresh integration
class ProgramCreationService {
  final ProgramRepository _programRepository;
  final AutoRefreshService _autoRefreshService;

  ProgramCreationService({
    ProgramRepository? programRepository,
    AutoRefreshService? autoRefreshService,
  }) : _programRepository = programRepository ?? getIt<ProgramRepository>(),
        _autoRefreshService = autoRefreshService ?? AutoRefreshService();

  /// Create a new program and trigger auto-refresh
  Future<String> createProgram(Program program) async {
    try {
      // Create the program
      await _programRepository.createProgram(program);
      
      // Trigger auto-refresh for related data
      _autoRefreshService.onProgramChanged();
      
      return program.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing program and trigger auto-refresh
  Future<void> updateProgram(Program program) async {
    try {
      // Update the program
      await _programRepository.updateProgram(program);
      
      // Trigger auto-refresh for related data
      _autoRefreshService.onProgramChanged();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a program and trigger auto-refresh
  Future<void> deleteProgram(String programId) async {
    try {
      // Delete the program
      await _programRepository.deleteProgram(programId);
      
      // Trigger auto-refresh for related data
      _autoRefreshService.onProgramChanged();
    } catch (e) {
      rethrow;
    }
  }

  /// Join a program and trigger auto-refresh
  Future<void> joinProgram(String programId) async {
    try {
      // TODO: Implement join program logic when repository supports it
      // For now, just trigger refresh
      
      // Trigger auto-refresh for programs and stats
      _autoRefreshService.scheduleMultipleRefresh([
        AutoRefreshService.programs,
        AutoRefreshService.stats,
        AutoRefreshService.profile,
      ]);
    } catch (e) {
      rethrow;
    }
  }

  /// Leave a program and trigger auto-refresh
  Future<void> leaveProgram(String programId) async {
    try {
      // TODO: Implement leave program logic when repository supports it
      // For now, just trigger refresh
      
      // Trigger auto-refresh for programs and stats
      _autoRefreshService.scheduleMultipleRefresh([
        AutoRefreshService.programs,
        AutoRefreshService.stats,
        AutoRefreshService.profile,
      ]);
    } catch (e) {
      rethrow;
    }
  }

  /// Complete a program day and trigger auto-refresh
  Future<void> completeProgramDay({
    required String programId,
    required int dayNumber,
    required Map<String, dynamic> completionData,
  }) async {
    try {
      // Record day completion (implement based on your progress tracking)
      // This would typically update program progress
      
      // Trigger auto-refresh for programs, sessions, stats, and profile
      _autoRefreshService.scheduleMultipleRefresh([
        AutoRefreshService.programs,
        AutoRefreshService.sessions,
        AutoRefreshService.stats,
        AutoRefreshService.profile,
      ]);
    } catch (e) {
      rethrow;
    }
  }

  /// Toggle program favorite status and trigger auto-refresh
  Future<void> toggleFavorite(String programId, bool isFavorite) async {
    try {
      // TODO: Implement toggle favorite logic when repository supports it
      // For now, just trigger refresh
      
      // Trigger auto-refresh for program data
      _autoRefreshService.triggerRefresh(AutoRefreshService.programs);
    } catch (e) {
      rethrow;
    }
  }
}
