import 'dart:async';
import 'dart:math';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/features/drills/data/session_repository.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/features/drills/domain/session_result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class DrillRunnerScreen extends StatefulWidget {
  final Drill drill;
  const DrillRunnerScreen({super.key, required this.drill});

  @override
  State<DrillRunnerScreen> createState() => _DrillRunnerScreenState();
}

class _DrillRunnerScreenState extends State<DrillRunnerScreen> {
  final _uuid = const Uuid();
  final _stopwatch = Stopwatch();
  Timer? _ticker;

  late DateTime _startedAt;
  DateTime? _endedAt;

  // Pre-generated schedule of stimuli times (ms) within duration
  late final List<_Stimulus> _schedule;
  int _currentIndex = -1;
  _Stimulus? _current;

  // Stats
  int _score = 0;
  final List<ReactionEvent> _events = [];

  // UI
  String _display = '';
  Color _displayColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _schedule = _generateSchedule(widget.drill);
  }

  List<_Stimulus> _generateSchedule(Drill drill) {
    final totalMs = drill.durationSec * 1000;
    final rnd = Random();
    // Spread evenly, add small jitter to avoid predictability
    final baseInterval = (totalMs / max(1, drill.numberOfStimuli)).floor();
    final types = drill.stimulusTypes.isEmpty ? [StimulusType.color] : drill.stimulusTypes;
    final out = <_Stimulus>[];
    for (int i = 0; i < drill.numberOfStimuli; i++) {
      final t = types[i % types.length];
      final targetMs = min(totalMs - 1, (i * baseInterval) + rnd.nextInt(max(1, baseInterval ~/ 3)));
      out.add(_Stimulus(index: i, timeMs: targetMs, type: t, label: _labelFor(t, drill)));
    }
    out.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return out;
  }

  String _labelFor(StimulusType t, Drill drill) {
    switch (t) {
      case StimulusType.arrow:
        const dirs = ['↑', '→', '↓', '←'];
        return dirs[Random().nextInt(dirs.length)];
      case StimulusType.number:
        return (1 + Random().nextInt(9)).toString();
      case StimulusType.shape:
        const shapes = ['●', '■', '▲'];
        return shapes[Random().nextInt(shapes.length)];
      case StimulusType.audio:
        return '♪';
      case StimulusType.color:
      default:
        final colors = drill.colors.isEmpty
            ? [Colors.red, Colors.green, Colors.blue, Colors.yellow]
            : drill.colors;
        final c = colors[Random().nextInt(colors.length)];
        _displayColor = c;
        return '';
    }
  }

  void _start() {
    if (_ticker != null) return;
    _startedAt = DateTime.now();
    _stopwatch
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 8), _onTick); // ~120 fps
  }

  void _onTick(Timer timer) {
    final ms = _stopwatch.elapsedMilliseconds;
    // Advance stimulus when time passes
    if (_currentIndex + 1 < _schedule.length && ms >= _schedule[_currentIndex + 1].timeMs) {
      _currentIndex++;
      _current = _schedule[_currentIndex];
      setState(() {
        _display = _current!.type == StimulusType.color ? '' : _current!.label;
        if (_current!.type == StimulusType.color) {
          // color chosen during label generation
        } else {
          _displayColor = Colors.white;
        }
      });
    }

    // End of drill
    if (ms >= widget.drill.durationSec * 1000) {
      _finish();
    } else {
      setState(() {});
    }
  }

  void _registerTap() {
    final current = _current;
    if (current == null) return;
    final rt = _stopwatch.elapsedMilliseconds - current.timeMs;
    final correct = rt >= 0 && rt <= 1000; // within 1s window considered correct (placeholder rule)
    _events.add(ReactionEvent(
      stimulusIndex: current.index,
      stimulusTimeMs: current.timeMs,
      stimulusLabel: current.label.isEmpty ? _displayColor.value.toRadixString(16) : current.label,
      reactionTimeMs: max(0, rt),
      correct: correct,
    ));
    if (correct) _score++;
    // Move to next stimulus quickly to avoid double hits
    _current = null;
    setState(() {});
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    _stopwatch.stop();
    _endedAt = DateTime.now();
    final result = SessionResult(
      id: _uuid.v4(),
      drill: widget.drill,
      startedAt: _startedAt,
      endedAt: _endedAt!,
      events: List.unmodifiable(_events),
    );
    await getIt<SessionRepository>().save(result);
    if (!mounted) return;
    context.go('/drill-results', extra: result);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _stopwatch.elapsedMilliseconds;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text('Running: ${widget.drill.name}')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _registerTap,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${(elapsed / 1000).toStringAsFixed(2)}s', style: const TextStyle(color: Colors.white, fontSize: 28)),
              const SizedBox(height: 8),
              Text('Score: $_score', style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 24),
              Container(
                width: 220,
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _current?.type == StimulusType.color ? _displayColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(_display, style: TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: _ticker == null ? _start : null,
                    child: const Text('Start'),
                  ),
                  FilledButton(
                    onPressed: _ticker != null ? _finish : null,
                    child: const Text('Finish'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _Stimulus {
  final int index;
  final int timeMs;
  final StimulusType type;
  final String label;
  _Stimulus({required this.index, required this.timeMs, required this.type, required this.label});
}
