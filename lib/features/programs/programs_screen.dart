import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/features/programs/bloc/programs_bloc.dart';
import 'package:brainblot_app/features/programs/domain/program.dart';
import 'package:brainblot_app/features/programs/services/drill_assignment_service.dart';
import 'package:brainblot_app/features/programs/services/program_progress_service.dart';
import 'package:brainblot_app/features/programs/ui/program_creation_dialog.dart';
import 'package:brainblot_app/features/programs/ui/program_day_screen.dart';
import 'package:brainblot_app/features/sharing/services/sharing_service.dart';
import 'package:brainblot_app/features/sharing/ui/privacy_control_widget.dart';
import 'package:brainblot_app/features/sharing/ui/sharing_screen.dart';
import 'package:brainblot_app/core/services/auto_refresh_service.dart';
import 'package:brainblot_app/core/widgets/confirmation_dialog.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> 
    with TickerProviderStateMixin, AutoRefreshMixin {
  late TabController _tabController;
  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;
  late SharingService _sharingService;
  String _selectedCategory = '';
  String _selectedLevel = '';
  final Map<String, bool> _ownershipCache = {};

  @override
  void initState() {
    super.initState();
    _sharingService = getIt<SharingService>();
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
    
    // Setup auto-refresh listeners
    listenToMultipleAutoRefresh({
      AutoRefreshService.programs: _refreshPrograms,
      AutoRefreshService.sharing: _refreshPrograms,
    });
    
    // Programs are automatically loaded by the singleton BLoC
  }

  void _refreshPrograms() {
    if (mounted) {
      context.read<ProgramsBloc>().add(ProgramsRefreshRequested());
    }
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
              
              if (state.status == ProgramsStatus.error) {
                return _buildErrorState(state.errorMessage ?? 'Unknown error occurred');
              }

              return Column(
                children: [
                  // Filter Bar
                  _buildFilterBar(state.programs),
                  // Tab Content
                  Expanded(
                    child: Stack(
                      children: [
                        TabBarView(
                          controller: _tabController,
                          children: [
                            _buildActiveTabWithRefresh(state),
                            _buildBrowseTabWithRefresh(state),
                            _buildCompletedTabWithRefresh(state),
                          ],
                        ),
                        // Show refreshing indicator
                        if (state.isRefreshing)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 4,
                              child: LinearProgressIndicator(
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
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
          _showCreateProgramScreen();
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading programs...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Setting up your training programs',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
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
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<ProgramsBloc>().add(const ProgramsRetryRequested());
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () {
                    context.read<ProgramsBloc>().add(const ProgramsSeedDefaultRequested());
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Load Defaults'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(List<Program> programs) {
    final categories = programs.map((p) => p.category).toSet().toList()..sort();
    final levels = programs.map((p) => p.level).toSet().toList()..sort();
    final filteredPrograms = _applyFilters(programs);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        'Category', 
                        _selectedCategory.isEmpty ? 'All' : _formatCategoryName(_selectedCategory), 
                        () => _showCategoryFilter(categories),
                        isActive: _selectedCategory.isNotEmpty,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Level', 
                        _selectedLevel.isEmpty ? 'All' : _selectedLevel, 
                        () => _showLevelFilter(levels),
                        isActive: _selectedLevel.isNotEmpty,
                      ),
                      const SizedBox(width: 8),
                      if (_selectedCategory.isNotEmpty || _selectedLevel.isNotEmpty)
                        _buildClearFiltersButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${filteredPrograms.length} of ${programs.length} programs',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              if (_selectedCategory.isNotEmpty || _selectedLevel.isNotEmpty)
                Text(
                  'Filtered',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, VoidCallback onTap, {bool isActive = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? colorScheme.primaryContainer 
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive 
                ? colorScheme.primary 
                : colorScheme.outline.withOpacity(0.3),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.filter_alt,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ),
            Text(
              '$label: $value',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isActive 
                    ? colorScheme.onPrimaryContainer 
                    : colorScheme.onSurface,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down, 
              size: 16, 
              color: isActive 
                  ? colorScheme.onPrimaryContainer 
                  : colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildClearFiltersButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: _clearAllFilters,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.error.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.clear,
              size: 14,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 4),
            Text(
              'Clear',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _clearAllFilters() {
    setState(() {
      _selectedCategory = '';
      _selectedLevel = '';
    });
  }
  
  String _formatCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
        return 'Fitness';
      case 'soccer':
        return 'Soccer';
      case 'basketball':
        return 'Basketball';
      case 'tennis':
        return 'Tennis';
      case 'hockey':
        return 'Hockey';
      case 'agility':
        return 'Agility';
      case 'general':
        return 'General';
      default:
        return category.substring(0, 1).toUpperCase() + category.substring(1).toLowerCase();
    }
  }

  Widget _buildActiveTabWithRefresh(ProgramsState state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<ProgramsBloc>().add(const ProgramsRefreshRequested());
      },
      child: _buildActiveTab(state),
    );
  }

  Widget _buildBrowseTabWithRefresh(ProgramsState state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<ProgramsBloc>().add(const ProgramsRefreshRequested());
      },
      child: _buildBrowseTab(state),
    );
  }

  Widget _buildCompletedTabWithRefresh(ProgramsState state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<ProgramsBloc>().add(const ProgramsRefreshRequested());
      },
      child: _buildCompletedTab(state),
    );
  }

  Widget _buildActiveTab(ProgramsState state) {
    if (state.active == null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: _buildEmptyActiveState(),
        ),
      );
    }
    
    // Find the active program
    final matchingPrograms = state.programs.where((p) => p.id == state.active!.programId);
    final Program? activeProgram = matchingPrograms.isNotEmpty 
        ? matchingPrograms.first 
        : (state.programs.isNotEmpty ? state.programs.first : null);
    
    // If no active program found, show empty state
    if (activeProgram == null) {
      return RefreshIndicator(
        onRefresh: () async {
          context.read<ProgramsBloc>().add(const ProgramsRefreshRequested());
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildEmptyActiveState(),
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: _buildEmptyBrowseState(),
        ),
      );
    }
    
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: filteredPrograms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildProgramCard(
        filteredPrograms[index],
        isActive: state.active?.programId == filteredPrograms[index].id,
        state: state,
      ),
    );
  }

  Widget _buildCompletedTab(ProgramsState state) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: _buildEmptyCompletedState(),
      ),
    );
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
    final progress = active.currentDay / program.durationDays;
    
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
                'Day ${active.currentDay} of ${program.durationDays}',
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
                    '${program.durationDays - active.currentDay + 1}',
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
    
    // Handle both old format (days list) and new format (dayWiseDrillIds)
    ProgramDay? todayDay;
    String? todayDrillId;
    int drillCount = 0;
    
    if (program.days.isNotEmpty) {
      // Old format: use days list
      try {
        todayDay = program.days.firstWhere(
          (day) => day.dayNumber == active.currentDay,
        );
      } catch (e) {
        // Day not found, use fallback
        todayDay = ProgramDay(
          dayNumber: active.currentDay,
          title: 'Day ${active.currentDay}',
          description: 'Training day',
        );
      }
    } else if (program.dayWiseDrillIds.isNotEmpty) {
      // New enhanced format: use dayWiseDrillIds
      final drillIds = program.dayWiseDrillIds[active.currentDay];
      if (drillIds != null && drillIds.isNotEmpty) {
        todayDrillId = drillIds.first;
        drillCount = drillIds.length;
        todayDay = ProgramDay(
          dayNumber: active.currentDay,
          title: 'Day ${active.currentDay}',
          description: drillCount > 1 
              ? '$drillCount drills assigned for today' 
              : 'Training day',
          drillId: todayDrillId,
        );
      } else {
        // No drills for today
        todayDay = ProgramDay(
          dayNumber: active.currentDay,
          title: 'Day ${active.currentDay}',
          description: 'Rest day - No drills assigned',
        );
      }
    } else {
      // Fallback for programs with no data
      todayDay = ProgramDay(
        dayNumber: active.currentDay,
        title: 'Day ${active.currentDay}',
        description: 'No specific training scheduled for today',
      );
    }
    
    final hasDrill = todayDay.drillId != null && todayDay.drillId!.isNotEmpty;
    
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
                  color: hasDrill 
                      ? colorScheme.primaryContainer 
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasDrill ? Icons.fitness_center : Icons.self_improvement,
                  color: hasDrill 
                      ? colorScheme.onPrimaryContainer 
                      : colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              title: Text(
                todayDay.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(todayDay.description),
              trailing: hasDrill
                  ? FilledButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _startTodayTraining(todayDay!);
                      },
                      child: const Text('Start'),
                    )
                  : null,
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

  Widget _buildProgramCard(Program program, {required bool isActive, required ProgramsState state}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryColor = _getCategoryColor(program.category);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isActive 
            ? Border.all(color: colorScheme.primary, width: 2)
            : Border.all(color: colorScheme.outline.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: isActive 
                ? colorScheme.primary.withOpacity(0.1)
                : colorScheme.shadow.withOpacity(0.05),
            blurRadius: isActive ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProgramDetails(program),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon, title, and active badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category icon with gradient background
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            categoryColor.withOpacity(0.8),
                            categoryColor.withOpacity(0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: categoryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getCategoryIcon(program.category),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title and metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  program.name,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.primary.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.play_circle_fill,
                                        color: colorScheme.onPrimary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ACTIVE',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onPrimary,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Program stats
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildStatChip(
                                Icons.calendar_today,
                                '${program.durationDays} days',
                                Colors.blue,
                              ),
                              _buildStatChip(
                                Icons.trending_up,
                                program.level,
                                Colors.orange,
                              ),
                              if (program.dayWiseDrillIds.isNotEmpty)
                                _buildStatChip(
                                  Icons.fitness_center,
                                  '${program.dayWiseDrillIds.length} days with drills',
                                  Colors.green,
                                ),
                              if (program.selectedDrillIds.isNotEmpty)
                                _buildStatChip(
                                  Icons.list_alt,
                                  '${program.selectedDrillIds.length} drills',
                                  Colors.purple,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _shareProgram(program),
                      icon: const Icon(Icons.share_outlined),
                      tooltip: 'Share Program',
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.primary,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Category badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: categoryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon(program.category),
                            color: categoryColor,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            program.category.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: categoryColor,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildPrivacyIndicator(program),
                  ],
                ),
                // Privacy indicator


                const SizedBox(height: 12),
                
                // Program description (if available)
                if (program.description != null && program.description!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      program.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.8),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Action buttons
                Row(
                  children: [
                    // Details button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showProgramDetails(program),
                        icon: Icon(Icons.info_outline, size: 18),
                        label: const Text('Details'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    

                    
                    // Activate button (if not active)
                    if (!isActive)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final confirmed = await ConfirmationDialog.showProgramActivationConfirmation(
                              context,
                              programName: program.name,
                              durationDays: program.durationDays,
                              category: program.category,
                              level: program.level,
                              hasCurrentProgram: state.active != null,
                            );
                            
                            if (confirmed == true) {
                              HapticFeedback.mediumImpact();
                              context.read<ProgramsBloc>().add(ProgramsActivateRequested(program));
                            }
                          },
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Activate'),
                          style: FilledButton.styleFrom(
                            backgroundColor: categoryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterBottomSheet(
        title: 'Select Category',
        options: ['All', ...categories],
        selectedValue: _selectedCategory.isEmpty ? 'All' : _selectedCategory,
        onSelected: (value) {
          setState(() {
            _selectedCategory = value == 'All' ? '' : value;
          });
        },
        icons: {
          'All': Icons.apps,
          'fitness': Icons.fitness_center,
          'soccer': Icons.sports_soccer,
          'basketball': Icons.sports_basketball,
          'tennis': Icons.sports_tennis,
          'hockey': Icons.sports_hockey,
          'agility': Icons.speed,
          'general': Icons.psychology,
        },
      ),
    );
  }

  void _showLevelFilter(List<String> levels) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterBottomSheet(
        title: 'Select Level',
        options: ['All', ...levels],
        selectedValue: _selectedLevel.isEmpty ? 'All' : _selectedLevel,
        onSelected: (value) {
          setState(() {
            _selectedLevel = value == 'All' ? '' : value;
          });
        },
        icons: {
          'All': Icons.apps,
          'Beginner': Icons.star_border,
          'Intermediate': Icons.star_half,
          'Advanced': Icons.star,
        },
        colors: {
          'All': Colors.grey,
          'Beginner': Colors.green,
          'Intermediate': Colors.orange,
          'Advanced': Colors.red,
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
          MaterialPageRoute<void>(
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
    showModalBottomSheet<void>(
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
                    
                    // Handle both old format (days list) and new format (dayWiseDrillIds)
                    if (program.days.isNotEmpty) {
                      // Old format: use days list
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: program.days.length,
                        itemBuilder: (context, index) {
                          final day = program.days[index];
                          final isCompleted = progress?.isDayCompleted(day.dayNumber) ?? false;
                          final isCurrent = active.currentDay == day.dayNumber;
                          final isAccessible = day.dayNumber <= active.currentDay;
                          
                          return _buildDayOverviewCard(
                            context,
                            program,
                            dayNumber: day.dayNumber,
                            title: day.title,
                            description: day.description,
                            isCompleted: isCompleted,
                            isCurrent: isCurrent,
                            isAccessible: isAccessible,
                          );
                        },
                      );
                    } else if (program.dayWiseDrillIds.isNotEmpty) {
                      // New enhanced format: use dayWiseDrillIds
                      final sortedDays = program.dayWiseDrillIds.keys.toList()..sort();
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: sortedDays.length,
                        itemBuilder: (context, index) {
                          final dayNumber = sortedDays[index];
                          final drillIds = program.dayWiseDrillIds[dayNumber] ?? [];
                          final isCompleted = progress?.isDayCompleted(dayNumber) ?? false;
                          final isCurrent = active.currentDay == dayNumber;
                          final isAccessible = dayNumber <= active.currentDay;
                          final drillCount = drillIds.length;
                          
                          return _buildDayOverviewCard(
                            context,
                            program,
                            dayNumber: dayNumber,
                            title: 'Day $dayNumber',
                            description: drillCount > 1 
                                ? '$drillCount drills assigned' 
                                : (drillCount == 1 ? 'Training day' : 'Rest day'),
                            isCompleted: isCompleted,
                            isCurrent: isCurrent,
                            isAccessible: isAccessible,
                          );
                        },
                      );
                    } else {
                      // No data available
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No program schedule available',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateProgramScreen() {
    // Get the bloc from the parent context before navigating
    final programsBloc = context.read<ProgramsBloc>();
    
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BlocProvider.value(
          value: programsBloc,
          child: const ProgramCreationScreen(),
        ),
      ),
    );
  }

  void _showProgramDetails(Program program) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProgramDetailsSheet(program: program),
    );
  }

  Widget _buildDayOverviewCard(
    BuildContext context,
    Program program, {
    required int dayNumber,
    required String title,
    required String description,
    required bool isCompleted,
    required bool isCurrent,
    required bool isAccessible,
  }) {
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
                    '$dayNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isAccessible ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          description.length > 60 
              ? '${description.substring(0, 60)}...'
              : description,
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
                _navigateToProgramDay(program, dayNumber);
              }
            : null,
      ),
    );
  }

  void _startTodayTraining(ProgramDay day) async {
    if (day.drillId != null) {
      try {
        // Get the drill from the drill assignment service
        final drillService = getIt<DrillAssignmentService>();
        final drill = await drillService.getDrillById(day.drillId!);
        
        if (drill != null && mounted) {
          // Navigate to drill runner with program context
          final programs = context.read<ProgramsBloc>().state.programs;
          final program = programs.where((p) => p.days.contains(day)).firstOrNull;
          
          if (program == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Program not found')),
            );
            return;
          }
          context.push('/drill-runner', extra: {
            'drill': drill,
            'programId': program.id,
            'programDayNumber': day.dayNumber,
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Drill not found'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading drill: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // No drill assigned, navigate to program day screen
      final programs = context.read<ProgramsBloc>().state.programs;
      final program = programs.where((p) => p.days.contains(day)).firstOrNull;
      
      if (program != null) {
        _navigateToProgramDay(
          program,
          day.dayNumber,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Program not found')),
        );
      }
    }
  }

  void _shareProgram(Program program) {
    try {
      HapticFeedback.lightImpact();
      
      // Navigate to sharing screen
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => SharingScreen(
            itemType: 'program',
            itemId: program.id,
            itemName: program.name,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open sharing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPrivacyIndicator(Program program) {
    return FutureBuilder<bool>(
      future: _isOwner(program),
      builder: (context, snapshot) {
        final isOwner = snapshot.data ?? false;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        
        return PrivacyToggleButton(
          isPublic: program.isPublic,
          isOwner: isOwner,
          onToggle: isOwner ? () => _toggleProgramPrivacy(program) : null,
          isLoading: isLoading,
        );
      },
    );
  }

  Future<bool> _isOwner(Program program) async {
    if (_ownershipCache.containsKey(program.id)) {
      return _ownershipCache[program.id]!;
    }
    
    try {
      final isOwner = await _sharingService.isOwner('program', program.id);
      _ownershipCache[program.id] = isOwner;
      return isOwner;
    } catch (e) {
      return false;
    }
  }

  Future<void> _toggleProgramPrivacy(Program program) async {
    // Show confirmation dialog
    final confirmed = await ConfirmationDialog.showPrivacyConfirmation(
      context,
      isCurrentlyPublic: program.isPublic,
      itemType: 'program',
      itemName: program.name,
    );

    if (confirmed != true) return;

    try {
      await _sharingService.togglePrivacy('program', program.id, !program.isPublic);
      
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                !program.isPublic ? Icons.public : Icons.lock,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(!program.isPublic 
                  ? 'Program is now public! 🌍'
                  : 'Program is now private 🔒'),
            ],
          ),
          backgroundColor: !program.isPublic ? Colors.green : Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Refresh the programs list to show updated privacy status
      context.read<ProgramsBloc>().add(const ProgramsStarted());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update privacy: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
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
  final Map<String, IconData>? icons;
  final Map<String, Color>? colors;

  const _FilterBottomSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.icons,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          ...options.map((option) {
            final icon = icons?[option];
            final color = colors?[option] ?? theme.colorScheme.primary;
            final isSelected = option == selectedValue;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                    : null,
                borderRadius: BorderRadius.circular(12),
                border: isSelected 
                    ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                    : null,
              ),
              child: ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: option,
                      groupValue: selectedValue,
                      onChanged: (value) {
                        if (value != null) {
                          onSelected(value);
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
                title: Text(
                  option,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                ),
                onTap: () {
                  onSelected(option);
                  Navigator.of(context).pop();
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ProgramDetailsSheet extends StatefulWidget {
  final Program program;

  const _ProgramDetailsSheet({required this.program});

  @override
  State<_ProgramDetailsSheet> createState() => _ProgramDetailsSheetState();
}

class _ProgramDetailsSheetState extends State<_ProgramDetailsSheet> {
  final Map<String, String> _drillNames = {};
  bool _isLoadingDrills = false;

  @override
  void initState() {
    super.initState();
    _loadDrillNames();
  }

  Future<void> _loadDrillNames() async {
    setState(() => _isLoadingDrills = true);
    
    try {
      final drillService = getIt<DrillAssignmentService>();
      
      // Get unique drill IDs from both program days and dayWiseDrillIds
      final Set<String> drillIds = {};
      
      // From program days (old format)
      for (final day in widget.program.days) {
        if (day.drillId != null && day.drillId!.isNotEmpty) {
          drillIds.add(day.drillId!);
        }
      }
      
      // From dayWiseDrillIds (new enhanced format)
      for (final drillIdsList in widget.program.dayWiseDrillIds.values) {
        drillIds.addAll(drillIdsList);
      }
      
      // Load drill names
      for (final drillId in drillIds) {
        try {
          final drill = await drillService.getDrillById(drillId);
          if (drill != null && mounted) {
            setState(() {
              _drillNames[drillId] = drill.name;
            });
          }
        } catch (e) {
          // Skip if drill not found
          print('Error loading drill $drillId: $e');
        }
      }
    } catch (e) {
      print('Error loading drill names: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingDrills = false);
      }
    }
  }

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
                  widget.program.name,
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
                label: Text(widget.program.category),
                backgroundColor: colorScheme.primaryContainer,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(widget.program.level),
                backgroundColor: colorScheme.secondaryContainer,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text('${widget.program.durationDays} days'),
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
          const SizedBox(height: 8),
          if (widget.program.days.isEmpty && widget.program.dayWiseDrillIds.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No days scheduled for this program',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            )
          else
            Expanded(
              child: widget.program.days.isNotEmpty
                  ? _buildOldFormatDaysList(theme, colorScheme)
                  : _buildEnhancedFormatDaysList(theme, colorScheme),
            ),
        ],
      ),
    );
  }

  Widget _buildOldFormatDaysList(ThemeData theme, ColorScheme colorScheme) {
    return ListView.separated(
      itemCount: widget.program.days.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final day = widget.program.days[index];
        final hasDrill = day.drillId != null && day.drillId!.isNotEmpty;
        final drillName = hasDrill ? _drillNames[day.drillId] : null;
        
        return _buildDayListTile(
          theme,
          colorScheme,
          dayNumber: day.dayNumber,
          title: day.title,
          description: day.description,
          drillId: day.drillId,
          drillName: drillName,
        );
      },
    );
  }

  Widget _buildEnhancedFormatDaysList(ThemeData theme, ColorScheme colorScheme) {
    // Build list from dayWiseDrillIds
    final sortedDays = widget.program.dayWiseDrillIds.keys.toList()..sort();
    
    return ListView.separated(
      itemCount: sortedDays.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final dayNumber = sortedDays[index];
        final drillIds = widget.program.dayWiseDrillIds[dayNumber] ?? [];
        final hasDrill = drillIds.isNotEmpty;
        final drillId = hasDrill ? drillIds.first : null;
        final drillName = drillId != null ? _drillNames[drillId] : null;
        final drillCount = drillIds.length;
        
        return _buildDayListTile(
          theme,
          colorScheme,
          dayNumber: dayNumber,
          title: 'Day $dayNumber',
          description: drillCount > 1 
              ? '$drillCount drills assigned' 
              : (hasDrill ? 'Training day' : 'Rest day'),
          drillId: drillId,
          drillName: drillName,
          drillCount: drillCount,
        );
      },
    );
  }

  Widget _buildDayListTile(
    ThemeData theme,
    ColorScheme colorScheme, {
    required int dayNumber,
    required String title,
    required String description,
    String? drillId,
    String? drillName,
    int drillCount = 1,
  }) {
    final hasDrill = drillId != null && drillId.isNotEmpty;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: hasDrill 
            ? colorScheme.primary 
            : colorScheme.surfaceContainerHighest,
        child: Text(
          '$dayNumber',
          style: TextStyle(
            color: hasDrill 
                ? colorScheme.onPrimary 
                : colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty)
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (hasDrill) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 14,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    drillName ?? (_isLoadingDrills ? 'Loading drill...' : 'Drill assigned'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (drillCount > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '+${drillCount - 1}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      trailing: hasDrill
          ? Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: colorScheme.primary,
            )
          : Icon(
              Icons.info_outline,
              size: 16,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
      onTap: hasDrill
          ? () {
              Navigator.pop(context);
              // Navigate to drill or day details
            }
          : null,
    );
  }
}
