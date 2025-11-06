import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/services/drill_creation_service.dart';

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
  String _category = 'fitness';
  Difficulty _difficulty = Difficulty.beginner;
  int _duration = 60;
  int _rest = 30;
  int _sets = 1;
  int _reps = 3;
  int _numberOfStimuli = 30;
  final Set<StimulusType> _stimuli = {StimulusType.color};
  final Set<ReactionZone> _zones = {ReactionZone.center};
  final List<Color> _selectedColors = [Colors.red, Colors.green, Colors.blue, Colors.yellow];
  
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
    ));
    
    final d = widget.initial;
    _name = TextEditingController(text: d?.name ?? 'Custom Drill');
    _description = TextEditingController(text: '');
    
    if (d != null) {
      _category = d.category;
      _difficulty = d.difficulty;
      _duration = d.durationSec < 60 ? 60 : d.durationSec; // Ensure minimum 60 seconds
      _rest = d.restSec;
      _sets = d.sets;
      _reps = d.reps;
      _numberOfStimuli = d.numberOfStimuli;
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
    }
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
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
      favorite: initial?.favorite ?? false,
      isPreset: initial?.isPreset ?? false,
      createdBy: initial?.createdBy,
      sharedWith: initial?.sharedWith ?? [],
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

            // Category Selection
            Text(
              'Category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'fitness', 'soccer', 'basketball', 'hockey', 'tennis', 
                'volleyball', 'football', 'lacrosse', 'physiotherapy', 'agility'
              ].map((cat) => _buildCategoryChip(cat)).toList(),
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

  Widget _buildCategoryChip(String category) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _category == category;

    return FilterChip(
      label: Text(
        category.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _category = category;
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
            duration: const Duration(seconds: 4),
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

  void _saveDrillOld() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_build());
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
                _buildSummaryRow('Avg stimuli per second:', '${(_numberOfStimuli / _duration).toStringAsFixed(1)}'),
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
          // Stimulus Types Section
          Text(
            'Stimulus Types',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the types of stimuli that will appear during the drill',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: StimulusType.values.map((type) => _buildStimulusTypeChip(type)).toList(),
          ),
          const SizedBox(height: 32),

          // Reaction Zones Section
          Text(
            'Reaction Zones',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose where stimuli can appear on the screen',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ReactionZone.values.map((zone) => _buildReactionZoneChip(zone)).toList(),
          ),
          const SizedBox(height: 32),

          // Color Selection Section
          Text(
            'Stimulus Colors',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select colors for your stimuli (minimum 2 colors)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Colors.red, Colors.green, Colors.blue, Colors.yellow,
                    Colors.orange, Colors.purple, Colors.pink, Colors.cyan,
                    Colors.brown, Colors.grey, Colors.black, Colors.white,
                  ].map((color) => _buildColorChip(color)).toList(),
                ),
                if (_selectedColors.length < 2) ...[
                  const SizedBox(height: 12),
                  Container(
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
                        Text(
                          'Please select at least 2 colors',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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
              _buildReviewItem('Difficulty', _difficulty?.name.toUpperCase() ?? 'Not selected'),
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
                  )),
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

  Widget _buildStimulusTypeChip(StimulusType type) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _stimuli.contains(type);

    return FilterChip(
      label: Text(_getStimulusTypeLabel(type)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _stimuli.add(type);
          } else {
            _stimuli.remove(type);
          }
        });
        HapticFeedback.lightImpact();
      },
      avatar: Icon(
        _getStimulusTypeIcon(type),
        size: 18,
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.7),
      ),
      selectedColor: colorScheme.primary,
      checkmarkColor: colorScheme.onPrimary,
    );
  }

  Widget _buildReactionZoneChip(ReactionZone zone) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _zones.contains(zone);

    return FilterChip(
      label: Text(_getReactionZoneLabel(zone)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _zones.add(zone);
          } else {
            _zones.remove(zone);
          }
        });
        HapticFeedback.lightImpact();
      },
      avatar: Icon(
        _getReactionZoneIcon(zone),
        size: 18,
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.7),
      ),
      selectedColor: colorScheme.secondary,
      checkmarkColor: colorScheme.onSecondary,
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
    
    if (_category == null) {
      errors.add('Please select a category');
    }
    
    if (_difficulty == null) {
      errors.add('Please select a difficulty level');
    }
    
    // Validate minimum duration of 60 seconds
    if (_duration < 60) {
      errors.add('Drill duration must be at least 60 seconds (1 minute)');
    }
    
    if (_stimuli.isEmpty) {
      errors.add('Please select at least one stimulus type');
    }
    
    if (_zones.isEmpty) {
      errors.add('Please select at least one reaction zone');
    }
    
    if (_selectedColors.length < 2) {
      errors.add('Please select at least 2 colors');
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
        if (_zones.isEmpty) {
          errors.add('Select at least one reaction zone');
        }
        if (_stimuli.contains(StimulusType.color) && _selectedColors.length < 2) {
          errors.add('Select at least 2 colors for color stimulus');
        }
        break;
        
      case 3: // Review - no additional validation needed
        break;
    }
    
    return errors;
  }

  String _getStimulusTypeLabel(StimulusType type) {
    switch (type) {
      case StimulusType.color: return 'Color';
      case StimulusType.shape: return 'Shape';
      case StimulusType.arrow: return 'Arrow';
      case StimulusType.number: return 'Number';
      case StimulusType.audio: return 'Audio';
    }
  }

  IconData _getStimulusTypeIcon(StimulusType type) {
    switch (type) {
      case StimulusType.color: return Icons.palette;
      case StimulusType.shape: return Icons.category;
      case StimulusType.arrow: return Icons.arrow_forward;
      case StimulusType.number: return Icons.numbers;
      case StimulusType.audio: return Icons.volume_up;
    }
  }

  String _getReactionZoneLabel(ReactionZone zone) {
    switch (zone) {
      case ReactionZone.center: return 'Center';
      case ReactionZone.top: return 'Top';
      case ReactionZone.bottom: return 'Bottom';
      case ReactionZone.left: return 'Left';
      case ReactionZone.right: return 'Right';
      case ReactionZone.quadrants: return 'Quadrants';
    }
  }

  IconData _getReactionZoneIcon(ReactionZone zone) {
    switch (zone) {
      case ReactionZone.center: return Icons.center_focus_strong;
      case ReactionZone.top: return Icons.keyboard_arrow_up;
      case ReactionZone.bottom: return Icons.keyboard_arrow_down;
      case ReactionZone.left: return Icons.keyboard_arrow_left;
      case ReactionZone.right: return Icons.keyboard_arrow_right;
      case ReactionZone.quadrants: return Icons.grid_view;
    }
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
}
