import 'package:brainblot_app/features/drills/domain/drill.dart';

class ReactionEvent {
  final int stimulusIndex;
  final int stimulusTimeMs;
  final String stimulusLabel; // e.g., color/arrow/number
  final int? reactionTimeMs; // null if missed
  final bool correct;
  const ReactionEvent({
    required this.stimulusIndex,
    required this.stimulusTimeMs,
    required this.stimulusLabel,
    required this.reactionTimeMs,
    required this.correct,
  });

  Map<String, dynamic> toMap() => {
        'stimulusIndex': stimulusIndex,
        'stimulusTimeMs': stimulusTimeMs,
        'stimulusLabel': stimulusLabel,
        'reactionTimeMs': reactionTimeMs,
        'correct': correct,
      };

  static ReactionEvent fromMap(Map<String, dynamic> map) => ReactionEvent(
        stimulusIndex: map['stimulusIndex'] as int,
        stimulusTimeMs: map['stimulusTimeMs'] as int,
        stimulusLabel: map['stimulusLabel'] as String,
        reactionTimeMs: map['reactionTimeMs'] as int?,
        correct: map['correct'] as bool,
      );
}

class SessionResult {
  final String id;
  final Drill drill;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<ReactionEvent> events;

  const SessionResult({
    required this.id,
    required this.drill,
    required this.startedAt,
    required this.endedAt,
    required this.events,
  });

  int get durationMs => endedAt.millisecondsSinceEpoch - startedAt.millisecondsSinceEpoch;
  int get totalStimuli => events.length;
  int get hits => events.where((e) => e.correct).length;
  int get misses => totalStimuli - hits;
  double get accuracy => totalStimuli == 0 ? 0 : hits / totalStimuli;
  double get avgReactionMs {
    final rts = events.where((e) => e.reactionTimeMs != null && e.correct).map((e) => e.reactionTimeMs!).toList();
    if (rts.isEmpty) return 0;
    return rts.reduce((a, b) => a + b) / rts.length;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'drill': drill.toMap(),
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endedAt': endedAt.millisecondsSinceEpoch,
        'events': events.map((e) => e.toMap()).toList(),
      };

  static SessionResult fromMap(Map<String, dynamic> map) => SessionResult(
        id: map['id'] as String,
        drill: Drill.fromMap(Map<String, dynamic>.from(map['drill'] as Map)),
        startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
        endedAt: DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int),
        events: (map['events'] as List).map((e) => ReactionEvent.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      );
}
