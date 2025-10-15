import 'package:flutter/material.dart';

enum Difficulty { beginner, intermediate, advanced }

enum StimulusType { color, shape, arrow, number, audio }

enum ReactionZone { center, top, bottom, left, right, quadrants }

class Drill {
  final String id;
  final String name;
  final String category; // e.g., soccer, hockey, fitness
  final Difficulty difficulty;
  final int durationSec;
  final int restSec;
  final int reps;
  final List<StimulusType> stimulusTypes;
  final int numberOfStimuli; // per rep or per minute depending on design
  final List<ReactionZone> zones;
  final List<Color> colors; // used for color stimulus
  final bool favorite;
  final bool isPreset; // preset vs user-created
  final String? createdBy; // user ID who created the drill
  final List<String> sharedWith; // user IDs who have access to this drill
  final bool isPublic; // whether drill is publicly visible
  final DateTime createdAt; // when the drill was created

  Drill({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.durationSec,
    required this.restSec,
    required this.reps,
    required this.stimulusTypes,
    required this.numberOfStimuli,
    required this.zones,
    required this.colors,
    this.favorite = false,
    this.isPreset = false,
    this.createdBy,
    this.sharedWith = const [],
    this.isPublic = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Drill copyWith({
    String? id,
    String? name,
    String? category,
    Difficulty? difficulty,
    int? durationSec,
    int? restSec,
    int? reps,
    List<StimulusType>? stimulusTypes,
    int? numberOfStimuli,
    List<ReactionZone>? zones,
    List<Color>? colors,
    bool? favorite,
    bool? isPreset,
    String? createdBy,
    List<String>? sharedWith,
    bool? isPublic,
    DateTime? createdAt,
  }) => Drill(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        difficulty: difficulty ?? this.difficulty,
        durationSec: durationSec ?? this.durationSec,
        restSec: restSec ?? this.restSec,
        reps: reps ?? this.reps,
        stimulusTypes: stimulusTypes ?? this.stimulusTypes,
        numberOfStimuli: numberOfStimuli ?? this.numberOfStimuli,
        zones: zones ?? this.zones,
        colors: colors ?? this.colors,
        favorite: favorite ?? this.favorite,
        isPreset: isPreset ?? this.isPreset,
        createdBy: createdBy ?? this.createdBy,
        sharedWith: sharedWith ?? this.sharedWith,
        isPublic: isPublic ?? this.isPublic,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'difficulty': difficulty.name,
        'durationSec': durationSec,
        'restSec': restSec,
        'reps': reps,
        'stimulusTypes': stimulusTypes.map((e) => e.name).toList(),
        'numberOfStimuli': numberOfStimuli,
        'zones': zones.map((e) => e.name).toList(),
        'colors': colors.map((c) => '#${c.value.toRadixString(16).padLeft(8, '0')}').toList(),
        'favorite': favorite,
        'isPreset': isPreset,
        'createdBy': createdBy,
        'sharedWith': sharedWith,
        'isPublic': isPublic,
        'createdAt': createdAt.toIso8601String(),
      };

  static Drill fromMap(Map<String, dynamic> map) => Drill(
        id: map['id'] as String,
        name: map['name'] as String,
        category: map['category'] as String,
        difficulty: Difficulty.values.firstWhere((d) => d.name == map['difficulty']),
        durationSec: map['durationSec'] as int,
        restSec: map['restSec'] as int,
        reps: map['reps'] as int,
        stimulusTypes: (map['stimulusTypes'] as List).map((e) => StimulusType.values.firstWhere((s) => s.name == e)).toList(),
        numberOfStimuli: map['numberOfStimuli'] as int,
        zones: (map['zones'] as List).map((e) => ReactionZone.values.firstWhere((z) => z.name == e)).toList(),
        colors: (map['colors'] as List).map((hex) => Color(int.parse((hex as String).replaceFirst('#', ''), radix: 16))).toList(),
        favorite: (map['favorite'] as bool?) ?? false,
        isPreset: (map['isPreset'] as bool?) ?? false,
        createdBy: map['createdBy'] as String?,
        sharedWith: List<String>.from((map['sharedWith'] as List?) ?? []),
        isPublic: (map['isPublic'] as bool?) ?? false,
        createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      );
}
