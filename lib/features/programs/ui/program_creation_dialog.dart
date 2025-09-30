import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/programs/bloc/programs_bloc.dart';
import 'package:brainblot_app/features/programs/domain/program.dart';
import 'package:uuid/uuid.dart';

class ProgramCreationDialog extends StatefulWidget {
  const ProgramCreationDialog({super.key});

  @override
  State<ProgramCreationDialog> createState() => _ProgramCreationDialogState();
}

class _ProgramCreationDialogState extends State<ProgramCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalDaysController = TextEditingController();

  String _selectedCategory = 'general';
  String _selectedLevel = 'Beginner';

  final List<String> _categories = [
    'general',
    'agility',
    'soccer',
    'basketball',
    'tennis',
    'football',
    'hockey',
    'baseball',
  ];

  final List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _totalDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 900;

    return BlocListener<ProgramsBloc, ProgramsState>(
      listener: (context, state) {
        if (state.status == ProgramsStatus.loaded) {
          Navigator.of(context).pop();
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
        } else if (state.status == ProgramsStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(state.errorMessage ?? 'Failed to create program'),
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
                  if (_formKey.currentState!.validate()) {
                    _createProgram();
                  }
                },
              ),
            ),
          );
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: isDesktop ? 900 : (isTablet ? 700 : size.width * 0.95),
          constraints: BoxConstraints(
            maxHeight: size.height * 0.9,
            maxWidth: 900,
          ),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _buildBody(context, isTablet, isDesktop),
              ),
              _buildFooter(context, isTablet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.add_circle_outline,
              color: colorScheme.onPrimary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Program',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Design a custom training program',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: colorScheme.onPrimaryContainer),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isTablet, bool isDesktop) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBasicInformation(context, isTablet, isDesktop),
            const SizedBox(height: 32),
            _buildProgramDetails(context, isTablet, isDesktop),
            const SizedBox(height: 32),
            _buildProgramPreviewSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInformation(
      BuildContext context, bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Basic Information', Icons.info_outline),
        const SizedBox(height: 20),
        _buildNameField(),
        const SizedBox(height: 20),
        _buildDescriptionField(),
      ],
    );
  }

  Widget _buildProgramDetails(
      BuildContext context, bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Program Details', Icons.tune),
        const SizedBox(height: 20),
        if (isTablet)
          Row(
            children: [
              Expanded(child: _buildCategoryDropdown()),
              const SizedBox(width: 20),
              Expanded(child: _buildLevelDropdown()),
              const SizedBox(width: 20),
              Expanded(child: _buildTotalDaysField()),
            ],
          )
        else
          Column(
            children: [
              _buildCategoryDropdown(),
              const SizedBox(height: 20),
              _buildLevelDropdown(),
              const SizedBox(height: 20),
              _buildTotalDaysField(),
            ],
          ),
      ],
    );
  }

  Widget _buildProgramPreviewSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Program Preview', Icons.visibility),
        const SizedBox(height: 20),
        _buildProgramPreview(),
      ],
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
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
            color: theme.colorScheme.outline.withOpacity(0.5),
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
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
        labelText: 'Description *',
        hintText: 'Describe the goals and focus areas of your program...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
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
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        alignLabelWithHint: true,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a description';
        }
        if (value.trim().length < 10) {
          return 'Description must be at least 10 characters';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildCategoryDropdown() {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
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
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      items: _categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withOpacity(0.1),
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
          });
        }
      },
    );
  }

  Widget _buildLevelDropdown() {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String>(
      value: _selectedLevel,
      decoration: InputDecoration(
        labelText: 'Difficulty Level *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        prefixIcon:
            Icon(Icons.signal_cellular_alt, color: theme.colorScheme.primary),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      items: _levels.map((level) {
        return DropdownMenuItem(
          value: level,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getLevelColor(level).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getLevelIcon(level),
                  size: 18,
                  color: _getLevelColor(level),
                ),
              ),
              const SizedBox(width: 10),
              Text(level),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedLevel = value;
          });
        }
      },
    );
  }

  Widget _buildTotalDaysField() {
    final theme = Theme.of(context);

    return TextFormField(
      controller: _totalDaysController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Program Duration *',
        hintText: '1-365',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        prefixIcon:
            Icon(Icons.calendar_today, color: theme.colorScheme.primary),
        suffixText: 'days',
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter total days';
        }
        final days = int.tryParse(value);
        if (days == null || days < 1 || days > 365) {
          return 'Enter a number between 1 and 365';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildProgramPreview() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalDays = int.tryParse(_totalDaysController.text) ?? 0;
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
            _getCategoryColor(_selectedCategory).withOpacity(0.1),
            colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getCategoryColor(_selectedCategory).withOpacity(0.3),
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
                          _getCategoryColor(_selectedCategory).withOpacity(0.3),
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
                            : colorScheme.onSurface.withOpacity(0.4),
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
                  color: colorScheme.onSurface.withOpacity(0.8),
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
                color: colorScheme.primaryContainer.withOpacity(0.5),
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
                        color: colorScheme.onSurface.withOpacity(0.7),
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
                : colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: active
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurface.withOpacity(0.4),
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
            color: colorScheme.outline.withOpacity(0.2),
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

  void _createProgram() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    HapticFeedback.mediumImpact();

    final totalDays = int.parse(_totalDaysController.text);
    final program = Program(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      category: _selectedCategory,
      totalDays: totalDays,
      level: _selectedLevel,
      createdAt: DateTime.now(),
      days: _generateProgramDays(totalDays),
    );

    context.read<ProgramsBloc>().add(ProgramsCreateRequested(program));
  }

  List<ProgramDay> _generateProgramDays(int totalDays) {
    return List.generate(totalDays, (index) {
      final dayNumber = index + 1;
      return ProgramDay(
        dayNumber: dayNumber,
        title: 'Day $dayNumber: ${_generateDayTitle(dayNumber, totalDays)}',
        description: _generateDayDescription(dayNumber, totalDays),
        drillId: null,
      );
    });
  }

  String _generateDayTitle(int day, int totalDays) {
    final week = ((day - 1) ~/ 7) + 1;
    final dayInWeek = ((day - 1) % 7) + 1;

    if (day == 1) return 'Introduction & Assessment';
    if (day == totalDays) return 'Final Assessment';

    final weekPhase = _getWeekPhase(week, (totalDays / 7).ceil());
    final dayType = _getDayType(dayInWeek);

    return '$weekPhase $dayType';
  }

  String _generateDayDescription(int day, int totalDays) {
    final description = _descriptionController.text.trim();
    final week = ((day - 1) ~/ 7) + 1;

    if (day == 1) {
      return 'Welcome to your $_selectedLevel ${_formatCategoryName(_selectedCategory)} program. $description';
    }

    if (day == totalDays) {
      return 'Final assessment and program completion. Evaluate your progress and achievements.';
    }

    final weekPhase = _getWeekPhase(week, (totalDays / 7).ceil());
    return '$weekPhase training session focusing on ${description.toLowerCase()}.';
  }

  String _getWeekPhase(int week, int totalWeeks) {
    if (totalWeeks <= 2) {
      return week == 1 ? 'Foundation' : 'Advanced';
    } else if (totalWeeks <= 4) {
      switch (week) {
        case 1:
          return 'Foundation';
        case 2:
          return 'Development';
        case 3:
          return 'Intermediate';
        default:
          return 'Advanced';
      }
    } else {
      final phase = (week - 1) / (totalWeeks / 4);
      if (phase < 1) return 'Foundation';
      if (phase < 2) return 'Development';
      if (phase < 3) return 'Intermediate';
      return 'Advanced';
    }
  }

  String _getDayType(int dayInWeek) {
    switch (dayInWeek) {
      case 1:
        return 'Power Training';
      case 2:
        return 'Skill Development';
      case 3:
        return 'Speed Work';
      case 4:
        return 'Coordination';
      case 5:
        return 'Endurance';
      case 6:
        return 'Competition Prep';
      case 7:
        return 'Recovery';
      default:
        return 'Training';
    }
  }

  String _formatCategoryName(String category) {
    return category[0].toUpperCase() + category.substring(1);
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'agility':
        return Icons.speed;
      case 'soccer':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      case 'tennis':
        return Icons.sports_tennis;
      case 'football':
        return Icons.sports_football;
      case 'hockey':
        return Icons.sports_hockey;
      case 'baseball':
        return Icons.sports_baseball;
      default:
        return Icons.psychology;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'Beginner':
        return Icons.signal_cellular_0_bar;
      case 'Intermediate':
        return Icons.signal_cellular_alt_2_bar;
      case 'Advanced':
        return Icons.signal_cellular_alt;
      default:
        return Icons.signal_cellular_0_bar;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'agility':
        return Colors.orange;
      case 'soccer':
        return Colors.green;
      case 'basketball':
        return Colors.deepOrange;
      case 'tennis':
        return Colors.blue;
      case 'football':
        return Colors.brown;
      case 'hockey':
        return Colors.cyan;
      case 'baseball':
        return Colors.red;
      default:
        return Colors.purple;
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Beginner':
        return Colors.green;
      case 'Intermediate':
        return Colors.orange;
      case 'Advanced':
        return Colors.red;
      default:
        return Colors.green;
    }
  }
}
