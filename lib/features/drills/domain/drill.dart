import 'package:flutter/material.dart';

enum Difficulty { beginner, intermediate, advanced }

enum StimulusType { color, shape, arrow, number }

enum PresentationMode { visual, audio }

enum ReactionZone { center, top, bottom, left, right, quadrants }

class Drill {
  final String id;
  final String name;
  final String category; // e.g., soccer, hockey, fitness
  final Difficulty difficulty;
  final int durationSec;
  final int restSec;
  final int sets; // number of sets to perform
  final int reps; // repetitions per set
  final List<StimulusType> stimulusTypes;
  final int numberOfStimuli; // per rep or per minute depending on design
  final List<ReactionZone> zones;
  final List<Color> colors; // used for color stimulus
  final PresentationMode presentationMode; // visual or audio presentation
  final bool favorite;
  final bool isPreset; // preset vs user-created
  final String? createdBy; // user ID who created the drill
  final List<String> sharedWith; // user IDs who have access to this drill
  final DateTime createdAt; // when the drill was created

  Drill({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.durationSec,
    required this.restSec,
    this.sets = 1, // default to 1 set
    required this.reps,
    required this.stimulusTypes,
    required this.numberOfStimuli,
    required this.zones,
    required this.colors,
    this.presentationMode = PresentationMode.visual, // default to visual
    this.favorite = false,
    this.isPreset = false,
    this.createdBy,
    this.sharedWith = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Drill copyWith({
    String? id,
    String? name,
    String? category,
    Difficulty? difficulty,
    int? durationSec,
    int? restSec,
    int? sets,
    int? reps,
    List<StimulusType>? stimulusTypes,
    int? numberOfStimuli,
    List<ReactionZone>? zones,
    List<Color>? colors,
    PresentationMode? presentationMode,
    bool? favorite,
    bool? isPreset,
    String? createdBy,
    List<String>? sharedWith,
    DateTime? createdAt,
  }) => Drill(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        difficulty: difficulty ?? this.difficulty,
        durationSec: durationSec ?? this.durationSec,
        restSec: restSec ?? this.restSec,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        stimulusTypes: stimulusTypes ?? this.stimulusTypes,
        numberOfStimuli: numberOfStimuli ?? this.numberOfStimuli,
        zones: zones ?? this.zones,
        colors: colors ?? this.colors,
        presentationMode: presentationMode ?? this.presentationMode,
        favorite: favorite ?? this.favorite,
        isPreset: isPreset ?? this.isPreset,
        createdBy: createdBy ?? this.createdBy,
        sharedWith: sharedWith ?? this.sharedWith,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'difficulty': difficulty.name,
        'durationSec': durationSec,
        'restSec': restSec,
        'sets': sets,
        'reps': reps,
        'stimulusTypes': stimulusTypes.map((e) => e.name).toList(),
        'numberOfStimuli': numberOfStimuli,
        'zones': zones.map((e) => e.name).toList(),
        'colors': colors.map((c) => '#${c.value.toRadixString(16).padLeft(8, '0')}').toList(),
        'presentationMode': presentationMode.name,
        'favorite': favorite,
        'isPreset': isPreset,
        'createdBy': createdBy,
        'sharedWith': sharedWith,
        'createdAt': createdAt.toIso8601String(),
      };

  static Drill fromMap(Map<String, dynamic> map) => Drill(
        id: map['id'] as String,
        name: map['name'] as String,
        category: map['category'] as String,
        difficulty: Difficulty.values.firstWhere((d) => d.name == map['difficulty']),
        durationSec: map['durationSec'] as int,
        restSec: map['restSec'] as int,
        sets: (map['sets'] as int?) ?? 1, // default to 1 for backward compatibility
        reps: map['reps'] as int,
        stimulusTypes: (map['stimulusTypes'] as List).map((e) => StimulusType.values.firstWhere((s) => s.name == e)).toList(),
        numberOfStimuli: map['numberOfStimuli'] as int,
        zones: (map['zones'] as List).map((e) => ReactionZone.values.firstWhere((z) => z.name == e)).toList(),
        colors: (map['colors'] as List).map((hex) => Color(int.parse((hex as String).replaceFirst('#', ''), radix: 16))).toList(),
        presentationMode: map['presentationMode'] != null
            ? PresentationMode.values.firstWhere((p) => p.name == map['presentationMode'], orElse: () => PresentationMode.visual)
            : PresentationMode.visual, // default to visual for backward compatibility
        favorite: (map['favorite'] as bool?) ?? false,
        isPreset: (map['isPreset'] as bool?) ?? false,
        createdBy: map['createdBy'] as String?,
        sharedWith: List<String>.from((map['sharedWith'] as List?) ?? []),
        createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      );
}
