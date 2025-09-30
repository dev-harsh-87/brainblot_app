import 'dart:async';
import 'dart:math';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/features/drills/data/session_repository.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/features/drills/domain/session_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class DrillRunnerScreen extends StatefulWidget {
  final Drill drill;
  const DrillRunnerScreen({super.key, required this.drill});

  @override
  State<DrillRunnerScreen> createState() => _DrillRunnerScreenState();
}

class _DrillRunnerScreenState extends State<DrillRunnerScreen>
    with TickerProviderStateMixin {
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
  
  // Animation controllers
  late AnimationController _stimulusAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _feedbackAnimationController;
  
  late Animation<double> _stimulusScaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _feedbackOpacityAnimation;
  
  // State management
  DrillRunnerState _state = DrillRunnerState.ready;
  String _feedbackText = '';
  Color _feedbackColor = Colors.green;
  
  // Countdown
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _schedule = _generateSchedule(widget.drill);
    _initializeAnimations();
  }
  
  void _initializeAnimations() {
    _stimulusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _feedbackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _stimulusScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _stimulusAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _feedbackOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _feedbackAnimationController,
      curve: Curves.easeOut,
    ));
    
    _pulseAnimationController.repeat(reverse: true);
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
    if (_state != DrillRunnerState.ready) return;
    _startCountdown();
  }
  
  void _startCountdown() {
    setState(() {
      _state = DrillRunnerState.countdown;
      _countdown = 3;
    });
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
        HapticFeedback.lightImpact();
      } else {
        timer.cancel();
        _startDrill();
      }
    });
  }
  
  void _startDrill() {
    setState(() {
      _state = DrillRunnerState.running;
    });
    
    _startedAt = DateTime.now();
    _stopwatch
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 8), _onTick); // ~120 fps
    HapticFeedback.mediumImpact();
  }

  void _onTick(Timer timer) {
    final ms = _stopwatch.elapsedMilliseconds;
    
    // Check for missed stimuli (stimuli that were shown but not responded to)
    if (_current != null && ms > _current!.timeMs + 1500) { // 1.5s timeout for response
      _handleMissedStimulus(_current!);
      _current = null;
    }
    
    // Advance stimulus when time passes
    if (_currentIndex + 1 < _schedule.length && ms >= _schedule[_currentIndex + 1].timeMs) {
      _currentIndex++;
      _current = _schedule[_currentIndex];
      
      // Animate stimulus appearance
      _stimulusAnimationController.reset();
      _stimulusAnimationController.forward();
      
      setState(() {
        _display = _current!.type == StimulusType.color ? '' : _current!.label;
        if (_current!.type == StimulusType.color) {
          _displayColor = _getRandomColor();
        } else {
          _displayColor = Colors.white;
        }
      });
      
      HapticFeedback.lightImpact();
    }

    // End of drill
    if (ms >= widget.drill.durationSec * 1000) {
      _finish();
    } else {
      setState(() {});
    }
  }

  void _registerTap() {
    if (_state != DrillRunnerState.running) return;
    
    final current = _current;
    if (current == null) return;
    
    final rt = _stopwatch.elapsedMilliseconds - current.timeMs;
    final correct = rt >= 0 && rt <= 1000; // within 1s window considered correct
    
    _events.add(ReactionEvent(
      stimulusIndex: current.index,
      stimulusTimeMs: current.timeMs,
      stimulusLabel: current.label.isEmpty ? _displayColor.value.toRadixString(16) : current.label,
      reactionTimeMs: max(0, rt),
      correct: correct,
    ));
    
    if (correct) {
      _score++;
      _showFeedback('Great!', Colors.green);
      HapticFeedback.mediumImpact();
    } else {
      _showFeedback('Too slow!', Colors.red);
      HapticFeedback.heavyImpact();
    }
    
    // Move to next stimulus quickly to avoid double hits
    _current = null;
    setState(() {});
  }

  void _handleMissedStimulus(_Stimulus stimulus) {
    // Record missed stimulus as an event with null reaction time
    _events.add(ReactionEvent(
      stimulusIndex: stimulus.index,
      stimulusTimeMs: stimulus.timeMs,
      stimulusLabel: stimulus.label.isEmpty ? _displayColor.value.toRadixString(16) : stimulus.label,
      reactionTimeMs: null, // null indicates missed stimulus
      correct: false,
    ));
    
    _showFeedback('Missed!', Colors.orange);
    HapticFeedback.lightImpact();
  }

  Color _getRandomColor() {
    final colors = widget.drill.colors;
    if (colors.isEmpty) return Colors.red;
    return colors[Random().nextInt(colors.length)];
  }
  
  void _showFeedback(String text, Color color) {
    setState(() {
      _feedbackText = text;
      _feedbackColor = color;
    });
    
    _feedbackAnimationController.reset();
    _feedbackAnimationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _feedbackAnimationController.reverse();
        }
      });
    });
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    _countdownTimer?.cancel();
    _stopwatch.stop();
    
    // Handle any remaining current stimulus as missed
    if (_current != null) {
      _handleMissedStimulus(_current!);
      _current = null;
    }
    
    // Handle any remaining stimuli in the schedule that weren't shown yet as missed
    final currentTime = _stopwatch.elapsedMilliseconds;
    for (int i = _currentIndex + 1; i < _schedule.length; i++) {
      final stimulus = _schedule[i];
      if (stimulus.timeMs <= currentTime + 1000) { // Only count stimuli that should have appeared
        _events.add(ReactionEvent(
          stimulusIndex: stimulus.index,
          stimulusTimeMs: stimulus.timeMs,
          stimulusLabel: stimulus.label,
          reactionTimeMs: null, // null indicates missed stimulus
          correct: false,
        ));
      }
    }
    
    setState(() {
      _state = DrillRunnerState.finished;
    });
    
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
    
    // Show completion feedback
    HapticFeedback.heavyImpact();
    
    // Navigate to results after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.go('/drill-results', extra: result);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _countdownTimer?.cancel();
    _stopwatch.stop();
    _stimulusAnimationController.dispose();
    _pulseAnimationController.dispose();
    _feedbackAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final elapsed = _stopwatch.elapsedMilliseconds;
    final progress = elapsed / (widget.drill.durationSec * 1000);
    
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _registerTap,
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    Colors.grey.shade900,
                    Colors.black,
                  ],
                ),
              ),
            ),
            
            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Progress and stats header
                  _buildStatsHeader(elapsed, progress),
                  
                  // Main stimulus area
                  Expanded(
                    child: Center(
                      child: _buildStimulusArea(),
                    ),
                  ),
                  
                  // Control buttons
                  _buildControlButtons(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            
            // Feedback overlay
            _buildFeedbackOverlay(),
            
            // Countdown overlay
            if (_state == DrillRunnerState.countdown) _buildCountdownOverlay(),
          ],
        ),
      ),
    );
  }
  
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      title: Text(
        widget.drill.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (_state == DrillRunnerState.running)
          IconButton(
            onPressed: _showPauseDialog,
            icon: const Icon(Icons.pause, color: Colors.white),
          ),
      ],
    );
  }
  
  Widget _buildStatsHeader(int elapsed, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress bar
          Container(
            width: double.infinity,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade400,
                      Colors.purple.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                'Time',
                '${(elapsed / 1000).toStringAsFixed(1)}s',
                Icons.timer,
              ),
              _buildStatItem(
                'Score',
                '$_score',
                Icons.star,
              ),
              _buildStatItem(
                'Accuracy',
                _events.isEmpty ? '0%' : '${((_score / _events.length) * 100).toStringAsFixed(0)}%',
                Icons.gps_fixed,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStimulusArea() {
    return AnimatedBuilder(
      animation: _stimulusScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _stimulusScaleAnimation.value,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _current != null ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 280,
                  height: 280,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _current?.type == StimulusType.color 
                        ? _displayColor 
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _current != null 
                          ? Colors.white.withOpacity(0.8) 
                          : Colors.white.withOpacity(0.3),
                      width: 3,
                    ),
                    boxShadow: _current != null ? [
                      BoxShadow(
                        color: (_current?.type == StimulusType.color 
                            ? _displayColor 
                            : Colors.white).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ] : null,
                  ),
                  child: Text(
                    _display,
                    style: TextStyle(
                      color: _current?.type == StimulusType.color 
                          ? Colors.white 
                          : Colors.white,
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          if (_state == DrillRunnerState.ready) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Drill'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else if (_state == DrillRunnerState.running) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.stop),
                label: const Text('End Early'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else if (_state == DrillRunnerState.finished) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check),
                label: const Text('Completed!'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFeedbackOverlay() {
    return AnimatedBuilder(
      animation: _feedbackOpacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _feedbackOpacityAnimation.value,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _feedbackColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                _feedbackText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Get Ready!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '$_countdown',
              style: TextStyle(
                color: Colors.white,
                fontSize: 120,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showPauseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Pause Drill'),
        content: const Text('The drill is paused. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Resume'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _finish();
            },
            child: const Text('End Drill'),
          ),
        ],
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

enum DrillRunnerState {
  ready,
  countdown,
  running,
  finished,
}
