import 'dart:async';
import 'dart:math';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/drills/data/session_repository.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/domain/session_result.dart';
import 'package:spark_app/features/programs/services/program_progress_service.dart';
import 'package:spark_app/features/multiplayer/services/session_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  
  // Text-to-Speech
  final FlutterTts _flutterTts = FlutterTts();
  bool _isTtsInitialized = false;

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
  int _currentRep = 1;
  bool _isInRestPeriod = false;
  Timer? _restTimer;
  int _restCountdown = 0;
  
  // Detailed results tracking for each set and rep
  final List<SetResult> _setResults = [];
  List<ReactionEvent> _currentRepEvents = [];
  DateTime? _currentRepStartTime;
  DateTime? _currentSetStartTime;

  // Multiplayer sync
  SessionSyncService? _syncService;
  StreamSubscription? _drillEventSubscription;
  bool _isMultiplayerPaused = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize multiplayer sync if in multiplayer mode
    if (widget.isMultiplayerMode) {
      _initializeMultiplayerSync();
    }
    
    // Debug: Print drill configuration to verify sets value
    print('🏃‍♂️ Drill Runner - Drill Configuration:');
    print('  Name: ${widget.drill.name}');
    print('  Sets: ${widget.drill.sets}');
    print('  Reps: ${widget.drill.reps}');
    print('  Duration: ${widget.drill.durationSec}s');
    print('  Rest: ${widget.drill.restSec}s');
    print('  Presentation Mode: ${widget.drill.presentationMode.name}');
    print('  Created At: ${widget.drill.createdAt}');
    
    // Additional safety check for invalid sets value
    if (widget.drill.sets < 1) {
      print('⚠️ WARNING: Invalid sets value (${widget.drill.sets}), defaulting to 1');
    }
    
    _schedule = _generateSchedule(widget.drill);
    _initializeAnimations();
    _initializeTts();
  }
  
  // Helper method to get safe sets value (minimum 1)
  int get _safeSetCount => widget.drill.sets < 1 ? 1 : widget.drill.sets;

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

  Future<void> _initializeTts() async {
    try {
      print('🔧 Initializing TTS...');
      
      // Set completion handler to track speech completion
      _flutterTts.setCompletionHandler(() {
        print('✅ TTS speech completed');
      });
      
      // Set error handler
      _flutterTts.setErrorHandler((msg) {
        print('❌ TTS error handler: $msg');
      });
      
      // Set start handler
      _flutterTts.setStartHandler(() {
        print('▶️ TTS speech started');
      });
      
      // Configure TTS settings
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5); // Slightly slower for clarity
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      // Set iOS-specific settings if needed
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
      
      // Test TTS with a silent test
      print('🔍 Testing TTS...');
      final testResult = await _flutterTts.speak("");
      print('🔍 TTS test result: $testResult');
      await _flutterTts.stop();
      
      _isTtsInitialized = true;
      print('✅ TTS initialized successfully with handlers');
    } catch (e, stackTrace) {
      print('❌ TTS initialization error: $e');
      print('Stack trace: $stackTrace');
      _isTtsInitialized = false;
    }
  }

  void _initializeMultiplayerSync() {
    try {
      _syncService = getIt<SessionSyncService>();
      
      // Listen for drill synchronization events
      _drillEventSubscription = _syncService!.drillEventStream.listen(
        (event) {
          _handleMultiplayerDrillEvent(event);
        },
        onError: (error) {
          print('❌ Multiplayer sync error: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sync error: $error'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
      );
      
      print('🔗 Multiplayer sync initialized for drill runner');
    } catch (e) {
      print('❌ Failed to initialize multiplayer sync: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize multiplayer sync'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleMultiplayerDrillEvent(dynamic event) {
    if (!widget.isMultiplayerMode || !mounted) return;
    
    print('🎮 Multiplayer drill event received: ${event.runtimeType}');
    
    try {
      if (event is DrillStartedEvent) {
        // Host started the drill - start locally if not already running
        if (_state == DrillRunnerState.ready || _state == DrillRunnerState.paused) {
          print('🎮 Starting drill from multiplayer sync');
          _startDrillFromSync();
        }
      } else if (event is DrillStoppedEvent) {
        // Host stopped the drill - stop locally
        if (_state == DrillRunnerState.running || _state == DrillRunnerState.paused) {
          print('🎮 Stopping drill from multiplayer sync');
          _stopDrillFromSync();
        }
      } else if (event is DrillPausedEvent) {
        // Host paused the drill - pause locally
        if (_state == DrillRunnerState.running) {
          print('🎮 Pausing drill from multiplayer sync');
          _pauseDrillFromSync();
        }
      } else if (event is DrillResumedEvent) {
        // Host resumed the drill - resume locally
        if (_state == DrillRunnerState.paused || _isMultiplayerPaused) {
          print('🎮 Resuming drill from multiplayer sync');
          _resumeDrillFromSync();
        }
      }
    } catch (e) {
      print('❌ Error handling multiplayer drill event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startDrillFromSync() {
    if (_state != DrillRunnerState.ready && _state != DrillRunnerState.paused) return;
    
    try {
      // Start the drill without countdown for sync
      _startedAt = DateTime.now();
      _currentRepStartTime = _startedAt;
      _currentSetStartTime = _startedAt;
      
      _stopwatch.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 8), _onTick);
      
      setState(() {
        _state = DrillRunnerState.running;
        _display = 'Ready';
        _displayColor = Colors.white;
      });
      
      _showFeedback('Started by Host', Colors.green);
      HapticFeedback.mediumImpact();
      
      print('✅ Drill started from multiplayer sync');
    } catch (e) {
      print('❌ Error starting drill from sync: $e');
    }
  }

  void _stopDrillFromSync() {
    if (_state != DrillRunnerState.running && _state != DrillRunnerState.paused) return;
    
    try {
      _ticker?.cancel();
      _stopwatch.stop();
      _endedAt = DateTime.now();
      
      setState(() {
        _state = DrillRunnerState.finished;
      });
      
      _showFeedback('Stopped by Host', Colors.red);
      HapticFeedback.mediumImpact();
      
      // Complete the drill and navigate back
      _completeMultiplayerDrill();
      
      print('✅ Drill stopped from multiplayer sync');
    } catch (e) {
      print('❌ Error stopping drill from sync: $e');
    }
  }

  void _completeMultiplayerDrill() {
    try {
      // Create a basic session result for multiplayer mode
      final sessionResult = SessionResult(
        id: _uuid.v4(),
        drill: widget.drill,
        startedAt: _startedAt,
        endedAt: _endedAt ?? DateTime.now(),
        events: List.from(_events),
      );
      
      // Call completion callback if provided
      if (widget.onDrillComplete != null) {
        widget.onDrillComplete!(sessionResult);
      }
      
      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      print('❌ Error completing multiplayer drill: $e');
      // Still navigate back on error
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _pauseDrillFromSync() {
    if (_state != DrillRunnerState.running) return;
    
    _ticker?.cancel();
    _stopwatch.stop();
    _isMultiplayerPaused = true;
    
    setState(() {
      _state = DrillRunnerState.paused;
      _feedbackText = 'Paused by Host';
      _feedbackColor = Colors.orange;
    });
    
    _showFeedback('Paused by Host', Colors.orange);
    HapticFeedback.mediumImpact();
  }

  void _resumeDrillFromSync() {
    if (_state != DrillRunnerState.paused && !_isMultiplayerPaused) return;
    
    _isMultiplayerPaused = false;
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(milliseconds: 8), _onTick);
    
    setState(() {
      _state = DrillRunnerState.running;
    });
    
    _showFeedback('Resumed by Host', Colors.green);
    HapticFeedback.mediumImpact();
  }

  Future<void> _speakStimulus(String text) async {
    if (!_isTtsInitialized) {
      print('⚠️ TTS not initialized, skipping speech');
      return;
    }
    
    // Only speak in audio mode
    if (widget.drill.presentationMode != PresentationMode.audio) {
      return;
    }
    
    try {
      // Stop any ongoing speech
      await _flutterTts.stop();
      
      // Add a small delay to ensure stop completes
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Speak the stimulus
      final result = await _flutterTts.speak(text);
      print('🔊 Speaking: $text (result: $result)');
      
      if (result == 0) {
        print('❌ TTS speak failed with result 0');
      }
    } catch (e) {
      print('❌ TTS speak error: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  String _getStimulusTextForTts(_Stimulus stimulus) {
    switch (stimulus.type) {
      case StimulusType.color:
        // For colors, speak the color name
        final colorName = _getColorName(_displayColor);
        return colorName;
      case StimulusType.arrow:
        // For arrows, speak just the direction
        switch (stimulus.label) {
          case '↑': return 'Up';
          case '→': return 'Right';
          case '↓': return 'Down';
          case '←': return 'Left';
          default: return stimulus.label;
        }
      case StimulusType.number:
        return stimulus.label;
      case StimulusType.shape:
        // For shapes, speak the shape name
        switch (stimulus.label) {
          case '●': return 'Circle';
          case '■': return 'Square';
          case '▲': return 'Triangle';
          default: return 'Shape';
        }
    }
  }

  String _getColorName(Color color) {
    // Compare color values instead of objects since deserialized colors
    // from Firebase won't match Flutter constant colors using ==
    final colorValue = color.value;
    
    if (colorValue == Colors.red.value) return 'Red';
    if (colorValue == Colors.green.value) return 'Green';
    if (colorValue == Colors.blue.value) return 'Blue';
    if (colorValue == Colors.yellow.value) return 'Yellow';
    if (colorValue == Colors.orange.value) return 'Orange';
    if (colorValue == Colors.purple.value) return 'Purple';
    if (colorValue == Colors.pink.value) return 'Pink';
    if (colorValue == Colors.cyan.value) return 'Cyan';
    if (colorValue == Colors.brown.value) return 'Brown';
    if (colorValue == Colors.grey.value) return 'Grey';
    if (colorValue == Colors.black.value) return 'Black';
    if (colorValue == Colors.white.value) return 'White';
    return 'Color';
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
    
    // Initialize first set and rep ONLY if this is the initial start (no sets exist yet)
    if (_setResults.isEmpty) {
      _initializeNewSet();
      _initializeNewRep();
    } else {
      // For subsequent sets, just initialize the rep (set was already initialized in _completeSet)
      _initializeNewRep();
    }
    
    _stopwatch
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 8), _onTick); // ~120 fps
    HapticFeedback.mediumImpact();
  }

  void _initializeNewSet() {
    print('🔧 _initializeNewSet called: _currentSet=$_currentSet, existing sets=${_setResults.length}');
    print('   Stack trace: ${StackTrace.current}');
    _currentSetStartTime = DateTime.now();
    final newSet = SetResult(
      setNumber: _currentSet,
      repResults: [],
      startTime: _currentSetStartTime!,
    );
    _setResults.add(newSet);
    print('✅ Set initialized: setNumber=${newSet.setNumber}, total sets now=${_setResults.length}');
  }

  void _initializeNewRep() {
    _currentRepStartTime = DateTime.now();
    _currentRepEvents = [];
    _events.clear(); // Clear events for new rep
    _score = 0; // Reset score for new rep
    _currentIndex = -1; // Reset stimulus index
    _current = null; // Clear current stimulus
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
      
      print('🎬 Stimulus shown: type=${_current!.type}, mode=${widget.drill.presentationMode.name}');
      
      // Speak the stimulus if in audio mode
      if (widget.drill.presentationMode == PresentationMode.audio) {
        final textToSpeak = _getStimulusTextForTts(_current!);
        print('🎯 Attempting to speak: "$textToSpeak" for stimulus type: ${_current!.type}');
        _speakStimulus(textToSpeak);
      } else {
        print('👁️ Visual mode - showing stimulus visually');
      }
      
      // Enhanced feedback based on stimulus type
      switch (_current!.type) {
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
    print('🔄 _completeRep called: Set $_currentSet, Rep $_currentRep');
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
          : (_currentRepEvents.where((e) => e.correct).length / _currentRepEvents.length);
      
      final repResult = RepResult(
        repNumber: _currentRep,
        events: List.from(_currentRepEvents),
        startTime: _currentRepStartTime!,
        endTime: DateTime.now(),
        score: repScore,
        averageReactionTime: avgReactionTime,
        accuracy: accuracy,
      );
      
      print('   Rep result: score=$repScore, events=${_currentRepEvents.length}');
      
      // Add to current set's rep results
      if (_setResults.isNotEmpty) {
        _setResults.last.repResults.add(repResult);
        print('   Added to set ${_setResults.last.setNumber}, total reps now: ${_setResults.last.repResults.length}');
      }
    }
    
    // Check if set is complete
    print('   Checking: _currentRep=$_currentRep >= widget.drill.reps=${widget.drill.reps}?');
    if (_currentRep >= widget.drill.reps) {
      print('   ✅ Set complete! Calling _completeSet()');
      _completeSet();
    } else {
      print('   ⏭️ More reps needed');
      // Increment rep counter for next rep
      _currentRep++;
      print('   Incremented _currentRep to $_currentRep');
      
      // Start rest period between reps if rest time is configured
      if (widget.drill.restSec > 0) {
        _startRestPeriod();
      } else {
        _startNextRep();
      }
    }
  }

  void _completeSet() {
    print('🏁 _completeSet called: _currentSet=$_currentSet, _safeSetCount=$_safeSetCount');
    
    // Update current set's end time and stats
    if (_setResults.isNotEmpty) {
      _setResults.last.endTime = DateTime.now();
      _setResults.last.updateStats();
      print('   Updated set ${_setResults.last.setNumber}: ${_setResults.last.repResults.length} reps');
    }
    
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    
    // Show set completion feedback
    _showFeedback('Set ${_currentSet} Complete!', Colors.green);
    
    // Check if all sets are complete
    if (_currentSet >= _safeSetCount) {
      print('✅ All sets complete! Finishing drill...');
      // All sets complete - finish drill
      setState(() {
        _state = DrillRunnerState.finished;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        _finish();
      });
    } else {
      print('➡️ Moving to next set...');
      // Move to next set
      _currentSet++;
      _currentRep = 1; // Initialize rep counter for new set
      print('   New values: _currentSet=$_currentSet, _currentRep=$_currentRep');
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        _initializeNewSet();
        if (widget.drill.restSec > 0) {
          _startRestPeriod();
        } else {
          _initializeNewRep(); // Start first rep of new set
          _startCountdown();
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
    
    // Initialize new rep (within current set)
    _initializeNewRep();
    
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
          // Navigate to drill results screen with detailed set results
          final detailedSetResults = _setResults.map((setResult) {
            print('📊 Set ${setResult.setNumber}: ${setResult.repResults.length} reps');
            return {
              'setNumber': setResult.setNumber,
              'reps': setResult.repResults.map((repResult) {
                print('  Rep ${repResult.repNumber}: ${repResult.score} hits, ${repResult.events.length} stimuli');
                return {
                  'repNumber': repResult.repNumber,
                  'hits': repResult.score,
                  'totalStimuli': repResult.events.length,
                  'accuracy': repResult.accuracy,
                  'avgReactionTime': repResult.averageReactionTime,
                };
              }).toList(),
            };
          }).toList();
          
          print('📦 Total sets being passed: ${detailedSetResults.length}');
          
          context.go('/drill-results', extra: {
            'result': result,
            'detailedSetResults': detailedSetResults,
          });
        }
      }
    });
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
    // Stop and cleanup TTS synchronously
    _flutterTts.stop();
    print('🛑 TTS stopped on dispose');
    // Clean up multiplayer subscription
    _drillEventSubscription?.cancel();
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
                '$_currentSet/$_safeSetCount',
                Icons.layers,
              ),
              _buildStatItem(
                'Rep',
                '$_currentRep/${widget.drill.reps}',
                Icons.repeat,
              ),
              _buildStatItem(
                'Score',
                '$_score/${widget.drill.numberOfStimuli}',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use full available space for better visibility
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            children: [
              // Zone indicators
              ..._buildZoneIndicators(constraints),
              
              // Active stimulus
              if (_current != null) _buildActiveStimulus(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildZoneIndicators(BoxConstraints constraints) {
    final zones = widget.drill.zones.isEmpty ? [ReactionZone.center] : widget.drill.zones;
    return zones.map((zone) => _buildZoneIndicator(zone, constraints)).toList();
  }

  Widget _buildZoneIndicator(ReactionZone zone, BoxConstraints constraints) {
    final position = _getZonePosition(zone, constraints);
    final isActive = _current != null && _getCurrentZone() == zone;
    
    // Calculate size based on available space - much larger for better visibility
    final availableSize = constraints.maxHeight.clamp(200.0, 600.0);
    final stimulusSize = availableSize * 0.6; // 60% of available height
    final fontSize = stimulusSize * 0.4; // 40% of stimulus size
    final iconSize = stimulusSize * 0.25; // 25% of stimulus size
    
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
                      width: stimulusSize,
                      height: stimulusSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive
                            ? (_current?.type == StimulusType.color ? _displayColor : Colors.white.withOpacity(0.9))
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(stimulusSize / 2),
                        border: Border.all(
                          color: isActive
                              ? Colors.white.withOpacity(0.9)
                              : Colors.white.withOpacity(0.3),
                          width: isActive ? 6 : 3,
                        ),
                        boxShadow: isActive ? [
                          BoxShadow(
                            color: (_current?.type == StimulusType.color
                                ? _displayColor
                                : Colors.white).withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 15,
                          ),
                        ] : null,
                      ),
                      child: isActive ? Text(
                        _display,
                        style: TextStyle(
                          color: _current?.type == StimulusType.color
                              ? Colors.white
                              : Colors.black,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ) : Icon(
                        _getZoneIcon(zone),
                        color: Colors.white.withOpacity(0.5),
                        size: iconSize,
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

  Offset _getZonePosition(ReactionZone zone, BoxConstraints constraints) {
    final centerX = constraints.maxWidth / 2;
    final centerY = constraints.maxHeight / 2;
    
    // Calculate size based on available space
    final availableSize = constraints.maxHeight.clamp(200.0, 600.0);
    final stimulusSize = availableSize * 0.6;
    final halfSize = stimulusSize / 2;
    final offset = stimulusSize * 0.8; // Distance from center
    
    switch (zone) {
      case ReactionZone.center:
        return Offset(centerX - halfSize, centerY - halfSize);
      case ReactionZone.top:
        return Offset(centerX - halfSize, centerY - offset - halfSize);
      case ReactionZone.bottom:
        return Offset(centerX - halfSize, centerY + offset - halfSize);
      case ReactionZone.left:
        return Offset(centerX - offset - halfSize, centerY - halfSize);
      case ReactionZone.right:
        return Offset(centerX + offset - halfSize, centerY - halfSize);
      case ReactionZone.quadrants:
        // For quadrants, we'll show multiple zones
        return Offset(centerX - halfSize, centerY - halfSize);
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
  paused,
  rest,
  finished,
}
