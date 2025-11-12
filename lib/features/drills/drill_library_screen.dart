import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:spark_app/features/drills/data/drill_repository.dart';
import 'package:spark_app/features/drills/data/firebase_drill_repository.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/sharing/ui/privacy_control_widget.dart';
import 'package:spark_app/features/sharing/services/sharing_service.dart';
import 'package:spark_app/core/services/auto_refresh_service.dart';
import 'package:spark_app/core/widgets/confirmation_dialog.dart';
import 'package:spark_app/core/ui/edge_to_edge.dart';
import 'package:spark_app/core/auth/services/session_management_service.dart';
import 'package:spark_app/core/auth/services/subscription_permission_service.dart';
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
  String _selectedCategory = '';
  Difficulty? _selectedDifficulty;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showFab = true;
  final Map<String, bool> _ownershipCache = {};
  bool _isAdmin = false;
  bool _isLoading = true;
  bool _hasDrillAccess = false;

  @override
  void initState() {
    super.initState();
    _sharingService = getIt<SharingService>();
    _drillRepository = getIt<DrillRepository>();
    
    // Initialize with default length, will be updated after role check
    _tabController = TabController(length: 2, vsync: this);
    
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
    
    // Check user role and update tab configuration
    _checkUserRoleAndUpdateTabs();
  }
  
  Future<void> _checkUserRoleAndUpdateTabs() async {
    try {
      final sessionService = getIt<SessionManagementService>();
      final subscriptionService = getIt<SubscriptionPermissionService>();
      
      final isAdmin = sessionService.isAdmin();
      final hasDrillAccess = await subscriptionService.hasModuleAccess('admin_drills');
      
      setState(() {
        _isAdmin = isAdmin;
        _hasDrillAccess = hasDrillAccess;
        _isLoading = false;
      });
      
      // Update tab controller length based on role and access
      _tabController.removeListener(_onTabChanged);
      _tabController.dispose();
      
      // Tab configuration:
      // Admin: 2 tabs (My Drills, Favorites)
      // User with drill access: 3 tabs (My Drills, Admin Drills, Favorites)
      // User without drill access: 2 tabs (My Drills, Favorites)
      int tabLength;
      if (isAdmin) {
        tabLength = 2; // My Drills, Favorites
      } else if (hasDrillAccess) {
        tabLength = 3; // My Drills, Admin Drills, Favorites
      } else {
        tabLength = 2; // My Drills, Favorites (no Admin Drills)
      }
      
      _tabController = TabController(
        length: tabLength,
        vsync: this,
      );
      _tabController.addListener(_onTabChanged);
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error checking user role and access: $e');
      setState(() {
        _isAdmin = false;
        _hasDrillAccess = false;
        _isLoading = false;
      });
    }
  }

  void _refreshDrills() {
    if (mounted) {
      context.read<DrillLibraryBloc>().add(DrillLibraryRefreshRequested());
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;

    // Tab mapping based on role and access:
    // Admin: 0=My Drills, 1=Favorites
    // User with drill access: 0=My Drills, 1=Admin Drills, 2=Favorites
    // User without drill access: 0=My Drills, 1=Favorites
    DrillLibraryView view;
    
    if (_isAdmin) {
      // Admin tabs: My Drills, Favorites
      view = switch (_tabController.index) {
        0 => DrillLibraryView.custom, // My Drills
        1 => DrillLibraryView.favorites, // Favorites
        _ => DrillLibraryView.custom,
      };
    } else if (_hasDrillAccess) {
      // User with drill access: My Drills, Admin Drills, Favorites
      view = switch (_tabController.index) {
        0 => DrillLibraryView.custom, // My Drills
        1 => DrillLibraryView.all, // Admin Drills
        2 => DrillLibraryView.favorites, // Favorites
        _ => DrillLibraryView.custom,
      };
    } else {
      // User without drill access: My Drills, Favorites (no Admin Drills)
      view = switch (_tabController.index) {
        0 => DrillLibraryView.custom, // My Drills
        1 => DrillLibraryView.favorites, // Favorites
        _ => DrillLibraryView.custom,
      };
    }

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

  List<Widget> _buildTabs() {
    if (_isAdmin) {
      // Admin: My Drills, Favorites
      return const [
        Tab(text: 'My Drills'),
        Tab(text: 'Favorites'),
      ];
    } else if (_hasDrillAccess) {
      // User with drill access: My Drills, Admin Drills, Favorites
      return const [
        Tab(text: 'My Drills'),
        Tab(text: 'Admin Drills'),
        Tab(text: 'Favorites'),
      ];
    } else {
      // User without drill access: My Drills, Favorites (no Admin Drills)
      return const [
        Tab(text: 'My Drills'),
        Tab(text: 'Favorites'),
      ];
    }
  }

  List<Widget> _buildTabViews(DrillLibraryState state) {
    if (_isAdmin) {
      // Admin: My Drills, Favorites
      return [
        _buildMyDrillsViewWithRefresh(state), // My drills only
        _buildFavoriteDrillsViewWithRefresh(state), // Favorites
      ];
    } else if (_hasDrillAccess) {
      // User with drill access: My Drills, Admin Drills, Favorites
      return [
        _buildMyDrillsViewWithRefresh(state), // My drills only
        _buildAdminDrillsViewWithRefresh(state), // Admin drills only
        _buildFavoriteDrillsViewWithRefresh(state), // Favorites
      ];
    } else {
      // User without drill access: My Drills, Favorites (no Admin Drills)
      return [
        _buildMyDrillsViewWithRefresh(state), // My drills only
        _buildFavoriteDrillsViewWithRefresh(state), // Favorites
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Set system UI for primary colored app bar
    EdgeToEdge.setPrimarySystemUI(context);

    return EdgeToEdgeScaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context),
      extendBodyBehindAppBar: false,
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchAndFilterSection(context),
          // Drill Content
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
                      children: _buildTabViews(state),
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      elevation: 0,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      title: Text(
        'Drill Library',
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
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchAndFilterSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withOpacity(0.3),
            colorScheme.secondaryContainer.withOpacity(0.2),
          ],
        ),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onChanged: (query) {
                  setState(() {});
                  print('🔍 Search query changed: "$query"');
                  context.read<DrillLibraryBloc>().add(DrillLibraryQueryChanged(query));
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Filter Tabs
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                indicatorColor: colorScheme.primary,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: _buildTabs(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildEnhancedFilterChip('Category', _selectedCategory.isEmpty ? 'All' : _selectedCategory, () => _showCategoryFilter()),
                  const SizedBox(width: 8),
                  _buildEnhancedFilterChip('Difficulty', _selectedDifficulty?.name ?? 'All', () => _showDifficultyFilter()),
                  const SizedBox(width: 8),
                  _buildEnhancedFilterChip('Sport', _selectedCategory.isEmpty ? 'All Sports' : _selectedCategory.toUpperCase(), () => _showSportFilter()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedFilterChip(String label, String value, VoidCallback onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = (label == 'Category' && _selectedCategory.isNotEmpty) ||
                     (label == 'Difficulty' && _selectedDifficulty != null) ||
                     (label == 'Sport' && _selectedCategory.isNotEmpty);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.15),
                    colorScheme.primary.withOpacity(0.05),
                  ],
                )
              : null,
          color: isActive ? null : colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? colorScheme.primary.withOpacity(0.3)
                : colorScheme.outline.withOpacity(0.2),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.filter_alt,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ),
            Text(
              '$label: $value',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurface,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

 

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(64),
        child: Column(
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
                    'Fetching the latest drill library',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
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

  Widget _buildErrorState(String error) {
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
              'Failed to load drills',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
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

  
  Widget _buildAdminDrillsViewWithRefresh(DrillLibraryState state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
      },
      child: _buildAdminDrillsView(),
    );
  }

  Widget _buildFavoriteDrillsViewWithRefresh(DrillLibraryState state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<DrillLibraryBloc>().add(const DrillLibraryRefreshRequested());
      },
      child: _buildFavoriteDrillsView(),
    );
  }

  Widget _buildDrillView(List<Drill> drills) {
    if (drills.isEmpty) {
      return _buildEmptyStateForTab();
    }

    return _buildListView(drills);
  }

  

  Widget _buildListView(List<Drill> drills) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: drills.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildDrillListTile(drills[index]),
    );
  }
  




  
Widget _buildCompactStatChip(IconData icon, String text, Color color) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
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
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrillListTile(Drill drill) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface,
            colorScheme.surface.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: _getDifficultyColor(drill.difficulty).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _getDifficultyColor(drill.difficulty).withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/drill-detail', extra: drill);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Leading icon
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getDifficultyColor(drill.difficulty).withOpacity(0.15),
                        _getDifficultyColor(drill.difficulty).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _getDifficultyColor(drill.difficulty).withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    _getCategoryIcon(drill.category),
                    color: _getDifficultyColor(drill.difficulty),
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with favorite
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              drill.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _toggleFavorite(drill),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(

                                color: drill.favorite
                                    ? Colors.red.withOpacity(0.1)
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                drill.favorite ? Icons.favorite : Icons.favorite_border,
                                color: drill.favorite ? Colors.red : colorScheme.onSurface.withOpacity(0.6),
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Category and difficulty
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              drill.category.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getDifficultyColor(drill.difficulty).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _getDifficultyColor(drill.difficulty).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _getDifficultyColor(drill.difficulty),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  drill.difficulty.name.toUpperCase(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: _getDifficultyColor(drill.difficulty),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Stats and tags row
                      Row(
                        children: [
                          _buildCompactStatChip(Icons.timer_outlined, '${drill.durationSec}s', colorScheme.primary),
                          const SizedBox(width: 8),
                          _buildCompactStatChip(Icons.repeat_rounded, '${drill.reps}x', Colors.orange),
                          const SizedBox(width: 8),
                          _buildCompactStatChip(Icons.pause_circle_outline, '${drill.restSec}s', Colors.grey),
                          const Spacer(),
                          if (drill.sharedWith.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline, color: Colors.blue, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    'SHARED',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.blue,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (drill.sharedWith.isNotEmpty && !drill.isPreset)
                            const SizedBox(width: 6),
                          if (!drill.isPreset)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'CUSTOM',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.orange,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
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
        ),);
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
        ),);
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
                    _selectedDifficulty == difficulty,
                  ),),
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
        ),);
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

  Widget _buildAdminDrillsView() {
    return FutureBuilder<bool>(
      future: getIt<SubscriptionPermissionService>().hasModuleAccess('drills'),
      builder: (context, moduleAccessSnapshot) {
        if (moduleAccessSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final hasAccess = moduleAccessSnapshot.data ?? false;
        
        if (!hasAccess) {
          return _buildNoAccessState();
        }

        return BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
          builder: (context, state) {
            return FutureBuilder<List<Drill>>(
              key: ValueKey('admin-${state.query}-${state.category}-${state.difficulty}'),
              future: getIt<DrillRepository>().fetchAdminDrills(
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
                      Text('Error loading admin drills: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final adminDrills = snapshot.data ?? [];
              if (adminDrills.isEmpty) {
                return _buildEmptyAdminDrillsState();
              }

              return _buildDrillView(adminDrills);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFavoriteDrillsView() {
    return BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
      builder: (context, state) {
        return FutureBuilder<List<Drill>>(
          key: ValueKey('favorites-${state.query}-${state.category}-${state.difficulty}'),
          future: getIt<DrillRepository>().fetchFavoriteDrills(
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
                  Text('Error loading favorite drills: ${snapshot.error}'),
                ],
              ),
            );
          }

          final favoriteDrills = snapshot.data ?? [];
          if (favoriteDrills.isEmpty) {
            return _buildEmptyFavoriteDrillsState();
          }

          return _buildDrillView(favoriteDrills);
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

  Widget _buildNoAccessState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outlined,
            size: 80,
            color: colorScheme.error.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Access Required',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You need module access to view admin drills.\nPlease contact an administrator to request access.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFavoriteDrillsState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_outline,
            size: 80,
            color: colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No Favorite Drills Yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Mark drills as favorites to see them here.\nTap the heart icon on any drill to add it to favorites.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAdminDrillsState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: 80,
            color: colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No Admin Drills Available',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No drills have been created by admins yet.\nCheck back later for admin-created drills.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
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
                  : 'Added to favorites',),
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


}
