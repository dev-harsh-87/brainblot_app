import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/domain/drill_category.dart';
import 'package:spark_app/features/drills/data/drill_category_repository.dart';
import 'package:spark_app/features/drills/services/drill_creation_service.dart';
import 'package:spark_app/features/drills/services/image_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  int _reps = 3;
  int _numberOfStimuli = 30;
  final Set<StimulusType> _stimuli = {StimulusType.color};
  final Set<ReactionZone> _zones = {ReactionZone.center}; // Always center only
  final List<Color> _selectedColors = [Colors.red, Colors.green, Colors.blue, Colors.yellow];
  final List<ArrowDirection> _selectedArrows = [ArrowDirection.up, ArrowDirection.down, ArrowDirection.left, ArrowDirection.right];
  final List<ShapeType> _selectedShapes = [ShapeType.circle, ShapeType.square, ShapeType.triangle];
  NumberRange _selectedNumberRange = NumberRange.oneToFive;
  PresentationMode _presentationMode = PresentationMode.visual;
  
  int _currentStep = 0;
  final int _totalSteps = 4;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ),);
    
    final d = widget.initial;
    _name = TextEditingController(text: d?.name ?? 'Custom Drill');
    _description = TextEditingController(text: '');
    _videoUrl = TextEditingController(text: d?.videoUrl ?? '');
    _stepImageUrl = d?.stepImageUrl;
    
    if (d != null) {
      _category = d.category;
      _difficulty = d.difficulty;
      _duration = d.durationSec < 60 ? 60 : d.durationSec; // Ensure minimum 60 seconds
      _rest = d.restSec;
      _sets = d.sets;
      _reps = d.reps;
      _numberOfStimuli = d.numberOfStimuli;
      _presentationMode = d.presentationMode;
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
      _selectedNumberRange = d.numberRange;
    }
    
    _loadCategories();
    _animationController.forward();
  }

  Future<void> _loadCategories() async {
    try {
      print('🔄 Loading categories...');
      final repository = DrillCategoryRepository();
      final categories = await repository.getActiveCategories();
      print('✅ Loaded ${categories.length} categories');
      
      if (categories.isNotEmpty) {
        print('📋 Categories: ${categories.map((c) => c.displayName).join(", ")}');
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

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _videoUrl.dispose();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Drill _build() {
    final initial = widget.initial;
    return Drill(
      id: initial?.id ?? _uuid.v4(),
      name: _name.text.trim(),
      category: _category,
      difficulty: _difficulty,
      durationSec: _duration,
      restSec: _rest,
      sets: _sets,
      reps: _reps,
      stimulusTypes: _stimuli.toList(),
      numberOfStimuli: _numberOfStimuli,
      zones: _zones.toList(),
      colors: _selectedColors,
      arrows: _selectedArrows,
      shapes: _selectedShapes,
      numberRange: _selectedNumberRange,
      presentationMode: _presentationMode,
      favorite: initial?.favorite ?? false,
      isPreset: initial?.isPreset ?? false,
      createdBy: initial?.createdBy,
      sharedWith: initial?.sharedWith ?? [],
      videoUrl: _videoUrl.text.trim().isEmpty ? null : _videoUrl.text.trim(),
      stepImageUrl: _stepImageUrl,
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
                  _buildConfigurationStep(),
                  _buildStimulusStep(),
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.9),
              colorScheme.secondary.withOpacity(0.8),
            ],
          ),
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
                  margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
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
      case 0: return 'Basic Information';
      case 1: return 'Configuration';
      case 2: return 'Stimulus & Zones';
      case 3: return 'Review & Save';
      default: return '';
    }
  }

  String _getStepSubtitle(int step) {
    switch (step) {
      case 0: return 'Name, category, and difficulty';
      case 1: return 'Duration, repetitions, and timing';
      case 2: return 'Stimulus types and reaction zones';
      case 3: return 'Review your drill settings';
      default: return '';
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
              validator: (v) => (v == null || v.isEmpty) ? 'Drill name is required' : null,
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
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
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
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
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
                            onPressed: _isUploadingImage ? null : () => _pickImage(ImageSource.gallery),
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
                            onPressed: _isUploadingImage ? null : () => _pickImage(ImageSource.camera),
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
              children: Difficulty.values.map((diff) => 
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildDifficultyCard(diff),
                  ),
                ),
              ).toList(),
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
        case Difficulty.beginner: return Colors.green;
        case Difficulty.intermediate: return Colors.orange;
        case Difficulty.advanced: return Colors.red;
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
              color: isSelected ? getDifficultyColor() : colorScheme.onSurface.withOpacity(0.7),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              difficulty.name.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? getDifficultyColor() : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDifficultyIcon(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner: return Icons.sentiment_satisfied;
      case Difficulty.intermediate: return Icons.sentiment_neutral;
      case Difficulty.advanced: return Icons.sentiment_very_dissatisfied;
    }
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
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: FilledButton.icon(
              onPressed: _currentStep < _totalSteps - 1 ? _nextStep : _saveDrill,
              icon: Icon(_currentStep < _totalSteps - 1 ? Icons.arrow_forward : Icons.save),
              label: Text(_currentStep < _totalSteps - 1 ? 'Next' : 'Save Drill'),
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
            backgroundColor: Colors.red,
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
          // Duration Section
          Text(
            'Drill Duration',
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
                        'Duration (seconds)',
                        _duration.toDouble(),
                        60.0,
                        300.0,
                        (value) => setState(() => _duration = value.round()),
                        '${_duration}s',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSliderField(
                        'Rest between reps (seconds)',
                        _rest.toDouble(),
                        10.0,
                        120.0,
                        (value) => setState(() => _rest = value.round()),
                        '${_rest}s',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Repetitions and Stimuli
          Text(
            'Repetitions & Stimuli',
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
                        'Number of sets',
                        _sets.toDouble(),
                        1.0,
                        5.0,
                        (value) => setState(() => _sets = value.round()),
                        '$_sets sets',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSliderField(
                        'Repetitions per set',
                        _reps.toDouble(),
                        1.0,
                        10.0,
                        (value) => setState(() => _reps = value.round()),
                        '$_reps reps',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSliderField(
                        'Stimuli per repetition',
                        _numberOfStimuli.toDouble(),
                        5.0,
                        100.0,
                        (value) => setState(() => _numberOfStimuli = value.round()),
                        '$_numberOfStimuli stimuli',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Drill Summary',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSummaryRow('Total drill time:', '${(_duration * _reps + _rest * (_reps - 1))}s'),
                _buildSummaryRow('Total stimuli:', '${_numberOfStimuli * _reps}'),
                _buildSummaryRow('Avg stimuli per second:', (_numberOfStimuli / _duration).toStringAsFixed(1)),
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
              RichText(
                text: TextSpan(
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                  ),
                  children: [
                    const TextSpan(text: 'SELECT YOUR '),
                    TextSpan(
                      text: 'STIMULI',
                      style: TextStyle(
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select which cues will appear on the screen',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 40),

              // Colors Section with Checkbox
              _buildStimulusSelectionSection(
                'Colors',
                StimulusType.color,
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    Colors.red, Colors.blue, Colors.green, Colors.yellow,
                    Colors.purple, Colors.orange, Colors.black, Colors.grey,
                  ].map((color) => _buildSimpleColorChip(color)).toList(),
                ),
                _stimuli.contains(StimulusType.color) && _selectedColors.length < 2,
              ),
              const SizedBox(height: 32),

              // Arrows Section with Checkbox
              _buildStimulusSelectionSection(
                'Arrows',
                StimulusType.arrow,
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    ArrowDirection.up, ArrowDirection.down,
                    ArrowDirection.left, ArrowDirection.right,
                    ArrowDirection.upLeft, ArrowDirection.upRight,
                    ArrowDirection.downLeft, ArrowDirection.downRight,
                  ].map((arrow) => _buildSimpleArrowChip(arrow)).toList(),
                ),
                _stimuli.contains(StimulusType.arrow) && _selectedArrows.length < 2,
              ),
              const SizedBox(height: 32),

              // Numbers Section with Checkbox
              _buildStimulusSelectionSection(
                'Numbers',
                StimulusType.number,
                Column(
                  children: [
                    Row(
                      children: [1, 2, 3, 4].map((num) =>
                        Expanded(child: _buildSimpleNumberChip(num))
                      ).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [5, 6, 7, 8].map((num) =>
                        Expanded(child: _buildSimpleNumberChip(num))
                      ).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Number Range Selection
                    Text(
                      'Select Range:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: NumberRange.values.map((range) =>
                        _buildNumberRangeChip(range)
                      ).toList(),
                    ),
                  ],
                ),
                false, // Numbers don't need validation warning
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
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Review Your Drill',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
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
          const SizedBox(height: 24),

          // Basic Information
          _buildReviewSection(
            'Basic Information',
            Icons.info_outline,
            [
              _buildReviewItem('Name', _name.text),
              _buildReviewItem('Description', _description.text.isEmpty ? 'No description' : _description.text),
              _buildReviewItem('Category', _category ?? 'Not selected'),
              _buildReviewItem('Difficulty', _difficulty.name.toUpperCase() ?? 'Not selected'),
            ],
          ),
          const SizedBox(height: 20),

          // Configuration
          _buildReviewSection(
            'Configuration',
            Icons.settings,
            [
              _buildReviewItem('Duration per rep', '${_duration}s'),
              _buildReviewItem('Rest between reps', '${_rest}s'),
              _buildReviewItem('Number of reps', '$_reps'),
              _buildReviewItem('Stimuli per rep', '$_numberOfStimuli'),
              _buildReviewItem('Total drill time', '${(_duration * _reps + _rest * (_reps - 1))}s'),
            ],
          ),
          const SizedBox(height: 20),

          // Stimulus & Zones
          _buildReviewSection(
            'Stimulus & Zones',
            Icons.psychology,
            [
              _buildReviewItem('Presentation mode', _presentationMode.name.toUpperCase()),
              _buildReviewItem('Stimulus types', _stimuli.isEmpty ? 'None selected' : _stimuli.map((s) => s.name).join(', ')),
              _buildReviewItem('Reaction zones', _zones.isEmpty ? 'None selected' : _zones.map((z) => z.name).join(', ')),
              _buildReviewItem('Colors', '${_selectedColors.length} colors selected'),
            ],
          ),
          const SizedBox(height: 24),

          // Validation Warnings
          if (_getValidationErrors().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Please fix the following issues:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._getValidationErrors().map((error) => Padding(
                    padding: const EdgeInsets.only(left: 28, top: 4),
                    child: Text(
                      '• $error',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Success Message
          if (_getValidationErrors().isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your drill is ready to save! All settings look good.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
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
  // Helper methods for the drill builder
  Widget _buildSliderField(String label, double value, double min, double max, ValueChanged<double> onChanged, String displayValue) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              getLabel(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
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

  Widget _buildColorChip(Color color) {
    final isSelected = _selectedColors.contains(color);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedColors.remove(color);
          } else {
            _selectedColors.add(color);
          }
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: _getContrastColor(color),
                size: 24,
              )
            : null,
      ),
    );
  }

  Widget _buildReviewSection(String title, IconData icon, List<Widget> items) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
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
        if (_reps < 1) {
          errors.add('Repetitions must be at least 1');
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
        if (_stimuli.contains(StimulusType.color) && _selectedColors.length < 2) {
          errors.add('Select at least 2 colors for color stimulus');
        }
        if (_stimuli.contains(StimulusType.arrow) && _selectedArrows.length < 2) {
          errors.add('Select at least 2 arrow directions for arrow stimulus');
        }
        if (_stimuli.contains(StimulusType.shape) && _selectedShapes.length < 2) {
          errors.add('Select at least 2 shapes for shape stimulus');
        }
        break;
        
      case 3: // Review - no additional validation needed
        break;
    }
    
    return errors;
  }


  Widget _buildStimulusCard(String title, IconData icon, StimulusType type, String description, Color accentColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _stimuli.contains(type);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _stimuli.remove(type);
          } else {
            _stimuli.add(type);
          }
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? accentColor.withOpacity(0.1) 
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? accentColor 
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? accentColor 
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected 
                    ? Colors.white 
                    : colorScheme.onSurface.withOpacity(0.7),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? accentColor : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_presentationMode == PresentationMode.audio)
                        Icon(
                          Icons.volume_up,
                          size: 16,
                          color: isSelected ? accentColor : colorScheme.onSurface.withOpacity(0.5),
                        ),
                      if (_presentationMode == PresentationMode.visual)
                        Icon(
                          Icons.visibility,
                          size: 16,
                          color: isSelected ? accentColor : colorScheme.onSurface.withOpacity(0.5),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected 
                          ? colorScheme.onSurface 
                          : colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: accentColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionZoneCard(String title, IconData icon, String description, ReactionZone zone) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _zones.contains(zone);

    return GestureDetector(
      onTap: () {
        setState(() {
          // Clear all zones and add the selected one (single selection)
          _zones.clear();
          _zones.add(zone);
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
              icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
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

  Color _getContrastColor(Color color) {
    // Calculate luminance to determine if we should use black or white text
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  void _saveDrill() async {
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
          Navigator.of(context).pop(drill);
          HapticFeedback.mediumImpact();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.initial == null ? 'Drill created successfully!' : 'Drill updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Show validation error from service
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString().replaceAll('Exception: ', '').replaceAll('ArgumentError: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
          HapticFeedback.heavyImpact();
        }
      }
    } else {
      // Show validation errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fix ${errors.length} validation error${errors.length > 1 ? 's' : ''}'),
          backgroundColor: Colors.red,
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
        final base64Image = await imageUploadService.convertImageToBase64(imageFile);
        
        setState(() {
          _stepImageUrl = base64Image;
          _isUploadingImage = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully!'),
            backgroundColor: Colors.green,
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
          content: Text('Failed to upload image: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildArrowChip(ArrowDirection arrow) {
    final isSelected = _selectedArrows.contains(arrow);
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(
        _getArrowDirectionLabel(arrow),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
      avatar: Icon(
        _getArrowDirectionIcon(arrow),
        size: 18,
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.7),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedArrows.add(arrow);
          } else {
            _selectedArrows.remove(arrow);
          }
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

  Widget _buildShapeChip(ShapeType shape) {
    final isSelected = _selectedShapes.contains(shape);
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(
        _getShapeTypeLabel(shape),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
      avatar: Icon(
        _getShapeTypeIcon(shape),
        size: 18,
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.7),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedShapes.add(shape);
          } else {
            _selectedShapes.remove(shape);
          }
        });
        HapticFeedback.lightImpact();
      },
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.secondary,
      checkmarkColor: colorScheme.onSecondary,
      side: BorderSide(
        color: isSelected ? colorScheme.secondary : colorScheme.outline,
      ),
    );
  }

  Widget _buildNumberRangeCard(NumberRange range) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedNumberRange == range;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedNumberRange = range;
          });
          HapticFeedback.lightImpact();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.orange.withOpacity(0.1)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.orange
                  : colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.orange
                      : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.numbers,
                  color: isSelected
                      ? Colors.white
                      : colorScheme.onSurface.withOpacity(0.7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getNumberRangeLabel(range),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.orange : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getNumberRangeDescription(range),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Colors.orange,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getArrowDirectionLabel(ArrowDirection direction) {
    switch (direction) {
      case ArrowDirection.up: return 'Up';
      case ArrowDirection.down: return 'Down';
      case ArrowDirection.left: return 'Left';
      case ArrowDirection.right: return 'Right';
      case ArrowDirection.upLeft: return 'Up-Left';
      case ArrowDirection.upRight: return 'Up-Right';
      case ArrowDirection.downLeft: return 'Down-Left';
      case ArrowDirection.downRight: return 'Down-Right';
    }
  }

  IconData _getArrowDirectionIcon(ArrowDirection direction) {
    switch (direction) {
      case ArrowDirection.up: return Icons.keyboard_arrow_up;
      case ArrowDirection.down: return Icons.keyboard_arrow_down;
      case ArrowDirection.left: return Icons.keyboard_arrow_left;
      case ArrowDirection.right: return Icons.keyboard_arrow_right;
      case ArrowDirection.upLeft: return Icons.north_west;
      case ArrowDirection.upRight: return Icons.north_east;
      case ArrowDirection.downLeft: return Icons.south_west;
      case ArrowDirection.downRight: return Icons.south_east;
    }
  }

  String _getShapeTypeLabel(ShapeType shape) {
    switch (shape) {
      case ShapeType.circle: return 'Circle';
      case ShapeType.square: return 'Square';
      case ShapeType.triangle: return 'Triangle';
      case ShapeType.diamond: return 'Diamond';
      case ShapeType.star: return 'Star';
      case ShapeType.hexagon: return 'Hexagon';
      case ShapeType.pentagon: return 'Pentagon';
      case ShapeType.oval: return 'Oval';
    }
  }

  IconData _getShapeTypeIcon(ShapeType shape) {
    switch (shape) {
      case ShapeType.circle: return Icons.circle_outlined;
      case ShapeType.square: return Icons.square_outlined;
      case ShapeType.triangle: return Icons.change_history;
      case ShapeType.diamond: return Icons.diamond_outlined;
      case ShapeType.star: return Icons.star_outline;
      case ShapeType.hexagon: return Icons.hexagon_outlined;
      case ShapeType.pentagon: return Icons.pentagon_outlined;
      case ShapeType.oval: return Icons.circle;
    }
  }

  String _getNumberRangeLabel(NumberRange range) {
    switch (range) {
      case NumberRange.oneToThree: return '1-3';
      case NumberRange.oneToFive: return '1-5';
      case NumberRange.oneToNine: return '1-9';
      case NumberRange.oneToTwelve: return '1-12';
    }
  }

  String _getNumberRangeDescription(NumberRange range) {
    switch (range) {
      case NumberRange.oneToThree: return 'Numbers 1, 2, 3';
      case NumberRange.oneToFive: return 'Numbers 1, 2, 3, 4, 5';
      case NumberRange.oneToNine: return 'Numbers 1 through 9';
      case NumberRange.oneToTwelve: return 'Numbers 1 through 12';
    }
  }

  Widget _buildSelectionSection(String title, IconData icon, Color accentColor, Widget content) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildValidationWarning(String message) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanStimulusSection(String title, Widget content, bool showWarning) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 20),
        content,
        if (showWarning) ...[
          const SizedBox(height: 16),
          _buildValidationWarning('Please select at least 2 ${title.toLowerCase()}'),
        ],
      ],
    );
  }

  Widget _buildSimpleColorChip(Color color) {
    final isSelected = _selectedColors.contains(color);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedColors.remove(color);
          } else {
            _selectedColors.add(color);
          }
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: _getContrastColor(color),
                size: 24,
              )
            : null,
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
          } else {
            _selectedArrows.add(arrow);
          }
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.1) : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Icon(
          _getArrowDirectionIcon(arrow),
          color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSimpleNumberChip(int number) {
    final isInRange = _isNumberInSelectedRange(number);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: isInRange ? Colors.orange.withOpacity(0.1) : colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isInRange ? Colors.orange : colorScheme.outline.withOpacity(0.3),
                  width: isInRange ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  number.toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isInRange ? Colors.orange : colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isInRange ? Colors.orange : Colors.transparent,
              border: Border.all(
                color: isInRange ? Colors.orange : colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: isInRange
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPresentationModeIndicator() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Visual Indicator
        Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            color: _presentationMode == PresentationMode.visual
                ? Colors.orange.withOpacity(0.2)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _presentationMode == PresentationMode.visual
                  ? Colors.orange
                  : colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.visibility,
                color: _presentationMode == PresentationMode.visual
                    ? Colors.orange
                    : colorScheme.onSurface.withOpacity(0.5),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                'VISUAL',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _presentationMode == PresentationMode.visual
                      ? Colors.orange
                      : colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Audio Indicator
        Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            color: _presentationMode == PresentationMode.audio
                ? Colors.orange.withOpacity(0.2)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _presentationMode == PresentationMode.audio
                  ? Colors.orange
                  : colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.volume_up,
                color: _presentationMode == PresentationMode.audio
                    ? Colors.orange
                    : colorScheme.onSurface.withOpacity(0.5),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                'AUDIO',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _presentationMode == PresentationMode.audio
                      ? Colors.orange
                      : colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isNumberInSelectedRange(int number) {
    switch (_selectedNumberRange) {
      case NumberRange.oneToThree:
        return number >= 1 && number <= 3;
      case NumberRange.oneToFive:
        return number >= 1 && number <= 5;
      case NumberRange.oneToNine:
        return number >= 1 && number <= 9;
      case NumberRange.oneToTwelve:
        return number >= 1 && number <= 12;
    }
  }

  Widget _buildNumberRangeChip(NumberRange range) {
    final isSelected = _selectedNumberRange == range;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      label: Text(
        _getNumberRangeLabel(range),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: isSelected ? Colors.white : colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedNumberRange = range;
        });
        HapticFeedback.lightImpact();
      },
      backgroundColor: colorScheme.surface,
      selectedColor: Colors.orange,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.orange : colorScheme.outline,
      ),
    );
  }

  Widget _buildStimulusSelectionSection(String title, StimulusType type, Widget content, bool showWarning) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _stimuli.contains(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with checkbox
        Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _stimuli.add(type);
                  } else {
                    _stimuli.remove(type);
                  }
                });
                HapticFeedback.lightImpact();
              },
              activeColor: Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Content (only show if stimulus type is selected)
        if (isSelected) ...[
          content,
          if (showWarning) ...[
            const SizedBox(height: 16),
            _buildValidationWarning('Please select at least 2 ${title.toLowerCase()}'),
          ],
        ],
      ],
    );
  }
}
