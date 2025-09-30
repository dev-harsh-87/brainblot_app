import 'dart:async';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

abstract class DrillRepository {
  Future<List<Drill>> fetchAll({String? query, String? category, Difficulty? difficulty});
  Future<Drill> upsert(Drill drill);
  Future<void> delete(String id);
  Stream<List<Drill>> watchAll();
}

class InMemoryDrillRepository implements DrillRepository {
  final _controller = StreamController<List<Drill>>.broadcast();
  final _items = <Drill>[];
  final _uuid = const Uuid();

  InMemoryDrillRepository() {
    _seedPresets();
    _emit();
  }

  void _emit() => _controller.add(List.unmodifiable(_items));

  void _seedPresets() {
    // Comprehensive sample drill data for testing and demonstration
    _items.addAll([
      // Beginner Drills
      Drill(
        id: _uuid.v4(),
        name: 'Basic Colors (Beginner)',
        category: 'fitness',
        difficulty: Difficulty.beginner,
        durationSec: 60,
        restSec: 30,
        reps: 3,
        stimulusTypes: const [StimulusType.color],
        numberOfStimuli: 30,
        zones: const [ReactionZone.center],
        colors: const [Colors.red, Colors.green, Colors.blue, Colors.yellow],
        isPreset: true,
      ),
      Drill(
        id: _uuid.v4(),
        name: 'Simple Shapes',
        category: 'fitness',
        difficulty: Difficulty.beginner,
        durationSec: 45,
        restSec: 20,
        reps: 2,
        stimulusTypes: const [StimulusType.shape],
        numberOfStimuli: 20,
        zones: const [ReactionZone.center],
        colors: const [Colors.blue, Colors.orange],
        isPreset: true,
      ),
      Drill(
        id: _uuid.v4(),
        name: 'Number Recognition',
        category: 'fitness',
        difficulty: Difficulty.beginner,
        durationSec: 50,
        restSec: 25,
        reps: 3,
        stimulusTypes: const [StimulusType.number],
        numberOfStimuli: 25,
        zones: const [ReactionZone.center],
        colors: const [Colors.white],
        isPreset: true,
      ),

      // Soccer Drills
      Drill(
        id: _uuid.v4(),
        name: 'Arrow Decisions (Intermediate)',
        category: 'soccer',
        difficulty: Difficulty.intermediate,
        durationSec: 90,
        restSec: 30,
        reps: 3,
        stimulusTypes: const [StimulusType.arrow],
        numberOfStimuli: 45,
        zones: const [ReactionZone.left, ReactionZone.right, ReactionZone.top, ReactionZone.bottom],
        colors: const [Colors.white],
        isPreset: true,
      ),
      Drill(
        id: _uuid.v4(),
        name: 'Soccer Field Awareness',
        category: 'soccer',
        difficulty: Difficulty.intermediate,
        durationSec: 75,
        restSec: 35,
        reps: 4,
        stimulusTypes: const [StimulusType.color, StimulusType.arrow],
        numberOfStimuli: 40,
        zones: const [ReactionZone.quadrants],
        colors: const [Colors.green, Colors.white, Colors.yellow],
        isPreset: true,
      ),
      Drill(
        id: _uuid.v4(),
        name: 'Advanced Soccer Reactions',
        category: 'soccer',
        difficulty: Difficulty.advanced,
        durationSec: 120,
        restSec: 40,
        reps: 3,
        stimulusTypes: const [StimulusType.color, StimulusType.arrow, StimulusType.shape],
        numberOfStimuli: 65,
        zones: const [ReactionZone.left, ReactionZone.right, ReactionZone.top, ReactionZone.bottom, ReactionZone.center],
        colors: const [Colors.green, Colors.white, Colors.red, Colors.yellow],
        isPreset: true,
      ),

      // Basketball Drills
      Drill(
        id: _uuid.v4(),
        name: 'Court Vision Training',
        category: 'basketball',
        difficulty: Difficulty.intermediate,
        durationSec: 80,
        restSec: 30,
        reps: 3,
        stimulusTypes: const [StimulusType.color, StimulusType.number],
        numberOfStimuli: 35,
        zones: const [ReactionZone.left, ReactionZone.right],
        colors: const [Colors.orange, Colors.black, Colors.white],
        isPreset: true,
      ),
      Drill(
        id: _uuid.v4(),
        name: 'Numbers & Audio Mix (Advanced)',
        category: 'basketball',
        difficulty: Difficulty.advanced,
        durationSec: 120,
        restSec: 45,
        reps: 2,
        stimulusTypes: const [StimulusType.number, StimulusType.audio],
        numberOfStimuli: 60,
        zones: const [ReactionZone.quadrants],
        colors: const [Colors.white],
        isPreset: true,
      ),
      Drill(
        id: _uuid.v4(),
        name: 'Fast Break Reactions',
        category: 'basketball',
        difficulty: Difficulty.advanced,
        durationSec: 100,
        restSec: 35,
        reps: 4,
        stimulusTypes: const [StimulusType.arrow, StimulusType.color],
        numberOfStimuli: 55,
        zones: const [ReactionZone.top, ReactionZone.bottom],
        colors: const [Colors.orange, Colors.red, Colors.blue],
        isPreset: true,
      ),

      // Tennis Drills
      Drill(
        id: _uuid.v4(),
        name: 'Tennis Court Coverage',
        category: 'tennis',
        difficulty: Difficulty.intermediate,
        durationSec: 70,
        restSec: 25,
        reps: 3,
        stimulusTypes: const [StimulusType.color],
        numberOfStimuli: 30,
        zones: const [ReactionZone.left, ReactionZone.right],
        colors: const [Colors.green, Colors.white, Colors.yellow],
        isPreset: true,
      ),
      Drill(
        id: _uuid.v4(),
        name: 'Serve Return Reactions',
        category: 'tennis',
        difficulty: Difficulty.advanced,
        durationSec: 90,
        restSec: 30,
        reps: 3,
        stimulusTypes: const [StimulusType.arrow, StimulusType.shape],
        numberOfStimuli: 45,
        zones: const [ReactionZone.quadrants],
        colors: const [Colors.green, Colors.white],
        isPreset: true,
      ),

      // Hockey Drills
      Drill(
        id: _uuid.v4(),
        name: 'Ice Hockey Awareness',
        category: 'hockey',
        difficulty: Difficulty.intermediate,
        durationSec: 85,
        restSec: 40,
        reps: 3,
        stimulusTypes: const [StimulusType.color, StimulusType.arrow],
        numberOfStimuli: 40,
        zones: const [ReactionZone.left, ReactionZone.right, ReactionZone.center],
        colors: const [Colors.blue, Colors.red, Colors.white],
        isPreset: true,
      ),
      Drill(
        id: _uuid.v4(),
        name: 'Power Play Reactions',
        category: 'hockey',
        difficulty: Difficulty.advanced,
        durationSec: 110,
        restSec: 45,
        reps: 2,
        stimulusTypes: const [StimulusType.color, StimulusType.number, StimulusType.arrow],
        numberOfStimuli: 50,
        zones: const [ReactionZone.quadrants],
        colors: const [Colors.blue, Colors.red, Colors.white, Colors.black],
        isPreset: true,
      ),

      // Volleyball Drills
      Drill(
        id: _uuid.v4(),
        name: 'Volleyball Net Play',
        category: 'volleyball',
        difficulty: Difficulty.intermediate,
        durationSec: 75,
        restSec: 30,
        reps: 3,
        stimulusTypes: const [StimulusType.color, StimulusType.shape],
        numberOfStimuli: 35,
        zones: const [ReactionZone.top, ReactionZone.bottom],
        colors: const [Colors.white, Colors.blue, Colors.yellow],
        isPreset: true,
      ),

      // Football Drills
      Drill(
        id: _uuid.v4(),
        name: 'Quarterback Reads',
        category: 'football',
        difficulty: Difficulty.advanced,
        durationSec: 95,
        restSec: 35,
        reps: 3,
        stimulusTypes: const [StimulusType.number, StimulusType.arrow, StimulusType.color],
        numberOfStimuli: 45,
        zones: const [ReactionZone.left, ReactionZone.right, ReactionZone.center],
        colors: const [Colors.brown, Colors.white, Colors.green],
        isPreset: true,
      ),
      Drill(
        id: _uuid.v4(),
        name: 'Defensive Line Reactions',
        category: 'football',
        difficulty: Difficulty.intermediate,
        durationSec: 80,
        restSec: 30,
        reps: 4,
        stimulusTypes: const [StimulusType.arrow, StimulusType.audio],
        numberOfStimuli: 40,
        zones: const [ReactionZone.left, ReactionZone.right],
        colors: const [Colors.white],
        isPreset: true,
      ),

      // Physiotherapy Drills
      Drill(
        id: _uuid.v4(),
        name: 'Rehabilitation Colors',
        category: 'physiotherapy',
        difficulty: Difficulty.beginner,
        durationSec: 40,
        restSec: 20,
        reps: 2,
        stimulusTypes: const [StimulusType.color],
        numberOfStimuli: 15,
        zones: const [ReactionZone.center],
        colors: const [Colors.red, Colors.blue],
        isPreset: true,
      ),
      Drill(
        id: _uuid.v4(),
        name: 'Cognitive Recovery',
        category: 'physiotherapy',
        difficulty: Difficulty.intermediate,
        durationSec: 60,
        restSec: 30,
        reps: 3,
        stimulusTypes: const [StimulusType.shape, StimulusType.number],
        numberOfStimuli: 25,
        zones: const [ReactionZone.left, ReactionZone.right],
        colors: const [Colors.green, Colors.blue, Colors.orange],
        isPreset: true,
      ),

      // Agility Drills
      Drill(
        id: _uuid.v4(),
        name: 'Multi-Zone Agility',
        category: 'agility',
        difficulty: Difficulty.advanced,
        durationSec: 100,
        restSec: 40,
        reps: 3,
        stimulusTypes: const [StimulusType.color, StimulusType.arrow, StimulusType.shape, StimulusType.number],
        numberOfStimuli: 55,
        zones: const [ReactionZone.left, ReactionZone.right, ReactionZone.top, ReactionZone.bottom, ReactionZone.center],
        colors: const [Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.orange, Colors.purple],
        isPreset: true,
      ),
      Drill(
        id: _uuid.v4(),
        name: 'Speed & Precision',
        category: 'agility',
        difficulty: Difficulty.intermediate,
        durationSec: 65,
        restSec: 25,
        reps: 4,
        stimulusTypes: const [StimulusType.color, StimulusType.shape],
        numberOfStimuli: 35,
        zones: const [ReactionZone.quadrants],
        colors: const [Colors.red, Colors.blue, Colors.green, Colors.yellow],
        isPreset: true,
      ),

      // Lacrosse Drills
      Drill(
        id: _uuid.v4(),
        name: 'Lacrosse Field Vision',
        category: 'lacrosse',
        difficulty: Difficulty.intermediate,
        durationSec: 85,
        restSec: 35,
        reps: 3,
        stimulusTypes: const [StimulusType.color, StimulusType.arrow],
        numberOfStimuli: 40,
        zones: const [ReactionZone.left, ReactionZone.right, ReactionZone.top, ReactionZone.bottom],
        colors: const [Colors.white, Colors.orange, Colors.blue],
        isPreset: true,
      ),
    ]);
  }

  @override
  Future<List<Drill>> fetchAll({String? query, String? category, Difficulty? difficulty}) async {
    Iterable<Drill> out = _items;
    if (query != null && query.isNotEmpty) {
      out = out.where((d) => d.name.toLowerCase().contains(query.toLowerCase()));
    }
    if (category != null && category.isNotEmpty) {
      out = out.where((d) => d.category == category);
    }
    if (difficulty != null) {
      out = out.where((d) => d.difficulty == difficulty);
    }
    return out.toList(growable: false);
  }

  @override
  Future<Drill> upsert(Drill drill) async {
    final idx = _items.indexWhere((e) => e.id == drill.id);
    if (idx == -1) {
      final toAdd = drill.id.isEmpty ? drill.copyWith(id: _uuid.v4()) : drill;
      _items.add(toAdd);
    } else {
      _items[idx] = drill;
    }
    _emit();
    return drill;
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    _emit();
  }

  @override
  Stream<List<Drill>> watchAll() => _controller.stream;
}
