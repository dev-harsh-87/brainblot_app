import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/programs/data/program_repository.dart';
import 'package:spark_app/features/programs/domain/program.dart';
import 'package:spark_app/features/programs/services/drill_assignment_service.dart';

class FirebaseProgramRepository implements ProgramRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _uuid = const Uuid();

  // Collections
  static const String _programsCollection = 'programs';
  static const String _activeProgramsCollection = 'active_programs';
  static const String _userProgramsCollection = 'user_programs';

  FirebaseProgramRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // Helper method to get programs shared with the current user (excluding system programs)
  Future<List<Program>> _getSharedPrograms(String userId) async {
    try {
      final sharedPrograms = await _firestore
          .collection(_programsCollection)
          .where('sharedWith', arrayContains: userId)
          .get();
          
      final programs = _mapSnapshotToPrograms(sharedPrograms);
      
      // Filter out system-created programs
      return programs.where((program) => 
        program.createdBy != null && 
        program.createdBy != 'system'
      ).toList();
    } catch (e) {
      print('Error fetching shared programs: $e');
      return [];
    }
  }

  @override
  Stream<List<Program>> watchAll() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection(_programsCollection)
        .where('createdBy', isEqualTo: userId) // Only user-created programs
        .snapshots()
        .asyncMap((snapshot) async {
          try {
            // Get shared programs for current user (excluding system programs)
            final sharedPrograms = await _getSharedPrograms(userId);
            final userPrograms = _mapSnapshotToPrograms(snapshot);
            
            // Combine user-created and shared programs, remove duplicates
            final allPrograms = {...userPrograms, ...sharedPrograms}.toList();
            
            // Sort by createdAt in memory
            allPrograms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            
            return allPrograms;
          } catch (e) {
            developer.log(
              'Error in watchAll',
              error: e,
              name: 'FirebaseProgramRepository',
            );
            return <Program>[];
          }
        });
  }

  @override
  Stream<List<Program>> watchByCategory(String category) {
    return _firestore
        .collection(_programsCollection)
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
          try {
            final programs = _mapSnapshotToPrograms(snapshot);
            // Sort by createdAt in memory
            programs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return programs;
          } catch (e) {
            developer.log(
              'Error in watchByCategory',
              error: e,
              name: 'FirebaseProgramRepository',
            );
            return <Program>[];
          }
        });
  }

  @override
  Stream<List<Program>> watchByLevel(String level) {
    return _firestore
        .collection(_programsCollection)
        .where('level', isEqualTo: level)
        .snapshots()
        .map((snapshot) {
          try {
            final programs = _mapSnapshotToPrograms(snapshot);
            // Sort by createdAt in memory
            programs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return programs;
          } catch (e) {
            developer.log(
              'Error in watchByLevel',
              error: e,
              name: 'FirebaseProgramRepository',
            );
            return <Program>[];
          }
        });
  }

  @override
  Stream<List<Program>> watchFavorites() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value(<Program>[]);
    }

    return _firestore
        .collection(_programsCollection)
        .where('favorite', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          try {
            final programs = _mapSnapshotToPrograms(snapshot);
            // Filter to only show programs user can see (their own or public ones)
            final filtered = programs.where((program) =>
                program.createdBy == userId).toList();
            // Sort by createdAt in memory
            filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return filtered;
          } catch (e) {
            developer.log(
              'Error in watchFavorites',
              error: e,
              name: 'FirebaseProgramRepository',
            );
            return <Program>[];
          }
        });
  }

  @override
  Stream<ActiveProgram?> watchActive() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection(_activeProgramsCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return ActiveProgram.fromJson(doc.data()!);
    });
  }

  @override
  Future<void> setActive(ActiveProgram? active) async {
    final userId = _currentUserId;
    if (userId == null) {
      // For unauthenticated users, we can't store active programs
      // This could be enhanced to use local storage instead
      return;
    }

    if (active == null) {
      // Remove active program
      await _firestore
          .collection(_activeProgramsCollection)
          .doc(userId)
          .delete();
      return;
    }

    final activeWithUser = active.copyWith(userId: userId);
    
    await _firestore
        .collection(_activeProgramsCollection)
        .doc(userId)
        .set(activeWithUser.toJson());
  }

  Future<void> createProgram(Program program) async {
    final userId = _currentUserId;
    
    try {
      // Assign drills to program days
      final drillAssignmentService = getIt<DrillAssignmentService>();
      final daysWithDrills = await drillAssignmentService.assignDrillsToProgram(program);
      
      // Create a properly formatted program with dayWiseDrillIds
      final programWithMetadata = Program(
        id: program.id.isEmpty ? _uuid.v4() : program.id,
        name: program.name,
        description: program.description,
        category: program.category,
        durationDays: program.durationDays,
        days: daysWithDrills, // Use days with assigned drills
        level: program.level,
        createdAt: DateTime.now(),
        createdBy: userId, // Can be null for anonymous users
        favorite: false, // Default to not favorite
        dayWiseDrillIds: program.dayWiseDrillIds.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
        selectedDrillIds: List<String>.from(program.selectedDrillIds ?? []),
      );

      final batch = _firestore.batch();

      // Add to global programs collection (works for both authenticated and anonymous)
      final programRef = _firestore
          .collection(_programsCollection)
          .doc(programWithMetadata.id);
      
      // Convert to JSON and ensure proper formatting for Firestore
      final programData = programWithMetadata.toJson();
      
      // Ensure dayWiseDrillIds is properly formatted as Map<String, dynamic>
      if (programData['dayWiseDrillIds'] != null) {
        final dayWiseDrillIds = <String, dynamic>{};
        (programData['dayWiseDrillIds'] as Map<dynamic, dynamic>).forEach((key, value) {
          if (value is List) {
            dayWiseDrillIds[key.toString()] = value;
          }
        });
        programData['dayWiseDrillIds'] = dayWiseDrillIds;
      }
      
      batch.set(programRef, programData);

      // Add to user's programs collection only if authenticated
      if (userId != null) {
        final userProgramRef = _firestore
            .collection(_userProgramsCollection)
            .doc(userId)
            .collection('programs')
            .doc(programWithMetadata.id);
        batch.set(userProgramRef, {
          'programId': programWithMetadata.id,
          'createdAt': programWithMetadata.createdAt.toIso8601String(),
          'isCustom': true,
        });
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProgram(Program program) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Check if user owns this program
    final programDoc = await _firestore
        .collection(_programsCollection)
        .doc(program.id)
        .get();

    if (!programDoc.exists) {
      throw Exception('Program not found');
    }

    final existingProgram = Program.fromJson({
      'id': programDoc.id,
      ...programDoc.data()!,
    });

    if (existingProgram.createdBy != userId) {
      throw Exception('Not authorized to update this program');
    }

    await _firestore
        .collection(_programsCollection)
        .doc(program.id)
        .update(program.toJson());
  }

  Future<void> deleteProgram(String programId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Check if user owns this program
    final programDoc = await _firestore
        .collection(_programsCollection)
        .doc(programId)
        .get();

    if (!programDoc.exists) {
      throw Exception('Program not found');
    }

    final program = Program.fromJson({
      'id': programDoc.id,
      ...programDoc.data()!,
    });

    if (program.createdBy != userId) {
      throw Exception('Not authorized to delete this program');
    }

    final batch = _firestore.batch();

    // Remove from global programs collection
    final programRef = _firestore
        .collection(_programsCollection)
        .doc(programId);
    batch.delete(programRef);

    // Remove from user's programs collection
    final userProgramRef = _firestore
        .collection(_userProgramsCollection)
        .doc(userId)
        .collection('programs')
        .doc(programId);
    batch.delete(userProgramRef);

    await batch.commit();
  }

  Future<Program?> getProgram(String programId) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    final doc = await _firestore
        .collection(_programsCollection)
        .doc(programId)
        .get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    final sharedWith = List<String>.from((data['sharedWith'] as List<dynamic>?)?.cast<String>() ?? <String>[]);
    final createdBy = data['createdBy'] as String?;

    // Check if user has access (is owner, is public, or is in sharedWith)
    final hasAccess = createdBy == userId ||
                     sharedWith.contains(userId);

    if (!hasAccess) {
      return null; // User doesn't have access to this program
    }

    return Program.fromJson({
      'id': doc.id,
      ...data,
    });
  }

  Stream<List<Program>> watchUserPrograms() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_programsCollection)
        .where('createdBy', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          try {
            final programs = _mapSnapshotToPrograms(snapshot);
            // Sort by createdAt in memory
            programs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return programs;
          } catch (e) {
            developer.log(
              'Error in watchUserPrograms',
              error: e,
              name: 'FirebaseProgramRepository',
            );
            return <Program>[];
          }
        });
  }

  Future<void> updateProgramProgress(String programId, int currentDay) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final activeProgram = ActiveProgram(
      programId: programId,
      currentDay: currentDay,
      startedAt: DateTime.now(),
      userId: userId,
    );

    await setActive(activeProgram);
  }

  Future<void> completeProgram(String programId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Update program progress to completed status
    final progressQuery = await _firestore
        .collection('program_progress')
        .where('userId', isEqualTo: userId)
        .where('programId', isEqualTo: programId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (progressQuery.docs.isNotEmpty) {
      await progressQuery.docs.first.reference.update({
        'status': 'completed',
        'completedAt': DateTime.now().toIso8601String(),
        'stats': {
          'completionPercentage': 100.0,
        },
      });
    }
  }

  Stream<List<String>> watchCompletedPrograms() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('program_progress')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['programId'] as String)
            .toList());
  }

  Future<void> seedDefaultPrograms() async {
    try {
      print('🌱 Seeding default programs...');
      
      // Check if default programs already exist by looking for system programs
      final existingPrograms = await _firestore
          .collection(_programsCollection)
          .limit(5)
          .get();
      
      // Check if we already have some default programs
      final hasDefaultPrograms = existingPrograms.docs.any((doc) {
        final data = doc.data();
        return data['createdBy'] == null || data['createdBy'] == 'system';
      });
      
      if (hasDefaultPrograms) {
        print('✅ Default programs already exist, skipping seeding');
        return; // Default programs already seeded
      }

      final defaultPrograms = _createDefaultPrograms();
      
      // Assign drills to each default program
      final drillAssignmentService = getIt<DrillAssignmentService>();
      final programsWithDrills = <Program>[];
      
      for (final program in defaultPrograms) {
        try {
          final daysWithDrills = await drillAssignmentService.assignDrillsToProgram(program);
          final programWithDrills = Program(
            id: program.id,
            name: program.name,
            description: program.description,
            category: program.category,
            durationDays: program.durationDays,
            days: daysWithDrills,
            level: program.level,
            createdAt: program.createdAt,
            createdBy: 'system', // Mark as system program
            favorite: false,
            dayWiseDrillIds: program.dayWiseDrillIds,
            selectedDrillIds: program.selectedDrillIds,
          );
          programsWithDrills.add(programWithDrills);
          print('✅ Prepared program: ${program.name}');
        } catch (e) {
          print('❌ Failed to prepare program ${program.name}: $e');
          // Continue with other programs even if one fails
        }
      }
      
      if (programsWithDrills.isEmpty) {
        print('❌ No programs to seed');
        return;
      }
      
      final batch = _firestore.batch();

      for (final program in programsWithDrills) {
        final ref = _firestore
            .collection(_programsCollection)
            .doc(program.id);
        
        final programData = program.toJson();
        programData['createdBy'] = 'system'; // Ensure system attribution
        
        batch.set(ref, programData);
      }

      await batch.commit();
      print('🎉 Successfully seeded ${programsWithDrills.length} default programs');
    } catch (e) {
      rethrow;
    }
  }

  List<Program> _createDefaultPrograms() {
    final now = DateTime.now();
    
    final p1 = Program(
      id: _uuid.v4(),
      name: '4-week Agility Boost',
      description: 'Improve your agility and reaction time with progressive training over 4 weeks.',
      category: 'agility',
      durationDays: 28,
      level: 'Beginner',
      createdAt: now,
      createdBy: 'system', // System program
      favorite: false,
      days: List.generate(28, (i) => ProgramDay(
        dayNumber: i + 1, 
        title: 'Day ${i + 1}: ${_getAgilitydayTitle(i + 1)}', 
        description: _getAgilityDayDescription(i + 1), 
        drillId: null // Will be assigned during seeding
      )),
    );
    
    final p2 = Program(
      id: _uuid.v4(),
      name: 'Soccer: Decision Speed',
      description: 'Enhance your soccer decision-making speed and field awareness through targeted training.',
      category: 'soccer',
      durationDays: 21,
      level: 'Intermediate',
      createdAt: now,
      createdBy: 'system',
      favorite: false,
      days: List.generate(21, (i) => ProgramDay(
        dayNumber: i + 1, 
        title: 'Day ${i + 1}: ${_getSoccerDayTitle(i + 1)}', 
        description: _getSoccerDayDescription(i + 1), 
        drillId: null
      )),
    );
    
    final p3 = Program(
      id: _uuid.v4(),
      name: 'Basketball Elite',
      description: 'Elite basketball training focusing on court vision and reaction speed.',
      category: 'basketball',
      durationDays: 14,
      level: 'Advanced',
      createdAt: now,
      createdBy: 'system',
      favorite: false,
      days: List.generate(14, (i) => ProgramDay(
        dayNumber: i + 1, 
        title: 'Day ${i + 1}: ${_getBasketballDayTitle(i + 1)}', 
        description: _getBasketballDayDescription(i + 1), 
        drillId: null
      )),
    );
    
    final p4 = Program(
      id: _uuid.v4(),
      name: 'Tennis Precision',
      description: 'Develop precise timing and anticipation skills for competitive tennis.',
      category: 'tennis',
      durationDays: 35,
      level: 'Intermediate',
      createdAt: now,
      createdBy: 'system',
      favorite: false,
      days: List.generate(35, (i) => ProgramDay(
        dayNumber: i + 1, 
        title: 'Day ${i + 1}: ${_getTennisDayTitle(i + 1)}', 
        description: _getTennisDayDescription(i + 1), 
        drillId: null
      )),
    );
    
    final p5 = Program(
      id: _uuid.v4(),
      name: 'Quick Start Basics',
      description: 'A quick introduction to cognitive training fundamentals for beginners.',
      category: 'general',
      durationDays: 7,
      level: 'Beginner',
      createdAt: now,
      createdBy: 'system',
      favorite: false,
      days: List.generate(7, (i) => ProgramDay(
        dayNumber: i + 1, 
        title: 'Day ${i + 1}: ${_getGeneralDayTitle(i + 1)}', 
        description: _getGeneralDayDescription(i + 1), 
        drillId: null
      )),
    );
    
    return [p1, p2, p3, p4, p5];
  }

  String _getAgilitydayTitle(int day) {
    final titles = [
      'Foundation Building', 'Basic Reactions', 'Speed Development', 'Coordination Focus',
      'Multi-directional Movement', 'Quick Feet Training', 'Rest & Recovery', 'Power Building',
      'Reaction Time Boost', 'Agility Ladder Work', 'Cone Drills', 'Sprint Intervals',
      'Balance Training', 'Rest Day', 'Plyometric Power', 'Direction Changes',
      'Speed Endurance', 'Reactive Agility', 'Competition Prep', 'Peak Performance',
      'Recovery Session', 'Advanced Patterns', 'Sport-Specific Moves', 'Power Testing',
      'Final Preparations', 'Peak Training', 'Active Recovery', 'Program Completion'
    ];
    return titles[(day - 1) % titles.length];
  }

  String _getAgilityDayDescription(int day) {
    if (day <= 7) return 'Building foundational movement patterns and basic reaction skills';
    if (day <= 14) return 'Developing speed and coordination through structured drills';
    if (day <= 21) return 'Advanced agility training with complex movement patterns';
    return 'Peak performance training and program consolidation';
  }

  String _getSoccerDayTitle(int day) {
    final titles = [
      'Ball Control Reactions', 'Passing Decisions', 'Defensive Positioning', 'Attacking Moves',
      'Goalkeeper Training', 'Set Piece Focus', 'Rest Day', 'Match Simulation',
      'Technical Skills', 'Tactical Awareness', 'Physical Conditioning', 'Mental Training',
      'Team Coordination', 'Rest & Recovery', 'Competition Prep', 'Advanced Tactics',
      'Finishing Practice', 'Midfield Play', 'Wing Play', 'Final Assessment', 'Peak Performance'
    ];
    return titles[(day - 1) % titles.length];
  }

  String _getSoccerDayDescription(int day) {
    if (day <= 7) return 'Soccer-specific reaction training and ball control exercises';
    if (day <= 14) return 'Advanced tactical decision-making and positioning drills';
    return 'Match-ready training with complex game scenarios';
  }

  String _getBasketballDayTitle(int day) {
    final titles = [
      'Court Vision', 'Defensive Reactions', 'Shooting Accuracy', 'Ball Handling',
      'Rebounding Skills', 'Fast Break Training', 'Rest Day', 'Game Situations',
      'Footwork Drills', 'Passing Precision', 'Defensive Stance', 'Offensive Moves',
      'Conditioning', 'Competition Ready'
    ];
    return titles[(day - 1) % titles.length];
  }

  String _getBasketballDayDescription(int day) {
    if (day <= 7) return 'Basketball-specific reaction training and skill development';
    return 'Advanced basketball training with game-like scenarios';
  }

  String _getTennisDayTitle(int day) {
    final titles = [
      'Serve Returns', 'Baseline Play', 'Net Approach', 'Volley Training',
      'Footwork Focus', 'Match Play', 'Rest Day', 'Power Training',
      'Precision Shots', 'Court Coverage', 'Mental Toughness', 'Strategy Work',
      'Endurance Building', 'Technical Refinement', 'Competition Prep'
    ];
    return titles[(day - 1) % titles.length];
  }

  String _getTennisDayDescription(int day) {
    final week = (day - 1) ~/ 7 + 1;
    switch (week) {
      case 1: return 'Foundation tennis skills and basic reaction training';
      case 2: return 'Intermediate tennis techniques and court positioning';
      case 3: return 'Advanced tennis strategies and match preparation';
      case 4: return 'Competition-level training and performance optimization';
      default: return 'Peak tennis performance and tournament readiness';
    }
  }

  String _getGeneralDayTitle(int day) {
    final titles = [
      'Introduction', 'Basic Training', 'Skill Building', 'Coordination',
      'Speed Work', 'Power Development', 'Assessment'
    ];
    return titles[day - 1];
  }

  String _getGeneralDayDescription(int day) {
    final descriptions = [
      'Welcome to cognitive training - basic introduction and assessment',
      'Fundamental reaction time and visual processing exercises',
      'Building core cognitive and motor skills',
      'Hand-eye coordination and multi-tasking training',
      'Speed-focused drills and rapid decision making',
      'Power and precision training with complex patterns',
      'Final assessment and progress evaluation'
    ];
    return descriptions[day - 1];
  }

  /// Helper method to safely map Firestore snapshot to Program list
  List<Program> _mapSnapshotToPrograms(QuerySnapshot<Map<String, dynamic>> snapshot) {
    try {
      return snapshot.docs
          .map((doc) {
            try {
              final data = Map<String, dynamic>.from(doc.data() ?? {});
              if (data.isEmpty) return null;
              
              // Convert dayWiseDrillIds from Map<dynamic, dynamic> to Map<String, dynamic>
              final dayWiseDrillIds = <String, dynamic>{};
              if (data['dayWiseDrillIds'] != null) {
                final dayWiseData = data['dayWiseDrillIds'] as Map<dynamic, dynamic>;
                dayWiseData.forEach((key, value) {
                  if (value is List) {
                    dayWiseDrillIds[key.toString()] = value.map((e) => e.toString()).toList();
                  } else if (value is Map) {
                    // Handle case where value might be a MapEntry or similar
                    dayWiseDrillIds[key.toString()] = value.values.map((e) => e.toString()).toList();
                  }
                });
              }
              
              // Convert selectedDrillIds to List<String>
              final selectedDrillIds = (data['selectedDrillIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
              
              // Create a new map with the correct types for Firestore
              final jsonData = Map<String, dynamic>.from(data);
              jsonData['id'] = doc.id;
              
              // Only include dayWiseDrillIds if it's not empty
              if (dayWiseDrillIds.isNotEmpty) {
                jsonData['dayWiseDrillIds'] = dayWiseDrillIds;
              } else {
                jsonData.remove('dayWiseDrillIds');
              }
              
              // Only include selectedDrillIds if it's not empty
              if (selectedDrillIds.isNotEmpty) {
                jsonData['selectedDrillIds'] = selectedDrillIds;
              } else {
                jsonData.remove('selectedDrillIds');
              }
              
              // Convert the data to a format that Program.fromJson can handle
              final programData = Map<String, dynamic>.from(jsonData);
              
              // Ensure required fields have default values
              programData['days'] = programData['days'] ?? [];
              programData['sharedWith'] = programData['sharedWith'] ?? [];
              programData['favorite'] = programData['favorite'] ?? false;
              
              return Program.fromJson(programData);
            } catch (e, stackTrace) {
              developer.log(
                'Error parsing program ${doc.id}',
                error: e,
                stackTrace: stackTrace,
                name: 'FirebaseProgramRepository',
              );
              return null;
            }
          })
          .whereType<Program>()
          .toList();
    } catch (e, stackTrace) {
      developer.log(
        'Error in _mapSnapshotToPrograms',
        error: e,
        stackTrace: stackTrace,
        name: 'FirebaseProgramRepository',
      );
      return [];
    }
  }

  @override
  Future<List<Program>> fetchMyPrograms({String? query, String? category, String? level}) async {
    final userId = _currentUserId;
    if (userId == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection(_programsCollection)
          .where('createdBy', isEqualTo: userId)
          .get();
      
      List<Program> programs = _mapSnapshotToPrograms(snapshot);

      // Apply filters in memory to avoid complex Firestore indexes
      if (category != null && category.isNotEmpty) {
        programs = programs.where((p) => p.category == category).toList();
      }

      if (level != null && level.isNotEmpty) {
        programs = programs.where((p) => p.level == level).toList();
      }

      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        programs = programs.where((program) => 
            program.name.toLowerCase().contains(queryLower)).toList();
      }

      // Sort by createdAt
      programs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return programs;
    } catch (error) {
      developer.log(
        'Failed to fetch my programs',
        error: error,
        name: 'FirebaseProgramRepository',
      );
      throw Exception('Failed to fetch my programs: $error');
    }
  }

  @override
  Future<List<Program>> fetchPublicPrograms({String? query, String? category, String? level}) async {
    final userId = _currentUserId;
    
    try {
      // Start with just public programs to avoid complex index
      final snapshot = await _firestore
          .collection(_programsCollection)
          .get();
      
      List<Program> programs = _mapSnapshotToPrograms(snapshot);

      // Apply all filters in memory to avoid complex indexes
      if (category != null && category.isNotEmpty) {
        programs = programs.where((p) => p.category == category).toList();
      }

      if (level != null && level.isNotEmpty) {
        programs = programs.where((p) => p.level == level).toList();
      }

      // Filter out current user's programs
      if (userId != null) {
        programs = programs.where((program) => program.createdBy != userId).toList();
      }

      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        programs = programs.where((program) => 
            program.name.toLowerCase().contains(queryLower)).toList();
      }

      // Sort by createdAt
      programs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return programs;
    } catch (error) {
      developer.log(
        'Failed to fetch public programs',
        error: error,
        name: 'FirebaseProgramRepository',
      );
      throw Exception('Failed to fetch public programs: $error');
    }
  }

  @override
  Future<List<Program>> fetchAll({String? query, String? category, String? level}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];

      // Get shared programs for current user (excluding system programs)
      final sharedPrograms = await _getSharedPrograms(userId);
      
      // Query for user-created programs only
      final snapshot = await _firestore
          .collection(_programsCollection)
          .where('createdBy', isEqualTo: userId)
          .get();
      
      final userPrograms = _mapSnapshotToPrograms(snapshot);
      
      // Combine and remove duplicates by ID
      final allPrograms = <String, Program>{};
      for (final program in [...userPrograms, ...sharedPrograms]) {
        allPrograms[program.id] = program;
      }

      // Convert back to list
      var result = allPrograms.values.toList();
      
      // Apply filters in memory to avoid complex indexes
      if (category?.isNotEmpty ?? false) {
        result = result.where((p) => p.category == category).toList();
      }
      
      if (level?.isNotEmpty ?? false) {
        result = result.where((p) => p.level == level).toList();
      }
      
      if (query?.isNotEmpty ?? false) {
        final queryLower = query!.toLowerCase();
        result = result.where((program) => 
          program.name.toLowerCase().contains(queryLower) ||
          program.category.toLowerCase().contains(queryLower) ||
          program.level.toLowerCase().contains(queryLower) ||
          program.days.any((day) => 
            day.title.toLowerCase().contains(queryLower) ||
            day.description.toLowerCase().contains(queryLower)
          )
        ).toList();
      }

      // Sort by createdAt
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return result;
    } catch (error) {
      throw Exception('Failed to fetch all programs: $error');
    }
  }

  @override
  Future<List<Program>> fetchFavoritePrograms({String? query, String? category, String? level}) async {
    final userId = _currentUserId;
    if (userId == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection(_programsCollection)
          .where('favorite', isEqualTo: true)
          .get();
      
      List<Program> programs = _mapSnapshotToPrograms(snapshot);

      // Filter to only show programs user can see (their own or public ones)
      programs = programs.where((program) =>
          program.createdBy == userId).toList();

      // Apply filters in memory to avoid complex indexes
      if (category != null && category.isNotEmpty) {
        programs = programs.where((p) => p.category == category).toList();
      }

      if (level != null && level.isNotEmpty) {
        programs = programs.where((p) => p.level == level).toList();
      }

      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        programs = programs.where((program) => 
            program.name.toLowerCase().contains(queryLower)).toList();
      }

      // Sort by createdAt
      programs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return programs;
    } catch (error) {
      developer.log(
        'Failed to fetch favorite programs',
        error: error,
        name: 'FirebaseProgramRepository',
      );
      throw Exception('Failed to fetch favorite programs: $error');
    }
  }

  @override
  Future<void> toggleFavorite(String programId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to favorite programs');
    }

    try {
      final programDoc = await _firestore
          .collection(_programsCollection)
          .doc(programId)
          .get();

      if (!programDoc.exists) {
        throw Exception('Program not found');
      }

      final program = Program.fromJson({
        'id': programDoc.id,
        ...programDoc.data()!,
      });

      // Users can only favorite their own programs
      if (program.createdBy == userId) {
        await _firestore
            .collection(_programsCollection)
            .doc(programId)
            .update({'favorite': !program.favorite});
      }
    } catch (error) {
      throw Exception('Failed to toggle favorite: $error');
    }
  }

  @override
  Future<bool> isFavorite(String programId) async {
    try {
      final programDoc = await _firestore
          .collection(_programsCollection)
          .doc(programId)
          .get();

      if (!programDoc.exists) {
        return false;
      }

      final data = programDoc.data()!;
      return data['favorite'] as bool? ?? false;
    } catch (error) {
      return false;
    }
  }
}
