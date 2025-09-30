import 'dart:async';
import 'package:brainblot_app/features/drills/data/session_repository.dart';
import 'package:brainblot_app/features/drills/domain/session_result.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveSessionRepository implements SessionRepository {
  final Box _box = Hive.box('sessions');
  final _controller = StreamController<List<SessionResult>>.broadcast();

  HiveSessionRepository() {
    _initializeWithSampleData();
    _emit();
    _box.watch().listen((_) => _emit());
  }

  Future<void> _initializeWithSampleData() async {
    // Add sample data if box is empty for testing purposes
    if (_box.isEmpty) {
      await _addSampleSessions();
    }
  }

  Future<void> _addSampleSessions() async {
    final now = DateTime.now();
    
    // Sample drill for testing
    final sampleDrill = Drill(
      id: 'sample_drill_1',
      name: 'Reaction Training',
      category: 'fitness',
      difficulty: Difficulty.beginner,
      durationSec: 30,
      restSec: 5,
      reps: 1,
      stimulusTypes: [StimulusType.color],
      numberOfStimuli: 10,
      zones: [ReactionZone.center],
      colors: [Colors.red, Colors.blue, Colors.green],
      isPreset: true,
    );
    
    // Create sample sessions with different performance levels
    final sessions = [
      SessionResult(
        id: 'session_1',
        drill: sampleDrill,
        startedAt: now.subtract(const Duration(days: 7)),
        endedAt: now.subtract(const Duration(days: 7)).add(const Duration(seconds: 30)),
        events: _generateSampleEvents(10, 320, 0.85),
      ),
      SessionResult(
        id: 'session_2',
        drill: sampleDrill,
        startedAt: now.subtract(const Duration(days: 5)),
        endedAt: now.subtract(const Duration(days: 5)).add(const Duration(seconds: 30)),
        events: _generateSampleEvents(10, 295, 0.90),
      ),
      SessionResult(
        id: 'session_3',
        drill: sampleDrill,
        startedAt: now.subtract(const Duration(days: 3)),
        endedAt: now.subtract(const Duration(days: 3)).add(const Duration(seconds: 30)),
        events: _generateSampleEvents(10, 280, 0.95),
      ),
      SessionResult(
        id: 'session_4',
        drill: sampleDrill,
        startedAt: now.subtract(const Duration(days: 1)),
        endedAt: now.subtract(const Duration(days: 1)).add(const Duration(seconds: 30)),
        events: _generateSampleEvents(10, 275, 0.90),
      ),
    ];
    
    for (final session in sessions) {
      await _box.put(session.id, session.toMap());
    }
  }
  
  List<ReactionEvent> _generateSampleEvents(int count, int avgReactionMs, double accuracy) {
    final events = <ReactionEvent>[];
    final correctCount = (count * accuracy).round();
    
    for (int i = 0; i < count; i++) {
      final isCorrect = i < correctCount;
      final reactionTime = isCorrect 
        ? avgReactionMs + (i % 2 == 0 ? -20 : 20) + (i * 5)
        : null;
      
      events.add(ReactionEvent(
        stimulusIndex: i,
        stimulusTimeMs: i * 2000,
        stimulusLabel: 'stimulus_$i',
        reactionTimeMs: reactionTime,
        correct: isCorrect,
      ));
    }
    
    return events;
  }

  void _emit() {
    final items = _box.values
        .whereType<Map>()
        .map((e) => SessionResult.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    // Sort newest first
    items.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    _controller.add(items);
  }

  @override
  Future<void> save(SessionResult result) async {
    await _box.put(result.id, result.toMap());
    await _syncToCloud(result);
  }

  @override
  Stream<List<SessionResult>> watchAll() => _controller.stream;

  Future<void> _syncToCloud(SessionResult result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc(result.id)
        .set(result.toMap());
  }
}
