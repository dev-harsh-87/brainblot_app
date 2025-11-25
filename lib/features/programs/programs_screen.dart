import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'package:spark_app/core/widgets/main_navigation.dart';
import 'package:spark_app/core/widgets/app_loader.dart';
import 'package:spark_app/features/drills/data/drill_category_repository.dart';
import 'package:spark_app/features/drills/domain/drill_category.dart';
import 'package:spark_app/features/programs/bloc/programs_bloc.dart';
import 'package:spark_app/features/programs/domain/program.dart';
import 'package:spark_app/features/programs/services/drill_assignment_service.dart';
import 'package:spark_app/features/programs/services/program_progress_service.dart';
import 'package:spark_app/features/programs/ui/program_creation_dialog.dart';
import 'package:spark_app/features/programs/ui/program_day_screen.dart';
import 'package:spark_app/features/programs/ui/program_details_screen.dart';
import 'package:spark_app/features/programs/ui/program_stats_screen.dart';
import 'package:spark_app/features/profile/services/profile_service.dart';
import 'package:spark_app/features/sharing/domain/user_profile.dart';
import 'package:spark_app/features/sharing/services/sharing_service.dart';
import 'package:spark_app/features/sharing/ui/sharing_screen.dart';
import 'package:spark_app/core/services/auto_refresh_service.dart';
import 'package:spark_app/core/widgets/confirmation_dialog.dart';
import 'package:spark_app/core/ui/edge_to_edge.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/core/widgets/profile_avatar.dart';
import 'package:spark_app/features/profile/services/profile_service.dart';
import 'package:spark_app/features/sharing/domain/user_profile.dart';
import 'package:spark_app/features/auth/bloc/auth_bloc.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen>
    with TickerProviderStateMixin, AutoRefreshMixin {
  late TabController _tabController;
  late AnimationController _headerAnimationController;
  late SharingService _sharingService;
  late ProfileService _profileService;
  String _selectedCategory = '';
  String _selectedLevel = '';
  List<DrillCategory> _availableCategories = [];
  final Map<String, bool> _ownershipCache = {};
  final TextEditingController _searchController = TextEditingController();
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _sharingService = getIt<SharingService>();
    _tabController = TabController(length: 3, vsync: this);
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _headerAnimationController.forward();

    // Setup auto-refresh listeners
    listenToMultipleAutoRefresh({
      AutoRefreshService.programs: _refreshPrograms,
      AutoRefreshService.sharing: _refreshPrograms,
    });

    // Load categories
    _loadCategories();

    // Programs are automatically loaded by the singleton BLoC
  }

  Future<void> _loadCategories() async {
    try {
      final categoryRepository = getIt<DrillCategoryRepository>();
      final categories = await categoryRepository.getActiveCategories();
      if (mounted) {
        setState(() {
          _availableCategories = categories;
        });
      }
    } catch (e) {
      print('❌ Error loading categories: $e');
    }
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

  void _refreshPrograms() {
    if (mounted) {
      context.read<ProgramsBloc>().add(ProgramsRefreshRequested());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Register TabBar with MainNavigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TabBarProvider.of(context)?.registerTabBar((context) {
        return TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Browse'),
            Tab(text: 'Completed'),
          ],
        );
      });
    });

    // Set system UI for primary colored app bar
    EdgeToEdge.setPrimarySystemUI(context);

    return EdgeToEdgeScaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchAndFilterSection(context),
          // Program Content
          Expanded(
            child: BlocListener<ProgramsBloc, ProgramsState>(
              listener: (context, state) {
                if (state.status == ProgramsStatus.error &&
                    state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.errorMessage!),
                      backgroundColor: theme.colorScheme.error,
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
                    return _buildErrorState(
                      state.errorMessage ?? 'Unknown error occurred',
                    );
                  }

                  return Stack(
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
                          child: SizedBox(
                            height: 4,
                            child: LinearProgressIndicator(
                              backgroundColor: colorScheme.surface.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          // Only show FAB on Browse tab (index 1), hide on Active tab (index 0)
          if (_tabController.index == 1) {
            return FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showCreateProgramScreen();
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Program'),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            );
          }
          return const SizedBox.shrink(); // Hide FAB on other tabs
        },
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
        'Training Programs',
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
        _buildFilterButton(colorScheme),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const AppLoader.fullScreen(
      message: 'Loading programs...',
    );
  }

  Widget _buildErrorState(String errorMessage) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
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
              'Failed to load programs',
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
            FilledButton.icon(
              onPressed: () {
                context
                    .read<ProgramsBloc>()
                    .add(const ProgramsRetryRequested());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.08),
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search programs...',
                  prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: colorScheme.onSurface.withOpacity(0.6)),
                          onPressed: () {
                            _searchController.clear();
                            context
                                .read<ProgramsBloc>()
                                .add(const ProgramsQueryChanged(''));
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onChanged: (query) {
                  setState(() {});
                  context.read<ProgramsBloc>().add(ProgramsQueryChanged(query));
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(ColorScheme colorScheme) {
    return IconButton(
      onPressed: () {
        // Show filter options
        _showFilterOptions();
      },
      icon: Icon(
        Icons.filter_list,
        color: colorScheme.onPrimary,
      ),
      tooltip: 'Filter Programs',
    );
  }

  void _showFilterOptions() {
    // Get the current state to extract levels before showing modal
    final currentState = context.read<ProgramsBloc>().state;
    final levels = currentState.programs.map((p) => p.level).toSet().toList()
      ..sort();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        final theme = Theme.of(modalContext);
        final colorScheme = theme.colorScheme;

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Filter Programs',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedCategory.isNotEmpty ||
                          _selectedLevel.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = '';
                              _selectedLevel = '';
                            });
                            Navigator.pop(modalContext);
                          },
                          child: Text(
                            'Clear All',
                            style: TextStyle(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Category Section
                  Text(
                    'Category',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        modalContext,
                        'All',
                        _selectedCategory.isEmpty,
                        () {
                          setState(() {
                            _selectedCategory = '';
                          });
                          Navigator.pop(modalContext);
                        },
                      ),
                      ..._availableCategories
                          .map((category) => _buildFilterChip(
                                modalContext,
                                _formatCategoryName(category.name),
                                _selectedCategory == category.name,
                                () {
                                  setState(() {
                                    _selectedCategory =
                                        _selectedCategory == category.name
                                            ? ''
                                            : category.name;
                                  });
                                  Navigator.pop(modalContext);
                                },
                              )),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Level Section
                  Text(
                    'Level',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        modalContext,
                        'All',
                        _selectedLevel.isEmpty,
                        () {
                          setState(() {
                            _selectedLevel = '';
                          });
                          Navigator.pop(modalContext);
                        },
                      ),
                      ...levels.map((level) => _buildFilterChip(
                            modalContext,
                            level,
                            _selectedLevel == level,
                            () {
                              setState(() {
                                _selectedLevel =
                                    _selectedLevel == level ? '' : level;
                              });
                              Navigator.pop(modalContext);
                            },
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
      BuildContext context, String label, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
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
        return category.substring(0, 1).toUpperCase() +
            category.substring(1).toLowerCase();
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

  // ENHANCED ACTIVE TAB - This is the main improvement
  Widget _buildActiveTab(ProgramsState state) {
    // Debug logging for active tab
    print('🔍 DEBUG: Active Tab State:');
    print('  - Status: ${state.status}');
    print('  - Active program: ${state.active}');
    print('  - Active program ID: ${state.active?.programId}');
    print('  - Programs count: ${state.programs.length}');
    print('  - Programs: ${state.programs.map((p) => '${p.id}: ${p.name} (${p.createdByRole})').toList()}');
    
    // Handle loading state with professional loading UI
    if (state.status == ProgramsStatus.loading) {
      print('  - Showing loading state');
      return _buildActiveTabLoadingState();
    }

    // Handle no active program
    if (state.active == null) {
      print('  - No active program found, showing empty state');
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: _buildEmptyActiveState(),
        ),
      );
    }

    // Find the active program with better error handling
    final Program? activeProgram = _findActiveProgramSafely(state);

    // If no active program found, show error state with recovery options
    if (activeProgram == null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: _buildActiveProgramNotFoundState(state.active!),
        ),
      );
    }

    // Validate active program data
    if (!_isActiveProgramValid(activeProgram, state.active!)) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: _buildInvalidActiveProgramState(activeProgram, state.active!),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEnhancedActiveProgramCard(activeProgram, state.active!),
          const SizedBox(height: 24),
          _buildEnhancedProgressSection(activeProgram, state.active!),
          const SizedBox(height: 24),
          _buildEnhancedTodaySection(activeProgram, state.active!),
        ],
      ),
    );
  }

  // Enhanced helper methods for active program tab
  Widget _buildActiveTabLoadingState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Animated loading card
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: colorScheme.primary,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your active program...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Loading progress section
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary.withOpacity(0.5),
                strokeWidth: 2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Loading today section
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary.withOpacity(0.3),
                strokeWidth: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Program? _findActiveProgramSafely(ProgramsState state) {
    if (state.active == null || state.programs.isEmpty) {
      return null;
    }

    try {
      // First, try to find exact match
      final exactMatch = state.programs
          .where((p) => p.id == state.active!.programId)
          .firstOrNull;
      if (exactMatch != null) {
        return exactMatch;
      }

      // If no exact match, log the issue and return null
      print('⚠️ Active program with ID ${state.active!.programId} not found in programs list');
      return null;
    } catch (e) {
      print('❌ Error finding active program: $e');
      return null;
    }
  }

  bool _isActiveProgramValid(Program program, ActiveProgram active) {
    try {
      // Check if current day is within program duration
      if (active.currentDay < 1 || active.currentDay > program.durationDays) {
        return false;
      }

      // Allow empty programs to be displayed - they might be in draft state
      if (program.days.isEmpty && program.dayWiseDrillIds.isEmpty) {
        return true; // Allow empty programs to be shown
      }

      // Check if current day exists in program structure
      if (program.days.isNotEmpty) {
        // Old format - check if day exists
        final dayExists =
            program.days.any((day) => day.dayNumber == active.currentDay);
        return dayExists;
      } else if (program.dayWiseDrillIds.isNotEmpty) {
        // New format - day might not exist (rest day), which is valid
        return true;
      }

      return true;
    } catch (e) {
      print('❌ Error validating active program: $e');
      return false;
    }
  }

  Widget _buildActiveProgramNotFoundState(ActiveProgram active) {
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
              'Active Program Not Found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The program you were following (ID: ${active.programId}) could not be found. It may have been deleted or you may have lost access to it.',
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
                    _tabController.animateTo(1); // Switch to Browse tab
                  },
                  icon: const Icon(Icons.explore),
                  label: const Text('Browse Programs'),
                ),
                
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvalidActiveProgramState(
      Program program, ActiveProgram active) {
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
                color: colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_outlined,
                size: 60,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Program Data Issue',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There\'s an issue with your active program "${program.name}". You\'re on day ${active.currentDay} but the program structure seems incomplete.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
        
          
                FilledButton.icon(
                  onPressed: () {
                    _tabController.animateTo(1); // Switch to Browse tab
                  },
                  icon: const Icon(Icons.explore),
                  label: const Text('Choose New Program'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology_outlined,
                size: 60,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Program',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your training journey by selecting a program from the Browse tab or create your own custom program.',
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
                    _tabController.animateTo(1); // Switch to Browse tab
                  },
                  icon: const Icon(Icons.explore),
                  label: const Text('Browse Programs'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _showCreateProgramScreen();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Program'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced UI components for active program tab

  Widget _buildEnhancedActiveProgramCard(
      Program program, ActiveProgram active) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryColor = _getCategoryColor(program.category);
    final categoryIcon = _getCategoryIcon(program.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surface,
        border: Border.all(
          color: categoryColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: categoryColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: categoryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    categoryIcon,
                    color: colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
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
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Admin tag for admin programs
                          if (program.createdByRole == 'admin' || program.createdByRole == null)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: colorScheme.onPrimary,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: colorScheme.onPrimary,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              program.category.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: categoryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer
                                  .withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              program.level,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${program.durationDays} days',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Modern Progress Section
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedProgressSection(Program program, ActiveProgram active) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final daysCompleted = active.currentDay - 1; // Days actually completed
    final progress = daysCompleted / program.durationDays; // Progress based on completed days
    final daysRemaining = program.durationDays - active.currentDay + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📊 Progress',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Enhanced Progress Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Compact Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '✅ $daysCompleted completed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '⏳ $daysRemaining remaining',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '🎯 ${program.durationDays} total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Compact Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _showProgramDaysOverview(program, active);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.calendar_view_day, size: 18),
              label: const Text('View Schedule'),
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildProgressStatItem(
      String label, String value, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTodaySection(Program program, ActiveProgram active) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Find today's training
    ProgramDay? todayDay;
    String? todayDrillId;
    int drillCount = 0;

    // Check old format first
    if (program.days.isNotEmpty) {
      todayDay = program.days
          .where((day) => day.dayNumber == active.currentDay)
          .firstOrNull;
      if (todayDay != null && todayDay.drillId != null) {
        todayDrillId = todayDay.drillId;
        drillCount = 1;
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

    final hasDrill = todayDay?.drillId != null && todayDay!.drillId!.isNotEmpty;
    final isRestDay = !hasDrill;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasDrill
            ? colorScheme.secondaryContainer.withOpacity(0.3)
            : colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDrill
              ? colorScheme.secondary.withOpacity(0.2)
              : colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasDrill
                      ? colorScheme.secondary
                      : colorScheme.outline,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (hasDrill
                              ? colorScheme.secondary
                              : colorScheme.outline)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  hasDrill ? Icons.fitness_center : Icons.self_improvement,
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
                      hasDrill ? '🔥 Today\'s Training' : '😌 Rest Day',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hasDrill
                            ? colorScheme.secondary
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Day ${active.currentDay} of ${program.durationDays}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Training Details Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasDrill ? Icons.schedule : Icons.spa,
                      color: hasDrill
                          ? colorScheme.secondary
                          : colorScheme.onSurface.withOpacity(0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      todayDay?.title ?? 'Day ${active.currentDay}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hasDrill
                            ? colorScheme.secondary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  todayDay?.description ?? 'No training scheduled',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                if (hasDrill && drillCount > 1) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '🎯 $drillCount drills to complete',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (hasDrill) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (todayDay != null) {
                    _startTodayTraining(todayDay);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow, size: 24),
                label: Text(
                  drillCount > 1 ? 'Start All Drills' : 'Start Training',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgramDetailChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatStartDate(DateTime? startDate) {
    if (startDate == null) return 'Today';
    final now = DateTime.now();
    final difference = now.difference(startDate).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';
    if (difference < 30) return '${(difference / 7).floor()} weeks ago';
    return '${(difference / 30).floor()} months ago';
  }

  String _formatTargetDate(DateTime? startDate, int durationDays) {
    if (startDate == null) {
      final targetDate = DateTime.now().add(Duration(days: durationDays));
      return '${targetDate.day}/${targetDate.month}';
    }
    final targetDate = startDate.add(Duration(days: durationDays));
    return '${targetDate.day}/${targetDate.month}';
  }

  Color _getDifficultyColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return AppTheme.successColor;
      case 'intermediate':
        return AppTheme.warningColor;
      case 'advanced':
        return AppTheme.errorColor;
      default:
        return AppTheme.infoColor;
    }
  }

  Widget _buildProgramCard(
    Program program, {
    required bool isActive,
    required ProgramsState state,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryColor = _getCategoryColor(program.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            isActive ? Border.all(color: colorScheme.primary, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: isActive
                ? colorScheme.primary.withOpacity(0.15)
                : colorScheme.shadow.withOpacity(0.08),
            blurRadius: isActive ? 20 : 12,
            offset: const Offset(0, 4),
            spreadRadius: isActive ? 1 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProgramDetailsScreen(program: program),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section with gradient background
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.08),
                  ),
                  child: Row(
                    children: [
                      // Modern category icon
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: categoryColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                      
                          ],
                        ),
                        child: Icon(
                          _getCategoryIcon(program.category),
                          color: colorScheme.onPrimary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title and category
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
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onSurface,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Admin tag for admin programs
                                if (program.createdByRole == 'admin' || program.createdByRole == null)
                                  Container(
                                    margin: EdgeInsets.only(right: isActive ? 8 : 0),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.admin_panel_settings,
                                          color: colorScheme.onPrimary,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ADMIN',
                                          style: TextStyle(
                                            color: colorScheme.onPrimary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_circle_fill,
                                          color: colorScheme.onPrimary,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            color: colorScheme.onPrimary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                program.category.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: categoryColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats row
                      Row(
                        children: [
                          _buildModernStatItem(
                            Icons.calendar_today_outlined,
                            '${program.durationDays}',
                            'Days',
                            AppTheme.infoColor,
                          ),
                          const SizedBox(width: 20),
                          _buildModernStatItem(
                            Icons.trending_up,
                            program.level,
                            'Level',
                            AppTheme.warningColor,
                          ),
                          const SizedBox(width: 20),
                          if (program.selectedDrillIds.isNotEmpty)
                            _buildModernStatItem(
                              Icons.fitness_center_outlined,
                              '${program.selectedDrillIds.length}',
                              'Drills',
                              AppTheme.successColor,
                            ),
                        ],
                      ),

                      // Description
                      if (program.description != null &&
                          program.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          program.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Action buttons
                      Row(
                        children: [
                          // Details button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // Check if this is an admin program and user has access
                                final isAdminProgram = program.createdByRole == 'admin' || program.createdByRole == null;
                                if (isAdminProgram) {
                                  final authState = context.read<AuthBloc>().state;
                                  final permissions = authState.permissions;
                                  final hasProgramAccess = permissions?.hasProgramAccess ?? false;
                                  
                                  if (!hasProgramAccess) {
                                    // Show snackbar for no access
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('No access to Admin Programs'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }
                                }
                                
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ProgramDetailsScreen(program: program),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'View Details',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Activate button (if not active)
                          if (!isActive)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  // Check if this is an admin program and user has access
                                  final isAdminProgram = program.createdByRole == 'admin' || program.createdByRole == null;
                                  if (isAdminProgram) {
                                    final authState = context.read<AuthBloc>().state;
                                    final permissions = authState.permissions;
                                    final hasProgramAccess = permissions?.hasProgramAccess ?? false;
                                    
                                    if (!hasProgramAccess) {
                                      // Show snackbar for no access
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('No access to Admin Programs'),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      return;
                                    }
                                  }
                                  
                                  final confirmed = await ConfirmationDialog
                                      .showProgramActivationConfirmation(
                                    context,
                                    programName: program.name,
                                    durationDays: program.durationDays,
                                    category: program.category,
                                    level: program.level,
                                    hasCurrentProgram: state.active != null,
                                  );

                                  if (confirmed == true) {
                                    HapticFeedback.mediumImpact();
                                    context.read<ProgramsBloc>().add(
                                        ProgramsActivateRequested(program));
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: categoryColor,
                                  foregroundColor: colorScheme.onPrimary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Activate',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                          // Share button
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () => _shareProgram(program),
                              icon: Icon(
                                Icons.share_outlined,
                                color: colorScheme.onSurface.withOpacity(0.7),
                                size: 20,
                              ),
                              tooltip: 'Share Program',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatItem(
      IconData icon, String value, String label, Color color) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (category.toLowerCase()) {
      case 'agility':
        return AppTheme.warningColor;
      case 'soccer':
        return AppTheme.successColor;
      case 'basketball':
        return AppTheme.errorColor;
      case 'tennis':
        return AppTheme.infoColor;
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


  Map<String, IconData> _buildCategoryIconMap() {
    final iconMap = <String, IconData>{};
    for (final category in _availableCategories) {
      iconMap[category.name] = _getCategoryIcon(category.name);
    }
    return iconMap;
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showProgramDaysOverview(Program program, ActiveProgram active) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.7, // 70% of screen height
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // --- Top drag handle and title ---
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  '${program.name} - Program Days',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),

                // --- Scrollable content ---
                Expanded(
                  child: FutureBuilder<ProgramProgress?>(
                    future: getIt<ProgramProgressService>()
                        .getProgramProgress(program.id),
                    builder: (context, snapshot) {
                      final progress = snapshot.data;

                      if (program.days.isNotEmpty) {
                        // Old format
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: program.days.length,
                          itemBuilder: (context, index) {
                            final day = program.days[index];
                            final isCompleted =
                                progress?.isDayCompleted(day.dayNumber) ??
                                    false;
                            final isCurrent =
                                active.currentDay == day.dayNumber;
                            final isAccessible =
                                day.dayNumber <= active.currentDay;

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
                        // New format
                        final sortedDays = program.dayWiseDrillIds.keys.toList()
                          ..sort();

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: sortedDays.length,
                          itemBuilder: (context, index) {
                            final dayNumber = sortedDays[index];
                            final drillIds =
                                program.dayWiseDrillIds[dayNumber] ?? [];
                            final isCompleted =
                                progress?.isDayCompleted(dayNumber) ?? false;
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
                                  : (drillCount == 1
                                      ? 'Training day'
                                      : 'Rest day'),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
        );
      },
    );
  }

  void _showCreateProgramScreen() {
    HapticFeedback.mediumImpact();
    context.push('/program-builder');
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Check if this day has drills assigned
    bool hasDrills = false;
    int drillCount = 0;
    List<String> drillIds = [];

    if (program.days.isNotEmpty) {
      // Old format
      final day =
          program.days.where((d) => d.dayNumber == dayNumber).firstOrNull;
      hasDrills = day?.drillId != null && day!.drillId!.isNotEmpty;
      if (hasDrills) {
        drillCount = 1;
        drillIds = [day!.drillId!];
      }
    } else if (program.dayWiseDrillIds.isNotEmpty) {
      // New format
      drillIds = program.dayWiseDrillIds[dayNumber] ?? [];
      hasDrills = drillIds.isNotEmpty;
      drillCount = drillIds.length;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrent ? 4 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isCurrent
              ? Border.all(color: colorScheme.primary, width: 2)
              : null,
        ),
        child: Column(
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.successColor
                      : isCurrent
                          ? colorScheme.primary
                          : isAccessible
                              ? colorScheme.outline
                              : colorScheme.outline.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, color: colorScheme.onPrimary, size: 20)
                      : Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
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
                  color: isAccessible ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description.length > 60
                        ? '${description.substring(0, 60)}...'
                        : description,
                    style: TextStyle(
                      color: isAccessible ? colorScheme.onSurface.withOpacity(0.8) : colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  if (hasDrills) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 14,
                          color: isCurrent
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          drillCount > 1
                              ? '$drillCount drills assigned'
                              : '1 drill assigned',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCurrent
                                ? colorScheme.primary
                                : colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: isAccessible
                  ? Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: isCurrent ? colorScheme.primary : null,
                    )
                  : Icon(Icons.lock, color: colorScheme.onSurface.withOpacity(0.4), size: 16),
              onTap: isAccessible
                  ? () {
                      Navigator.pop(context);
                      _navigateToProgramDay(program, dayNumber);
                    }
                  : null,
            ),

            // Enhanced current day actions
            if (isCurrent && isAccessible && hasDrills) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _navigateToProgramDay(program, dayNumber);
                            },
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('View Details'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _startAllDrillsForDay(
                                  program, dayNumber, drillIds);
                            },
                            icon:
                                const Icon(Icons.play_circle_filled, size: 18),
                            label: Text(drillCount > 1
                                ? 'Start All Drills'
                                : 'Start Drill'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _completeDayDirectly(program, dayNumber);
                        },
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Complete Day'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isCurrent && isAccessible && !hasDrills) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _completeDayDirectly(program, dayNumber);
                    },
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Complete Rest Day'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
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
          // Get the active program from the current state
          final state = context.read<ProgramsBloc>().state;
          final activeProgram = state.active;

          if (activeProgram == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active program found')),
            );
            return;
          }

          // Find the program by active program ID
          final program = state.programs
              .where((p) => p.id == activeProgram.programId)
              .firstOrNull;

          if (program == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Program not found')),
            );
            return;
          }

          // Navigate to drill runner with program context
          context.push('/drill-runner', extra: {
            'drill': drill,
            'programId': program.id,
            'programDayNumber': day.dayNumber,
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Drill not found'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading drill: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } else {
      // No drill assigned, navigate to program day screen
      final state = context.read<ProgramsBloc>().state;
      final activeProgram = state.active;

      if (activeProgram == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active program found')),
        );
        return;
      }

      // Find the program by active program ID
      final program = state.programs
          .where((p) => p.id == activeProgram.programId)
          .firstOrNull;

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

  /// Starts all drills for a specific day
  Future<void> _startAllDrillsForDay(
      Program program, int dayNumber, List<String> drillIds) async {
    if (drillIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No drills assigned for this day'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    try {
      // Ensure program progress exists before starting drills
      await _ensureProgramProgressExists(program);

      final drillService = getIt<DrillAssignmentService>();

      // Get the first drill to start with
      final firstDrill = await drillService.getDrillById(drillIds.first);

      if (firstDrill != null && mounted) {
        // Navigate to drill runner with program context
        context.push('/drill-runner', extra: {
          'drill': firstDrill,
          'programId': program.id,
          'programDayNumber': dayNumber,
          'allDrillIds':
              drillIds, // Pass all drill IDs for sequential execution
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Drill not found'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading drill: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Completes a program day directly without running drills
  Future<void> _completeDayDirectly(Program program, int dayNumber) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Day'),
          content: Text(
              'Are you sure you want to mark Day $dayNumber as completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Complete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final progressService = getIt<ProgramProgressService>();

      // First, ensure the program has progress tracking set up
      await _ensureProgramProgressExists(program);

      // Then complete the day
      await progressService.completeProgramDay(program.id, dayNumber);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Day $dayNumber completed! 🎉'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh the programs to update the UI
        context.read<ProgramsBloc>().add(const ProgramsRefreshRequested());

        // Check if there's a next day and show option to start it
        final nextDay = dayNumber + 1;
        if (nextDay <= program.durationDays) {
          _showNextDayOption(program, nextDay);
        }
      }
    } catch (e) {
      if (mounted) {
        print("completd day error is : $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing day: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Ensures that program progress tracking exists for the given program
  Future<void> _ensureProgramProgressExists(Program program) async {
    try {
      final progressService = getIt<ProgramProgressService>();

      // Check if progress already exists
      final existingProgress =
          await progressService.getProgramProgress(program.id);

      if (existingProgress == null) {
        // No progress exists, we need to create it
        // This happens when a program is active but progress tracking wasn't set up properly

        // Get current user ID
        final auth = FirebaseAuth.instance;
        final userId = auth.currentUser?.uid;

        if (userId == null) {
          throw Exception('User not authenticated');
        }

        // Create initial progress document
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('program_progress').add({
          'userId': userId,
          'programId': program.id,
          'currentDay': 1,
          'completedDays': <int>[],
          'totalDays': program.durationDays,
          'durationDays': program.durationDays,
          'startedAt': DateTime.now().toIso8601String(),
          'status': 'active',
          'progressPercentage': 0.0,
          'lastCompletedAt': null,
        });

        AppLogger.info(
            'Created missing program progress for program ${program.id}');
      }
    } catch (e) {
      AppLogger.error('Error ensuring program progress exists', error: e);
      rethrow;
    }
  }

  /// Shows option to start the next day after completing current day
  void _showNextDayOption(Program program, int nextDayNumber) {
    // Check if next day has drills
    bool hasNextDayDrills = false;
    List<String> nextDayDrillIds = [];

    if (program.days.isNotEmpty) {
      final nextDay =
          program.days.where((d) => d.dayNumber == nextDayNumber).firstOrNull;
      hasNextDayDrills =
          nextDay?.drillId != null && nextDay!.drillId!.isNotEmpty;
      if (hasNextDayDrills) {
        nextDayDrillIds = [nextDay!.drillId!];
      }
    } else if (program.dayWiseDrillIds.isNotEmpty) {
      nextDayDrillIds = program.dayWiseDrillIds[nextDayNumber] ?? [];
      hasNextDayDrills = nextDayDrillIds.isNotEmpty;
    }

    if (hasNextDayDrills) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Day $nextDayNumber Ready!'),
          content: Text(
              'Great job! Day $nextDayNumber is now available. Would you like to start the ${nextDayDrillIds.length > 1 ? 'drills' : 'drill'} for the next day?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startAllDrillsForDay(program, nextDayNumber, nextDayDrillIds);
              },
              child: Text(nextDayDrillIds.length > 1
                  ? 'Start All Drills'
                  : 'Start Drill'),
            ),
          ],
        ),
      );
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
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // Browse Tab - Shows all available programs
  Widget _buildBrowseTab(ProgramsState state) {
    final filteredPrograms = _getFilteredPrograms(state);

    if (filteredPrograms.isEmpty) {
      return _buildEmptyBrowseState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPrograms.length,
      itemBuilder: (context, index) {
        final program = filteredPrograms[index];
        final isActive = state.active?.programId == program.id;
        return _buildProgramCard(
          program,
          isActive: isActive,
          state: state,
        );
      },
    );
  }

  // Completed Tab - Shows completed programs
  Widget _buildCompletedTab(ProgramsState state) {
    // For now, show empty state as we don't have completed programs tracking
    return _buildEmptyCompletedState();
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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 60,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Programs Found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or create a new program to get started.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showCreateProgramScreen();
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Program'),
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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 60,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Completed Programs',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first program to see your achievements here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () {
                _tabController.animateTo(1); // Switch to Browse tab
              },
              icon: const Icon(Icons.explore),
              label: const Text('Browse Programs'),
            ),
          ],
        ),
      ),
    );
  }

  List<Program> _getFilteredPrograms(ProgramsState state) {
    var programs = state.programs;

    // Apply search filter
    if (state.searchQuery.isNotEmpty) {
      programs = programs.where((program) {
        return program.name
                .toLowerCase()
                .contains(state.searchQuery.toLowerCase()) ||
            program.category
                .toLowerCase()
                .contains(state.searchQuery.toLowerCase()) ||
            program.level
                .toLowerCase()
                .contains(state.searchQuery.toLowerCase());
      }).toList();
    }

    // Apply category filter
    if (_selectedCategory.isNotEmpty) {
      programs = programs
          .where((program) => program.category == _selectedCategory)
          .toList();
    }

    // Apply level filter
    if (_selectedLevel.isNotEmpty) {
      programs =
          programs.where((program) => program.level == _selectedLevel).toList();
    }

    return programs;
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
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
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
          if (widget.program.days.isEmpty &&
              widget.program.dayWiseDrillIds.isEmpty)
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

  Widget _buildEnhancedFormatDaysList(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
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
            color: hasDrill ? colorScheme.onPrimary : colorScheme.onSurface,
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
                    drillName ??
                        (_isLoadingDrills
                            ? 'Loading drill...'
                            : 'Drill assigned'),
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
