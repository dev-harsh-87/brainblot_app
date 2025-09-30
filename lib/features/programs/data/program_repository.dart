import 'dart:async';
import 'dart:collection';
import 'package:brainblot_app/features/programs/domain/program.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

abstract class ProgramRepository {
  Stream<List<Program>> watchAll();
  Future<void> createProgram(Program program);
  Future<void> setActive(ActiveProgram? active);
  Stream<ActiveProgram?> watchActive();
  
  // Optional: Add these methods if needed
  Future<void> updateProgram(Program program);
  Future<void> deleteProgram(String programId);
}

class InMemoryProgramRepository implements ProgramRepository {
  final _uuid = const Uuid();
  final _programsCtrl = StreamController<List<Program>>.broadcast();
  final _activeCtrl = StreamController<ActiveProgram?>.broadcast();

  List<Program> _programs = [];
  ActiveProgram? _activeProgram;
  
  // For demo purposes - you can remove this in production
  bool _isInitialized = false;

  InMemoryProgramRepository() {
    _initializeSync();
  }
  
  void _initializeSync() {
    if (!_isInitialized) {
      _programs = _seedPrograms();
      _isInitialized = true;
      // Emit initial data immediately
      _emitPrograms();
      _emitActive();
    }
  }

  List<Program> _seedPrograms() {
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
        drillId: null
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

  void _emitPrograms() {
    if (!_programsCtrl.isClosed) {
      _programsCtrl.add(UnmodifiableListView<Program>(_programs));
    }
  }
  
  void _emitActive() {
    if (!_activeCtrl.isClosed) {
      _activeCtrl.add(_activeProgram);
    }
  }

  @override
  Stream<List<Program>> watchAll() {
    return _programsCtrl.stream.distinct((a, b) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i].id != b[i].id) return false;
      }
      return true;
    });
  }

  @override
  Stream<ActiveProgram?> watchActive() {
    return _activeCtrl.stream.distinct((a, b) => a?.programId == b?.programId);
  }
  
  @override
  Future<void> createProgram(Program program) async {
    await Future.delayed(const Duration(milliseconds: 200)); // Simulate network delay
    _programs = [..._programs, program];
    _programsCtrl.add(_programs);
  }
  
  @override
  Future<void> updateProgram(Program program) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _programs.indexWhere((p) => p.id == program.id);
    if (index != -1) {
      _programs = [
        ..._programs.sublist(0, index),
        program,
        ..._programs.sublist(index + 1)
      ];
      _programsCtrl.add(_programs);
    }
  }
  
  @override
  Future<void> deleteProgram(String programId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _programs = _programs.where((p) => p.id != programId).toList();
    _programsCtrl.add(_programs);
    
    // If the deleted program was active, clear the active program
    if (_activeProgram?.programId == programId) {
      await setActive(null);
    }
  }

  @override
  Future<void> setActive(ActiveProgram? active) async {
    _activeProgram = active;
    _emitActive();
  }
}
