import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/features/programs/domain/program.dart';
import 'package:brainblot_app/features/programs/data/program_repository.dart';
import 'package:brainblot_app/features/programs/services/drill_assignment_service.dart';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:uuid/uuid.dart';

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

  @override
  Stream<List<Program>> watchAll() {
    print('🔍 FirebaseProgramRepository: Starting watchAll stream');
    return _firestore
        .collection(_programsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('📊 FirebaseProgramRepository: Received ${snapshot.docs.length} programs from Firestore');
          final programs = snapshot.docs
              .map((doc) {
                try {
                  final data = {
                    'id': doc.id,
                    ...doc.data(),
                  };
                  print('📄 Program data: ${doc.id} - ${data['name']}');
                  return Program.fromJson(data);
                } catch (e) {
                  print('❌ Error parsing program ${doc.id}: $e');
                  return null;
                }
              })
              .where((program) => program != null)
              .cast<Program>()
              .toList();
          print('✅ Successfully parsed ${programs.length} programs');
          return programs;
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
    print('🚀 FirebaseProgramRepository: Starting createProgram');
    print('📝 Program details: ${program.name}, ${program.category}, ${program.totalDays} days');
    
    final userId = _currentUserId;
    print('👤 Current user ID: ${userId ?? "Anonymous"}');
    
    try {
      // Assign drills to program days
      print('🎯 Assigning drills to program days...');
      final drillAssignmentService = getIt<DrillAssignmentService>();
      final daysWithDrills = await drillAssignmentService.assignDrillsToProgram(program);
      print('✅ Assigned drills to ${daysWithDrills.length} days');
      
      final programWithMetadata = Program(
        id: program.id.isEmpty ? _uuid.v4() : program.id,
        name: program.name,
        category: program.category,
        totalDays: program.totalDays,
        days: daysWithDrills, // Use days with assigned drills
        level: program.level,
        createdAt: DateTime.now(),
        createdBy: userId, // Can be null for anonymous users
      );

      print('🆔 Generated program ID: ${programWithMetadata.id}');
      print('📅 Created at: ${programWithMetadata.createdAt}');

      final batch = _firestore.batch();

      // Add to global programs collection (works for both authenticated and anonymous)
      final programRef = _firestore
          .collection(_programsCollection)
          .doc(programWithMetadata.id);
      
      final programJson = programWithMetadata.toJson();
      print('📊 Program created with ${daysWithDrills.where((d) => d.drillId != null).length} drill assignments');
      batch.set(programRef, programJson);
      print('✅ Added program to global collection batch');

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
        print('✅ Added program to user collection batch');
      } else {
        print('ℹ️ Skipping user collection (anonymous user)');
      }

      print('🔄 Committing batch to Firestore...');
      await batch.commit();
      print('🎉 Program created successfully in Firebase with drill assignments!');
    } catch (e) {
      print('❌ Error creating program: $e');
      print('📍 Stack trace: ${StackTrace.current}');
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
    final doc = await _firestore
        .collection(_programsCollection)
        .doc(programId)
        .get();

    if (!doc.exists) return null;

    return Program.fromJson({
      'id': doc.id,
      ...doc.data()!,
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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Program.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
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

    // Remove from active programs
    await _firestore
        .collection(_activeProgramsCollection)
        .doc(userId)
        .delete();

    // Add to completed programs
    await _firestore
        .collection('completed_programs')
        .doc(userId)
        .collection('programs')
        .doc(programId)
        .set({
      'programId': programId,
      'completedAt': DateTime.now().toIso8601String(),
      'userId': userId,
    });
  }

  Stream<List<String>> watchCompletedPrograms() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('completed_programs')
        .doc(userId)
        .collection('programs')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['programId'] as String)
            .toList());
  }

  Future<void> seedDefaultPrograms() async {
    print('🌱 FirebaseProgramRepository: Starting seedDefaultPrograms');
    
    try {
      // Check if default programs already exist
      print('🔍 Checking for existing default programs...');
      final existingPrograms = await _firestore
          .collection(_programsCollection)
          .where('createdBy', isNull: true)
          .limit(1)
          .get();

      print('📊 Found ${existingPrograms.docs.length} existing default programs');
      
      if (existingPrograms.docs.isNotEmpty) {
        print('✅ Default programs already exist, skipping seeding');
        return; // Default programs already seeded
      }

      print('🏗️ Creating default programs...');
      final defaultPrograms = _createDefaultPrograms();
      print('📝 Generated ${defaultPrograms.length} default programs');
      
      // Assign drills to each default program
      final drillAssignmentService = getIt<DrillAssignmentService>();
      final programsWithDrills = <Program>[];
      
      for (final program in defaultPrograms) {
        print('🎯 Assigning drills to program: ${program.name}');
        final daysWithDrills = await drillAssignmentService.assignDrillsToProgram(program);
        final programWithDrills = Program(
          id: program.id,
          name: program.name,
          category: program.category,
          totalDays: program.totalDays,
          days: daysWithDrills,
          level: program.level,
          createdAt: program.createdAt,
          createdBy: program.createdBy,
        );
        programsWithDrills.add(programWithDrills);
        print('✅ Assigned drills to ${daysWithDrills.where((d) => d.drillId != null).length} days');
      }
      
      final batch = _firestore.batch();

      for (final program in programsWithDrills) {
        final ref = _firestore
            .collection(_programsCollection)
            .doc(program.id);
        batch.set(ref, program.toJson());
        print('➕ Added ${program.name} to batch');
      }

      print('🔄 Committing default programs batch to Firestore...');
      await batch.commit();
      print('🎉 Default programs seeded successfully!');
    } catch (e) {
      print('❌ Error seeding default programs: $e');
      print('📍 Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  List<Program> _createDefaultPrograms() {
    final now = DateTime.now();
    
    final p1 = Program(
      id: _uuid.v4(),
      name: '4-week Agility Boost',
      category: 'agility',
      totalDays: 28,
      level: 'Beginner',
      createdAt: now,
      createdBy: null, // System program
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
      category: 'soccer',
      totalDays: 21,
      level: 'Intermediate',
      createdAt: now,
      createdBy: null,
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
      category: 'basketball',
      totalDays: 14,
      level: 'Advanced',
      createdAt: now,
      createdBy: null,
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
      category: 'tennis',
      totalDays: 35,
      level: 'Intermediate',
      createdAt: now,
      createdBy: null,
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
      category: 'general',
      totalDays: 7,
      level: 'Beginner',
      createdAt: now,
      createdBy: null,
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
}
