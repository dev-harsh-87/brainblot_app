import 'package:brainblot_app/features/programs/bloc/programs_bloc.dart';
import 'package:brainblot_app/features/programs/domain/program.dart';
import 'package:brainblot_app/features/programs/ui/program_creation_dialog.dart';
import 'package:brainblot_app/features/programs/ui/program_day_screen.dart';
import 'package:brainblot_app/features/programs/services/program_progress_service.dart';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;
  String _selectedCategory = '';
  String _selectedLevel = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    );
    _headerAnimationController.forward();
    
    // Load programs on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProgramsBloc>().add(const ProgramsStarted());
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            flexibleSpace: FlexibleSpaceBar(
              // title: Text(
              //   'Training Programs',
              //   style: theme.textTheme.headlineSmall?.copyWith(
              //     fontWeight: FontWeight.bold,
              //     color: colorScheme.onSurface,
              //   ),
              // ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [

                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -50,
                      bottom: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.secondary.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 100,
                      right: 20,
                      child: FadeTransition(
                        opacity: _headerAnimation,
                        child: Icon(
                          Icons.psychology,
                          size: 80,
                          color: colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: TabBar(
                  controller: _tabController,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                  indicatorColor: colorScheme.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Active'),
                    Tab(text: 'Browse'),
                    Tab(text: 'Completed'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: BlocListener<ProgramsBloc, ProgramsState>(
          listener: (context, state) {
            if (state.status == ProgramsStatus.error && state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: BlocBuilder<ProgramsBloc, ProgramsState>(
            builder: (context, state) {
              if (state.status == ProgramsStatus.loading) {
                return _buildLoadingState();
              }

              return Column(
                children: [
                  // Filter Bar
                  _buildFilterBar(state.programs),
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildActiveTab(state),
                        _buildBrowseTab(state),
                        _buildCompletedTab(state),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showCreateProgramDialog();
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Program'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Loading programs...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<Program> programs) {
    final categories = programs.map((p) => p.category).toSet().toList();
    final levels = programs.map((p) => p.level).toSet().toList();
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Category', _selectedCategory.isEmpty ? 'All' : _selectedCategory, () => _showCategoryFilter(categories)),
                  const SizedBox(width: 8),
                  _buildFilterChip('Level', _selectedLevel.isEmpty ? 'All' : _selectedLevel, () => _showLevelFilter(levels)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, VoidCallback onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $value',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: colorScheme.onSurface),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTab(ProgramsState state) {
    if (state.active == null) {
      return _buildEmptyActiveState();
    }
    
    final activeProgram = state.programs.firstWhere(
      (p) => p.id == state.active!.programId,
      orElse: () => state.programs.first,
    );
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActiveProgramCard(activeProgram, state.active!),
          const SizedBox(height: 24),
          _buildProgressSection(activeProgram, state.active!),
          const SizedBox(height: 24),
          _buildTodaySection(activeProgram, state.active!),
        ],
      ),
    );
  }

  Widget _buildBrowseTab(ProgramsState state) {
    final filteredPrograms = _applyFilters(state.programs);
    
    if (filteredPrograms.isEmpty) {
      return _buildEmptyBrowseState();
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPrograms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildProgramCard(
        filteredPrograms[index],
        isActive: state.active?.programId == filteredPrograms[index].id,
      ),
    );
  }

  Widget _buildCompletedTab(ProgramsState state) {
    return _buildEmptyCompletedState();
  }

  List<Program> _applyFilters(List<Program> programs) {
    return programs.where((program) {
      if (_selectedCategory.isNotEmpty && program.category != _selectedCategory) {
        return false;
      }
      if (_selectedLevel.isNotEmpty && program.level != _selectedLevel) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildEmptyActiveState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_circle_outline,
                size: 60,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Program',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse and activate a training program to get started',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                _tabController.animateTo(1);
              },
              icon: const Icon(Icons.explore),
              label: const Text('Browse Programs'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBrowseState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 40,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No programs found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or create a new program',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCompletedState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 50,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Completed Programs',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first program to see it here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveProgramCard(Program program, ActiveProgram active) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = active.currentDay / program.totalDays;
    
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.psychology,
                      color: colorScheme.onPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          '${program.category} • ${program.level}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Day ${active.currentDay} of ${program.totalDays}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: colorScheme.onPrimaryContainer.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).round()}% Complete',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToProgramDay(program, active.currentDay),
                      icon: const Icon(Icons.play_arrow),
                      label: Text('Day ${active.currentDay}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _showProgramDaysOverview(program, active),
                    child: const Icon(Icons.calendar_view_day),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(Program program, ActiveProgram active) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Days Completed',
                    '${active.currentDay - 1}',
                    Icons.check_circle,
                    colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Days Remaining',
                    '${program.totalDays - active.currentDay + 1}',
                    Icons.schedule,
                    colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySection(Program program, ActiveProgram active) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final todayDay = program.days.firstWhere(
      (day) => day.dayNumber == active.currentDay,
      orElse: () => program.days.first,
    );
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Training',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                todayDay.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(todayDay.description),
              trailing: FilledButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _startTodayTraining(todayDay);
                },
                child: const Text('Start'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard(Program program, {required bool isActive}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: isActive ? 4 : 1,
      child: InkWell(
        onTap: () => _showProgramDetails(program),
        borderRadius: BorderRadius.circular(12),
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
                      color: _getCategoryColor(program.category).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(program.category),
                      color: _getCategoryColor(program.category),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${program.totalDays} days • ${program.level}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Active',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  program.category,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _showProgramDetails(program),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('Details'),
                  ),
                  if (!isActive)
                    FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        context.read<ProgramsBloc>().add(ProgramsActivateRequested(program));
                      },
                      child: const Text('Activate'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (category.toLowerCase()) {
      case 'agility':
        return Colors.orange;
      case 'soccer':
        return Colors.green;
      case 'basketball':
        return Colors.deepOrange;
      case 'tennis':
        return Colors.blue;
      default:
        return colorScheme.primary;
    }
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
      default:
        return Icons.psychology;
    }
  }

  void _showCategoryFilter(List<String> categories) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterBottomSheet(
        title: 'Select Category',
        options: ['All', ...categories],
        selectedValue: _selectedCategory.isEmpty ? 'All' : _selectedCategory,
        onSelected: (value) {
          setState(() {
            _selectedCategory = value == 'All' ? '' : value;
          });
        },
      ),
    );
  }

  void _showLevelFilter(List<String> levels) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterBottomSheet(
        title: 'Select Level',
        options: ['All', ...levels],
        selectedValue: _selectedLevel.isEmpty ? 'All' : _selectedLevel,
        onSelected: (value) {
          setState(() {
            _selectedLevel = value == 'All' ? '' : value;
          });
        },
      ),
    );
  }

  Future<void> _navigateToProgramDay(Program program, int dayNumber) async {
    try {
      final progressService = getIt<ProgramProgressService>();
      final progress = await progressService.getProgramProgress(program.id);
      
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProgramDayScreen(
              program: program,
              dayNumber: dayNumber,
              progress: progress,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error navigating to program day: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showProgramDaysOverview(Program program, ActiveProgram active) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${program.name} - Program Days',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<ProgramProgress?>(
                  future: getIt<ProgramProgressService>().getProgramProgress(program.id),
                  builder: (context, snapshot) {
                    final progress = snapshot.data;
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: program.days.length,
                      itemBuilder: (context, index) {
                        final day = program.days[index];
                        final isCompleted = progress?.isDayCompleted(day.dayNumber) ?? false;
                        final isCurrent = active.currentDay == day.dayNumber;
                        final isAccessible = day.dayNumber <= active.currentDay;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isCompleted 
                                    ? Colors.green 
                                    : isCurrent 
                                        ? Theme.of(context).primaryColor
                                        : isAccessible
                                            ? Colors.grey[400]
                                            : Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isCompleted
                                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                                    : Text(
                                        '${day.dayNumber}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                            title: Text(
                              day.title,
                              style: TextStyle(
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                color: isAccessible ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              day.description.length > 60 
                                  ? '${day.description.substring(0, 60)}...'
                                  : day.description,
                              style: TextStyle(
                                color: isAccessible ? null : Colors.grey,
                              ),
                            ),
                            trailing: isAccessible 
                                ? const Icon(Icons.arrow_forward_ios, size: 16)
                                : Icon(Icons.lock, color: Colors.grey[400], size: 16),
                            onTap: isAccessible 
                                ? () {
                                    Navigator.pop(context);
                                    _navigateToProgramDay(program, day.dayNumber);
                                  }
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateProgramDialog() {
    // Get the bloc from the parent context before showing the dialog
    final programsBloc = context.read<ProgramsBloc>();
    
    showDialog(
      context: context,
      builder: (context) => BlocProvider.value(
        value: programsBloc,
        child: const ProgramCreationDialog(),
      ),
    );
  }

  void _showProgramDetails(Program program) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProgramDetailsSheet(program: program),
    );
  }

  void _startTodayTraining(ProgramDay day) {
    if (day.drillId != null) {
      context.go('/drills/${day.drillId}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No drill assigned for today'),
        ),
      );
    }
  }
}

class _FilterBottomSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const _FilterBottomSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...options.map((option) => ListTile(
                title: Text(option),
                leading: Radio<String>(
                  value: option,
                  groupValue: selectedValue,
                  onChanged: (value) {
                    if (value != null) {
                      onSelected(value);
                      Navigator.of(context).pop();
                    }
                  },
                ),
                onTap: () {
                  onSelected(option);
                  Navigator.of(context).pop();
                },
              )),
        ],
      ),
    );
  }
}

class _ProgramDetailsSheet extends StatelessWidget {
  final Program program;

  const _ProgramDetailsSheet({required this.program});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  program.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Chip(
                label: Text(program.category),
                backgroundColor: colorScheme.primaryContainer,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(program.level),
                backgroundColor: colorScheme.secondaryContainer,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text('${program.totalDays} days'),
                backgroundColor: colorScheme.tertiaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Program Schedule',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: program.days.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final day = program.days[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      '${day.dayNumber}',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(day.title),
                  subtitle: Text(day.description),
                  trailing: day.drillId != null
                      ? Icon(Icons.fitness_center, color: colorScheme.primary)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
