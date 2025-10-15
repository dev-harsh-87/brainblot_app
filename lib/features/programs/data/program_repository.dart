import 'dart:async';
import 'dart:collection';
import 'package:brainblot_app/features/programs/domain/program.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

abstract class ProgramRepository {
  Stream<List<Program>> watchAll();
  Stream<List<Program>> watchByCategory(String category);
  Stream<List<Program>> watchByLevel(String level);
  Stream<ActiveProgram?> watchActive();
  Stream<List<Program>> watchFavorites();
  Future<List<Program>> fetchAll({String? query, String? category, String? level});
  Future<List<Program>> fetchMyPrograms({String? query, String? category, String? level});
  Future<List<Program>> fetchPublicPrograms({String? query, String? category, String? level});
  Future<List<Program>> fetchFavoritePrograms({String? query, String? category, String? level});
  Future<void> createProgram(Program program);
  Future<void> updateProgram(Program program);
  Future<void> deleteProgram(String programId);
  Future<void> setActive(ActiveProgram? active);
  Future<void> toggleFavorite(String programId);
  Future<bool> isFavorite(String programId);
}

class InMemoryProgramRepository implements ProgramRepository {
  final _uuid = const Uuid();
  final _programsCtrl = StreamController<List<Program>>.broadcast();
  final _activeCtrl = StreamController<ActiveProgram?>.broadcast();
  
  List<Program> _programs = [];
  ActiveProgram? _activeProgram;

  InMemoryProgramRepository() {
    _emitPrograms();
    _emitActive();
  }

  void _emitPrograms() => _programsCtrl.add(UnmodifiableListView(_programs));
  void _emitActive() => _activeCtrl.add(_activeProgram);

  @override
  Stream<List<Program>> watchAll() => _programsCtrl.stream;

  @override
  Stream<List<Program>> watchByCategory(String category) {
    return _programsCtrl.stream.map((programs) => 
        programs.where((p) => p.category == category).toList());
  }

  @override
  Stream<List<Program>> watchByLevel(String level) {
    return _programsCtrl.stream.map((programs) => 
        programs.where((p) => p.level == level).toList());
  }

  @override
  Stream<ActiveProgram?> watchActive() => _activeCtrl.stream;

  @override
  Stream<List<Program>> watchFavorites() {
    return _programsCtrl.stream.map((programs) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return <Program>[];
      
      return programs.where((p) => 
          p.favorite && 
          (p.createdBy == currentUserId || p.isPublic)
      ).toList();
    });
  }
  
  @override
  Future<void> createProgram(Program program) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User must be logged in to create programs');
    }

    await Future.delayed(const Duration(milliseconds: 200)); // Simulate network delay
    
    // Ensure program belongs to current user and is private by default
    final newProgram = program.copyWith(
      id: program.id.isEmpty ? _uuid.v4() : program.id,
      createdBy: currentUserId,
      isPublic: false, // Private by default
    );
    
    _programs = [..._programs, newProgram];
    _emitPrograms();
  }
  
  @override
  Future<void> updateProgram(Program program) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User must be logged in to update programs');
    }

    await Future.delayed(const Duration(milliseconds: 200));
    final index = _programs.indexWhere((p) => p.id == program.id);
    if (index != -1) {
      // Verify ownership before updating
      final existingProgram = _programs[index];
      if (existingProgram.createdBy != currentUserId) {
        throw Exception('You can only edit your own programs');
      }
      
      _programs = [
        ..._programs.sublist(0, index),
        program,
        ..._programs.sublist(index + 1)
      ];
      _emitPrograms();
    }
  }
  
  @override
  Future<void> deleteProgram(String programId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User must be logged in to delete programs');
    }

    await Future.delayed(const Duration(milliseconds: 200));
    
    final programIndex = _programs.indexWhere((p) => p.id == programId);
    if (programIndex != -1) {
      final program = _programs[programIndex];
      if (program.createdBy != currentUserId) {
        throw Exception('You can only delete your own programs');
      }
      
      _programs = _programs.where((p) => p.id != programId).toList();
      _emitPrograms();
      
      // If the deleted program was active, clear the active program
      if (_activeProgram?.programId == programId) {
        await setActive(null);
      }
    }
  }

  @override
  Future<void> setActive(ActiveProgram? active) async {
    _activeProgram = active;
    _emitActive();
  }

  @override
  Future<List<Program>> fetchMyPrograms({String? query, String? category, String? level}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Get current user from Firebase Auth
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return [];
    
    Iterable<Program> out = _programs.where((program) => program.createdBy == currentUserId);
    
    if (query != null && query.isNotEmpty) {
      out = out.where((p) => p.name.toLowerCase().contains(query.toLowerCase()));
    }
    if (category != null && category.isNotEmpty) {
      out = out.where((p) => p.category == category);
    }
    if (level != null && level.isNotEmpty) {
      out = out.where((p) => p.level == level);
    }
    return out.toList(growable: false);
  }

  @override
  Future<List<Program>> fetchAll({String? query, String? category, String? level}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    Iterable<Program> out = _programs;
    
    if (query != null && query.isNotEmpty) {
      out = out.where((p) => p.name.toLowerCase().contains(query.toLowerCase()));
    }
    if (category != null && category.isNotEmpty) {
      out = out.where((p) => p.category == category);
    }
    if (level != null && level.isNotEmpty) {
      out = out.where((p) => p.level == level);
    }
    return out.toList(growable: false);
  }

  @override
  Future<List<Program>> fetchPublicPrograms({String? query, String? category, String? level}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Get current user from Firebase Auth
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // Only return public programs that are not created by current user
    Iterable<Program> out = _programs.where((program) => 
        program.isPublic && program.createdBy != currentUserId);
    
    if (query != null && query.isNotEmpty) {
      out = out.where((p) => p.name.toLowerCase().contains(query.toLowerCase()));
    }
    if (category != null && category.isNotEmpty) {
      out = out.where((p) => p.category == category);
    }
    if (level != null && level.isNotEmpty) {
      out = out.where((p) => p.level == level);
    }
    return out.toList(growable: false);
  }

  @override
  Future<List<Program>> fetchFavoritePrograms({String? query, String? category, String? level}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Get current user from Firebase Auth
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return [];
    
    // Return favorite programs that user can see (their own or public ones)
    Iterable<Program> out = _programs.where((program) => 
        program.favorite && 
        (program.createdBy == currentUserId || program.isPublic));
    
    if (query != null && query.isNotEmpty) {
      out = out.where((p) => p.name.toLowerCase().contains(query.toLowerCase()));
    }
    if (category != null && category.isNotEmpty) {
      out = out.where((p) => p.category == category);
    }
    if (level != null && level.isNotEmpty) {
      out = out.where((p) => p.level == level);
    }
    return out.toList(growable: false);
  }

  @override
  Future<void> toggleFavorite(String programId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User must be logged in to favorite programs');
    }

    final index = _programs.indexWhere((program) => program.id == programId);
    if (index != -1) {
      final program = _programs[index];
      // Users can only favorite programs they can see (their own or public ones)
      if (program.createdBy == currentUserId || program.isPublic) {
        _programs = [
          ..._programs.sublist(0, index),
          _programs[index].copyWith(favorite: !_programs[index].favorite),
          ..._programs.sublist(index + 1)
        ];
        _emitPrograms();
      }
    }
  }

  @override
  Future<bool> isFavorite(String programId) async {
    final program = _programs.firstWhereOrNull((program) => program.id == programId);
    return program?.favorite ?? false;
  }

  /// Dispose resources when no longer needed
  void dispose() {
    _programsCtrl.close();
    _activeCtrl.close();
  }
}

// Extension to add firstWhereOrNull if not available
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
