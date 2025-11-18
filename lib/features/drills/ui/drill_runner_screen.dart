import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/drills/data/session_repository.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/domain/session_result.dart';
import 'package:spark_app/features/programs/services/program_progress_service.dart';
import 'package:spark_app/features/programs/data/program_repository.dart';
import 'package:spark_app/features/programs/domain/program.dart';
import 'package:spark_app/features/programs/services/drill_assignment_service.dart';
import 'package:spark_app/features/multiplayer/services/session_sync_service.dart';
import 'package:spark_app/features/admin/services/custom_stimulus_service.dart';
import 'package:spark_app/features/admin/domain/custom_stimulus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:spark_app/core/utils/app_logger.dart';

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
  final bool isHost;
  final Function(SessionResult)? onDrillComplete;
  
  const DrillRunnerScreen({
    super.key,
    required this.drill,
    this.programId,
    this.programDayNumber,
    this.isMultiplayerMode = false,
    this.isHost = true,
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
  
  // Custom stimuli cache
  final Map<String, CustomStimulus> _customStimuliCache = {};
  
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
  final bool _soundEnabled = true;
  final bool _vibrationEnabled = true;
  final bool _voiceEnabled = true;
  
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
      
      // Check if drill is already active in multiplayer session
      _checkMultiplayerDrillState();
    }
    
    // Validate and enhance drill configuration for proper functionality
    final validatedDrill = _validateAndEnhanceDrillConfiguration(widget.drill);
    
    // Debug: Print drill configuration to verify values
    AppLogger.debug('Drill Runner - Enhanced Drill Configuration: ${validatedDrill.name}, Sets: ${validatedDrill.sets}, Reps: ${validatedDrill.reps}, Duration: ${validatedDrill.durationSec}s, Rest: ${validatedDrill.restSec}s, Stimuli: ${validatedDrill.numberOfStimuli}');
    
    // Preload custom stimuli if needed
    _preloadCustomStimuli(validatedDrill);
    
    _schedule = _generateSchedule(validatedDrill);
    _initializeAnimations();
    _initializeTts();
  }
  
  /// Validates and enhances drill configuration to ensure proper functionality
  /// This ensures stimulus selection, zone selection, and screen coverage work correctly
  Drill _validateAndEnhanceDrillConfiguration(Drill drill) {
    AppLogger.debug('Validating drill configuration for proper functionality');
    
    var enhancedDrill = drill;
    bool needsUpdate = false;
    
    // 1. Validate sets (minimum 1)
    if (drill.sets < 1) {
      AppLogger.warning('Invalid sets value (${drill.sets}), correcting to 1');
      enhancedDrill = enhancedDrill.copyWith(sets: 1);
      needsUpdate = true;
    }
    
    // 2. Validate reps (minimum 1)
    if (drill.reps < 1) {
      AppLogger.warning('Invalid reps value (${drill.reps}), correcting to 1');
      enhancedDrill = enhancedDrill.copyWith(reps: 1);
      needsUpdate = true;
    }
    
    // 3. Validate duration (minimum 10 seconds for meaningful drill)
    if (drill.durationSec < 10) {
      AppLogger.warning('Duration too short (${drill.durationSec}s), correcting to 30s', tag: 'DrillValidation');
      enhancedDrill = enhancedDrill.copyWith(durationSec: 30);
      needsUpdate = true;
    }
    
    // 4. Validate and optimize number of stimuli for proper timing
    final maxReasonableStimuli = (drill.durationSec / 1.5).floor(); // Max 1 stimulus per 1.5 seconds
    final minStimuli = max(1, (drill.durationSec / 10).floor()); // Min 1 stimulus per 10 seconds
    
    if (drill.numberOfStimuli < minStimuli) {
      AppLogger.warning('Too few stimuli (${drill.numberOfStimuli}), correcting to $minStimuli', tag: 'DrillValidation');
      enhancedDrill = enhancedDrill.copyWith(numberOfStimuli: minStimuli);
      needsUpdate = true;
    } else if (drill.numberOfStimuli > maxReasonableStimuli) {
      AppLogger.warning('Too many stimuli (${drill.numberOfStimuli}) for duration, correcting to $maxReasonableStimuli', tag: 'DrillValidation');
      enhancedDrill = enhancedDrill.copyWith(numberOfStimuli: maxReasonableStimuli);
      needsUpdate = true;
    }
    
    // 5. Ensure stimulus types are present and valid
    if (drill.stimulusTypes.isEmpty) {
      AppLogger.warning('No stimulus types specified, adding color stimulus for proper functionality', tag: 'DrillValidation');
      enhancedDrill = enhancedDrill.copyWith(stimulusTypes: [StimulusType.color]);
      needsUpdate = true;
    }
    
    // 6. Ensure zones are present for proper screen coverage
    if (drill.zones.isEmpty) {
      AppLogger.warning('No zones specified, adding center zone for screen coverage', tag: 'DrillValidation');
      enhancedDrill = enhancedDrill.copyWith(zones: [ReactionZone.center]);
      needsUpdate = true;
    }
    
    // 7. Validate colors for color stimulus type
    if (drill.stimulusTypes.contains(StimulusType.color)) {
      if (drill.colors.isEmpty) {
        AppLogger.warning('Color stimulus specified but no colors provided, adding default colors', tag: 'DrillValidation');
        enhancedDrill = enhancedDrill.copyWith(colors: [
          Colors.red, Colors.green, Colors.blue, Colors.yellow,
          Colors.orange, Colors.purple, Colors.cyan, Colors.pink
        ]);
        needsUpdate = true;
      } else if (drill.colors.length < 3) {
        AppLogger.warning('Insufficient colors for variety, adding more colors', tag: 'DrillValidation');
        final additionalColors = [Colors.red, Colors.green, Colors.blue, Colors.yellow]
            .where((color) => !drill.colors.contains(color))
            .take(4 - drill.colors.length)
            .toList();
        enhancedDrill = enhancedDrill.copyWith(colors: [...drill.colors, ...additionalColors]);
        needsUpdate = true;
      }
    }
    
    // 8. Validate presentation mode compatibility
    if (drill.presentationMode == PresentationMode.audio) {
      // Ensure all stimulus types are audio-compatible
      final audioCompatibleTypes = drill.stimulusTypes.where((type) =>
        type == StimulusType.color ||
        type == StimulusType.arrow ||
        type == StimulusType.number ||
        type == StimulusType.shape ||
        type == StimulusType.custom
      ).toList();
      
      if (audioCompatibleTypes.isEmpty) {
        AppLogger.warning('Audio mode requires compatible stimulus types, adding color', tag: 'DrillValidation');
        enhancedDrill = enhancedDrill.copyWith(stimulusTypes: [StimulusType.color]);
        needsUpdate = true;
      } else if (audioCompatibleTypes.length != drill.stimulusTypes.length) {
        AppLogger.warning('Some stimulus types not compatible with audio mode, filtering', tag: 'DrillValidation');
        enhancedDrill = enhancedDrill.copyWith(stimulusTypes: audioCompatibleTypes);
        needsUpdate = true;
      }
    }
    
    if (needsUpdate) {
      AppLogger.success('Drill configuration enhanced for proper functionality', tag: 'DrillValidation');
    } else {
      AppLogger.success('Drill configuration is already optimal', tag: 'DrillValidation');
    }
    
    return enhancedDrill;
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
    ),);
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ),);
    
    _feedbackOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _feedbackAnimationController,
      curve: Curves.easeOut,
    ),);
    
    _pulseAnimationController.repeat(reverse: true);
  }

  /// Preloads custom stimuli for the drill to avoid async calls during stimulus generation
  Future<void> _preloadCustomStimuli(Drill drill) async {
    AppLogger.debug('Preloading custom stimuli - drill.customStimuliIds: ${drill.customStimuliIds}', tag: 'DrillRunner');
    
    if (drill.customStimuliIds.isEmpty) {
      AppLogger.debug('No custom stimuli IDs to preload', tag: 'DrillRunner');
      return; // No custom stimuli to preload
    }
    
    try {
      final customStimulusService = getIt<CustomStimulusService>();
      
      // Since drill.customStimuliIds contains item IDs, not stimulus IDs,
      // we need to load all custom stimuli and find the ones containing our items
      final allCustomStimuli = await customStimulusService.getAllCustomStimuli();
      AppLogger.debug('Loaded ${allCustomStimuli.length} total custom stimuli', tag: 'DrillRunner');
      
      for (final customStimulus in allCustomStimuli) {
        // Check if this stimulus contains any of our selected items
        final hasSelectedItems = customStimulus.items.any((item) => drill.customStimuliIds.contains(item.id));
        if (hasSelectedItems) {
          _customStimuliCache[customStimulus.id] = customStimulus;
          AppLogger.debug('Cached custom stimulus: ${customStimulus.name} (${customStimulus.items.length} items)', tag: 'DrillRunner');
          
          // Log which items from this stimulus are selected
          for (final item in customStimulus.items) {
            if (drill.customStimuliIds.contains(item.id)) {
              AppLogger.debug('  - Selected item: ${item.name} (${item.id})', tag: 'DrillRunner');
            }
          }
        }
      }
      
      AppLogger.success('Preloaded ${_customStimuliCache.length} custom stimuli containing selected items', tag: 'DrillRunner');
    } catch (e) {
      AppLogger.error('Failed to preload custom stimuli', error: e, tag: 'DrillRunner');
    }
  }

  Future<void> _initializeTts() async {
    try {
      AppLogger.info('Initializing TTS...', tag: 'TTS');
      
      // Set completion handler to track speech completion
      _flutterTts.setCompletionHandler(() {
        AppLogger.success('TTS speech completed', tag: 'TTS');
      });
      
      // Set error handler
      _flutterTts.setErrorHandler((msg) {
        AppLogger.error('TTS error handler: $msg', tag: 'TTS');
      });
      
      // Set start handler
      _flutterTts.setStartHandler(() {
        AppLogger.info('TTS speech started', tag: 'TTS');
      });
      
      // Configure TTS settings
      await _flutterTts.setLanguage('en-US');
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
      AppLogger.debug('Testing TTS...', tag: 'TTS');
      final testResult = await _flutterTts.speak('');
      AppLogger.debug('TTS test result: $testResult', tag: 'TTS');
      await _flutterTts.stop();
      
      _isTtsInitialized = true;
      AppLogger.success('TTS initialized successfully with handlers', tag: 'TTS');
    } catch (e, stackTrace) {
      AppLogger.error('TTS initialization error', error: e, stackTrace: stackTrace, tag: 'TTS');
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
          AppLogger.error('Multiplayer sync error', error: error, tag: 'Multiplayer');
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
      
      AppLogger.success('Multiplayer sync initialized for drill runner', tag: 'Multiplayer');
    } catch (e) {
      AppLogger.error('Failed to initialize multiplayer sync', error: e, tag: 'Multiplayer');
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

  void _checkMultiplayerDrillState() {
    if (_syncService == null) return;
    
    try {
      // Check if the drill is already active in the multiplayer session
      final isDrillActive = _syncService!.isDrillActive;
      final isDrillPaused = _syncService!.isDrillPaused;
      
      AppLogger.debug('Checking multiplayer drill state: active=$isDrillActive, paused=$isDrillPaused', tag: 'Multiplayer');
      
      if (isDrillActive && !isDrillPaused) {
        // Drill is already running, start it immediately for this participant
        AppLogger.info('Drill already active, auto-starting for participant', tag: 'Multiplayer');
        
        // Use a post-frame callback to ensure the widget is fully built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _state == DrillRunnerState.ready) {
            _startDrillFromSync();
          }
        });
      } else if (isDrillActive && isDrillPaused) {
        // Drill is paused, set the paused state
        AppLogger.info('Drill is paused, setting paused state for participant', tag: 'Multiplayer');
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _state == DrillRunnerState.ready) {
            setState(() {
              _state = DrillRunnerState.paused;
              _isMultiplayerPaused = true;
            });
          }
        });
      }
    } catch (e) {
      AppLogger.error('Error checking multiplayer drill state', error: e, tag: 'Multiplayer');
    }
  }

  void _handleMultiplayerDrillEvent(dynamic event) {
    if (!widget.isMultiplayerMode || !mounted) return;
    
    AppLogger.debug('Multiplayer drill event received: ${event.runtimeType}', tag: 'Multiplayer');
    
    try {
      if (event is DrillStartedEvent) {
        // Host started the drill - start locally if not already running
        if (_state == DrillRunnerState.ready || _state == DrillRunnerState.paused) {
          AppLogger.info('Starting drill from multiplayer sync', tag: 'Multiplayer');
          _startDrillFromSync();
        }
      } else if (event is DrillStoppedEvent) {
        // Host stopped the drill - stop locally
        if (_state == DrillRunnerState.running || _state == DrillRunnerState.paused) {
          AppLogger.info('Stopping drill from multiplayer sync', tag: 'Multiplayer');
          _stopDrillFromSync();
        }
      } else if (event is DrillPausedEvent) {
        // Host paused the drill - pause locally
        if (_state == DrillRunnerState.running) {
          AppLogger.info('Pausing drill from multiplayer sync', tag: 'Multiplayer');
          _pauseDrillFromSync();
        }
      } else if (event is DrillResumedEvent) {
        // Host resumed the drill - resume locally
        if (_state == DrillRunnerState.paused || _isMultiplayerPaused) {
          AppLogger.info('Resuming drill from multiplayer sync', tag: 'Multiplayer');
          _resumeDrillFromSync();
        }
      } else if (event is StimulusEvent) {
        // Participant receiving stimulus data from host
        if (!widget.isHost && _state == DrillRunnerState.running) {
          _handleStimulusFromHost(event.data);
        }
      }
    } catch (e) {
      AppLogger.error('Error handling multiplayer drill event', error: e, tag: 'Multiplayer');
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

  void _handleStimulusFromHost(Map<String, dynamic> stimulusData) {
    try {
      // Extract stimulus data
      final stimulusTypeStr = stimulusData['type'] as String;
      final label = stimulusData['label'] as String;
      final colorValue = stimulusData['colorValue'] as int;
      final index = stimulusData['index'] as int;
      
      // Parse stimulus type
      final stimulusType = StimulusType.values.firstWhere(
        (e) => e.name == stimulusTypeStr,
        orElse: () => StimulusType.color,
      );
      
      // Update current stimulus
      _currentIndex = index;
      if (_currentIndex < _schedule.length) {
        _current = _schedule[_currentIndex];
      }
      
      // Display the stimulus with the exact color from host
      final color = Color(colorValue);
      _showStimulus(label, color, stimulusType);
      
      AppLogger.debug('Participant received stimulus: type=$stimulusTypeStr, color=${color.value}, index=$index', tag: 'Multiplayer');
    } catch (e) {
      AppLogger.error('Error handling stimulus from host', error: e, tag: 'Multiplayer');
    }
  }

  void _startDrillFromSync() {
    // Allow starting from ready or paused states
    if (_state != DrillRunnerState.ready && _state != DrillRunnerState.paused) {
      AppLogger.warning('Cannot start drill from sync in state: $_state', tag: 'Multiplayer');
      return;
    }
    
    try {
      AppLogger.info('Starting drill from sync in state: $_state', tag: 'Multiplayer');
      
      // Start the drill without countdown for sync
      _startedAt = DateTime.now();
      _currentRepStartTime = _startedAt;
      _currentSetStartTime = _startedAt;
      
      _stopwatch.reset();
      _stopwatch.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 8), _onTick);
      
      setState(() {
        _state = DrillRunnerState.running;
        _isMultiplayerPaused = false;
        _display = 'Ready';
        _displayColor = Colors.white;
      });
      
      _showFeedback('Started by Host', Colors.green);
      HapticFeedback.mediumImpact();
      
      AppLogger.success('Drill started from multiplayer sync', tag: 'Multiplayer');
    } catch (e) {
      AppLogger.error('Error starting drill from sync', error: e, tag: 'Multiplayer');
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
      
      AppLogger.success('Drill stopped from multiplayer sync', tag: 'Multiplayer');
    } catch (e) {
      AppLogger.error('Error stopping drill from sync', error: e, tag: 'Multiplayer');
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
      
      // Navigate back after a short delay with proper navigation guard
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      AppLogger.error('Error completing multiplayer drill', error: e, tag: 'Multiplayer');
      // Still navigate back on error with proper navigation guard
      if (mounted && Navigator.of(context).canPop()) {
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

  void _resumeDrill() {
    if (_state != DrillRunnerState.paused) return;
    
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(milliseconds: 8), _onTick);
    
    setState(() {
      _state = DrillRunnerState.running;
    });
    
    _showFeedback('Resumed', Colors.green);
    HapticFeedback.mediumImpact();
  }

  Future<void> _speakStimulus(String text) async {
    if (!_isTtsInitialized) {
      AppLogger.warning('TTS not initialized, skipping speech', tag: 'TTS');
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
      AppLogger.debug('Speaking: $text (result: $result)', tag: 'TTS');
      
      if (result == 0) {
        AppLogger.error('TTS speak failed with result 0', tag: 'TTS');
      }
    } catch (e) {
      AppLogger.error('TTS speak error', error: e, stackTrace: StackTrace.current, tag: 'TTS');
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
      case StimulusType.custom:
        return stimulus.label.isEmpty ? 'Custom' : stimulus.label;
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
    final rnd = Random();
    
    switch (t) {
      case StimulusType.arrow:
        const dirs = ['↑', '→', '↓', '←'];
        return dirs[rnd.nextInt(dirs.length)];
      case StimulusType.number:
        // Generate numbers 1-9 for better variety
        return (1 + rnd.nextInt(9)).toString();
      case StimulusType.shape:
        const shapes = ['●', '■', '▲', '♦', '★']; // Added more shapes for variety
        return shapes[rnd.nextInt(shapes.length)];
      case StimulusType.custom:
        // Handle custom stimuli using selected item IDs
        AppLogger.debug('Custom stimulus generation - customStimuliIds: ${drill.customStimuliIds}', tag: 'DrillRunner');
        AppLogger.debug('Custom stimulus generation - cache size: ${_customStimuliCache.length}', tag: 'DrillRunner');
        
        if (drill.customStimuliIds.isNotEmpty && _customStimuliCache.isNotEmpty) {
          // Find all selected custom stimulus items from all cached stimuli
          final availableItems = <CustomStimulusItem>[];
          
          for (final customStimulus in _customStimuliCache.values) {
            AppLogger.debug('Checking stimulus: ${customStimulus.name} with ${customStimulus.items.length} items', tag: 'DrillRunner');
            for (final item in customStimulus.items) {
              AppLogger.debug('Checking item: ${item.id} (${item.name})', tag: 'DrillRunner');
              if (drill.customStimuliIds.contains(item.id)) {
                availableItems.add(item);
                AppLogger.debug('Added item to available: ${item.name}', tag: 'DrillRunner');
              }
            }
          }
          
          AppLogger.debug('Available items count: ${availableItems.length}', tag: 'DrillRunner');
          
          if (availableItems.isNotEmpty) {
            // Get a random item from the selected ones
            final randomItem = availableItems[rnd.nextInt(availableItems.length)];
            AppLogger.debug('Selected random item: ${randomItem.name}', tag: 'DrillRunner');
            
            // Find the parent stimulus to get the type
            CustomStimulus? parentStimulus;
            for (final stimulus in _customStimuliCache.values) {
              if (stimulus.items.contains(randomItem)) {
                parentStimulus = stimulus;
                break;
              }
            }
            
            if (parentStimulus != null) {
              AppLogger.debug('Parent stimulus type: ${parentStimulus.type}', tag: 'DrillRunner');
              // Return appropriate label based on item type
              switch (parentStimulus.type) {
                case CustomStimulusType.text:
                  final result = randomItem.textValue ?? randomItem.name;
                  AppLogger.debug('Returning text value: $result', tag: 'DrillRunner');
                  return result;
                case CustomStimulusType.image:
                  AppLogger.debug('Returning image name: ${randomItem.name}', tag: 'DrillRunner');
                  return randomItem.name; // Use name as label for images
                case CustomStimulusType.shape:
                  final result = randomItem.shapeType ?? randomItem.name;
                  AppLogger.debug('Returning shape value: $result', tag: 'DrillRunner');
                  return result; // Use shape type or name
                case CustomStimulusType.color:
                  // For colors, we might want to set the display color
                  if (randomItem.color != null) {
                    _displayColor = randomItem.color!;
                    final result = drill.presentationMode == PresentationMode.audio
                        ? randomItem.name
                        : '';
                    AppLogger.debug('Returning color value: $result', tag: 'DrillRunner');
                    return result;
                  }
                  AppLogger.debug('Returning color name: ${randomItem.name}', tag: 'DrillRunner');
                  return randomItem.name;
              }
            }
          }
        }
        AppLogger.warning('Falling back to Custom - no items found', tag: 'DrillRunner');
        return 'Custom'; // Fallback if no custom stimuli available
      case StimulusType.color:
      default:
        // Enhanced color selection with validation
        List<Color> availableColors = drill.colors.isNotEmpty
            ? drill.colors
            : [Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.orange, Colors.purple];
        
        // Ensure we have sufficient colors for variety
        if (availableColors.length < 3) {
          availableColors = [Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.orange, Colors.purple];
          AppLogger.warning('Insufficient colors provided, using enhanced default color set', tag: 'DrillValidation');
        }
        
        final selectedColor = availableColors[rnd.nextInt(availableColors.length)];
        _displayColor = selectedColor;
        
        // For audio mode, return color name for TTS
        if (drill.presentationMode == PresentationMode.audio) {
          return _getColorName(selectedColor);
        }
        
        return ''; // Empty for visual color display
    }
  }

  void _start() {
    try {
      if (_state != DrillRunnerState.ready) {
        AppLogger.warning('Cannot start drill in current state: $_state', tag: 'DrillRunner');
        return;
      }
      
      // Validate drill configuration before starting
      if (widget.drill.numberOfStimuli <= 0) {
        _showFeedback('Invalid drill configuration', Colors.red);
        return;
      }
      
      if (_schedule.isEmpty) {
        _showFeedback('No stimuli scheduled', Colors.red);
        return;
      }
      
      AppLogger.success('Starting drill with ${_schedule.length} stimuli', tag: 'DrillRunner');
      _startCountdown();
    } catch (e) {
      AppLogger.error('Error starting drill', error: e, tag: 'DrillRunner');
      _showFeedback('Failed to start drill', Colors.red);
    }
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
    AppLogger.debug('_initializeNewSet called: _currentSet=$_currentSet, existing sets=${_setResults.length}', tag: 'DrillRunner');
    AppLogger.debug('Stack trace: ${StackTrace.current}', tag: 'DrillRunner');
    _currentSetStartTime = DateTime.now();
    final newSet = SetResult(
      setNumber: _currentSet,
      repResults: [],
      startTime: _currentSetStartTime!,
    );
    _setResults.add(newSet);
    AppLogger.success('Set initialized: setNumber=${newSet.setNumber}, total sets now=${_setResults.length}', tag: 'DrillRunner');
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
    // In multiplayer mode, only the host generates and broadcasts stimuli
    if (_currentIndex + 1 < _schedule.length && ms >= _schedule[_currentIndex + 1].timeMs) {
      _currentIndex++;
      _current = _schedule[_currentIndex];
      
      // Generate display color for color stimuli
      Color stimulusColor = Colors.white;
      if (_current!.type == StimulusType.color) {
        stimulusColor = _getRandomColor();
      }
      
      // If host in multiplayer mode, broadcast the stimulus to participants
      if (widget.isMultiplayerMode && widget.isHost && _syncService != null) {
        _syncService!.broadcastStimulus(
          stimulusType: _current!.type.name,
          label: _current!.label,
          colorValue: stimulusColor.value,
          timeMs: _current!.timeMs,
          index: _current!.index,
        );
      }
      
      // Show the stimulus locally
      _showStimulus(_current!.label, stimulusColor, _current!.type);
    }

    // End of current rep
    if (ms >= widget.drill.durationSec * 1000) {
      _completeRep();
    } else {
      setState(() {});
    }
  }

  void _showStimulus(String label, Color color, StimulusType type) {
    // Animate stimulus appearance
    _stimulusAnimationController.reset();
    _stimulusAnimationController.forward();
    
    setState(() {
      _display = type == StimulusType.color ? '' : label;
      _displayColor = color;
    });
    
    AppLogger.debug('Stimulus shown: type=$type, mode=${widget.drill.presentationMode.name}', tag: 'DrillRunner');
    
    // Speak the stimulus if in audio mode
    if (widget.drill.presentationMode == PresentationMode.audio) {
      final textToSpeak = _getStimulusTextForTts(_Stimulus(
        index: _currentIndex,
        timeMs: _stopwatch.elapsedMilliseconds,
        type: type,
        label: label,
      ));
      AppLogger.debug('Attempting to speak: "$textToSpeak" for stimulus type: $type', tag: 'TTS');
      _speakStimulus(textToSpeak);
    } else {
      AppLogger.debug('Visual mode - showing stimulus visually', tag: 'DrillRunner');
    }
    
    // Enhanced feedback based on stimulus type
    switch (type) {
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
      case StimulusType.custom:
        HapticFeedback.selectionClick();
        break;
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
    AppLogger.debug('_completeRep called: Set $_currentSet, Rep $_currentRep', tag: 'DrillRunner');
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
      
      AppLogger.debug('Rep result: score=$repScore, events=${_currentRepEvents.length}', tag: 'DrillRunner');
      
      // Add to current set's rep results
      if (_setResults.isNotEmpty) {
        _setResults.last.repResults.add(repResult);
        AppLogger.debug('Added to set ${_setResults.last.setNumber}, total reps now: ${_setResults.last.repResults.length}', tag: 'DrillRunner');
      }
    }
    
    // Check if set is complete
    AppLogger.debug('Checking: _currentRep=$_currentRep >= widget.drill.reps=${widget.drill.reps}?', tag: 'DrillRunner');
    if (_currentRep >= widget.drill.reps) {
      AppLogger.success('Set complete! Calling _completeSet()', tag: 'DrillRunner');
      _completeSet();
    } else {
      AppLogger.debug('More reps needed', tag: 'DrillRunner');
      // Increment rep counter for next rep
      _currentRep++;
      AppLogger.debug('Incremented _currentRep to $_currentRep', tag: 'DrillRunner');
      
      // Start rest period between reps if rest time is configured
      if (widget.drill.restSec > 0) {
        _startRestPeriod();
      } else {
        _startNextRep();
      }
    }
  }

  void _completeSet() {
    AppLogger.debug('_completeSet called: _currentSet=$_currentSet, _safeSetCount=$_safeSetCount', tag: 'DrillRunner');
    
    // Update current set's end time and stats
    if (_setResults.isNotEmpty) {
      _setResults.last.endTime = DateTime.now();
      _setResults.last.updateStats();
      AppLogger.debug('Updated set ${_setResults.last.setNumber}: ${_setResults.last.repResults.length} reps', tag: 'DrillRunner');
    }
    
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    
    // Show set completion feedback
    _showFeedback('Set $_currentSet Complete!', Colors.green);
    
    // Check if all sets are complete
    if (_currentSet >= _safeSetCount) {
      AppLogger.success('All sets complete! Finishing drill...', tag: 'DrillRunner');
      // All sets complete - finish drill
      setState(() {
        _state = DrillRunnerState.finished;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        _finish();
      });
    } else {
      AppLogger.info('Moving to next set...', tag: 'DrillRunner');
      // Move to next set
      _currentSet++;
      _currentRep = 1; // Initialize rep counter for new set
      AppLogger.debug('New values: _currentSet=$_currentSet, _currentRep=$_currentRep', tag: 'DrillRunner');
      
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
        AppLogger.info('Program day ${widget.programDayNumber} completed successfully', tag: 'DrillRunner');
        
        // Show success message for program day completion
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Day ${widget.programDayNumber} completed! 🎉'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        AppLogger.error('Error completing program day', error: e, tag: 'DrillRunner');
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to complete program day: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
    
    if (!mounted) return;
    
    // Show completion feedback
    HapticFeedback.heavyImpact();
    
    // Navigate to detailed results after a brief delay with proper navigation guards
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      try {
        if (widget.isMultiplayerMode) {
          // Multiplayer mode - call completion callback
          widget.onDrillComplete?.call(result);
        } else if (widget.programId != null && widget.programDayNumber != null) {
          // Show success message for program completion
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Day ${widget.programDayNumber} completed! 🎉'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          
          // Check if there's a next day and show option to start it
          _checkAndShowNextDayOption();
          
          // Navigate back to program with guard after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && context.mounted) {
              context.go('/programs');
            }
          });
        } else {
          // Navigate to drill results screen with detailed set results
          final detailedSetResults = _setResults.map((setResult) {
            AppLogger.debug('Set ${setResult.setNumber}: ${setResult.repResults.length} reps', tag: 'DrillRunner');
            return {
              'setNumber': setResult.setNumber,
              'reps': setResult.repResults.map((repResult) {
                AppLogger.debug('Rep ${repResult.repNumber}: ${repResult.score} hits, ${repResult.events.length} stimuli', tag: 'DrillRunner');
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
          
          AppLogger.debug('Total sets being passed: ${detailedSetResults.length}', tag: 'DrillRunner');
          
          // Navigate with proper guard
          if (mounted && context.mounted) {
            context.go('/drill-results', extra: {
              'result': result,
              'detailedSetResults': detailedSetResults,
            });
          }
        }
      } catch (e) {
        AppLogger.error('Navigation error in _finish', error: e, tag: 'DrillRunner');
        // Fallback navigation
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
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
    AppLogger.info('TTS stopped on dispose', tag: 'TTS');
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
        // Only show pause button for host in multiplayer mode, or in non-multiplayer mode
        if (_state == DrillRunnerState.running && (!widget.isMultiplayerMode || widget.isHost))
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
        return SizedBox(
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
    // Always use only center zone - ignore drill configuration for consistent UX
    final zones = [ReactionZone.center];
    return zones.map((zone) => _buildZoneIndicator(zone, constraints)).toList();
  }

  Widget _buildZoneIndicator(ReactionZone zone, BoxConstraints constraints) {
    
    final isActive = _current != null && _getCurrentZone() == zone;
    
    // Calculate size based on available space - much larger for better visibility
    final availableSize = constraints.maxHeight.clamp(200.0, 600.0);
    final stimulusSize = availableSize * 0.6; // 60% of available height
    final fontSize = stimulusSize * 0.4; // 40% of stimulus size
    final iconSize = stimulusSize * 0.25; // 25% of stimulus size
    
    return Positioned(
      left: (constraints.maxWidth - stimulusSize) / 2,
      top: (constraints.maxHeight - stimulusSize) / 2,
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
                            ? (_current?.type == StimulusType.color || _current?.type == StimulusType.custom ? _displayColor : Colors.white.withOpacity(0.9))
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
                            color: (_current?.type == StimulusType.color || _current?.type == StimulusType.custom
                                ? _displayColor
                                : Colors.white).withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 15,
                          ),
                        ] : null,
                      ),
                      child: isActive ? _buildStimulusContent(fontSize) : Icon(
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

  Widget _buildStimulusContent(double fontSize) {
    if (_current?.type == StimulusType.custom) {
      // Handle custom stimulus display
      final drill = widget.drill;
      if (drill.customStimuliIds.isNotEmpty && _customStimuliCache.isNotEmpty) {
        // Find all selected custom stimulus items from all cached stimuli
        for (final customStimulus in _customStimuliCache.values) {
          for (final item in customStimulus.items) {
            if (drill.customStimuliIds.contains(item.id)) {
              bool isCurrentItem = false;
              
              switch (customStimulus.type) {
                case CustomStimulusType.text:
                  isCurrentItem = (item.textValue ?? item.name) == _display;
                  break;
                case CustomStimulusType.image:
                  isCurrentItem = item.name == _display;
                  break;
                case CustomStimulusType.shape:
                  isCurrentItem = (item.shapeType ?? item.name) == _display;
                  break;
                case CustomStimulusType.color:
                  isCurrentItem = item.name == _display;
                  break;
              }
              
              if (isCurrentItem) {
                // Display the custom stimulus item
                switch (customStimulus.type) {
                  case CustomStimulusType.image:
                    if (item.imageBase64 != null) {
                      try {
                        // Handle both data URL format and plain base64
                        String base64String = item.imageBase64!;
                        if (base64String.startsWith('data:')) {
                          // Extract base64 part from data URL (e.g., "data:image/png;base64,...")
                          final commaIndex = base64String.indexOf(',');
                          if (commaIndex != -1) {
                            base64String = base64String.substring(commaIndex + 1);
                          }
                        }
                        
                        final bytes = base64Decode(base64String);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            bytes,
                            width: fontSize * 2,
                            height: fontSize * 2,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              AppLogger.error('Failed to display custom image', error: error, tag: 'DrillRunner');
                              return Container(
                                width: fontSize * 2,
                                height: fontSize * 2,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.broken_image,
                                  size: fontSize,
                                  color: Colors.grey[600],
                                ),
                              );
                            },
                          ),
                        );
                      } catch (e) {
                        AppLogger.error('Failed to decode custom image', error: e, tag: 'DrillRunner');
                        // Return error placeholder instead of breaking
                        return Container(
                          width: fontSize * 2,
                          height: fontSize * 2,
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.error,
                            size: fontSize,
                            color: Colors.red,
                          ),
                        );
                      }
                    }
                    break;
                  case CustomStimulusType.text:
                  case CustomStimulusType.shape:
                  case CustomStimulusType.color:
                    // Fall through to default text display
                    break;
                }
                break;
              }
            }
          }
        }
      }
    }
    
    // Default text display for all other cases
    return Text(
      _display,
      style: TextStyle(
        color: _current?.type == StimulusType.color || _current?.type == StimulusType.custom
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
    );
  }

  Widget _buildActiveStimulus() {
    // This is now handled within zone indicators
    return const SizedBox.shrink();
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
    // Always return center zone - stimuli should always appear in the center
    return ReactionZone.center;
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
    // In multiplayer mode, only show controls for host
    if (widget.isMultiplayerMode && !widget.isHost) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.15),
                Colors.blue.withOpacity(0.25),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.blue.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  color: Colors.blue[300],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Participant Mode',
                      style: TextStyle(
                        color: Colors.blue[200],
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Host controls the drill session',
                      style: TextStyle(
                        color: Colors.blue[300],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Enhanced controls for host or non-multiplayer mode
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade900.withOpacity(0.8),
              Colors.grey.shade800.withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Main control button
            if (_state == DrillRunnerState.ready) ...[
              _buildPrimaryButton(
                onPressed: _start,
                icon: Icons.play_arrow_rounded,
                label: 'START DRILL',
                color: Colors.green,
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
              ),
            ] else if (_state == DrillRunnerState.countdown) ...[
              _buildPrimaryButton(
                onPressed: null,
                icon: Icons.timer,
                label: 'STARTING...',
                color: Colors.orange,
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                ),
              ),
            ] else if (_state == DrillRunnerState.running) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      onPressed: _showPauseDialog,
                      icon: Icons.pause_rounded,
                      label: 'PAUSE',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPrimaryButton(
                      onPressed: _finish,
                      icon: Icons.stop_rounded,
                      label: 'STOP',
                      color: Colors.red,
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (_state == DrillRunnerState.paused) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildPrimaryButton(
                      onPressed: _resumeDrill,
                      icon: Icons.play_arrow_rounded,
                      label: 'RESUME',
                      color: Colors.green,
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSecondaryButton(
                      onPressed: _finish,
                      icon: Icons.stop_rounded,
                      label: 'STOP',
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ] else if (_state == DrillRunnerState.rest) ...[
              _buildPrimaryButton(
                onPressed: null,
                icon: Icons.hourglass_empty_rounded,
                label: 'RESTING... ${_restCountdown}s',
                color: Colors.blue,
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
              ),
            ] else if (_state == DrillRunnerState.finished) ...[
              _buildPrimaryButton(
                onPressed: null,
                icon: Icons.check_circle_rounded,
                label: 'COMPLETED!',
                color: Colors.green,
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
              ),
            ],
            
            // Status indicator
            const SizedBox(height: 12),
            _buildStatusIndicator(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    Gradient? gradient,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient ?? LinearGradient(
          colors: [color.withOpacity(0.8), color],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed != null ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSecondaryButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.6),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusIndicator() {
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    switch (_state) {
      case DrillRunnerState.ready:
        statusText = 'Ready to start';
        statusColor = Colors.white70;
        statusIcon = Icons.radio_button_unchecked;
        break;
      case DrillRunnerState.countdown:
        statusText = 'Get ready...';
        statusColor = Colors.orange;
        statusIcon = Icons.timer;
        break;
      case DrillRunnerState.running:
        statusText = 'Drill in progress';
        statusColor = Colors.green;
        statusIcon = Icons.play_circle_filled;
        break;
      case DrillRunnerState.paused:
        statusText = 'Drill paused';
        statusColor = Colors.orange;
        statusIcon = Icons.pause_circle_filled;
        break;
      case DrillRunnerState.rest:
        statusText = 'Rest period';
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_empty;
        break;
      case DrillRunnerState.finished:
        statusText = 'Drill completed';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          statusIcon,
          color: statusColor,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
    // Pause the drill immediately
    _ticker?.cancel();
    _stopwatch.stop();
    
    setState(() {
      _state = DrillRunnerState.paused;
    });
    
    _showFeedback('Paused', Colors.orange);
    HapticFeedback.mediumImpact();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.pause_circle_filled,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Drill Paused'),
          ],
        ),
        content: const Text('The drill has been paused. What would you like to do?'),
        actions: [
          TextButton.icon(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              _resumeDrill();
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              _finish();
            },
            icon: const Icon(Icons.stop),
            label: const Text('End Drill'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  /// Checks if there's a next day and shows option to start it
  Future<void> _checkAndShowNextDayOption() async {
    if (widget.programId == null || widget.programDayNumber == null) return;
    
    try {
      final nextDay = widget.programDayNumber! + 1;
      
      // Show a simple dialog asking if user wants to continue to next day
      // The actual program data will be fetched when they navigate back to programs
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Day $nextDay Ready!'),
            content: Text(
              'Great job completing Day ${widget.programDayNumber}! Would you like to continue to Day $nextDay?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate back to programs screen where they can start the next day
                  context.go('/programs');
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error checking next day option', error: e, tag: 'DrillRunner');
    }
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
