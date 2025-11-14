import 'package:flutter/material.dart';

enum Difficulty { beginner, intermediate, advanced }

enum StimulusType { color, shape, arrow, number }

enum PresentationMode { visual, audio }

enum ReactionZone { center, top, bottom, left, right, quadrants }

class Drill {
  final String id;
  final String name;
  final String description; // drill description
  final String category; // e.g., soccer, hockey, fitness
  final Difficulty difficulty;
  final String type; // e.g., reaction, cognitive, physical, mixed
  final List<String> tags; // flexible tagging system
  final int durationSec;
  final int restSec;
  final int sets; // number of sets to perform
  final int reps; // repetitions per set
  final List<StimulusType> stimulusTypes;
  final int numberOfStimuli; // per rep or per minute depending on design
  final List<ReactionZone> zones;
  final List<Color> colors; // used for color stimulus
  final PresentationMode presentationMode; // visual or audio presentation
  final bool favorite; // legacy field - now handled by user_favorites collection
  final bool isPreset; // legacy field - no longer used
  final String? createdBy; // user ID who created the drill
  final String createdByRole; // role of creator (admin, user, coach)
  final String visibility; // public, private, shared
  final List<String> sharedWith; // user IDs who have access to this drill
  final String status; // active, archived, draft
  final DateTime createdAt; // when the drill was created
  final String? videoUrl; // YouTube video URL for drill demonstration
  final String? stepImageUrl; // Image URL for drill step visualization

  Drill({
    required this.id,
    required this.name,
    this.description = '',
    required this.category,
    required this.difficulty,
    this.type = 'reaction',
    this.tags = const [],
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
    this.createdByRole = 'user',
    this.visibility = 'private',
    this.sharedWith = const [],
    this.status = 'active',
    DateTime? createdAt,
    this.videoUrl,
    this.stepImageUrl,
  }) : createdAt = createdAt ?? DateTime.now();

  Drill copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    Difficulty? difficulty,
    String? type,
    List<String>? tags,
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
    String? createdByRole,
    String? visibility,
    List<String>? sharedWith,
    String? status,
    DateTime? createdAt,
    String? videoUrl,
    String? stepImageUrl,
  }) => Drill(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        difficulty: difficulty ?? this.difficulty,
        type: type ?? this.type,
        tags: tags ?? this.tags,
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
        createdByRole: createdByRole ?? this.createdByRole,
        visibility: visibility ?? this.visibility,
        sharedWith: sharedWith ?? this.sharedWith,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        videoUrl: videoUrl ?? this.videoUrl,
        stepImageUrl: stepImageUrl ?? this.stepImageUrl,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'difficulty': difficulty.name,
        'type': type,
        'tags': tags,
        'configuration': {
          'durationSec': durationSec,
          'restSec': restSec,
          'sets': sets,
          'reps': reps,
          'stimulusTypes': stimulusTypes.map((e) => e.name).toList(),
          'numberOfStimuli': numberOfStimuli,
          'zones': zones.map((e) => e.name).toList(),
          'colors': colors.map((c) => '#${c.value.toRadixString(16).padLeft(8, '0')}').toList(),
          'presentationMode': presentationMode.name,
        },
        'media': {
          'videoUrl': videoUrl,
          'stepImageUrl': stepImageUrl,
        },
        'favorite': favorite, // legacy field
        'isPreset': isPreset, // legacy field
        'createdBy': createdBy,
        'createdByRole': createdByRole,
        'visibility': visibility,
        'sharedWith': sharedWith,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        // Also include flat structure for backward compatibility
        'durationSec': durationSec,
        'restSec': restSec,
        'sets': sets,
        'reps': reps,
        'stimulusTypes': stimulusTypes.map((e) => e.name).toList(),
        'numberOfStimuli': numberOfStimuli,
        'zones': zones.map((e) => e.name).toList(),
        'colors': colors.map((c) => '#${c.value.toRadixString(16).padLeft(8, '0')}').toList(),
        'presentationMode': presentationMode.name,
        'videoUrl': videoUrl,
        'stepImageUrl': stepImageUrl,
      };

  static Drill fromMap(Map<String, dynamic> map) {
    // Handle both new nested structure and legacy flat structure
    final config = map['configuration'] as Map<String, dynamic>?;
    final media = map['media'] as Map<String, dynamic>?;
    
    return Drill(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      category: map['category'] as String,
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name == map['difficulty'],
        orElse: () => Difficulty.beginner,
      ),
      type: map['type'] as String? ?? 'reaction',
      tags: List<String>.from((map['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[]),
      
      // Configuration - try nested first, then flat
      durationSec: config?['durationSec'] as int? ?? map['durationSec'] as int? ?? 30,
      restSec: config?['restSec'] as int? ?? map['restSec'] as int? ?? 10,
      sets: config?['sets'] as int? ?? map['sets'] as int? ?? 1,
      reps: config?['reps'] as int? ?? map['reps'] as int? ?? 10,
      stimulusTypes: (config?['stimulusTypes'] as List? ?? map['stimulusTypes'] as List? ?? ['color'])
          .map((e) => StimulusType.values.firstWhere(
                (s) => s.name == e,
                orElse: () => StimulusType.color,
              ))
          .toList(),
      numberOfStimuli: config?['numberOfStimuli'] as int? ?? map['numberOfStimuli'] as int? ?? 4,
      zones: (config?['zones'] as List? ?? map['zones'] as List? ?? ['center'])
          .map((e) => ReactionZone.values.firstWhere(
                (z) => z.name == e,
                orElse: () => ReactionZone.center,
              ))
          .toList(),
      colors: (config?['colors'] as List? ?? map['colors'] as List? ?? ['#FF0000'])
          .map((hex) => Color(int.parse(
                (hex as String).replaceFirst('#', ''),
                radix: 16,
              )))
          .toList(),
      presentationMode: (config?['presentationMode'] ?? map['presentationMode']) != null
          ? PresentationMode.values.firstWhere(
              (p) => p.name == (config?['presentationMode'] ?? map['presentationMode']),
              orElse: () => PresentationMode.visual,
            )
          : PresentationMode.visual,
      
      // Media - try nested first, then flat
      videoUrl: media?['videoUrl'] as String? ?? map['videoUrl'] as String?,
      stepImageUrl: media?['stepImageUrl'] as String? ?? map['stepImageUrl'] as String?,
      
      // Other fields
      favorite: (map['favorite'] as bool?) ?? false,
      isPreset: (map['isPreset'] as bool?) ?? false,
      createdBy: map['createdBy'] as String?,
      createdByRole: map['createdByRole'] as String? ?? 'user',
      visibility: map['visibility'] as String? ?? 'private',
      sharedWith: List<String>.from((map['sharedWith'] as List?) ?? []),
      status: map['status'] as String? ?? 'active',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
