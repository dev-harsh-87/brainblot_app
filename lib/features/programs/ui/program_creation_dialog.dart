import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/features/programs/bloc/programs_bloc.dart';
import 'package:brainblot_app/features/programs/domain/program.dart';
import 'package:brainblot_app/features/programs/services/program_creation_service.dart';

class ProgramCreationScreen extends StatefulWidget {
  const ProgramCreationScreen({super.key});

  @override
  State<ProgramCreationScreen> createState() => _ProgramCreationScreenState();
}

class _ProgramCreationScreenState extends State<ProgramCreationScreen> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pageController = PageController();

  String _selectedCategory = 'fitness';
  String _selectedLevel = 'Beginner';
  int _programDuration = 30; // days instead of text field
  
  // Drill selection and assignment
  List<Drill> _availableDrills = [];
  final Map<int, List<Drill>> _dayWiseDrills = {}; // day -> drills
  final Set<String> _selectedDrillIds = {};
  
  // UI state
  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isLoading = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _categories = [
    'fitness',
    'soccer',
    'basketball',
    'tennis',
    'hockey',
  ];

  final List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    
    _loadAvailableDrills();
    _animationController.forward();
  }

  Future<void> _loadAvailableDrills() async {
    setState(() => _isLoading = true);
    
    try {
      final drillRepository = getIt<DrillRepository>();
      final drills = await drillRepository.fetchAll();
      
      setState(() {
        _availableDrills = drills;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading drills: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: const Text('Create Program'),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          actions: [
            if (_currentStep > 0)
              TextButton(
                onPressed: _previousStep,
                child: Text('Back', style: TextStyle(color: colorScheme.onPrimary)),
              ),
          ],
        ),
        body: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildBasicInfoStep(),
                    _buildDrillSelectionStep(),
                    _buildDayWiseAssignmentStep(),
                    _buildReviewStep(),
                  ],
                ),
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      );
  }







  Widget _buildNameField() {
    final theme = Theme.of(context);

    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Program Name *',
        hintText: 'e.g., Elite Soccer Training',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        prefixIcon: Icon(Icons.title, color: theme.colorScheme.primary),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a program name';
        }
        if (value.trim().length < 3) {
          return 'Program name must be at least 3 characters';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildDescriptionField() {
    final theme = Theme.of(context);

    return TextFormField(
      controller: _descriptionController,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Description (Optional)',
        hintText: 'Describe the goals and focus areas of your program...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Icon(Icons.description, color: theme.colorScheme.primary),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        alignLabelWithHint: true,
      ),
      // No validation needed since description is optional
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildCategoryDropdown() {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        prefixIcon: Icon(Icons.category, color: theme.colorScheme.primary),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      items: _categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getCategoryIcon(category),
                  size: 18,
                  color: _getCategoryColor(category),
                ),
              ),
              const SizedBox(width: 10),
              Text(_formatCategoryName(category)),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCategory = value;
            // Clear selected drills when category changes since filtered drills will be different
            _selectedDrillIds.clear();
            _dayWiseDrills.clear();
          });
        }
      },
    );
  }

  Widget _buildProgramPreview() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalDays = _programDuration;
    final hasName = _nameController.text.isNotEmpty;
    final hasDescription = _descriptionController.text.isNotEmpty;
    final hasValidDays = totalDays > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getCategoryColor(_selectedCategory).withValues(alpha: 0.1),
            colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getCategoryColor(_selectedCategory).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCategoryColor(_selectedCategory),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          _getCategoryColor(_selectedCategory).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _getCategoryIcon(_selectedCategory),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasName ? _nameController.text : 'Program Name',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hasName
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildInfoChip(
                          context,
                          Icons.calendar_today,
                          hasValidDays ? '$totalDays days' : '0 days',
                          hasValidDays,
                        ),
                        _buildInfoChip(
                          context,
                          Icons.signal_cellular_alt,
                          _selectedLevel,
                          true,
                        ),
                        _buildInfoChip(
                          context,
                          Icons.category,
                          _formatCategoryName(_selectedCategory),
                          true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasDescription) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _descriptionController.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (hasValidDays) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This program will generate $totalDays daily training sessions with progressive difficulty',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
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

  Widget _buildInfoChip(
      BuildContext context, IconData icon, String label, bool active) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: active
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: active
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isTablet) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: BlocBuilder<ProgramsBloc, ProgramsState>(
        builder: (context, state) {
          final isCreating = state.status == ProgramsStatus.creating;

          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      isCreating ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: isCreating ? null : _createProgram,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_circle, size: 20),
                            SizedBox(width: 8),
                            Text('Create Program'),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Navigation methods
  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Step builder methods
  Widget _buildProgressIndicator() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index <= _currentStep;
              
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? colorScheme.onPrimary 
                        : colorScheme.onPrimary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
              ),
              Text(
                _getStepTitle(_currentStep),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0: return 'Basic Information';
      case 1: return 'Select Drills';
      case 2: return 'Day Assignment';
      case 3: return 'Review & Create';
      default: return 'Step ${step + 1}';
    }
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameField(),
            const SizedBox(height: 20),
            _buildDescriptionField(),
            const SizedBox(height: 20),
            _buildCategoryDropdown(),
            const SizedBox(height: 20),
            _buildDurationSlider(),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSlider() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Program Duration',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Duration: $_programDuration days'),
                  Text(_formatDuration(_programDuration)),
                ],
              ),
              const SizedBox(height: 12),
              Slider(
                value: _programDuration.toDouble(),
                min: 7,
                max: 365,
                divisions: 358,
                onChanged: (value) {
                  setState(() => _programDuration = value.round());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(int days) {
    if (days < 14) return '$days days';
    if (days < 60) return '${(days / 7).round()} weeks';
    if (days < 365) return '${(days / 30).round()} months';
    return '${(days / 365).round()} year${days >= 730 ? 's' : ''}';
  }

  Widget _buildDrillSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Drills',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text('Choose drills for your program. You can filter by category.'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Available drills: ${_getFilteredDrills().length}', 
                   style: Theme.of(context).textTheme.bodySmall),
              if (_getFilteredDrills().isNotEmpty)
                TextButton.icon(
                  onPressed: _selectedDrillIds.length == _getFilteredDrills().length 
                      ? _deselectAllDrills 
                      : _selectAllDrills,
                  icon: Icon(_selectedDrillIds.length == _getFilteredDrills().length 
                      ? Icons.deselect 
                      : Icons.select_all),
                  label: Text(_selectedDrillIds.length == _getFilteredDrills().length 
                      ? 'Deselect All' 
                      : 'Select All'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _getFilteredDrills().isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('No drills available'),
                            const SizedBox(height: 8),
                            Text('You can still create the program without drills',
                                 style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _getFilteredDrills().length,
                        itemBuilder: (context, index) {
                          final drill = _getFilteredDrills()[index];
                          final isSelected = _selectedDrillIds.contains(drill.id);
                          
                          return CheckboxListTile(
                            title: Text(drill.name),
                            subtitle: Text('${drill.durationSec}s • ${drill.category}'),
                            value: isSelected,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedDrillIds.add(drill.id);
                                } else {
                                  _selectedDrillIds.remove(drill.id);
                                }
                              });
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  List<Drill> _getFilteredDrills() {
    // Filter drills based on selected program category
    return _availableDrills.where((drill) {
      // Match drill category with program category
      final drillCategory = drill.category.toLowerCase();
      final programCategory = _selectedCategory.toLowerCase();
      
      // Direct match or fitness category matches all
      if (drillCategory == programCategory) return true;
      if (programCategory == 'fitness' && 
          ['strength', 'cardio', 'flexibility', 'endurance'].contains(drillCategory)) {
        return true;
      }
      
      return false;
    }).toList();
  }

  Widget _buildDayWiseAssignmentStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day-wise Assignment',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text('Assign drills to specific days in your program.'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectedDrillIds.isNotEmpty ? _autoAssignDrills : null,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Auto-assign Drills'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _dayWiseDrills.isNotEmpty ? _clearAllAssignments : null,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Assignments: ${_dayWiseDrills.length} of $_programDuration days',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _dayWiseDrills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text('No drill assignments yet'),
                        const SizedBox(height: 8),
                        Text(
                          _selectedDrillIds.isEmpty 
                              ? 'Select drills first, then use auto-assign'
                              : 'Use auto-assign to distribute selected drills',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _programDuration,
                    itemBuilder: (context, index) {
                      final day = index + 1;
                      final dayDrills = _dayWiseDrills[day] ?? [];
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: dayDrills.isNotEmpty 
                                ? Theme.of(context).colorScheme.primary 
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: dayDrills.isNotEmpty 
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text('Day $day'),
                          subtitle: dayDrills.isEmpty
                              ? const Text('No drills assigned')
                              : Text('${dayDrills.length} drill(s) assigned'),
                          trailing: dayDrills.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _clearDayAssignment(day),
                                  tooltip: 'Clear assignments',
                                )
                              : null,
                          children: dayDrills.isEmpty 
                              ? []
                              : dayDrills.map((drill) => ListTile(
                                  leading: Icon(
                                    Icons.fitness_center,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  title: Text(
                                    drill.name,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    '${drill.durationSec}s • ${drill.difficulty.name}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  dense: true,
                                )).toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _autoAssignDrills() {
    final selectedDrills = _getSelectedDrills();
    if (selectedDrills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one drill first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _dayWiseDrills.clear();
    
    // Smart drill assignment based on program duration
    final drillsPerDay = _programDuration <= 30 ? 3 : _programDuration <= 60 ? 2 : 1;
    
    // Shuffle drills for variety
    final shuffledDrills = List<Drill>.from(selectedDrills)..shuffle();
    
    for (int day = 1; day <= _programDuration; day++) {
      final dayDrills = <Drill>[];
      for (int i = 0; i < drillsPerDay && shuffledDrills.isNotEmpty; i++) {
        final drillIndex = ((day - 1) * drillsPerDay + i) % shuffledDrills.length;
        dayDrills.add(shuffledDrills[drillIndex]);
      }
      if (dayDrills.isNotEmpty) {
        _dayWiseDrills[day] = dayDrills;
      }
    }
    
    setState(() {});
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-assigned drills to ${_dayWiseDrills.length} days'),
        backgroundColor: Colors.green,
      ),
    );
  }

  List<Drill> _getSelectedDrills() {
    return _availableDrills.where((drill) => _selectedDrillIds.contains(drill.id)).toList();
  }

  void _clearAllAssignments() {
    setState(() {
      _dayWiseDrills.clear();
    });
  }

  void _clearDayAssignment(int day) {
    setState(() {
      _dayWiseDrills.remove(day);
    });
  }

  void _selectAllDrills() {
    setState(() {
      final filteredDrills = _getFilteredDrills();
      _selectedDrillIds.addAll(filteredDrills.map((drill) => drill.id));
    });
  }

  void _deselectAllDrills() {
    setState(() {
      final filteredDrills = _getFilteredDrills();
      for (final drill in filteredDrills) {
        _selectedDrillIds.remove(drill.id);
      }
    });
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Your Program',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildProgramSummary(),
          const SizedBox(height: 20),
          _buildValidationStatus(),
        ],
      ),
    );
  }

  Widget _buildProgramSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(_selectedCategory).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(_selectedCategory),
                    color: _getCategoryColor(_selectedCategory),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.isNotEmpty ? _nameController.text : 'Program Name',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatCategoryName(_selectedCategory),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getCategoryColor(_selectedCategory),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_descriptionController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _descriptionController.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Program Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildSummaryRow('Duration', '$_programDuration days'),
            _buildSummaryRow('Level', _selectedLevel),
            _buildSummaryRow('Selected Drills', '${_selectedDrillIds.length}'),
            _buildSummaryRow('Days with Assignments', '${_dayWiseDrills.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildValidationStatus() {
    final errors = _getValidationErrors();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  errors.isEmpty ? Icons.check_circle : Icons.error,
                  color: errors.isEmpty ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  errors.isEmpty ? 'Ready to Create' : 'Please Fix Issues',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: errors.isEmpty ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...errors.map((error) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $error', style: TextStyle(color: Colors.red.shade700)),
              )),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _getValidationErrors() {
    final errors = <String>[];
    
    if (_nameController.text.trim().isEmpty) {
      errors.add('Program name is required');
    }
    
    // Make drill selection optional for now
    // if (_selectedDrillIds.isEmpty) {
    //   errors.add('At least one drill must be selected');
    // }
    
    return errors;
  }

  Widget _buildBottomNavigation() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final errors = _getValidationErrors();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _currentStep == _totalSteps - 1
                  ? (errors.isEmpty ? _createProgram : null)
                  : _nextStep,
              child: Text(
                _currentStep == _totalSteps - 1 ? 'Create Program' : 'Next',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createProgram() async {
    print('🚀 Creating program...');
    
    // Check validation errors directly instead of relying on form key
    final validationErrors = _getValidationErrors();
    print('Validation errors: $validationErrors');
    
    if (validationErrors.isNotEmpty) {
      print('❌ Validation failed: $validationErrors');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fix the following errors: ${validationErrors.join(', ')}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    
    // Show loading state
    setState(() => _isLoading = true);

    try {
      // Convert drill objects to drill IDs for storage
      final dayWiseDrillIds = <int, List<String>>{};
      _dayWiseDrills.forEach((day, drills) {
        dayWiseDrillIds[day] = drills.map((drill) => drill.id).toList();
      });

      // Create program with all required parameters
      final program = Program(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        category: _selectedCategory,
        durationDays: _programDuration,
        days: const [], // Empty list for days as we're using dayWiseDrillIds
        level: _selectedLevel, // Using the selected level from the UI
        createdAt: DateTime.now(),
        dayWiseDrillIds: dayWiseDrillIds,
        selectedDrillIds: _selectedDrillIds.toList(),
      );

      print('✅ Program created: ${program.name}');
      print('Selected drills: ${_selectedDrillIds.length}');
      print('Day-wise assignments: ${dayWiseDrillIds.length}');

      // Use ProgramCreationService for better integration with auto-refresh
      final programCreationService = getIt<ProgramCreationService>();
      await programCreationService.createProgram(program);
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Program created successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        
        // Navigate back
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ Error creating program: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to create program: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _createProgram();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper methods for UI styling
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
        return Colors.blue;
      case 'soccer':
        return Colors.green;
      case 'basketball':
        return Colors.orange;
      case 'tennis':
        return Colors.purple;
      case 'hockey':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
        return Icons.fitness_center;
      case 'soccer':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      case 'tennis':
        return Icons.sports_tennis;
      case 'hockey':
        return Icons.sports_hockey;
      default:
        return Icons.category;
    }
  }

  String _formatCategoryName(String category) {
    return category.substring(0, 1).toUpperCase() + category.substring(1).toLowerCase();
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return Icons.star_border;
      case 'intermediate':
        return Icons.star_half;
      case 'advanced':
        return Icons.star;
      default:
        return Icons.help_outline;
    }
  }
}
