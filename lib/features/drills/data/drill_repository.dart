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
    // Minimal seed for MVP; later expand to 200+ presets.
    _items.addAll([
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
