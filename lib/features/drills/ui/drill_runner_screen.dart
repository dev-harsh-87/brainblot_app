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
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/core/services/audio_service.dart';

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
  
  // Audio service
  final AudioService _audioService = AudioService();

  late DateTime _startedAt;
  DateTime? _endedAt;

  // Pre-generated schedule of stimuli times (ms) within duration
  late final List<_Stimulus> _schedule;
  int _currentIndex = -1;
  bool _isInitializationComplete = false;
  _Stimulus? _current;

  // Stats
  int _score = 0;
  final List<ReactionEvent> _events = [];

  // UI
  String _display = '';
  Color _displayColor = Colors.transparent; // Will be set dynamically based on theme
  
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
  Color _feedbackColor = AppTheme.successColor;
  
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
    
    // Initialize async operations
    _initializeAsync(validatedDrill);
    _initializeAnimations();
    _initializeTts();
  }
  
  Future<void> _initializeAsync(Drill validatedDrill) async {
    try {
      AppLogger.info('Starting drill initialization for: ${validatedDrill.name}', tag: 'DrillRunner');
      
      // Preload custom stimuli if needed - MUST complete before schedule generation
      if (validatedDrill.customStimuliIds.isNotEmpty) {
        AppLogger.info('Preloading ${validatedDrill.customStimuliIds.length} custom stimuli items', tag: 'DrillRunner');
        await _preloadCustomStimuli(validatedDrill);
        
        // Verify custom stimuli were loaded successfully
        if (_customStimuliCache.isEmpty) {
          AppLogger.error('Failed to load custom stimuli - cache is empty', tag: 'DrillRunner');
          throw Exception('Failed to load custom stimuli');
        }
        
        AppLogger.success('Custom stimuli preloaded successfully: ${_customStimuliCache.length} stimuli cached', tag: 'DrillRunner');
      }
      
      // Generate schedule after custom stimuli are loaded
      _schedule = _generateSchedule(validatedDrill);
      
      if (_schedule.isEmpty) {
        AppLogger.error('Generated schedule is empty', tag: 'DrillRunner');
        throw Exception('Failed to generate drill schedule');
      }
      AppLogger.success('Drill initialization complete - schedule has ${_schedule.length} stimuli', tag: 'DrillRunner');
      
      // Mark initialization as complete
      setState(() {
        _isInitializationComplete = true;
      });
      
      
      // Update UI to reflect that initialization is complete
      if (mounted) {
        setState(() {
          // Trigger rebuild now that everything is initialized
        });
      }
    } catch (e) {
      AppLogger.error('Drill initialization failed', error: e, tag: 'DrillRunner');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize drill: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      rethrow;
    }
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
    AppLogger.debug('Drill details - name: "${drill.name}", stimulusTypes: ${drill.stimulusTypes}', tag: 'DrillRunner');
    AppLogger.debug('Drill customStimuliIds length: ${drill.customStimuliIds.length}', tag: 'DrillRunner');
    
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
                backgroundColor: AppTheme.warningColor,
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
          SnackBar(
            content: const Text('Failed to initialize multiplayer sync'),
            backgroundColor: AppTheme.errorColor,
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
        // Drill is already running, start it for this participant after initialization
        AppLogger.info('Drill already active, auto-starting for participant', tag: 'Multiplayer');
        
        // Wait for initialization to complete before starting
        _waitForInitializationAndStart();
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
          _waitForInitializationAndStart();
        } else {
          AppLogger.warning('Ignoring drill start event - already in state: $_state', tag: 'Multiplayer');
        }
      } else if (event is DrillStoppedEvent) {
        // Host stopped the drill - stop locally and handle completion
        if (_state == DrillRunnerState.running || _state == DrillRunnerState.paused) {
          AppLogger.info('Stopping drill from multiplayer sync', tag: 'Multiplayer');
          _stopDrillFromSync();
        }
      } else if (event is DrillPausedEvent) {
        // Host paused the drill - pause locally
        if (_state == DrillRunnerState.running && !_isMultiplayerPaused) {
          AppLogger.info('Pausing drill from multiplayer sync', tag: 'Multiplayer');
          _pauseDrillFromSync(event);
        } else {
          AppLogger.warning('Ignoring drill pause event - state: $_state, isMultiplayerPaused: $_isMultiplayerPaused', tag: 'Multiplayer');
        }
      } else if (event is DrillResumedEvent) {
        // Host resumed the drill - resume locally
        if (_state == DrillRunnerState.paused || _isMultiplayerPaused) {
          AppLogger.info('Resuming drill from multiplayer sync', tag: 'Multiplayer');
          _resumeDrillFromSync(event);
        } else {
          AppLogger.warning('Ignoring drill resume event - state: $_state, isMultiplayerPaused: $_isMultiplayerPaused', tag: 'Multiplayer');
        }
      } else if (event is StimulusEvent) {
        // Participant receiving stimulus data from host
        if (!widget.isHost && _state == DrillRunnerState.running && !_isMultiplayerPaused) {
          _handleStimulusFromHost(event.data);
        }
      }
    } catch (e) {
      AppLogger.error('Error handling multiplayer drill event', error: e, tag: 'Multiplayer');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _handleStimulusFromHost(Map<String, dynamic> stimulusData) {
    try {
      // Only participants should handle stimulus from host
      if (widget.isHost) {
        AppLogger.debug('Host ignoring own stimulus broadcast', tag: 'Multiplayer');
        return;
      }
      
      // Extract stimulus data from host broadcast
      final stimulusTypeStr = stimulusData['stimulusType'] as String;
      final label = stimulusData['label'] as String;
      final colorValue = stimulusData['colorValue'] as int;
      final index = stimulusData['index'] as int;
      final hostTimeMs = stimulusData['timeMs'] as int;
      final hostTimestamp = stimulusData['timestamp'] as int?;
      final customStimulusItemId = stimulusData['customStimulusItemId'] as String?;
      
      // Parse stimulus type
      final stimulusType = StimulusType.values.firstWhere(
        (e) => e.name == stimulusTypeStr,
        orElse: () => StimulusType.color,
      );
      
      // Calculate network delay compensation
      int adjustedTimeMs = hostTimeMs;
      if (hostTimestamp != null) {
        final networkDelay = DateTime.now().millisecondsSinceEpoch - hostTimestamp;
        adjustedTimeMs = hostTimeMs + networkDelay;
        AppLogger.debug('Network delay compensation: ${networkDelay}ms', tag: 'Multiplayer');
      }
      
      // Handle custom stimuli reconstruction for participants
      Color displayColor = Color(colorValue);
      String displayLabel = label;
      
      if (stimulusType == StimulusType.custom && customStimulusItemId != null) {
        // Try to reconstruct custom stimulus from broadcast data
        final customStimulusType = stimulusData['customStimulusType'] as String?;
        final imageBase64 = stimulusData['imageBase64'] as String?;
        final textValue = stimulusData['textValue'] as String?;
        final customColorValue = stimulusData['customColorValue'] as int?;
        final shapeType = stimulusData['shapeType'] as String?;
        
        AppLogger.debug('Reconstructing custom stimulus: type=$customStimulusType, itemId=$customStimulusItemId', tag: 'Multiplayer');
        
        // Update display based on custom stimulus type
        if (customStimulusType != null) {
          switch (customStimulusType) {
            case 'image':
              // For images, keep the label as the item name
              displayLabel = label;
              break;
            case 'text':
              // For text, use the text value if available
              if (textValue != null) {
                displayLabel = textValue;
              }
              break;
            case 'color':
              // For colors, use custom color if available
              if (customColorValue != null) {
                displayColor = Color(customColorValue);
                displayLabel = widget.drill.presentationMode == PresentationMode.audio ? label : '';
              }
              break;
            case 'shape':
              // For shapes, use shape type if available
              if (shapeType != null) {
                displayLabel = shapeType;
              }
              break;
          }
        }
      }
      
      // Update current stimulus state to match host exactly
      _currentIndex = index;
      if (_currentIndex < _schedule.length) {
        _current = _schedule[_currentIndex];
        // Update the custom stimulus item ID if provided
        if (customStimulusItemId != null) {
          _current = _Stimulus(
            index: _current!.index,
            timeMs: _current!.timeMs,
            type: _current!.type,
            label: displayLabel,
            customStimulusItemId: customStimulusItemId,
          );
        }
      } else {
        // Create a temporary stimulus object for this broadcast
        _current = _Stimulus(
          index: index,
          timeMs: hostTimeMs,
          type: stimulusType,
          label: displayLabel,
          customStimulusItemId: customStimulusItemId,
        );
      }
      
      // Display the exact stimulus data from host (same color, same label)
      _showStimulus(displayLabel, displayColor, stimulusType);
      
      AppLogger.debug('Participant synchronized stimulus: type=$stimulusTypeStr, label="$displayLabel", color=${displayColor.value.toRadixString(16)}, index=$index, customItemId=$customStimulusItemId', tag: 'Multiplayer');
    } catch (e) {
      AppLogger.error('Error handling stimulus from host', error: e, tag: 'Multiplayer');
    }
  }

  void _waitForInitializationAndStart() {
    // If already initialized, start immediately
    if (_isInitializationComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _state == DrillRunnerState.ready) {
          _startDrillFromSync();
        }
      });
      return;
    }
    
    // Otherwise, wait for initialization to complete
    AppLogger.info('Waiting for drill initialization to complete before starting from sync', tag: 'Multiplayer');
    
    // Check periodically for initialization completion
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isInitializationComplete) {
        timer.cancel();
        AppLogger.info('Initialization complete, starting drill from sync', tag: 'Multiplayer');
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _state == DrillRunnerState.ready) {
            _startDrillFromSync();
          }
        });
      } else if (!mounted) {
        // Widget was disposed, cancel the timer
        timer.cancel();
      }
    });
  }

  bool _isScheduleInitialized() {
    // Use the completion flag for reliable initialization check
    if (!_isInitializationComplete) {
      return false;
    }
    
    try {
      // Double-check that schedule is actually accessible and not empty
      return _schedule.isNotEmpty;
    } catch (e) {
      // LateInitializationError means the schedule hasn't been set yet
      AppLogger.warning('Schedule access failed despite completion flag: $e', tag: 'DrillRunner');
      return false;
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
      
      // Critical: Ensure schedule is initialized before starting timer
      if (!_isScheduleInitialized()) {
        AppLogger.warning('Schedule not initialized, cannot start drill from sync', tag: 'Multiplayer');
        return;
      }
      
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
        _displayColor = Theme.of(context).colorScheme.onSurface;
      });
      
      _showFeedback('Started by Host', AppTheme.successColor);
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
        _isMultiplayerPaused = false; // Reset pause state
      });
      
      _showFeedback('Stopped by Host', AppTheme.errorColor);
      HapticFeedback.mediumImpact();
      
      // Complete the drill and navigate back with proper delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _completeMultiplayerDrill();
        }
      });
      
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
      
      AppLogger.info('Completing multiplayer drill: ${widget.drill.name}', tag: 'Multiplayer');
      
      // Call completion callback if provided
      if (widget.onDrillComplete != null) {
        AppLogger.debug('Using drill completion callback', tag: 'Multiplayer');
        widget.onDrillComplete!(sessionResult);
      } else {
        // If no callback provided, show completion feedback and navigate back
        AppLogger.debug('No completion callback, handling navigation manually', tag: 'Multiplayer');
        
        if (mounted) {
          // Show completion feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Drill completed: ${widget.drill.name}'),
                  Text(
                    'Your Score: ${sessionResult.hits}/${sessionResult.totalStimuli} (${(sessionResult.accuracy * 100).toStringAsFixed(1)}%)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Navigate back to join session screen immediately
          // Use popUntil to ensure we go back to the correct screen
          Navigator.of(context).popUntil((route) {
            // Pop until we reach the join session screen or multiplayer selection
            return route.settings.name == '/join-session' ||
                   route.settings.name == '/multiplayer-selection' ||
                   route.isFirst;
          });
        }
      }
    } catch (e) {
      AppLogger.error('Error completing multiplayer drill', error: e, tag: 'Multiplayer');
      // Still navigate back on error with proper navigation guard
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _pauseDrillFromSync(DrillPausedEvent event) {
    if (_state != DrillRunnerState.running) {
      AppLogger.warning('Cannot pause drill from sync in state: $_state', tag: 'Multiplayer');
      return;
    }
    
    AppLogger.info('Pausing drill from multiplayer sync with timing: ${event.currentTimeMs}ms, index: ${event.currentIndex}', tag: 'Multiplayer');
    
    try {
      // Cancel ticker and stop stopwatch
      _ticker?.cancel();
      _ticker = null;
      _stopwatch.stop();
      _isMultiplayerPaused = true;
      
      // Synchronize timing with host if provided
      if (event.currentTimeMs != null) {
        // Reset stopwatch to match host timing
        _stopwatch.reset();
        // Note: We can't directly set elapsed time, so we'll track the offset
        AppLogger.debug('Host timing: ${event.currentTimeMs}ms, participant will sync on resume', tag: 'Multiplayer');
      }
      
      // Synchronize current index with host if provided
      if (event.currentIndex != null && event.currentIndex! >= 0 && event.currentIndex! < _schedule.length) {
        _currentIndex = event.currentIndex!;
        AppLogger.debug('Synchronized current index to: $_currentIndex', tag: 'Multiplayer');
      }
      
      // Clear current stimulus display and show pause message
      setState(() {
        _state = DrillRunnerState.paused;
        _display = 'PAUSED BY HOST';
        _displayColor = AppTheme.warningColor;
        _current = null; // Clear current stimulus
      });
      
      _showFeedback('Paused by Host', AppTheme.warningColor);
      HapticFeedback.mediumImpact();
      
      // Stop any ongoing TTS
      if (_isTtsInitialized) {
        _flutterTts.stop();
      }
      
      AppLogger.success('Drill paused from multiplayer sync', tag: 'Multiplayer');
    } catch (e) {
      AppLogger.error('Error pausing drill from sync', error: e, tag: 'Multiplayer');
    }
  }

  void _resumeDrillFromSync(DrillResumedEvent event) {
    if (_state != DrillRunnerState.paused && !_isMultiplayerPaused) {
      AppLogger.warning('Cannot resume drill from sync in state: $_state, isMultiplayerPaused: $_isMultiplayerPaused', tag: 'Multiplayer');
      return;
    }
    
    AppLogger.info('Resuming drill from multiplayer sync with timing: ${event.currentTimeMs}ms, index: ${event.currentIndex}', tag: 'Multiplayer');
    
    try {
      _isMultiplayerPaused = false;
      
      // Synchronize timing with host if provided
      if (event.currentTimeMs != null) {
        // Reset and start stopwatch to match host timing
        _stopwatch.reset();
        _stopwatch.start();
        
        // Calculate how much time should have elapsed to match host
        final targetTimeMs = event.currentTimeMs!;
        AppLogger.debug('Synchronizing participant timing to match host: ${targetTimeMs}ms', tag: 'Multiplayer');
        
        // We'll let the _onTick method handle the timing synchronization
        // by checking against the schedule times
      } else {
        // Restart the stopwatch normally
        _stopwatch.start();
      }
      
      // Synchronize current index with host if provided
      if (event.currentIndex != null && event.currentIndex! >= 0 && event.currentIndex! < _schedule.length) {
        _currentIndex = event.currentIndex!;
        AppLogger.debug('Synchronized current index to: $_currentIndex', tag: 'Multiplayer');
      }
      
      _ticker = Timer.periodic(const Duration(milliseconds: 8), _onTick);
      
      setState(() {
        _state = DrillRunnerState.running;
        _display = 'Ready'; // Reset display
        _displayColor = Theme.of(context).colorScheme.onSurface;
      });
      
      _showFeedback('Resumed by Host', AppTheme.successColor);
      HapticFeedback.mediumImpact();
      
      AppLogger.success('Drill resumed from multiplayer sync', tag: 'Multiplayer');
    } catch (e) {
      AppLogger.error('Error resuming drill from sync', error: e, tag: 'Multiplayer');
    }
  }
void _broadcastStimulusToParticipants(String label, Color color, StimulusType type) {
    if (!widget.isMultiplayerMode || !widget.isHost || _syncService == null || _current == null) {
      return;
    }
    
    try {
      // Prepare stimulus data for broadcasting with enhanced custom stimuli support
      final stimulusData = {
        'stimulusType': type.name,
        'label': label,
        'colorValue': color.value,
        'timeMs': _stopwatch.elapsedMilliseconds,
        'index': _currentIndex,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'priority': 'high', // Mark stimulus messages as high priority
      };
      
      // Include custom stimulus item ID and metadata if applicable
      if (type == StimulusType.custom && _current!.customStimulusItemId != null) {
        stimulusData['customStimulusItemId'] = _current!.customStimulusItemId!;
        
        // Find and include custom stimulus metadata for participants
        for (final customStimulus in _customStimuliCache.values) {
          for (final item in customStimulus.items) {
            if (item.id == _current!.customStimulusItemId) {
              stimulusData['customStimulusType'] = customStimulus.type.name;
              stimulusData['customStimulusName'] = customStimulus.name;
              stimulusData['customItemName'] = item.name;
              
              // Include type-specific data with null safety
              switch (customStimulus.type) {
                case CustomStimulusType.image:
                  if (item.imageBase64 != null) {
                    stimulusData['imageBase64'] = item.imageBase64!;
                  }
                  break;
                case CustomStimulusType.text:
                  if (item.textValue != null) {
                    stimulusData['textValue'] = item.textValue!;
                  }
                  break;
                case CustomStimulusType.color:
                  if (item.color != null) {
                    stimulusData['customColorValue'] = item.color!.value;
                  }
                  break;
                case CustomStimulusType.shape:
                  if (item.shapeType != null) {
                    stimulusData['shapeType'] = item.shapeType!;
                  }
                  break;
              }
              break;
            }
          }
        }
      }
      
      // Broadcast to all participants
      _syncService!.broadcastStimulus(stimulusData);
      
      AppLogger.debug('Broadcasted stimulus to participants: type=$type, label="$label", color=${color.value.toRadixString(16)}, customItemId=${_current!.customStimulusItemId}', tag: 'Multiplayer');
    } catch (e) {
      AppLogger.error('Failed to broadcast stimulus to participants', error: e, tag: 'Multiplayer');
    }
  }

  void _resumeDrill() {
    if (_state != DrillRunnerState.paused) return;
    
    // If host in multiplayer mode, resume for all devices with timing info
    if (widget.isMultiplayerMode && widget.isHost && _syncService != null) {
      final currentTimeMs = _stopwatch.elapsedMilliseconds;
      _syncService!.resumeDrill(
        currentTimeMs: currentTimeMs,
        currentIndex: _currentIndex,
      );
    }
    
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(milliseconds: 8), _onTick);
    
    setState(() {
      _state = DrillRunnerState.running;
    });
    
    _showFeedback('Resumed', AppTheme.successColor);
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
    final types = drill.stimulusTypes.isEmpty ? [StimulusType.color] : drill.stimulusTypes;
    final out = <_Stimulus>[];
    
    // Calculate timing based on drill mode
    int currentTime = 0;
    
    for (int i = 0; i < drill.numberOfStimuli; i++) {
      final t = types[i % types.length];
      
      if (drill.drillMode == DrillMode.touch) {
        // Touch mode: stimuli appear with delay between them
        // First stimulus appears immediately, subsequent ones appear after delay
        currentTime = i * drill.delayBetweenStimuliMs;
      } else {
        // Timed mode: stimuli appear and stay for stimulusLength, then delay before next
        currentTime = i * (drill.stimulusLengthMs + drill.delayBetweenStimuliMs);
      }
      
      // Handle custom stimuli differently to store the item ID
      String? customStimulusItemId;
      String label;
      
      if (t == StimulusType.custom) {
        final customData = _generateCustomStimulusData(drill);
        label = customData['label'] ?? '';
        customStimulusItemId = customData['itemId'];
      } else {
        label = _labelFor(t, drill);
      }
      
      out.add(_Stimulus(
        index: i,
        timeMs: currentTime,
        type: t,
        label: label,
        customStimulusItemId: customStimulusItemId,
      ));
    }
    
    AppLogger.debug('Generated schedule: ${out.length} stimuli, mode: ${drill.drillMode.name}, total duration: ${drill.durationSec}s', tag: 'DrillRunner');
    
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
        // For visual mode, return empty string so the stimulus content builder can handle it
        // For audio mode, return 'Custom' as fallback
        return widget.drill.presentationMode == PresentationMode.audio ? 'Custom' : '';
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

  Map<String, String?> _generateCustomStimulusData(Drill drill) {
    final rnd = Random();
    
    AppLogger.debug('Custom stimulus generation - customStimuliIds: ${drill.customStimuliIds}', tag: 'DrillRunner');
    AppLogger.debug('Custom stimulus generation - cache size: ${_customStimuliCache.length}', tag: 'DrillRunner');
    
    if (drill.customStimuliIds.isNotEmpty && _customStimuliCache.isNotEmpty) {
      // Find all selected custom stimulus items from all cached stimuli
      final availableItems = <CustomStimulusItem>[];
      final itemToStimulusMap = <String, CustomStimulus>{};
      
      for (final customStimulus in _customStimuliCache.values) {
        AppLogger.debug('Checking stimulus: ${customStimulus.name} with ${customStimulus.items.length} items', tag: 'DrillRunner');
        for (final item in customStimulus.items) {
          AppLogger.debug('Checking item: ${item.id} (${item.name})', tag: 'DrillRunner');
          if (drill.customStimuliIds.contains(item.id)) {
            availableItems.add(item);
            itemToStimulusMap[item.id] = customStimulus;
            AppLogger.debug('Added item to available: ${item.name}', tag: 'DrillRunner');
          }
        }
      }
      
      AppLogger.debug('Available items count: ${availableItems.length}', tag: 'DrillRunner');
      
      if (availableItems.isNotEmpty) {
        // Get a random item from the selected ones
        final randomItem = availableItems[rnd.nextInt(availableItems.length)];
        final parentStimulus = itemToStimulusMap[randomItem.id]!;
        
        AppLogger.debug('Selected random item: ${randomItem.name} from ${parentStimulus.name}', tag: 'DrillRunner');
        
        // Return appropriate label based on item type
        String label;
        switch (parentStimulus.type) {
          case CustomStimulusType.text:
            label = randomItem.textValue ?? randomItem.name;
            AppLogger.debug('Returning text value: $label', tag: 'DrillRunner');
            break;
          case CustomStimulusType.image:
            label = randomItem.name; // Use name as label for images
            AppLogger.debug('Returning image name: $label', tag: 'DrillRunner');
            break;
          case CustomStimulusType.shape:
            label = randomItem.shapeType ?? randomItem.name;
            AppLogger.debug('Returning shape value: $label', tag: 'DrillRunner');
            break;
          case CustomStimulusType.color:
            // For colors, we might want to set the display color
            if (randomItem.color != null) {
              _displayColor = randomItem.color!;
              label = drill.presentationMode == PresentationMode.audio
                  ? randomItem.name
                  : '';
              AppLogger.debug('Returning color value: $label', tag: 'DrillRunner');
            } else {
              label = randomItem.name;
              AppLogger.debug('Returning color name: $label', tag: 'DrillRunner');
            }
            break;
        }
        
        return {
          'label': label,
          'itemId': randomItem.id,
        };
      }
    }
    
    AppLogger.warning('Falling back to Custom - no items found', tag: 'DrillRunner');
    // For visual mode, return empty string so the stimulus content builder can handle it
    // For audio mode, return 'Custom' as fallback
    return {
      'label': drill.presentationMode == PresentationMode.audio ? 'Custom' : '',
      'itemId': null,
    };
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
      _countdown = 5;
    });
    
    // Play initial countdown tick
    _audioService.playCountdownTick();
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
        // Play countdown tick sound
        _audioService.playCountdownTick();
      } else {
        timer.cancel();
        _playWhistleAndStartDrill();
      }
    });
  }
  
  void _playWhistleAndStartDrill() async {
    AppLogger.info('Playing whistle sound to signal "now stimuli comes"', tag: 'DrillRunner');
    
    // Play the user's whistle sound from assets/audio/whistle.mp3
    // This signals to the user that stimuli are about to appear
    await _audioService.playWhistle();
    
    AppLogger.info('Whistle sound completed - now starting drill with stimuli', tag: 'DrillRunner');
    
    // Start the drill immediately after whistle completes
    // The whistle sound method handles its own timing internally
    _startDrill();
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
    // Safety check: Ensure schedule is initialized before proceeding
    if (!_isScheduleInitialized()) {
      AppLogger.warning('Schedule not initialized in _onTick, stopping timer', tag: 'DrillRunner');
      timer.cancel();
      return;
    }
    
    final ms = _stopwatch.elapsedMilliseconds;
    
    // Handle stimulus hiding in timed mode
    if (widget.drill.drillMode == DrillMode.timed && _current != null) {
      // Check if stimulus should be hidden (after stimulusLengthMs)
      if (ms > _current!.timeMs + widget.drill.stimulusLengthMs) {
        // Hide the stimulus by clearing the display
        setState(() {
          _display = '';
          _displayColor = Colors.transparent;
        });
        _current = null;
      }
    } else if (widget.drill.drillMode == DrillMode.touch && _current != null) {
      // Touch mode: Check if next stimulus is about to appear
      // Mark current as missed only if next stimulus is coming and user hasn't tapped
      if (_currentIndex + 1 < _schedule.length &&
          ms >= _schedule[_currentIndex + 1].timeMs - 100) { // 100ms buffer before next stimulus
        _handleMissedStimulus(_current!);
        _current = null;
      }
    }
    
    // Advance stimulus when time passes
    // In multiplayer mode, only the host generates and broadcasts stimuli
    if (_currentIndex + 1 < _schedule.length && ms >= _schedule[_currentIndex + 1].timeMs) {
      
      // In multiplayer mode, completely separate host and participant behavior
      if (widget.isMultiplayerMode) {
        if (widget.isHost && _syncService != null) {
          // Host: Generate stimulus data and broadcast to participants
          _currentIndex++;
          _current = _schedule[_currentIndex];
          
          Color stimulusColor = Colors.white;
          String stimulusLabel = _current!.label;
          
          // Generate the actual stimulus data based on type
          if (_current!.type == StimulusType.color) {
            stimulusColor = _getRandomColor();
            // For color stimuli, regenerate label if needed for audio mode
            if (widget.drill.presentationMode == PresentationMode.audio) {
              stimulusLabel = _getColorName(stimulusColor);
            }
          } else if (_current!.type == StimulusType.custom) {
            // For custom stimuli, ensure we have the proper data
            if (_current!.customStimulusItemId != null) {
              // Find the custom stimulus item to get proper display data
              for (final customStimulus in _customStimuliCache.values) {
                for (final item in customStimulus.items) {
                  if (item.id == _current!.customStimulusItemId) {
                    // Update stimulus data based on custom stimulus type
                    switch (customStimulus.type) {
                      case CustomStimulusType.color:
                        if (item.color != null) {
                          stimulusColor = item.color!;
                          stimulusLabel = widget.drill.presentationMode == PresentationMode.audio
                              ? item.name
                              : '';
                        }
                        break;
                      case CustomStimulusType.text:
                        stimulusLabel = item.textValue ?? item.name;
                        break;
                      case CustomStimulusType.shape:
                        stimulusLabel = item.shapeType ?? item.name;
                        break;
                      case CustomStimulusType.image:
                        stimulusLabel = item.name;
                        break;
                    }
                    break;
                  }
                }
              }
            }
          }
          
          // Broadcast the exact stimulus data to participants
          final stimulusData = {
            'stimulusType': _current!.type.name,
            'label': stimulusLabel,
            'colorValue': stimulusColor.value,
            'timeMs': _current!.timeMs,
            'index': _current!.index,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
          
          // Add custom stimulus item ID if it's a custom stimulus
          if (_current!.type == StimulusType.custom && _current!.customStimulusItemId != null) {
            stimulusData['customStimulusItemId'] = _current!.customStimulusItemId!;
            AppLogger.debug('Broadcasting custom stimulus with itemId: ${_current!.customStimulusItemId}', tag: 'Multiplayer');
          }
          
          _syncService!.broadcastStimulus(stimulusData);
          
          // Show the stimulus locally on host
          _showStimulus(stimulusLabel, stimulusColor, _current!.type);
        }
        // Participants: Do NOTHING here - they only respond to broadcasts
        // This prevents participants from generating their own stimuli
      } else {
        // Single player mode: Generate and show stimulus normally
        _currentIndex++;
        _current = _schedule[_currentIndex];
        
        Color stimulusColor = Colors.white;
        String stimulusLabel = _current!.label;
        
        if (_current!.type == StimulusType.color) {
          stimulusColor = _getRandomColor();
          if (widget.drill.presentationMode == PresentationMode.audio) {
            stimulusLabel = _getColorName(stimulusColor);
          }
        }
        
        _showStimulus(stimulusLabel, stimulusColor, _current!.type);
      }
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
      // For custom stimuli, always set the display to the label
      // For color stimuli, set empty string for visual mode, label for audio mode
      if (type == StimulusType.custom) {
        _display = label;
      } else if (type == StimulusType.color) {
        _display = widget.drill.presentationMode == PresentationMode.audio ? label : '';
      } else {
        _display = label;
      }
      _displayColor = color;
    });
    
    AppLogger.debug('Stimulus shown: type=$type, mode=${widget.drill.presentationMode.name}', tag: 'DrillRunner');
    
    // Broadcast stimulus to participants if host in multiplayer mode
    if (widget.isMultiplayerMode && widget.isHost && _syncService != null && _current != null) {
      _broadcastStimulusToParticipants(label, color, type);
    }
    
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
    
    // Disable tap interaction for timed mode drills
    if (widget.drill.drillMode == DrillMode.timed) return;
    
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
      if (widget.drill.drillMode == DrillMode.touch) {
        _showFeedback('Great!', AppTheme.successColor);
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
      }
    } else {
      if (widget.drill.drillMode == DrillMode.touch) {
        _showFeedback('Too slow!', AppTheme.errorColor);
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      }
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
    
    // Only show missed feedback in touch mode
    if (widget.drill.drillMode == DrillMode.touch) {
      _showFeedback('Missed!', AppTheme.warningColor);
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.lightImpact();
    }
  }

  Color _getRandomColor() {
    final colors = widget.drill.colors;
    if (colors.isEmpty) return Colors.red;
    return colors[Random().nextInt(colors.length)];
  }
void _completeRep() {
    AppLogger.debug('_completeRep called: Set $_currentSet (no reps)', tag: 'DrillRunner');
    _ticker?.cancel();
    _stopwatch.stop();
    
    // Save current set results (no more rep logic)
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
        repNumber: 1, // Always 1 since no reps
        events: List.from(_currentRepEvents),
        startTime: _currentRepStartTime!,
        endTime: DateTime.now(),
        score: repScore,
        averageReactionTime: avgReactionTime,
        accuracy: accuracy,
      );
      
      AppLogger.debug('Set result: score=$repScore, events=${_currentRepEvents.length}', tag: 'DrillRunner');
      
      // Add to current set's rep results
      if (_setResults.isNotEmpty) {
        _setResults.last.repResults.add(repResult);
        AppLogger.debug('Added to set ${_setResults.last.setNumber}', tag: 'DrillRunner');
      }
    }
    
    // Set is complete (no reps to check)
    AppLogger.success('Set complete! Calling _completeSet()', tag: 'DrillRunner');
    _completeSet();
  }

  void _completeSet() {
    AppLogger.debug('_completeSet called: _currentSet=$_currentSet, _safeSetCount=$_safeSetCount', tag: 'DrillRunner');
    
    // Update current set's end time and stats
    if (_setResults.isNotEmpty) {
      _setResults.last.endTime = DateTime.now();
      _setResults.last.updateStats();
      AppLogger.debug('Updated set ${_setResults.last.setNumber}: ${_setResults.last.repResults.length} reps', tag: 'DrillRunner');
    }
    
    // Only show set completion feedback in touch mode
    if (widget.drill.drillMode == DrillMode.touch) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.click);
      _showFeedback('Set $_currentSet Complete!', AppTheme.successColor);
    }
    
    // Check if all sets are complete
    if (_currentSet >= _safeSetCount) {
      AppLogger.success('All sets complete! Finishing drill...', tag: 'DrillRunner');
      // All sets complete - finish drill
      setState(() {
        _state = DrillRunnerState.finished;
      });
      
      // In multiplayer mode, host should notify participants that drill is complete
      if (widget.isMultiplayerMode && widget.isHost && _syncService != null) {
        _syncService!.stopDrill(); // This will notify participants
      }
      
      Future.delayed(const Duration(milliseconds: 1500), () {
        _finish();
      });
    } else {
      AppLogger.info('Moving to next set...', tag: 'DrillRunner');
      // Move to next set
      _currentSet++;
      _currentRep = 1; // Keep at 1 (no reps)
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
    
    _showFeedback('Rest Time', AppTheme.infoColor);
    
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
              backgroundColor: AppTheme.successColor,
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
              backgroundColor: AppTheme.errorColor,
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
                backgroundColor: AppTheme.successColor,
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
          // Check drill mode
          if (widget.drill.drillMode == DrillMode.timed) {
            // For Timed mode: skip results and go directly to drill library
            AppLogger.info('Timed mode drill completed, navigating to /drills', tag: 'DrillRunner');
            if (mounted && context.mounted) {
              // Show completion message first
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Drill completed! 🎉'),
                  backgroundColor: AppTheme.successColor,
                  duration: const Duration(seconds: 2),
                ),
              );
              // Navigate after a small delay to allow snackbar to show
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted && context.mounted) {
                  context.go('/drills');
                }
              });
            }
          } else {
            // For Touch mode: Navigate to drill results screen with detailed set results
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
      backgroundColor: theme.colorScheme.surface,
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
                color: theme.colorScheme.surface,
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
      foregroundColor: theme.colorScheme.onSurface,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.drill.name,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.programId != null && widget.programDayNumber != null)
            Text(
              'Program Day ${widget.programDayNumber}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
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
            icon: Icon(Icons.pause, color: theme.colorScheme.onSurface),
          ),
      ],
    );
  }
  
  Widget _buildStatsHeader(int elapsed, double progress) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress bar
          Container(
            width: double.infinity,
            height: 8,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.playerColor,
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
                'Set',
                '$_currentSet/${widget.drill.sets}',
                Icons.layers,
              ),
              // Only show score and accuracy in touch mode
              if (widget.drill.drillMode == DrillMode.touch) ...[
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
            ],
          ),
          
          // Rest period display
          if (_isInRestPeriod) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'REST TIME',
                    style: TextStyle(
                      color: AppTheme.infoColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_restCountdown',
                    style: TextStyle(
                      color: AppTheme.infoColor,
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
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
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
    
    // Use full screen for stimulus display
    final fontSize = constraints.maxHeight * 0.3; // 30% of screen height for text
    final iconSize = constraints.maxHeight * 0.15; // 15% of screen height for icons
    
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => _registerZoneTap(zone),
          child: Container(
            width: constraints.maxWidth - 20,
            height: constraints.maxHeight - 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? (_current?.type == StimulusType.color || _current?.type == StimulusType.custom ? _displayColor : Colors.white)
                  : Colors.transparent,
            ),
            child: isActive ? _buildStimulusContent(fontSize) : Icon(
              _getZoneIcon(zone),
              color: Colors.white.withOpacity(0.3),
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStimulusContent(double fontSize) {
    AppLogger.debug('_buildStimulusContent called - current type: ${_current?.type}, fontSize: $fontSize', tag: 'DrillRunner');
    
    if (_current?.type == StimulusType.custom) {
      // Handle custom stimulus display
      final drill = widget.drill;
      AppLogger.debug('Building custom stimulus content - customStimuliIds: ${drill.customStimuliIds.length}, cache: ${_customStimuliCache.length}', tag: 'DrillRunner');
      AppLogger.debug('Current stimulus customStimulusItemId: "${_current?.customStimulusItemId}", label: "${_current?.label}"', tag: 'DrillRunner');
      AppLogger.debug('Cache keys: ${_customStimuliCache.keys.toList()}', tag: 'DrillRunner');
      
      if (drill.customStimuliIds.isNotEmpty && _customStimuliCache.isNotEmpty) {
        CustomStimulusItem? currentItem;
        CustomStimulus? parentStimulus;
        
        // First, try to find the item by the stored customStimulusItemId
        if (_current?.customStimulusItemId != null) {
          AppLogger.debug('Looking for custom stimulus item by ID: ${_current!.customStimulusItemId}', tag: 'DrillRunner');
          
          for (final customStimulus in _customStimuliCache.values) {
            for (final item in customStimulus.items) {
              if (item.id == _current!.customStimulusItemId) {
                currentItem = item;
                parentStimulus = customStimulus;
                AppLogger.success('Found custom stimulus item by ID: ${item.name} (${customStimulus.type})', tag: 'DrillRunner');
                break;
              }
            }
            if (currentItem != null) break;
          }
        }
        
        // If no item found by ID, fall back to any available custom stimulus item
        if (currentItem == null) {
          AppLogger.debug('No item found by ID, trying to get any available custom stimulus item', tag: 'DrillRunner');
          for (final customStimulus in _customStimuliCache.values) {
            for (final item in customStimulus.items) {
              if (drill.customStimuliIds.contains(item.id)) {
                currentItem = item;
                parentStimulus = customStimulus;
                AppLogger.success('Using available custom stimulus item: ${item.name} (${customStimulus.type})', tag: 'DrillRunner');
                break;
              }
            }
            if (currentItem != null) break;
          }
        }
        
        // Display the found custom stimulus item
        if (currentItem != null && parentStimulus != null) {
          AppLogger.success('Displaying custom stimulus: ${currentItem.name} (${parentStimulus.type})', tag: 'DrillRunner');
          switch (parentStimulus.type) {
            case CustomStimulusType.image:
              if (currentItem.imageBase64 != null && currentItem.imageBase64!.isNotEmpty) {
                AppLogger.debug('Processing custom image: ${currentItem.name}', tag: 'DrillRunner');
                AppLogger.debug('Base64 string length: ${currentItem.imageBase64!.length}', tag: 'DrillRunner');
                AppLogger.debug('Base64 string starts with: ${currentItem.imageBase64!.substring(0, currentItem.imageBase64!.length > 50 ? 50 : currentItem.imageBase64!.length)}...', tag: 'DrillRunner');
                
                try {
                  // Handle both data URL format and plain base64
                  String base64String = currentItem.imageBase64!.trim();
                  
                  // Remove data URL prefix if present
                  if (base64String.startsWith('data:')) {
                    AppLogger.debug('Detected data URL format, extracting base64 part', tag: 'DrillRunner');
                    final commaIndex = base64String.indexOf(',');
                    if (commaIndex != -1) {
                      base64String = base64String.substring(commaIndex + 1);
                      AppLogger.debug('Extracted base64 part, new length: ${base64String.length}', tag: 'DrillRunner');
                    }
                  }
                  
                  // Clean up the base64 string - remove any whitespace or newlines
                  base64String = base64String.replaceAll(RegExp(r'\s+'), '');
                  AppLogger.debug('Cleaned base64 string length: ${base64String.length}', tag: 'DrillRunner');
                  
                  // Validate base64 string
                  if (base64String.isEmpty) {
                    throw Exception('Base64 string is empty after processing');
                  }
                  
                  // Ensure proper base64 padding
                  while (base64String.length % 4 != 0) {
                    base64String += '=';
                  }
                  
                  AppLogger.debug('Attempting to decode base64 string...', tag: 'DrillRunner');
                  final bytes = base64Decode(base64String);
                  AppLogger.success('Successfully decoded custom image: ${bytes.length} bytes', tag: 'DrillRunner');
                  
                  AppLogger.success('Creating Image.memory widget with ${bytes.length} bytes', tag: 'DrillRunner');
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      bytes,
                      width: fontSize * 3,
                      height: fontSize * 3,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) {
                        AppLogger.error('Image.memory failed to display image', error: error, stackTrace: stackTrace, tag: 'DrillRunner');
                        return Container(
                          width: fontSize * 3,
                          height: fontSize * 3,
                          decoration: BoxDecoration(
                            color: Colors.orange[300],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange[600]!, width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: fontSize * 0.8,
                                color: Colors.orange[800],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Image Error',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: fontSize * 0.2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                } catch (e, stackTrace) {
                  AppLogger.error('Failed to decode/display custom image: ${currentItem.name}', error: e, stackTrace: stackTrace, tag: 'DrillRunner');
                  // Return detailed error placeholder
                  return Container(
                    width: fontSize * 3,
                    height: fontSize * 3,
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red[400]!, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: fontSize * 0.8,
                          color: Colors.red[700],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Decode Error',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: fontSize * 0.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          currentItem.name,
                          style: TextStyle(
                            color: Colors.red[600],
                            fontSize: fontSize * 0.15,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }
              } else {
                AppLogger.warning('Custom image item has no imageBase64 data', tag: 'DrillRunner');
              }
              break;
            case CustomStimulusType.color:
              // For color stimuli, the background color is already set via _displayColor
              // Just return empty container or color name for audio mode
              if (widget.drill.presentationMode == PresentationMode.audio) {
                return Text(
                  currentItem.name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Theme.of(context).colorScheme.shadow.withOpacity(0.7),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                );
              } else {
                // For visual mode, don't show text for colors - the background color is the stimulus
                return const SizedBox.shrink();
              }
            case CustomStimulusType.text:
            case CustomStimulusType.shape:
              // Display as text
              final displayText = parentStimulus.type == CustomStimulusType.text
                  ? (currentItem.textValue ?? currentItem.name)
                  : (currentItem.shapeType ?? currentItem.name);
              return Text(
                displayText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: fontSize * 1.2,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      color: Theme.of(context).colorScheme.shadow.withOpacity(0.8),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              );
          }
        } else {
          AppLogger.warning('No matching custom stimulus item found', tag: 'DrillRunner');
        }
      } else {
        AppLogger.warning('No custom stimuli IDs or cache is empty', tag: 'DrillRunner');
      }
      
      // If we reach here and it's a custom stimulus, try to get any available custom stimulus item
      if (_current?.type == StimulusType.custom && drill.customStimuliIds.isNotEmpty && _customStimuliCache.isNotEmpty) {
        AppLogger.debug('Attempting to display any available custom stimulus item as fallback', tag: 'DrillRunner');
        
        // Get any available custom stimulus item as fallback
        for (final customStimulus in _customStimuliCache.values) {
          for (final item in customStimulus.items) {
            if (drill.customStimuliIds.contains(item.id)) {
              AppLogger.success('Using fallback custom stimulus item: ${item.name} (${customStimulus.type})', tag: 'DrillRunner');
              
              switch (customStimulus.type) {
                case CustomStimulusType.image:
                  if (item.imageBase64 != null && item.imageBase64!.isNotEmpty) {
                    try {
                      // Handle both data URL format and plain base64
                      String base64String = item.imageBase64!;
                      if (base64String.startsWith('data:')) {
                        final commaIndex = base64String.indexOf(',');
                        if (commaIndex != -1) {
                          base64String = base64String.substring(commaIndex + 1);
                        }
                      }
                      
                      final bytes = base64Decode(base64String);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          bytes,
                          width: fontSize * 3,
                          height: fontSize * 3,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            AppLogger.error('Failed to display fallback custom image', error: error, tag: 'DrillRunner');
                            return Container(
                              width: fontSize * 3,
                              height: fontSize * 3,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[600]!, width: 2),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: fontSize,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Custom',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: fontSize * 0.3,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    } catch (e) {
                      AppLogger.error('Failed to decode fallback custom image', error: e, tag: 'DrillRunner');
                    }
                  }
                  break;
                case CustomStimulusType.color:
                  // For color stimuli, the background color is already set via _displayColor
                  if (widget.drill.presentationMode == PresentationMode.audio) {
                    return Text(
                      item.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Theme.of(context).colorScheme.shadow.withOpacity(0.7),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                case CustomStimulusType.text:
                case CustomStimulusType.shape:
                  final displayText = customStimulus.type == CustomStimulusType.text
                      ? (item.textValue ?? item.name)
                      : (item.shapeType ?? item.name);
                  return Text(
                    displayText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: fontSize * 1.2,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      shadows: [
                        Shadow(
                          color: Theme.of(context).colorScheme.shadow.withOpacity(0.8),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  );
              }
              break; // Exit after finding first available item
            }
          }
          break; // Exit after finding first available item
        }
      }
      
      // For custom stimuli that couldn't be found, show a placeholder in visual mode
      AppLogger.warning('Custom stimulus not found, showing placeholder', tag: 'DrillRunner');
      return Container(
        width: fontSize * 3,
        height: fontSize * 3,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[600]!, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: fontSize,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Custom',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: fontSize * 0.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    // Default text display for all other cases (non-custom stimuli)
    AppLogger.debug('Falling back to default text display: "$_display", current type: ${_current?.type}', tag: 'DrillRunner');
    
    // If _display is empty and it's a custom stimulus, show a fallback
    if ((_display.isEmpty || _display == '') && _current?.type == StimulusType.custom) {
      AppLogger.warning('Empty display for custom stimulus, showing fallback', tag: 'DrillRunner');
      return Container(
        width: fontSize * 3,
        height: fontSize * 3,
        decoration: BoxDecoration(
          color: Colors.orange[800],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange[600]!, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: fontSize,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              'Custom',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize * 0.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    return Text(
      _display,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _current?.type == StimulusType.color || _current?.type == StimulusType.custom
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurface,
        fontSize: fontSize * 1.2,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.0,
        shadows: [
          Shadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.8),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
      if (widget.drill.drillMode == DrillMode.touch) {
        _showFeedback('Wrong Zone!', Colors.orange);
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      }
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
            color: AppTheme.playerColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.playerColor.withOpacity(0.4),
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
                  color: AppTheme.infoColor,
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
                        color: AppTheme.infoColor.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Host controls the drill session',
                      style: TextStyle(
                        color: AppTheme.infoColor,
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
              Theme.of(context).colorScheme.surface.withOpacity(0.8),
              Theme.of(context).colorScheme.surface.withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
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
                color: AppTheme.successColor,
              ),
            ] else if (_state == DrillRunnerState.countdown) ...[
              _buildPrimaryButton(
                onPressed: null,
                icon: Icons.timer,
                label: 'STARTING...',
                color: AppTheme.warningColor,
              ),
            ] else if (_state == DrillRunnerState.running) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      onPressed: _showPauseDialog,
                      icon: Icons.pause_rounded,
                      label: 'PAUSE',
                      color: AppTheme.warningColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPrimaryButton(
                      onPressed: _finish,
                      icon: Icons.stop_rounded,
                      label: 'STOP',
                      color: AppTheme.errorColor,
                      gradient: LinearGradient(
                        colors: [AppTheme.errorColor.withOpacity(0.8), AppTheme.errorColor],
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
                      color: AppTheme.successColor,
                      gradient: LinearGradient(
                        colors: [AppTheme.successColor.withOpacity(0.8), AppTheme.successColor],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSecondaryButton(
                      onPressed: _finish,
                      icon: Icons.stop_rounded,
                      label: 'STOP',
                      color: AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ] else if (_state == DrillRunnerState.rest) ...[
              _buildPrimaryButton(
                onPressed: null,
                icon: Icons.hourglass_empty_rounded,
                label: 'RESTING... ${_restCountdown}s',
                color: AppTheme.infoColor,
                gradient: LinearGradient(
                  colors: [AppTheme.infoColor.withOpacity(0.8), AppTheme.infoColor],
                ),
              ),
            ] else if (_state == DrillRunnerState.finished) ...[
              _buildPrimaryButton(
                onPressed: null,
                icon: Icons.check_circle_rounded,
                label: 'COMPLETED!',
                color: AppTheme.successColor,
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
        statusColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
        statusIcon = Icons.radio_button_unchecked;
        break;
      case DrillRunnerState.countdown:
        statusText = 'Get ready...';
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.timer;
        break;
      case DrillRunnerState.running:
        statusText = 'Drill in progress';
        statusColor = AppTheme.successColor;
        statusIcon = Icons.play_circle_filled;
        break;
      case DrillRunnerState.paused:
        statusText = 'Drill paused';
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.pause_circle_filled;
        break;
      case DrillRunnerState.rest:
        statusText = 'Rest period';
        statusColor = AppTheme.infoColor;
        statusIcon = Icons.hourglass_empty;
        break;
      case DrillRunnerState.finished:
        statusText = 'Drill completed';
        statusColor = AppTheme.successColor;
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
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Get Ready!',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            // Circular countdown display
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                border: Border.all(
                  color: theme.colorScheme.onSurface,
                  width: 4,
                ),
              ),
              child: Center(
                child: Text(
                  '$_countdown',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
    
    // If host in multiplayer mode, pause for all devices with timing info
    if (widget.isMultiplayerMode && widget.isHost && _syncService != null) {
      final currentTimeMs = _stopwatch.elapsedMilliseconds;
      _syncService!.pauseDrill(
        currentTimeMs: currentTimeMs,
        currentIndex: _currentIndex,
      );
    }
    
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
              color: AppTheme.warningColor,
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
              foregroundColor: AppTheme.successColor,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              // If in multiplayer mode and participant, notify host about stopping
              if (widget.isMultiplayerMode && !widget.isHost && _syncService != null) {
                _syncService!.stopDrill();
              }
              
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              _finish();
            },
            icon: const Icon(Icons.stop),
            label: const Text('End Drill'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
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
  final String? customStimulusItemId; // Store the actual custom stimulus item ID
  _Stimulus({
    required this.index,
    required this.timeMs,
    required this.type,
    required this.label,
    this.customStimulusItemId,
  });
}

enum DrillRunnerState {
  ready,
  countdown,
  running,
  paused,
  rest,
  finished,
}
