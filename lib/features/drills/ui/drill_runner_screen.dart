import 'dart:async';
import 'dart:math';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/drills/data/session_repository.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/domain/session_result.dart';
import 'package:spark_app/features/programs/services/program_progress_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

// Data structures for detailed results tracking
class RepResult {
  final int repNumber;
  final List<ReactionEvent> events;
  final DateTime startTime;
  final DateTime endTime;
  final int score;
  final double averageReactionTime;
  final double accuracy;

  RepResult({
    required this.repNumber,
    required this.events,
    required this.startTime,
    required this.endTime,
    required this.score,
    required this.averageReactionTime,
    required this.accuracy,
  });
}

class SetResult {
  final int setNumber;
  final List<RepResult> repResults;
  final DateTime startTime;
  DateTime? endTime;
  int totalScore;
  double averageReactionTime;
  double accuracy;

  SetResult({
    required this.setNumber,
    required this.repResults,
    required this.startTime,
    this.endTime,
    this.totalScore = 0,
    this.averageReactionTime = 0.0,
    this.accuracy = 0.0,
  });
  
  void updateStats() {
    totalScore = repResults.fold(0, (sum, rep) => sum + rep.score);
    if (repResults.isNotEmpty) {
      averageReactionTime = repResults.map((r) => r.averageReactionTime).reduce((a, b) => a + b) / repResults.length;
      accuracy = repResults.map((r) => r.accuracy).reduce((a, b) => a + b) / repResults.length;
    }
  }
}

class DetailedSessionResult {
  final SessionResult sessionResult;
  final List<SetResult> setResults;
  final double overallAverageReactionTime;
  final double overallAccuracy;
  final int totalScore;

  DetailedSessionResult({
    required this.sessionResult,
    required this.setResults,
    required this.overallAverageReactionTime,
    required this.overallAccuracy,
    required this.totalScore,
  });
}

class DrillRunnerScreen extends StatefulWidget {
  final Drill drill;
  final String? programId;
  final int? programDayNumber;
  final bool isMultiplayerMode;
  final Function(SessionResult)? onDrillComplete;
  
  const DrillRunnerScreen({
    super.key, 
    required this.drill,
    this.programId,
    this.programDayNumber,
    this.isMultiplayerMode = false,
    this.onDrillComplete,
  });

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
  
  // Audio and feedback settings
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _voiceEnabled = true;
  
  // Set and rep tracking
  int _currentSet = 1;
  int _currentRep = 0;
  bool _isInRestPeriod = false;
  Timer? _restTimer;
  int _restCountdown = 0;
  
  // Detailed results tracking for each set and rep
  final List<SetResult> _setResults = [];
  List<ReactionEvent> _currentRepEvents = [];
  DateTime? _currentRepStartTime;
  DateTime? _currentSetStartTime;

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
      
      // Enhanced feedback based on stimulus type
      switch (_current!.type) {
        case StimulusType.audio:
          SystemSound.play(SystemSoundType.click);
          HapticFeedback.mediumImpact();
          break;
        case StimulusType.color:
          HapticFeedback.lightImpact();
          break;
        case StimulusType.shape:
          HapticFeedback.selectionClick();
          break;
        case StimulusType.arrow:
          HapticFeedback.mediumImpact();
          break;
        case StimulusType.number:
          HapticFeedback.lightImpact();
          break;
      }
    }

    // End of current rep
    if (ms >= widget.drill.durationSec * 1000) {
      _completeRep();
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
    
    final event = ReactionEvent(
      stimulusIndex: current.index,
      stimulusTimeMs: current.timeMs,
      stimulusLabel: current.label.isEmpty ? _displayColor.value.toRadixString(16) : current.label,
      reactionTimeMs: max(0, rt),
      correct: correct,
    );
    
    _events.add(event);
    _currentRepEvents.add(event);
    
    if (correct) {
      _score++;
      _showFeedback('Great!', Colors.green);
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    } else {
      _showFeedback('Too slow!', Colors.red);
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }
    
    // Move to next stimulus quickly to avoid double hits
    _current = null;
    setState(() {});
  }

  void _handleMissedStimulus(_Stimulus stimulus) {
    // Record missed stimulus as an event with null reaction time
    final event = ReactionEvent(
      stimulusIndex: stimulus.index,
      stimulusTimeMs: stimulus.timeMs,
      stimulusLabel: stimulus.label.isEmpty ? _displayColor.value.toRadixString(16) : stimulus.label,
      reactionTimeMs: null, // null indicates missed stimulus
      correct: false,
    );
    
    _events.add(event);
    _currentRepEvents.add(event);
    
    _showFeedback('Missed!', Colors.orange);
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.lightImpact();
  }

  Color _getRandomColor() {
    final colors = widget.drill.colors;
    if (colors.isEmpty) return Colors.red;
    return colors[Random().nextInt(colors.length)];
  }
void _completeRep() {
    _ticker?.cancel();
    _stopwatch.stop();
    
    // Save current rep results
    if (_currentRepStartTime != null) {
      final repScore = _currentRepEvents.where((e) => e.correct).length;
      final validReactions = _currentRepEvents.where((e) => e.reactionTimeMs != null).toList();
      final avgReactionTime = validReactions.isEmpty
          ? 0.0
          : validReactions.map((e) => e.reactionTimeMs!).reduce((a, b) => a + b) / validReactions.length;
      final accuracy = _currentRepEvents.isEmpty
          ? 0.0
          : (_currentRepEvents.where((e) => e.correct).length / _currentRepEvents.length) * 100;
      
      final repResult = RepResult(
        repNumber: _currentRep + 1,
        events: List.from(_currentRepEvents),
        startTime: _currentRepStartTime!,
        endTime: DateTime.now(),
        score: repScore,
        averageReactionTime: avgReactionTime,
        accuracy: accuracy,
      );
      
      // Add to current set's rep results
      if (_setResults.isNotEmpty) {
        _setResults.last.repResults.add(repResult);
      }
    }
    
    _currentRep++;
    
    // Check if set is complete
    if (_currentRep >= widget.drill.reps) {
      _completeSet();
    } else {
      // Start rest period between reps if rest time is configured
      if (widget.drill.restSec > 0) {
        _startRestPeriod();
      } else {
        _startNextRep();
      }
    }
  }

  void _completeSet() {
    setState(() {
      _state = DrillRunnerState.finished;
    });
    
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    
    // Show set completion feedback
    _showFeedback('Set ${_currentSet} Complete!', Colors.green);
    
    // Check if all sets are complete
    if (_currentSet >= widget.drill.reps) {
      // All sets complete - finish drill
      Future.delayed(const Duration(milliseconds: 1500), () {
        _finish();
      });
    } else {
      // Start rest period between sets
      _currentSet++;
      _currentRep = 0;
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (widget.drill.restSec > 0) {
          _startRestPeriod();
        } else {
          _startNextRep();
        }
      });
    }
  }

  void _startRestPeriod() {
    setState(() {
      _state = DrillRunnerState.rest;
      _isInRestPeriod = true;
      _restCountdown = widget.drill.restSec;
    });
    
    _showFeedback('Rest Time', Colors.blue);
    
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restCountdown > 1) {
        setState(() {
          _restCountdown--;
        });
        HapticFeedback.lightImpact();
      } else {
        timer.cancel();
        _startNextRep();
      }
    });
  }

  void _startNextRep() {
    setState(() {
      _isInRestPeriod = false;
      _restCountdown = 0;
    });
    
    // Reset for next rep
    _currentIndex = -1;
    _current = null;
    _stopwatch.reset();
    _events.clear();
    _score = 0;
    
    // Start countdown for next rep
    _startCountdown();
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
        final event = ReactionEvent(
          stimulusIndex: stimulus.index,
          stimulusTimeMs: stimulus.timeMs,
          stimulusLabel: stimulus.label,
          reactionTimeMs: null, // null indicates missed stimulus
          correct: false,
        );
        _events.add(event);
        _currentRepEvents.add(event);
      }
    }
    
    // Complete the final rep if in progress
    if (_currentRepStartTime != null && _currentRepEvents.isNotEmpty) {
      final repScore = _currentRepEvents.where((e) => e.correct).length;
      final validReactions = _currentRepEvents.where((e) => e.reactionTimeMs != null).toList();
      final avgReactionTime = validReactions.isEmpty
          ? 0.0
          : validReactions.map((e) => e.reactionTimeMs!).reduce((a, b) => a + b) / validReactions.length;
      final accuracy = _currentRepEvents.isEmpty
          ? 0.0
          : (_currentRepEvents.where((e) => e.correct).length / _currentRepEvents.length) * 100;
      
      final repResult = RepResult(
        repNumber: _currentRep + 1,
        events: List.from(_currentRepEvents),
        startTime: _currentRepStartTime!,
        endTime: DateTime.now(),
        score: repScore,
        averageReactionTime: avgReactionTime,
        accuracy: accuracy,
      );
      
      if (_setResults.isNotEmpty) {
        _setResults.last.repResults.add(repResult);
        _setResults.last.endTime = DateTime.now();
        _setResults.last.updateStats();
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
    
    // Create detailed results with set and rep breakdown
    final totalScore = _setResults.fold(0, (sum, set) => sum + set.totalScore);
    final allReactionTimes = _setResults
        .expand((set) => set.repResults)
        .expand((rep) => rep.events.where((e) => e.reactionTimeMs != null))
        .map((e) => e.reactionTimeMs!)
        .toList();
    final overallAvgReactionTime = allReactionTimes.isEmpty
        ? 0.0
        : allReactionTimes.reduce((a, b) => a + b) / allReactionTimes.length;
    final overallAccuracy = _setResults.isEmpty
        ? 0.0
        : _setResults.map((s) => s.accuracy).reduce((a, b) => a + b) / _setResults.length;
    
    final detailedResult = DetailedSessionResult(
      sessionResult: result,
      setResults: List.from(_setResults),
      overallAverageReactionTime: overallAvgReactionTime,
      overallAccuracy: overallAccuracy,
      totalScore: totalScore,
    );
    
    await getIt<SessionRepository>().save(result);
    
    // Complete program day if this was part of a program
    if (widget.programId != null && widget.programDayNumber != null) {
      try {
        final progressService = getIt<ProgramProgressService>();
        await progressService.completeProgramDay(widget.programId!, widget.programDayNumber!);
      } catch (e) {
        print('❌ Error completing program day: $e');
      }
    }
    
    if (!mounted) return;
    
    // Show completion feedback
    HapticFeedback.heavyImpact();
    
    // Navigate to detailed results after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        if (widget.isMultiplayerMode) {
          // Multiplayer mode - call completion callback
          widget.onDrillComplete?.call(result);
        } else if (widget.programId != null && widget.programDayNumber != null) {
          // Show success message for program completion
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Day ${widget.programDayNumber} completed! 🎉'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          // Navigate back to program
          context.go('/programs');
        } else {
          // Show detailed results screen
          _showDetailedResults(detailedResult);
        }
      }
    });
  }

  void _showDetailedResults(DetailedSessionResult detailedResult) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Drill Results',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.drill.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Overall Stats
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Total Score', '${detailedResult.totalScore}', Colors.green),
                    _buildStatColumn('Avg Reaction', '${detailedResult.overallAverageReactionTime.toStringAsFixed(0)}ms', Colors.blue),
                    _buildStatColumn('Accuracy', '${detailedResult.overallAccuracy.toStringAsFixed(1)}%', Colors.orange),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Detailed Results
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: detailedResult.setResults.length,
                  itemBuilder: (context, setIndex) {
                    final setResult = detailedResult.setResults[setIndex];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        title: Text('Set ${setResult.setNumber}'),
                        subtitle: Text(
                          'Score: ${setResult.totalScore} | Avg: ${setResult.averageReactionTime.toStringAsFixed(0)}ms | ${setResult.accuracy.toStringAsFixed(1)}%',
                        ),
                        children: [
                          ...setResult.repResults.asMap().entries.map((entry) {
                            final repIndex = entry.key;
                            final repResult = entry.value;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                              title: Text('Rep ${repIndex + 1}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Score: ${repResult.score}/${repResult.events.length}'),
                                  Text('Avg Reaction: ${repResult.averageReactionTime.toStringAsFixed(0)}ms'),
                                  Text('Accuracy: ${repResult.accuracy.toStringAsFixed(1)}%'),
                                ],
                              ),
                              trailing: Icon(
                                repResult.accuracy >= 80 ? Icons.check_circle : Icons.warning,
                                color: repResult.accuracy >= 80 ? Colors.green : Colors.orange,
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              // Close button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/drills');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Back to Drills'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _countdownTimer?.cancel();
    _restTimer?.cancel();
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
    final theme = Theme.of(context);
    
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.drill.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.programId != null && widget.programDayNumber != null)
            Text(
              'Program Day ${widget.programDayNumber}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
        ],
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
                'Set',
                '$_currentSet/${widget.drill.reps}',
                Icons.layers,
              ),
              _buildStatItem(
                'Rep',
                '$_currentRep/${widget.drill.reps}',
                Icons.repeat,
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
          
          // Rest period display
          if (_isInRestPeriod) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'REST TIME',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_restCountdown',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    return Container(
      width: double.infinity,
      height: 400,
      child: Stack(
        children: [
          // Zone indicators
          ..._buildZoneIndicators(),
          
          // Active stimulus
          if (_current != null) _buildActiveStimulus(),
        ],
      ),
    );
  }

  List<Widget> _buildZoneIndicators() {
    final zones = widget.drill.zones.isEmpty ? [ReactionZone.center] : widget.drill.zones;
    return zones.map((zone) => _buildZoneIndicator(zone)).toList();
  }

  Widget _buildZoneIndicator(ReactionZone zone) {
    final position = _getZonePosition(zone);
    final isActive = _current != null && _getCurrentZone() == zone;
    
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onTap: () => _registerZoneTap(zone),
        child: AnimatedBuilder(
          animation: _stimulusScaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isActive ? _stimulusScaleAnimation.value : 0.8,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isActive ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 120,
                      height: 120,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive
                            ? (_current?.type == StimulusType.color ? _displayColor : Colors.white.withOpacity(0.9))
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(60),
                        border: Border.all(
                          color: isActive
                              ? Colors.white.withOpacity(0.9)
                              : Colors.white.withOpacity(0.3),
                          width: isActive ? 4 : 2,
                        ),
                        boxShadow: isActive ? [
                          BoxShadow(
                            color: (_current?.type == StimulusType.color
                                ? _displayColor
                                : Colors.white).withOpacity(0.4),
                            blurRadius: 25,
                            spreadRadius: 8,
                          ),
                        ] : null,
                      ),
                      child: isActive ? Text(
                        _display,
                        style: TextStyle(
                          color: _current?.type == StimulusType.color
                              ? Colors.white
                              : Colors.black,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ) : Icon(
                        _getZoneIcon(zone),
                        color: Colors.white.withOpacity(0.5),
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveStimulus() {
    // This is now handled within zone indicators
    return const SizedBox.shrink();
  }

  Offset _getZonePosition(ReactionZone zone) {
    const centerX = 200.0; // Approximate center for 400px width
    const centerY = 200.0; // Approximate center for 400px height
    const offset = 120.0;  // Distance from center
    
    switch (zone) {
      case ReactionZone.center:
        return Offset(centerX - 60, centerY - 60);
      case ReactionZone.top:
        return Offset(centerX - 60, centerY - offset - 60);
      case ReactionZone.bottom:
        return Offset(centerX - 60, centerY + offset - 60);
      case ReactionZone.left:
        return Offset(centerX - offset - 60, centerY - 60);
      case ReactionZone.right:
        return Offset(centerX + offset - 60, centerY - 60);
      case ReactionZone.quadrants:
        // For quadrants, we'll show multiple zones
        return Offset(centerX - 60, centerY - 60);
    }
  }

  IconData _getZoneIcon(ReactionZone zone) {
    switch (zone) {
      case ReactionZone.center:
        return Icons.center_focus_strong;
      case ReactionZone.top:
        return Icons.keyboard_arrow_up;
      case ReactionZone.bottom:
        return Icons.keyboard_arrow_down;
      case ReactionZone.left:
        return Icons.keyboard_arrow_left;
      case ReactionZone.right:
        return Icons.keyboard_arrow_right;
      case ReactionZone.quadrants:
        return Icons.grid_view;
    }
  }

  ReactionZone _getCurrentZone() {
    if (_current == null) return ReactionZone.center;
    
    final zones = widget.drill.zones.isEmpty ? [ReactionZone.center] : widget.drill.zones;
    if (zones.length == 1) return zones.first;
    
    // For multiple zones, randomly select one for this stimulus
    final random = Random(_current!.index); // Use stimulus index as seed for consistency
    return zones[random.nextInt(zones.length)];
  }

  void _registerZoneTap(ReactionZone zone) {
    if (_state != DrillRunnerState.running) return;
    
    final current = _current;
    if (current == null) return;
    
    final correctZone = _getCurrentZone();
    final isCorrectZone = zone == correctZone;
    
    if (!isCorrectZone) {
      _showFeedback('Wrong Zone!', Colors.orange);
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      return;
    }
    
    // Process the tap as before
    _registerTap();
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
          ] else if (_state == DrillRunnerState.rest) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.hourglass_empty),
                label: Text('Resting... ${_restCountdown}s'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
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
  rest,
  finished,
}
