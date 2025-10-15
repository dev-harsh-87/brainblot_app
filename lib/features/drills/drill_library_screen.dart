import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/data/firebase_drill_repository.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/features/sharing/ui/privacy_control_widget.dart';
import 'package:brainblot_app/features/sharing/services/sharing_service.dart';
import 'package:brainblot_app/core/services/auto_refresh_service.dart';
import 'package:brainblot_app/core/widgets/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DrillLibraryScreen extends StatefulWidget {
  const DrillLibraryScreen({super.key});

  @override
  State<DrillLibraryScreen> createState() => _DrillLibraryScreenState();
}

class _DrillLibraryScreenState extends State<DrillLibraryScreen> 
    with TickerProviderStateMixin, AutoRefreshMixin {
  late TabController _tabController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  late SharingService _sharingService;
  late DrillRepository _drillRepository;
  bool _isGridView = true;
  String _selectedCategory = '';
  Difficulty? _selectedDifficulty;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showFab = true;
  final Map<String, bool> _ownershipCache = {};

  @override
  void initState() {
    super.initState();
    _sharingService = getIt<SharingService>();
    _drillRepository = getIt<DrillRepository>();
    _tabController = TabController(length: 4, vsync: this);
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();

    _scrollController.addListener(_onScroll);
    
    // Setup auto-refresh listeners
    listenToMultipleAutoRefresh({
      AutoRefreshService.drills: _refreshDrills,
      AutoRefreshService.sharing: _refreshDrills,
    });
    _tabController.addListener(_onTabChanged);
  }

  void _refreshDrills() {
    if (mounted) {
      context.read<DrillLibraryBloc>().add(DrillLibraryRefreshRequested());
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;

    final view = switch (_tabController.index) {
      0 => DrillLibraryView.all,
      1 => DrillLibraryView.favorites,
      2 => DrillLibraryView.custom,
      _ => DrillLibraryView.all,
    };

    context.read<DrillLibraryBloc>().add(DrillLibraryViewChanged(view));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabAnimationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 100 && _showFab) {
      setState(() => _showFab = false);
      _fabAnimationController.reverse();
    } else if (_scrollController.offset <= 100 && !_showFab) {
      setState(() => _showFab = true);
      _fabAnimationController.forward();
    }
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
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            flexibleSpace: FlexibleSpaceBar(
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
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.secondary.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => setState(() => _isGridView = !_isGridView),
                icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                tooltip: _isGridView ? 'List View' : 'Grid View',
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(120),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search drills...',
                          prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: colorScheme.onSurface.withOpacity(0.6)),
                                  onPressed: () {
                                    _searchController.clear();
                                    context.read<DrillLibraryBloc>().add(const DrillLibraryQueryChanged(''));
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (query) {
                          setState(() {});
                          print('🔍 Search query changed: "$query"');
                          context.read<DrillLibraryBloc>().add(DrillLibraryQueryChanged(query));
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter Tabs
                    TabBar(
                      controller: _tabController,
                      labelColor: colorScheme.primary,
                      unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                      indicatorColor: colorScheme.primary,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(text: 'All'),
                        Tab(text: 'My Drills'),
                        Tab(text: 'Public'),
                        Tab(text: 'Favorites'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // Filter Chips
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Category', _selectedCategory.isEmpty ? 'All' : _selectedCategory, () => _showCategoryFilter()),
                          const SizedBox(width: 8),
                          _buildFilterChip('Difficulty', _selectedDifficulty?.name ?? 'All', () => _showDifficultyFilter()),
                          const SizedBox(width: 8),
                          _buildFilterChip('Sport', _selectedCategory.isEmpty ? 'All Sports' : _selectedCategory.toUpperCase(), () => _showSportFilter()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Stats Bar
            // BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
            //   builder: (context, state) {
            //     if (state.status == DrillLibraryStatus.loaded) {
            //       return _buildStatsBar(state.items);
            //     }
            //     return const SizedBox.shrink();
            //   },
            // ),
            // Drill List/Grid
            Expanded(
              child: BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
                builder: (context, state) {
                  print('🔍 Drill Library State: ${state.status}, Items: ${state.items.length}');
                  
                  if (state.status == DrillLibraryStatus.loading) {
                    return _buildLoadingState();
                  }
                  
                  if (state.status == DrillLibraryStatus.error) {
                    return _buildErrorState(state.errorMessage ?? 'Unknown error');
                  }

                  final drills = state.items;
                  print('📊 Loaded ${drills.length} drills');
                  
                  if (drills.isEmpty) {
                    return _buildEmptyState();
                  }

                  return Stack(
                    children: [
                      TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDrillViewWithRefresh(drills, state), // All drills
                          _buildMyDrillsViewWithRefresh(state), // My drills only
                          _buildPublicDrillsViewWithRefresh(state), // Public drills only
                          _buildDrillViewWithRefresh(drills.where((d) => d.favorite).toList(), state), // Favorites
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
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () async {
            HapticFeedback.mediumImpact();
            final result = await context.push('/drill-builder');
            if (result is Drill && mounted) {
              await getIt<DrillRepository>().upsert(result);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Drill "${result.name}" created successfully!'),
                    backgroundColor: colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Create Drill'),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 8,
        ),
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


  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
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
                  'Loading drills...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fetching the latest data',
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

  Widget _buildErrorState(String error) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load drills',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }


  Widget _buildDrillViewWithRefresh(List<Drill> drills, DrillLibraryState state) {
    if (drills.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildEmptyStateForTab(),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
      },
      child: _isGridView ? _buildGridView(drills) : _buildListView(drills),
    );
  }

  Widget _buildMyDrillsViewWithRefresh(DrillLibraryState state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
      },
      child: _buildMyDrillsView(),
    );
  }

  Widget _buildPublicDrillsViewWithRefresh(DrillLibraryState state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
      },
      child: _buildPublicDrillsView(),
    );
  }

  Widget _buildDrillView(List<Drill> drills) {
    if (drills.isEmpty) {
      return _buildEmptyStateForTab();
    }

    if (_isGridView) {
      return _buildGridView(drills);
    } else {
      return _buildListView(drills);
    }
  }

  Widget _buildGridView(List<Drill> drills) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        controller: _scrollController,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: drills.length,
        itemBuilder: (context, index) => _buildDrillCard(drills[index]),
      ),
    );
  }

  Widget _buildListView(List<Drill> drills) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: drills.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildDrillListTile(drills[index]),
    );
  }
  Widget _buildDrillCard(Drill drill) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    // Dynamically adjust padding, font sizes, and spacing based on screen width
    final isCompact = size.width < 400;
    final padding = EdgeInsets.all(isCompact ? 12 : 16);
    final iconSize = isCompact ? 14.0 : 16.0;
    final smallFont = theme.textTheme.bodySmall?.copyWith(fontSize: isCompact ? 10 : 12);
    final labelFont = theme.textTheme.labelSmall?.copyWith(
      fontSize: isCompact ? 12 : 14,
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(


      builder: (context, constraints) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/drill-detail', extra: drill);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Header Row (icon + name)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(drill.difficulty).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getCategoryIcon(drill.category),
                          color: _getDifficultyColor(drill.difficulty),
                          size: iconSize,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          drill.name,
                          style: labelFont,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  /// Category
                  Text(
                    drill.category.toUpperCase(),
                    style: smallFont?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 6),

                  /// Chips (duration + reps)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildInfoChip(Icons.timer, '${drill.durationSec}s'),
                      _buildInfoChip(Icons.repeat, '${drill.reps}x',),
                    ],
                  ),

                  const SizedBox(height: 6),

                  /// Privacy indicator
                  Flexible(child: _buildPrivacyIndicator(drill)),

                  const SizedBox(height: 6),

                  /// Shared / Custom tags
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      if (drill.sharedWith.isNotEmpty)
                        _buildTag(
                          icon: Icons.people,
                          text: 'SHARED',
                          color: Colors.blue,
                          theme: theme,
                          fontSize: isCompact ? 8 : 10,
                        ),
                      if (!drill.isPreset)
                        _buildTag(
                          text: 'CUSTOM',
                          color: Colors.orange,
                          theme: theme,
                          fontSize: isCompact ? 8 : 10,
                        ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  /// Difficulty badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(drill.difficulty).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      drill.difficulty.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: smallFont?.copyWith(
                        color: _getDifficultyColor(drill.difficulty),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildTag({
    IconData? icon,
    required String text,
    required Color color,
    required ThemeData theme,
    double fontSize = 10,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: fontSize + 2),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrillListTile(Drill drill) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/drill-detail', extra: drill);
        },
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getDifficultyColor(drill.difficulty).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon(drill.category),
            color: _getDifficultyColor(drill.difficulty),
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                drill.name,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),


            ),
            if (!drill.isPreset) const SizedBox(width: 2),
            // Privacy indicator - always show, load ownership async
            Flexible(child: _buildPrivacyIndicator(drill)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (drill.sharedWith.isNotEmpty)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people, color: Colors.blue, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            'SHARED',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.blue,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (drill.sharedWith.isNotEmpty) const SizedBox(width: 4),
                if (!drill.isPreset)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'CUSTOM',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${drill.category.toUpperCase()} • ${drill.difficulty.name.toUpperCase()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoChip(Icons.timer, '${drill.durationSec}s'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.repeat, '${drill.reps}x'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.pause, '${drill.restSec}s rest'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.onSurface.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
                Icons.fitness_center,
                size: 60,
                color: colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No drills found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first drill or adjust your filters to get started',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    try {
                      final repo = getIt<DrillRepository>();
                      if (repo is FirebaseDrillRepository) {
                        await repo.seedDefaultDrills();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Default drills loaded successfully!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to load default drills: $e'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Load Default Drills'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final result = await context.push('/drill-builder');
                    if (result is Drill && mounted) {
                      await getIt<DrillRepository>().upsert(result);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Drill'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateForTab() {
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
              'No drills in this category',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different filter or create a new drill',
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

  Color _getDifficultyColor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return Colors.green;
      case Difficulty.intermediate:
        return Colors.orange;
      case Difficulty.advanced:
        return Colors.red;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'soccer':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      case 'tennis':
        return Icons.sports_tennis;
      case 'fitness':
        return Icons.fitness_center;
      case 'hockey':
        return Icons.sports_hockey;
      case 'volleyball':
        return Icons.sports_volleyball;
      case 'football':
        return Icons.sports_football;
      default:
        return Icons.psychology;
    }
  }

  void _showSportFilter() {
    final sports = ['Soccer', 'Basketball', 'Tennis', 'Fitness', 'Hockey', 'Volleyball', 'Football'];

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sports, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Filter by Sport',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSportChip('All Sports', _selectedCategory.isEmpty),
                  ...sports.map((sport) => _buildSportChip(sport, _selectedCategory == sport.toLowerCase())),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showCategoryFilter() {
    final categories = ['Soccer', 'Basketball', 'Tennis', 'Fitness', 'Hockey', 'Volleyball', 'Football'];

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by Category',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCategoryChip('All', _selectedCategory.isEmpty),
                  ...categories.map((category) => _buildCategoryChip(category, _selectedCategory == category)),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSportChip(String sport, bool isSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      label: Text(sport),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? (sport == 'All Sports' ? '' : sport.toLowerCase()) : '';
        });
        print('🏃 Sport filter changed: "$sport" -> category: "$_selectedCategory"');
        context.read<DrillLibraryBloc>().add(DrillLibraryFilterChanged(
          category: _selectedCategory.isEmpty ? null : _selectedCategory,
          difficulty: _selectedDifficulty,
        ));
        Navigator.pop(context);
      },
      selectedColor: colorScheme.primary.withOpacity(0.2),
      checkmarkColor: colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildCategoryChip(String category, bool isSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      label: Text(category),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? (category == 'All' ? '' : category.toLowerCase()) : '';
        });
        context.read<DrillLibraryBloc>().add(DrillLibraryFilterChanged(
          category: _selectedCategory.isEmpty ? null : _selectedCategory,
          difficulty: _selectedDifficulty,
        ));
        Navigator.pop(context);
      },
      selectedColor: colorScheme.primary.withOpacity(0.2),
      checkmarkColor: colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  void _showDifficultyFilter() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by Difficulty',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDifficultyChip('All', _selectedDifficulty == null),
                  ...Difficulty.values.map((difficulty) => _buildDifficultyChip(
                    difficulty.name.toUpperCase(),
                    _selectedDifficulty == difficulty
                  )),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDifficultyChip(String label, bool isSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color chipColor = colorScheme.primary;
    if (label != 'All') {
      final difficulty = Difficulty.values.firstWhere(
        (d) => d.name.toUpperCase() == label,
        orElse: () => Difficulty.beginner,
      );
      chipColor = _getDifficultyColor(difficulty);
    }

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (label == 'All') {
            _selectedDifficulty = null;
          } else {
            _selectedDifficulty = selected
                ? Difficulty.values.firstWhere((d) => d.name.toUpperCase() == label)
                : null;
          }
        });
        context.read<DrillLibraryBloc>().add(DrillLibraryFilterChanged(
          category: _selectedCategory.isEmpty ? null : _selectedCategory,
          difficulty: _selectedDifficulty,
        ));
        Navigator.pop(context);
      },
      selectedColor: chipColor.withOpacity(0.2),
      checkmarkColor: chipColor,
      labelStyle: TextStyle(
        color: isSelected ? chipColor : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildMyDrillsView() {
    return BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
      builder: (context, state) {
        return FutureBuilder<List<Drill>>(
          key: ValueKey('${state.query}-${state.category}-${state.difficulty}'),
          future: getIt<DrillRepository>().fetchMyDrills(
            query: state.query?.isEmpty == true ? null : state.query,
            category: state.category?.isEmpty == true ? null : state.category,
            difficulty: state.difficulty,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading your drills: ${snapshot.error}'),
              ],
            ),
          );
        }

        final myDrills = snapshot.data ?? [];
        if (myDrills.isEmpty) {
          return _buildEmptyMyDrillsState();
        }

        return _buildDrillView(myDrills);
        },
      );
      },
    );
  }

  Widget _buildPublicDrillsView() {
    return BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
      builder: (context, state) {
        return FutureBuilder<List<Drill>>(
          key: ValueKey('public-${state.query}-${state.category}-${state.difficulty}'),
          future: getIt<DrillRepository>().fetchPublicDrills(
            query: state.query?.isEmpty == true ? null : state.query,
            category: state.category?.isEmpty == true ? null : state.category,
            difficulty: state.difficulty,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading public drills: ${snapshot.error}'),
              ],
            ),
          );
        }

        final publicDrills = snapshot.data ?? [];
        if (publicDrills.isEmpty) {
          return _buildEmptyPublicDrillsState();
        }

        return _buildDrillView(publicDrills);
        },
      );
      },
    );
  }

  Widget _buildEmptyMyDrillsState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 80,
            color: colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No Personal Drills Yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your first drill to get started!\nYour drills will be private by default.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to create drill
            },
            icon: const Icon(Icons.add),
            label: const Text('Create First Drill'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPublicDrillsState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.public_outlined,
            size: 80,
            color: colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No Public Drills Available',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Be the first to share a drill with the community!\nMake your drills public to help others train.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyIndicator(Drill drill) {
    return FutureBuilder<bool>(
      future: _isOwner(drill),
      builder: (context, snapshot) {
        final isOwner = snapshot.data ?? false;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return PrivacyToggleButton(
          isPublic: drill.isPublic,
          isOwner: isOwner,
          onToggle: isOwner ? () => _toggleDrillPrivacy(drill) : null,
          isLoading: isLoading,
        );
      },
    );
  }

  Future<bool> _isOwner(Drill drill) async {
    if (_ownershipCache.containsKey(drill.id)) {
      return _ownershipCache[drill.id]!;
    }

    try {
      final isOwner = await _sharingService.isOwner('drill', drill.id);
      _ownershipCache[drill.id] = isOwner;
      return isOwner;
    } catch (e) {
      return false;
    }
  }

  Future<void> _toggleFavorite(Drill drill) async {
    try {
      await _drillRepository.toggleFavorite(drill.id);
      
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                drill.favorite ? Icons.favorite_border : Icons.favorite,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(drill.favorite 
                  ? 'Removed from favorites' 
                  : 'Added to favorites'),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Refresh the drills list to show updated favorite status
      context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update favorite: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editDrill(Drill drill) async {
    HapticFeedback.lightImpact();
    
    final editedDrill = await context.push<Drill>('/drill-builder', extra: drill);
    
    if (editedDrill != null && mounted) {
      try {
        await _drillRepository.upsert(editedDrill);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drill updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Refresh the drills list to show updated drill
        context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update drill: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleDrillPrivacy(Drill drill) async {
    // Show confirmation dialog
    final confirmed = await ConfirmationDialog.showPrivacyConfirmation(
      context,
      isCurrentlyPublic: drill.isPublic,
      itemType: 'drill',
      itemName: drill.name,
    );

    if (confirmed != true) return;

    try {
      await _sharingService.togglePrivacy('drill', drill.id, !drill.isPublic);

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                !drill.isPublic ? Icons.public : Icons.lock,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(!drill.isPublic
                  ? 'Drill is now public! 🌍'
                  : 'Drill is now private 🔒'),
            ],
          ),
          backgroundColor: !drill.isPublic ? Colors.green : Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Refresh the drills list to show updated privacy status
      context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
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
