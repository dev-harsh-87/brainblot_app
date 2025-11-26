import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/domain/drill_category.dart';
import 'package:spark_app/features/drills/data/drill_category_repository.dart';
import 'package:spark_app/features/drills/services/drill_creation_service.dart';
import 'package:spark_app/features/drills/services/image_upload_service.dart';
import 'package:spark_app/features/admin/domain/custom_stimulus.dart';
import 'package:spark_app/features/admin/services/custom_stimulus_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/core/widgets/profile_avatar.dart';
import 'package:spark_app/features/profile/services/profile_service.dart';
import 'package:spark_app/features/sharing/domain/user_profile.dart';

class DrillBuilderScreen extends StatefulWidget {
  final Drill? initial;
  const DrillBuilderScreen({super.key, this.initial});

  @override
  State<DrillBuilderScreen> createState() => _DrillBuilderScreenState();
}

class _DrillBuilderScreenState extends State<DrillBuilderScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _pageController = PageController();
  late ProfileService _profileService;
  UserProfile? _userProfile;

  late TextEditingController _name;
  late TextEditingController _description;
  late TextEditingController _videoUrl;
  String _category = '';
  List<DrillCategory> _availableCategories = [];
  bool _loadingCategories = true;
  String? _stepImageUrl;
  File? _selectedImageFile;
  bool _isUploadingImage = false;
  Difficulty _difficulty = Difficulty.beginner;
  int _duration = 60;
  int _rest = 30;
  int _sets = 1;
  int _reps = 1; // Fixed to 1, no longer configurable
  int _numberOfStimuli = 30;
  int _stimulusLengthMs = 1000; // 1 second default for Timed mode
  int _delayBetweenStimuliMs = 500; // 500ms default delay between stimuli
  final Set<StimulusType> _stimuli =
      <StimulusType>{}; // Start with no stimuli selected
  final Set<ReactionZone> _zones = {ReactionZone.center}; // Always center only
  final List<Color> _selectedColors =
      <Color>[]; // Start with no colors selected
  final List<ArrowDirection> _selectedArrows =
      <ArrowDirection>[]; // Start with no arrows selected
  final List<ShapeType> _selectedShapes =
      <ShapeType>[]; // Start with no shapes selected
  final List<int> _selectedNumbers = <int>[]; // Start with no numbers selected
  PresentationMode _presentationMode = PresentationMode.visual;
  DrillMode _drillMode = DrillMode.touch;

  // Custom stimulus variables
  List<CustomStimulus> _customStimuli = [];
  final List<CustomStimulusItem> _selectedCustomStimulusItems = [];
  bool _loadingCustomStimuli = true;

  int _currentStep = 0;
  final int _totalSteps = 4;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _profileService = getIt<ProfileService>();
    _loadUserProfile();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    final d = widget.initial;
    _name = TextEditingController(text: d?.name ?? 'Custom Drill');
    _description = TextEditingController(text: '');
    _videoUrl = TextEditingController(text: d?.videoUrl ?? '');
    _stepImageUrl = d?.stepImageUrl;

    if (d != null) {
      _category = d.category;
      _difficulty = d.difficulty;
      _duration =
          d.durationSec < 60 ? 60 : d.durationSec; // Ensure minimum 60 seconds
      _rest = d.restSec;
      _sets = d.sets;
      _reps = d.reps;
      _numberOfStimuli = d.numberOfStimuli;
      _presentationMode = d.presentationMode;
      _drillMode = d.drillMode;
      _stimulusLengthMs = d.stimulusLengthMs;
      _delayBetweenStimuliMs = d.delayBetweenStimuliMs;
      _stimuli
        ..clear()
        ..addAll(d.stimulusTypes);
      _zones
        ..clear()
        ..addAll(d.zones);
      if (d.colors.isNotEmpty) {
        _selectedColors
          ..clear()
          ..addAll(d.colors);
      }
      if (d.arrows.isNotEmpty) {
        _selectedArrows
          ..clear()
          ..addAll(d.arrows);
      }
      if (d.shapes.isNotEmpty) {
        _selectedShapes
          ..clear()
          ..addAll(d.shapes);
      }
      // Convert numberRange to selected numbers list
      switch (d.numberRange) {
        case NumberRange.oneToThree:
          _selectedNumbers.clear();
          _selectedNumbers.addAll([1, 2, 3]);
          break;
        case NumberRange.oneToFive:
          _selectedNumbers.clear();
          _selectedNumbers.addAll([1, 2, 3, 4, 5]);
          break;
        case NumberRange.oneToNine:
          _selectedNumbers.clear();
          _selectedNumbers.addAll([1, 2, 3, 4, 5, 6, 7, 8, 9]);
          break;
        case NumberRange.oneToTwelve:
          _selectedNumbers.clear();
          _selectedNumbers.addAll([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
          break;
      }
    }

    _loadCategories();
    _loadCustomStimuli();
    _animationController.forward();
  }

  Future<void> _loadCategories() async {
    try {
      print('🔄 Loading categories...');
      final repository = DrillCategoryRepository();
      final categories = await repository.getActiveCategories();
      print('✅ Loaded ${categories.length} categories');

      if (categories.isNotEmpty) {
        print(
            '📋 Categories: ${categories.map((c) => c.displayName).join(", ")}');
      }

      setState(() {
        _availableCategories = categories;
        _loadingCategories = false;
        // Set default category if not already set
        if (_category.isEmpty && categories.isNotEmpty) {
          _category = categories.first.name;
          print('✅ Set default category: ${categories.first.displayName}');
        }
      });
    } catch (e, stackTrace) {
      print('❌ Error loading categories: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _loadingCategories = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadCategories,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadCustomStimuli() async {
    try {
      print('🔄 Loading custom stimuli...');

      // Check if CustomStimulusService is registered
      if (getIt.isRegistered<CustomStimulusService>()) {
        final customStimulusService = getIt<CustomStimulusService>();
        final stimuli = await customStimulusService.getAllCustomStimuli();
        print('✅ Loaded ${stimuli.length} custom stimuli');

        setState(() {
          _customStimuli = stimuli;
          _loadingCustomStimuli = false;
        });

        // If editing an existing drill, populate selected custom stimulus items
        final existingDrill = widget.initial;
        if (existingDrill != null &&
            existingDrill.customStimuliIds.isNotEmpty) {
          print(
              '🔄 Loading selected custom stimulus items for existing drill...');
          print('🔍 Drill customStimuliIds: ${existingDrill.customStimuliIds}');

          _selectedCustomStimulusItems.clear();

          // Find and add the selected custom stimulus items
          for (final customStimulus in stimuli) {
            for (final item in customStimulus.items) {
              if (existingDrill.customStimuliIds.contains(item.id)) {
                _selectedCustomStimulusItems.add(item);
                print('✅ Added selected item: ${item.name} (${item.id})');
              }
            }
          }

          print(
              '✅ Loaded ${_selectedCustomStimulusItems.length} selected custom stimulus items');

          // Trigger UI update
          setState(() {});
        }
      } else {
        print(
            '⚠️ CustomStimulusService not registered - skipping custom stimuli loading');
        setState(() {
          _customStimuli = [];
          _loadingCustomStimuli = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error loading custom stimuli: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _customStimuli = [];
        _loadingCustomStimuli = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _videoUrl.dispose();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  int _calculateDuration() {
    if (_drillMode == DrillMode.touch) {
      // Touch mode: delay_time_seconds × stimuli_count
      return ((_delayBetweenStimuliMs / 1000) * _numberOfStimuli).round();
    } else {
      // Timed mode: (stimulus_length_seconds + delay_time_seconds) × stimuli_count
      return (((_stimulusLengthMs / 1000) + (_delayBetweenStimuliMs / 1000)) *
              _numberOfStimuli)
          .round();
    }
  }

  Drill _build() {
    final initial = widget.initial;

    // Debug logging
    print(
        '🔷 Spark 🔍 [DrillBuilder] Building drill with ${_selectedCustomStimulusItems.length} selected custom stimulus items');
    for (final item in _selectedCustomStimulusItems) {
      print(
          '🔷 Spark 🔍 [DrillBuilder] Selected item: ${item.name} (${item.id})');
    }
    print(
        '🔷 Spark 🔍 [DrillBuilder] Final customStimuliIds: ${_selectedCustomStimulusItems.map((item) => item.id).toList()}');

    // Calculate duration based on drill mode
    final calculatedDuration = _calculateDuration();

    print(
        '🔷 Spark 🔍 [DrillBuilder] Calculated duration: ${calculatedDuration}s (mode: $_drillMode, stimuli: $_numberOfStimuli, delay: ${_delayBetweenStimuliMs}ms, length: ${_stimulusLengthMs}ms)');

    return Drill(
      id: initial?.id ?? _uuid.v4(),
      name: _name.text.trim(),
      category: _category,
      difficulty: _difficulty,
      durationSec: calculatedDuration,
      restSec: _rest,
      sets: _sets,
      reps: _reps,
      stimulusTypes: _stimuli.toList(),
      numberOfStimuli: _numberOfStimuli,
      zones: _zones.toList(),
      colors: _selectedColors,
      arrows: _selectedArrows,
      shapes: _selectedShapes,
      numberRange: _getNumberRangeFromSelectedNumbers(),
      presentationMode: _presentationMode,
      drillMode: _drillMode,
      stimulusLengthMs: _stimulusLengthMs,
      delayBetweenStimuliMs: _delayBetweenStimuliMs,
      favorite: initial?.favorite ?? false,
      isPreset: initial?.isPreset ?? false,
      createdBy: initial?.createdBy,
      sharedWith: initial?.sharedWith ?? [],
      videoUrl: _videoUrl.text.trim().isEmpty ? null : _videoUrl.text.trim(),
      stepImageUrl: _stepImageUrl,
      customStimuliIds:
          _selectedCustomStimulusItems.map((item) => item.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),

          // Content
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBasicInfoStep(),
                  _buildStimulusStep(),
                  _buildConfigurationStep(),
                  _buildReviewStep(),
                ],
              ),
            ),
          ),

          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      elevation: 0,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
              iconTheme: IconThemeData(
          color: colorScheme.onPrimary,
        ),
      title: Text(
        widget.initial == null ? 'Create Drill' : 'Edit Drill',
        style: theme.textTheme.headlineSmall?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: AppTheme.goldPrimary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _profileService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
    }
  }

  Widget _buildProgressIndicator() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index <= _currentStep;
              final isCurrent = index == _currentStep;

              return Expanded(
                child: Container(
                  height: 4,
                  margin:
                      EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            _getStepTitle(_currentStep),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _getStepSubtitle(_currentStep),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Basic Information';
      case 1:
        return 'Select Stimulus';
      case 2:
        return 'Drill Settings & Mode';
      case 3:
        return 'Review & Save';
      default:
        return '';
    }
  }

  String _getStepSubtitle(int step) {
    switch (step) {
      case 0:
        return 'Name, category, and difficulty';
      case 1:
        return 'Stimulus types and reaction zones';
      case 2:
        return 'Mode, duration, repetitions, and timing';
      case 3:
        return 'Review your drill settings';
      default:
        return '';
    }
  }

  Widget _buildBasicInfoStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drill Name
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: 'Drill Name',
                hintText: 'Enter a descriptive name for your drill',
                prefixIcon: const Icon(Icons.fitness_center),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Drill name is required' : null,
            ),
            const SizedBox(height: 20),

            // Description
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Describe what this drill is for and how it works',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // YouTube Video URL
            TextFormField(
              controller: _videoUrl,
              decoration: InputDecoration(
                labelText: 'YouTube Video URL (Optional)',
                hintText: 'https://www.youtube.com/watch?v=...',
                prefixIcon: const Icon(Icons.video_library),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                helperText: 'Add a YouTube video to demonstrate this drill',
              ),
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v != null && v.isNotEmpty) {
                  // Basic YouTube URL validation
                  final youtubeRegex = RegExp(
                    r'^(https?://)?(www\.)?(youtube\.com|youtu\.be)/.+$',
                    caseSensitive: false,
                  );
                  if (!youtubeRegex.hasMatch(v)) {
                    return 'Please enter a valid YouTube URL';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Drill Step Image Upload
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.image, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Drill Step Image (Optional)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload an image showing the drill steps or visualization',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_stepImageUrl != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _stepImageUrl!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: 120,
                              color: colorScheme.errorContainer,
                              child: const Center(
                                child: Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _stepImageUrl = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.scrim.withOpacity(0.7),
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_selectedImageFile != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImageFile!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedImageFile = null;
                              });
                            },
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.scrim.withOpacity(0.7),
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploadingImage
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploadingImage
                                ? null
                                : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_isUploadingImage) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Category Selection
            Text(
              'Category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _loadingCategories
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _availableCategories.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.error.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No categories available. Please contact admin to add categories.',
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableCategories
                            .map((cat) => _buildCategoryChip(cat))
                            .toList(),
                      ),
            const SizedBox(height: 20),

            // Difficulty Selection
            Text(
              'Difficulty Level',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: Difficulty.values
                  .map(
                    (diff) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildDifficultyCard(diff),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(DrillCategory category) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _category == category.name;

    return FilterChip(
      label: Text(
        category.displayName.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _category = category.name;
        });
        HapticFeedback.lightImpact();
      },
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primary,
      checkmarkColor: colorScheme.onPrimary,
      side: BorderSide(
        color: isSelected ? colorScheme.primary : colorScheme.outline,
      ),
    );
  }

  Widget _buildDifficultyCard(Difficulty difficulty) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _difficulty == difficulty;

    Color getDifficultyColor() {
      switch (difficulty) {
        case Difficulty.beginner:
          return AppTheme.successColor;
        case Difficulty.intermediate:
          return AppTheme.warningColor;
        case Difficulty.advanced:
          return AppTheme.errorColor;
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _difficulty = difficulty;
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? getDifficultyColor().withOpacity(0.1)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? getDifficultyColor()
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _getDifficultyIcon(difficulty),
              color: isSelected
                  ? getDifficultyColor()
                  : colorScheme.onSurface.withOpacity(0.7),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              difficulty.name.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    isSelected ? getDifficultyColor() : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDifficultyIcon(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return Icons.sentiment_satisfied;
      case Difficulty.intermediate:
        return Icons.sentiment_neutral;
      case Difficulty.advanced:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  Widget _buildDrillModeCard(DrillMode mode) {
   final theme = Theme.of(context);
   final colorScheme = theme.colorScheme;
   final isSelected = _drillMode == mode;


   String getTitle() {
     switch (mode) {
       case DrillMode.touch:
         return 'Touch';
       case DrillMode.timed:
         return 'Timed';
     }
   }


   IconData getIcon() {
     switch (mode) {
       case DrillMode.touch:
         return Icons.touch_app;
       case DrillMode.timed:
         return Icons.timer;
     }
   }


   return GestureDetector(
     onTap: () {
       setState(() {
         _drillMode = mode;
       });
       HapticFeedback.lightImpact();
     },
     child: Container(
       padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
         color: isSelected
             ? colorScheme.primaryContainer
             : colorScheme.surfaceContainerHighest,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(
           color: isSelected
               ? colorScheme.primary
               : colorScheme.outline.withOpacity(0.3),
           width: isSelected ? 2 : 1,
         ),
 
       ),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
              Icon(
             getIcon(),
             color: isSelected
                 ? colorScheme.onPrimaryContainer
                 : colorScheme.onSurface.withOpacity(0.7),
             size: 32,
           ),
           const SizedBox(height: 10),
           Text(
             getTitle(),
 style: theme.textTheme.titleSmall?.copyWith(
               fontWeight: FontWeight.w600,
               color: isSelected
                   ? colorScheme.onPrimaryContainer
                   : colorScheme.onSurface,
             ),
           ),
         ],
       ),
     ),
   );
 }


  Widget _buildNavigationButtons() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          // Show different buttons based on current step
          if (_currentStep < _totalSteps - 1) ...[
            // Next button for non-final steps
            Expanded(
              child: FilledButton.icon(
                onPressed: _nextStep,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            // Save Drill button for final step
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saveDrill,
                icon: const Icon(Icons.save),
                label: const Text('Save Drill'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Save & Run button for final step
            Expanded(
              child: FilledButton.icon(
                onPressed: _saveAndRunDrill,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Save & Run'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
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

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      // Validate current step before proceeding
      final stepErrors = _getStepValidationErrors(_currentStep);
      if (stepErrors.isNotEmpty) {
        // Show validation errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fix the following: ${stepErrors.join(', ')}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        HapticFeedback.heavyImpact();
        return;
      }

      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticFeedback.lightImpact();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticFeedback.lightImpact();
    }
  }

  Widget _buildConfigurationStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drill Mode Section
          Text(
            'Drill Mode',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how you want to interact with the drill',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDrillModeCard(DrillMode.touch),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDrillModeCard(DrillMode.timed),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mode Meaning Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _drillMode == DrillMode.touch
                        ? 'Touch Mode: Tap stimuli as they appear. Performance metrics will be tracked and analyzed.'
                        : 'Timed Mode: Watch stimuli appear automatically. No interaction required, perfect for passive observation.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Timing Section - Different fields based on drill mode
          Text(
            'Timing Settings',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Timed Mode: Length of time and delay
                if (_drillMode == DrillMode.timed) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildSliderField(
                          'Length of Time',
                          (_stimulusLengthMs / 1000).toDouble(),
                          0.1,
                          5.0,
                          (value) => setState(
                              () => _stimulusLengthMs = (value * 1000).round()),
                          '${(_stimulusLengthMs / 1000).toStringAsFixed(1)}s',
                          description:
                              'How long each stimulus stays visible on screen',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSliderField(
                          'Delay Time',
                          (_delayBetweenStimuliMs / 1000).toDouble(),
                          0.1,
                          3.0,
                          (value) => setState(() =>
                              _delayBetweenStimuliMs = (value * 1000).round()),
                          '${(_delayBetweenStimuliMs / 1000).toStringAsFixed(1)}s',
                          description: 'Pause between each stimulus appearing',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSliderField(
                          'Rounds',
                          _numberOfStimuli.toDouble(),
                          5.0,
                          100.0,
                          (value) =>
                              setState(() => _numberOfStimuli = value.round()),
                          '$_numberOfStimuli stimuli',
                          description:
                              'Total number of stimuli shown during the drill',
                        ),
                      ),
                    ],
                  ),
                ],
                // Touch Mode: Delay time and rest time
                if (_drillMode == DrillMode.touch) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildSliderField(
                          'Delay Time',
                          (_delayBetweenStimuliMs / 1000).toDouble(),
                          0.1,
                          3.0,
                          (value) => setState(() =>
                              _delayBetweenStimuliMs = (value * 1000).round()),
                          '${(_delayBetweenStimuliMs / 1000).toStringAsFixed(1)}s',
                          description: 'Time between each stimulus appearing',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSliderField(
                          'Rounds',
                          _numberOfStimuli.toDouble(),
                          5.0,
                          100.0,
                          (value) =>
                              setState(() => _numberOfStimuli = value.round()),
                          '$_numberOfStimuli stimuli',
                          description:
                              'Total number of stimuli shown during the drill',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sets, Reps, and Stimuli Count
          Text(
            'Sets, Repetitions & Stimuli',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSliderField(
                        'Sets',
                        _sets.toDouble(),
                        1.0,
                        5.0,
                        (value) => setState(() => _sets = value.round()),
                        '$_sets sets',
                        description: 'Number of sets to complete in this drill',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSliderField(
                        'Rest Time',
                        _rest.toDouble(),
                        10.0,
                        120.0,
                        (value) => setState(() => _rest = value.round()),
                        '${_rest}s',
                        description: 'Break time between completing sets',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStimulusStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Presentation Mode Section
          Text(
            'Presentation Mode',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how stimuli will be presented during the drill',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPresentationModeCard(PresentationMode.visual),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPresentationModeCard(PresentationMode.audio),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Clean Stimulus Selection Section - Direct Integration
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Header

              Text(
                'Select Your Stimuli',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select which cues will appear on the screen',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),

              // Colors Section (always visible)
              _buildDirectStimulusSection(
                title: 'Colors',
                content: Column(
                  children: [
                    Row(
                      children: [
                        AppTheme.errorColor,
                        AppTheme.infoColor,
                        AppTheme.successColor,
                        AppTheme.warningColor
                      ]
                          .map((color) => Expanded(
                                  child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildSimpleColorChip(color),
                              )))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Color(0xFF8B5CF6),
                        AppTheme.warningColor,
                        AppTheme.neutral900,
                        AppTheme.neutral500
                      ]
                          .map((color) => Expanded(
                                  child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildSimpleColorChip(color),
                              )))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Arrows Section (always visible)
              _buildDirectStimulusSection(
                title: 'Arrows',
                content: Column(
                  children: [
                    Row(
                      children: [
                        ArrowDirection.up,
                        ArrowDirection.down,
                        ArrowDirection.left,
                        ArrowDirection.right
                      ]
                          .map((arrow) => Expanded(
                                  child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildSimpleArrowChip(arrow),
                              )))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ArrowDirection.upLeft,
                        ArrowDirection.upRight,
                        ArrowDirection.downLeft,
                        ArrowDirection.downRight
                      ]
                          .map((arrow) => Expanded(
                                  child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildSimpleArrowChip(arrow),
                              )))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Shapes Section (always visible)
              _buildDirectStimulusSection(
                title: 'Shapes',
                content: Column(
                  children: [
                    Row(
                      children: [
                        ShapeType.circle,
                        ShapeType.square,
                        ShapeType.triangle,
                        ShapeType.diamond
                      ]
                          .map((shape) => Expanded(
                                  child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildSimpleShapeChip(shape),
                              )))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ShapeType.star,
                        ShapeType.hexagon,
                        ShapeType.pentagon,
                        ShapeType.oval
                      ]
                          .map((shape) => Expanded(
                                  child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildSimpleShapeChip(shape),
                              )))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Numbers Section (always visible)
              _buildDirectStimulusSection(
                title: 'Numbers',
                content: Column(
                  children: [
                    Row(
                      children: [1, 2, 3, 4]
                          .map((number) => Expanded(
                                  child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildSimpleNumberChip(number),
                              )))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [5, 6, 7, 8]
                          .map((number) => Expanded(
                                  child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildSimpleNumberChip(number),
                              )))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Custom Stimuli Section (always visible)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Your Custom Stimuli',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select which cues will appear on the screen',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDirectStimulusSection(
                    content: Column(
                      children: [
                        if (_loadingCustomStimuli) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ] else if (_customStimuli.isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No custom stimuli available. Contact your administrator to add custom stimuli.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          ...(_customStimuli.map((stimulus) =>
                              _buildDirectCustomStimulusSection(stimulus))),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.primaryContainer.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.preview,
                      color: colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Review Your Drill',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Review all settings before saving your custom drill',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Basic Information
          _buildReviewSection(
            'Basic Information',
            Icons.info_outline,
            [
              _buildReviewItem('Name', _name.text),
              _buildReviewItem(
                  'Description',
                  _description.text.isEmpty
                      ? 'No description'
                      : _description.text),
              _buildReviewItem('Category', _category ?? 'Not selected'),
              _buildReviewItem('Difficulty',
                  _difficulty.name.toUpperCase() ?? 'Not selected'),
            ],
          ),
          const SizedBox(height: 24),

          // Configuration
          _buildReviewSection(
            'Configuration',
            Icons.settings,
            [
              _buildReviewItem('Drill Mode', _drillMode.name.toUpperCase()),
              if (_drillMode == DrillMode.timed) ...[
                _buildReviewItem('Length of time',
                    '${(_stimulusLengthMs / 1000).toStringAsFixed(1)}s'),
                _buildReviewItem('Delay time',
                    '${(_delayBetweenStimuliMs / 1000).toStringAsFixed(1)}s'),
              ],
              if (_drillMode == DrillMode.touch) ...[
                _buildReviewItem('Delay time',
                    '${(_delayBetweenStimuliMs / 1000).toStringAsFixed(1)}s'),
              ],
              _buildReviewItem(
                  'Total duration per set', '${_calculateDuration()}s'),
              _buildReviewItem('Rest time between sets', '${_rest}s'),
              _buildReviewItem('Set count', '$_sets'),
              _buildReviewItem('Stimuli count', '$_numberOfStimuli'),
            ],
          ),
          const SizedBox(height: 24),

          _buildReviewSection(
            'Stimulus & Zones',
            Icons.psychology,
            [
              _buildReviewItem(
                  'Presentation mode', _presentationMode.name.toUpperCase()),
              _buildReviewItem(
                  'Stimulus types',
                  _stimuli.isEmpty
                      ? 'None selected'
                      : _stimuli.map((s) => s.name).join(', ')),
              _buildReviewItem(
                  'Reaction zones',
                  _zones.isEmpty
                      ? 'None selected'
                      : _zones.map((z) => z.name).join(', ')),
              _buildReviewItem(
                  'Colors', '${_selectedColors.length} colors selected'),
            ],
          ),
          const SizedBox(height: 32),

          // Validation Warnings
          if (_getValidationErrors().isNotEmpty) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppTheme.errorColor.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              color: AppTheme.errorColor.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.warning_rounded,
                            color: AppTheme.errorColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Please fix the following issues:',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.errorColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._getValidationErrors().map(
                      (error) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                error,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.errorColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Success Message
          if (_getValidationErrors().isEmpty) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppTheme.successColor.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              color: AppTheme.successColor.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: AppTheme.successColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ready to Save!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your drill is configured correctly and ready to be saved.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDirectStimulusSection({
    String? title,
    required Widget content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title.isNotEmpty) ...[
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
        content,
      ],
    );
  }

  // Helper methods for the drill builder
  Widget _buildSliderField(String label, double value, double min, double max,
      ValueChanged<double> onChanged, String displayValue,
      {String? description}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine if this is a delay time slider (to remove divisions)
    final isDelayTime = label.toLowerCase().contains('delay');
    // Determine increment step
    final step = max > 10 ? 1.0 : 0.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayValue,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
        // Enhanced slider with +/- buttons
        Row(
          children: [
            // Minus button (compact design)
            GestureDetector(
              onTap: value > min
                  ? () {
                      final newValue = (value - step).clamp(min, max);
                      onChanged(newValue);
                      HapticFeedback.lightImpact();
                    }
                  : null,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  Icons.remove,
                  size: 12,
                  color: value > min
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Slider
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                // Remove divisions for delay time sliders, keep for others
                divisions: isDelayTime
                    ? null
                    : (max > 10
                        ? (max - min).round()
                        : ((max - min) * 10).round()),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            // Plus button (compact design)
            GestureDetector(
              onTap: value < max
                  ? () {
                      final newValue = (value + step).clamp(min, max);
                      onChanged(newValue);
                      HapticFeedback.lightImpact();
                    }
                  : null,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  Icons.add,
                  size: 12,
                  color: value < max
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPresentationModeCard(PresentationMode mode) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _presentationMode == mode;

    String getLabel() {
      switch (mode) {
        case PresentationMode.visual:
          return 'Visual';
        case PresentationMode.audio:
          return 'Audio';
      }
    }

    String getDescription() {
      switch (mode) {
        case PresentationMode.visual:
          return 'Show stimuli visually';
        case PresentationMode.audio:
          return 'Speak stimuli aloud';
      }
    }

    IconData getIcon() {
      switch (mode) {
        case PresentationMode.visual:
          return Icons.visibility;
        case PresentationMode.audio:
          return Icons.volume_up;
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _presentationMode = mode;
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              getIcon(),
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface.withOpacity(0.7),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              getLabel(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              getDescription(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(String title, IconData icon, List<Widget> items) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: colorScheme.onSurface.withOpacity(0.8),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface.withOpacity(0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: item,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getValidationErrors() {
    final errors = <String>[];

    if (_name.text.trim().isEmpty) {
      errors.add('Drill name is required');
    }

    // Validate minimum duration of 60 seconds
    if (_duration < 60) {
      errors.add('Drill duration must be at least 60 seconds (1 minute)');
    }

    if (_stimuli.isEmpty) {
      errors.add('Please select at least one stimulus type');
    }

    // Zones are always set to center, no validation needed

    if (_stimuli.contains(StimulusType.color) && _selectedColors.length < 2) {
      errors.add('Please select at least 2 colors');
    }

    if (_stimuli.contains(StimulusType.arrow) && _selectedArrows.length < 2) {
      errors.add('Please select at least 2 arrow directions');
    }

    if (_stimuli.contains(StimulusType.shape) && _selectedShapes.length < 2) {
      errors.add('Please select at least 2 shapes');
    }

    if (_stimuli.contains(StimulusType.number) && _selectedNumbers.length < 2) {
      errors.add('Please select at least 2 numbers');
    }

    if (_stimuli.contains(StimulusType.custom) &&
        _selectedCustomStimulusItems.length < 2) {
      errors.add('Please select at least 2 custom stimulus items');
    }

    return errors;
  }

  List<String> _getStepValidationErrors(int step) {
    final errors = <String>[];

    switch (step) {
      case 0: // Basic Information
        if (_name.text.trim().isEmpty) {
          errors.add('Drill name is required');
        }
        if (_name.text.trim().length < 3) {
          errors.add('Drill name must be at least 3 characters');
        }
        break;

      case 1: // Configuration
        if (_duration < 60) {
          errors.add('Duration must be at least 60 seconds');
        }
        if (_rest < 0) {
          errors.add('Rest time cannot be negative');
        }
        break;

      case 2: // Stimulus & Zones
        if (_stimuli.isEmpty) {
          errors.add('Select at least one stimulus type');
        }
        // Zones are always set to center, no validation needed
        if (_stimuli.contains(StimulusType.color) &&
            _selectedColors.length < 2) {
          errors.add('Select at least 2 colors for color stimulus');
        }
        if (_stimuli.contains(StimulusType.arrow) &&
            _selectedArrows.length < 2) {
          errors.add('Select at least 2 arrow directions for arrow stimulus');
        }
        if (_stimuli.contains(StimulusType.shape) &&
            _selectedShapes.length < 2) {
          errors.add('Select at least 2 shapes for shape stimulus');
        }
        if (_stimuli.contains(StimulusType.number) &&
            _selectedNumbers.length < 2) {
          errors.add('Select at least 2 numbers for number stimulus');
        }
        if (_stimuli.contains(StimulusType.custom) &&
            _selectedCustomStimulusItems.length < 2) {
          errors.add('Select at least 2 custom stimulus items');
        }
        break;

      case 3: // Review - no additional validation needed
        break;
    }

    return errors;
  }

  Color _getContrastColor(Color color) {
    // Calculate luminance to determine if we should use black or white text
    final luminance =
        (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? AppTheme.blackPure : AppTheme.whitePure;
  }

  void _saveDrill() async {
    await _saveDrillInternal(runAfterSave: false);
  }

  void _saveAndRunDrill() async {
    await _saveDrillInternal(runAfterSave: true);
  }

  Future<void> _saveDrillInternal({required bool runAfterSave}) async {
    final errors = _getValidationErrors();
    if (errors.isEmpty) {
      final drill = _build();

      try {
        // Use DrillCreationService for additional validation
        final drillCreationService = getIt<DrillCreationService>();

        if (widget.initial == null) {
          // Creating new drill
          await drillCreationService.createDrill(drill);
        } else {
          // Updating existing drill
          await drillCreationService.updateDrill(drill);
        }

        if (mounted) {
          HapticFeedback.mediumImpact();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.initial == null
                  ? 'Drill created successfully!'
                  : 'Drill updated successfully!'),
              backgroundColor: AppTheme.successColor,
            ),
          );

          if (runAfterSave) {
            // Navigate to drill runner screen
            context.go('/drill-runner', extra: drill);
          } else {
            // Navigate back to drill library
            context.go('/drills');
          }
        }
      } catch (e) {
        if (mounted) {
          // Show validation error from service
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Error: ${e.toString().replaceAll('Exception: ', '').replaceAll('ArgumentError: ', '')}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          HapticFeedback.heavyImpact();
        }
      }
    } else {
      // Show validation errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please fix ${errors.length} validation error${errors.length > 1 ? 's' : ''}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final imageUploadService = ImageUploadService();
      File? imageFile;

      if (source == ImageSource.gallery) {
        imageFile = await imageUploadService.pickImageFromGallery();
      } else {
        imageFile = await imageUploadService.pickImageFromCamera();
      }

      if (imageFile != null) {
        setState(() {
          _selectedImageFile = imageFile;
          _isUploadingImage = true;
        });

        // Convert image to base64
        final base64Image =
            await imageUploadService.convertImageToBase64(imageFile);

        setState(() {
          _stepImageUrl = base64Image;
          _isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully!'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
        _selectedImageFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to upload image: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  IconData _getArrowDirectionIcon(ArrowDirection direction) {
    switch (direction) {
      case ArrowDirection.up:
        return Icons.keyboard_arrow_up;
      case ArrowDirection.down:
        return Icons.keyboard_arrow_down;
      case ArrowDirection.left:
        return Icons.keyboard_arrow_left;
      case ArrowDirection.right:
        return Icons.keyboard_arrow_right;
      case ArrowDirection.upLeft:
        return Icons.north_west;
      case ArrowDirection.upRight:
        return Icons.north_east;
      case ArrowDirection.downLeft:
        return Icons.south_west;
      case ArrowDirection.downRight:
        return Icons.south_east;
    }
  }

  Widget _buildSimpleColorChip(Color color) {
    final isSelected = _selectedColors.contains(color);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedColors.remove(color);
            // Remove stimulus type if no colors are selected
            if (_selectedColors.isEmpty) {
              _stimuli.remove(StimulusType.color);
            }
          } else {
            _selectedColors.add(color);
            // Add stimulus type when first color is selected
            _stimuli.add(StimulusType.color);
          }
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.onPrimary,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleArrowChip(ArrowDirection arrow) {
    final isSelected = _selectedArrows.contains(arrow);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedArrows.remove(arrow);
            // Remove stimulus type if no arrows are selected
            if (_selectedArrows.isEmpty) {
              _stimuli.remove(StimulusType.arrow);
            }
          } else {
            _selectedArrows.add(arrow);
            // Add stimulus type when first arrow is selected
            _stimuli.add(StimulusType.arrow);
          }
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Icon(
          _getArrowDirectionIcon(arrow),
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withOpacity(0.6),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSimpleShapeChip(ShapeType shape) {
    final isSelected = _selectedShapes.contains(shape);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedShapes.remove(shape);
            // Remove stimulus type if no shapes are selected
            if (_selectedShapes.isEmpty) {
              _stimuli.remove(StimulusType.shape);
            }
          } else {
            _selectedShapes.add(shape);
            // Add stimulus type when first shape is selected
            _stimuli.add(StimulusType.shape);
          }
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Icon(
          _getShapeTypeIcon(shape),
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withOpacity(0.6),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSimpleNumberChip(int number) {
    final isSelected = _selectedNumbers.contains(number);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedNumbers.remove(number);
            // Remove stimulus type if no numbers are selected
            if (_selectedNumbers.isEmpty) {
              _stimuli.remove(StimulusType.number);
            }
          } else {
            _selectedNumbers.add(number);
            // Add stimulus type when first number is selected
            _stimuli.add(StimulusType.number);
          }
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  NumberRange _getNumberRangeFromSelectedNumbers() {
    if (_selectedNumbers.isEmpty) return NumberRange.oneToFive;

    final maxNumber = _selectedNumbers.reduce((a, b) => a > b ? a : b);

    if (maxNumber <= 3) return NumberRange.oneToThree;
    if (maxNumber <= 5) return NumberRange.oneToFive;
    if (maxNumber <= 9) return NumberRange.oneToNine;
    return NumberRange.oneToTwelve;
  }

  Widget _buildCustomStimulusItemChip(
      CustomStimulusItem item, CustomStimulusType stimulusType) {
    final isSelected = _selectedCustomStimulusItems.contains(item);
    final colorScheme = Theme.of(context).colorScheme;

    // For color stimuli, use circular design like current color chips
    if (stimulusType == CustomStimulusType.color) {
      return GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedCustomStimulusItems.remove(item);
              print(
                  '🔷 Spark 🔍 [DrillBuilder] Removed custom stimulus item: ${item.name} (${item.id})');
              // Remove custom stimulus type if no items are selected
              if (_selectedCustomStimulusItems.isEmpty) {
                _stimuli.remove(StimulusType.custom);
                print(
                    '🔷 Spark 🔍 [DrillBuilder] Removed StimulusType.custom - no items selected');
              }
            } else {
              _selectedCustomStimulusItems.add(item);
              print(
                  '🔷 Spark 🔍 [DrillBuilder] Added custom stimulus item: ${item.name} (${item.id})');
              // Add custom stimulus type when first item is selected
              _stimuli.add(StimulusType.custom);
              print(
                  '🔷 Spark 🔍 [DrillBuilder] Added StimulusType.custom to stimuli set');
            }
            print(
                '🔷 Spark 🔍 [DrillBuilder] Total selected custom items: ${_selectedCustomStimulusItems.length}');
            print(
                '🔷 Spark 🔍 [DrillBuilder] Current stimuli types: ${_stimuli.map((s) => s.name).join(', ')}');
          });
          HapticFeedback.lightImpact();
        },
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: item.color ?? AppTheme.neutral500,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.onSurface : AppTheme.neutral500.withOpacity(0.3),
              width: isSelected ? 3 : 1,
            ),
          ),
          child: isSelected
              ? Icon(
                  Icons.check,
                  color: _getContrastColor(item.color ?? AppTheme.neutral500),
                  size: 24,
                )
              : null,
        ),
      );
    }

    // For other stimuli (shape, text, image), use rounded rectangle design like arrows
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCustomStimulusItems.remove(item);
            print(
                '🔷 Spark 🔍 [DrillBuilder] Removed custom stimulus item: ${item.name} (${item.id})');
            // Remove custom stimulus type if no items are selected
            if (_selectedCustomStimulusItems.isEmpty) {
              _stimuli.remove(StimulusType.custom);
              print(
                  '🔷 Spark 🔍 [DrillBuilder] Removed StimulusType.custom - no items selected');
            }
          } else {
            _selectedCustomStimulusItems.add(item);
            print(
                '🔷 Spark 🔍 [DrillBuilder] Added custom stimulus item: ${item.name} (${item.id})');
            // Add custom stimulus type when first item is selected
            _stimuli.add(StimulusType.custom);
            print(
                '🔷 Spark 🔍 [DrillBuilder] Added StimulusType.custom to stimuli set');
          }
          print(
              '🔷 Spark 🔍 [DrillBuilder] Total selected custom items: ${_selectedCustomStimulusItems.length}');
          print(
              '🔷 Spark 🔍 [DrillBuilder] Current stimuli types: ${_stimuli.map((s) => s.name).join(', ')}');
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: _buildCustomStimulusItemContent(item, stimulusType, isSelected),
      ),
    );
  }

  Widget _buildCustomStimulusItemContent(CustomStimulusItem item,
      CustomStimulusType stimulusType, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (stimulusType) {
      case CustomStimulusType.color:
        // Color content is handled in the main method above
        return const SizedBox.shrink();
      case CustomStimulusType.shape:
        return Icon(
          _getShapeIcon(item.shapeType ?? ''),
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withOpacity(0.6),
          size: 24,
        );
      case CustomStimulusType.text:
        final text = item.textValue ?? '';
        return Center(
          child: Text(
            text.length > 2 ? text.substring(0, 2) : text,
            style: TextStyle(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      case CustomStimulusType.image:
        if (item.imageBase64 != null && item.imageBase64!.isNotEmpty) {
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
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                bytes,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.broken_image,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      size: 20,
                    ),
                  );
                },
              ),
            );
          } catch (e) {
            // If base64 decoding fails, show error icon
            return Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
            );
          }
        }
        return Icon(
          Icons.image,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withOpacity(0.6),
          size: 24,
        );
    }
  }

  IconData _getShapeIcon(String shapeValue) {
    switch (shapeValue.toLowerCase()) {
      case 'circle':
        return Icons.circle;
      case 'square':
        return Icons.square;
      case 'triangle':
        return Icons.change_history;
      case 'star':
        return Icons.star;
      case 'heart':
        return Icons.favorite;
      default:
        return Icons.shape_line;
    }
  }

  IconData _getShapeTypeIcon(ShapeType shape) {
    switch (shape) {
      case ShapeType.circle:
        return Icons.circle_outlined;
      case ShapeType.square:
        return Icons.square_outlined;
      case ShapeType.triangle:
        return Icons.change_history_outlined;
      case ShapeType.diamond:
        return Icons.diamond_outlined;
      case ShapeType.star:
        return Icons.star_outline;
      case ShapeType.hexagon:
        return Icons.hexagon;
      case ShapeType.pentagon:
        return Icons.pentagon;
      case ShapeType.oval:
        return Icons.circle;
    }
  }

  Widget _buildDirectCustomStimulusSection(CustomStimulus stimulus) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stimulus header without checkbox
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stimulus.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // Always show stimulus items in grid format (4 per row)
          const SizedBox(height: 12),
          _buildCustomStimulusGrid(stimulus.items, stimulus.type),
        ],
      ),
    );
  }

  Widget _buildCustomStimulusGrid(
      List<CustomStimulusItem> items, CustomStimulusType stimulusType) {
    // Group items into rows of 4
    final rows = <List<CustomStimulusItem>>[];
    for (int i = 0; i < items.length; i += 4) {
      final end = (i + 4 < items.length) ? i + 4 : items.length;
      rows.add(items.sublist(i, end));
    }

    return Column(
      children: rows.map((row) {
        return Column(
          children: [
            Row(
              children: row
                  .map((item) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child:
                              _buildCustomStimulusItemChip(item, stimulusType),
                        ),
                      ))
                  .toList(),
            ),
            if (row != rows.last) const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }
}
