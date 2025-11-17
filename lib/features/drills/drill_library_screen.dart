import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:spark_app/features/drills/data/drill_repository.dart';
import 'package:spark_app/features/drills/data/drill_category_repository.dart';
import 'package:spark_app/features/drills/data/firebase_drill_repository.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/domain/drill_category.dart';
import 'package:spark_app/features/sharing/ui/privacy_control_widget.dart';
import 'package:spark_app/features/sharing/services/sharing_service.dart';
import 'package:spark_app/core/services/auto_refresh_service.dart';
import 'package:spark_app/core/widgets/confirmation_dialog.dart';
import 'package:spark_app/core/ui/edge_to_edge.dart';
import 'package:spark_app/core/auth/services/session_management_service.dart';
import 'package:spark_app/core/auth/services/subscription_permission_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  List<DrillCategory> _availableCategories = [];
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
    
    // Load categories
    _loadCategories();
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
  
  Future<void> _checkUserRoleAndUpdateTabs() async {
    try {
      final sessionService = getIt<SessionManagementService>();
      final subscriptionService = getIt<SubscriptionPermissionService>();
      
      // Wait a bit for session to be fully established
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Debug session state
      final currentSession = sessionService.getCurrentSession();
      print('🔍 Current session: ${currentSession?.email}, role: ${currentSession?.role.value}');
      print('🔍 Session isLoggedIn: ${sessionService.isLoggedIn()}');
      
      // Check if user is admin first with retry mechanism
      bool isAdmin = sessionService.isAdmin();
      print('🔍 sessionService.isAdmin() returned: $isAdmin');
      
      // If not admin initially, retry a few times as session might still be loading
      if (!isAdmin) {
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          final retrySession = sessionService.getCurrentSession();
          isAdmin = sessionService.isAdmin();
          print('🔍 Retry $i: session=${retrySession?.email}, role=${retrySession?.role.value}, isAdmin=$isAdmin');
          if (isAdmin) break;
        }
      }
      
      // If still not admin, try direct Firestore check as fallback
      if (!isAdmin) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              final role = userData['role'] as String?;
              isAdmin = role == 'admin';
              print('🔍 Direct Firestore check: role=$role, isAdmin=$isAdmin');
            }
          }
        } catch (e) {
          print('🔍 Error in direct Firestore check: $e');
        }
      }
      
      // For non-admin users, wait for subscription sync to complete
      bool hasDrillAccess = false;
      if (!isAdmin) {
        print('🔍 User is not admin, checking drill access...');
        // Retry mechanism for subscription access check
        int retryCount = 0;
        const maxRetries = 3;
        
        while (retryCount < maxRetries) {
          try {
            hasDrillAccess = await subscriptionService.hasModuleAccess('admin_drills');
            print('🔍 hasModuleAccess(admin_drills) returned: $hasDrillAccess');
            break; // Success, exit retry loop
          } catch (e) {
            retryCount++;
            print('🔍 Error checking admin_drills access (attempt $retryCount): $e');
            if (retryCount >= maxRetries) {
              print('Failed to check admin_drills access after $maxRetries attempts: $e');
              hasDrillAccess = false;
            } else {
              // Wait before retry with exponential backoff
              await Future.delayed(Duration(milliseconds: 300 * retryCount));
            }
          }
        }
      } else {
        print('🔍 User is admin, skipping drill access check');
      }
      
      print('🔍 Final results: isAdmin=$isAdmin, hasDrillAccess=$hasDrillAccess');
      
      setState(() {
        _isAdmin = isAdmin;
        _hasDrillAccess = hasDrillAccess;
        _isLoading = false;
      });
      
      // Update tab controller length based on role and access
      _tabController.removeListener(_onTabChanged);
      _tabController.dispose();
      
      // Tab configuration:
      // Admin: 3 tabs (My Drills, Admin Drills, Favorites) - admins can see admin drills
      // User with drill access: 3 tabs (My Drills, Admin Drills, Favorites)
      // User without drill access: 2 tabs (My Drills, Favorites)
      int tabLength;
      if (isAdmin || hasDrillAccess) {
        tabLength = 3; // My Drills, Admin Drills, Favorites
        print('🔍 Setting tabLength to 3 for ${isAdmin ? 'admin' : 'user with drill access'} (isAdmin=$isAdmin, hasDrillAccess=$hasDrillAccess)');
      } else {
        tabLength = 2; // My Drills, Favorites (no Admin Drills)
        print('🔍 Setting tabLength to 2 for user without drill access');
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
    // Admin or User with drill access: 0=My Drills, 1=Admin Drills, 2=Favorites
    // User without drill access: 0=My Drills, 1=Favorites
    DrillLibraryView view;
    
    if (_isAdmin || _hasDrillAccess) {
      // Admin or User with drill access: My Drills, Admin Drills, Favorites
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
    print('🔍 _buildTabs called: _isAdmin=$_isAdmin, _hasDrillAccess=$_hasDrillAccess');
    if (_isAdmin || _hasDrillAccess) {
      // Admin or User with drill access: My Drills, Admin Drills, Favorites
      print('🔍 Building 3 tabs for ${_isAdmin ? 'admin' : 'user with drill access'} (My Drills, Admin Drills, Favorites)');
      return [
        const Tab(text: 'My Drills'),
        const Tab(text: 'Admin Drills'),
        const Tab(text: 'Favorites'),
      ];
    } else {
      // User without drill access: My Drills, Favorites (no Admin Drills)
      print('🔍 Building 2 tabs for user without drill access (My Drills, Favorites)');
      return [
        const Tab(text: 'My Drills'),
        const Tab(text: 'Favorites'),
      ];
    }
  }

  List<Widget> _buildTabsWithCounts(DrillLibraryState state) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    // Calculate counts for each tab based on current state
    final myDrillsCount = state.all.where((drill) =>
      !drill.isPreset && drill.createdBy == userId
    ).length;
    
    if (_isAdmin || _hasDrillAccess) {
      // Admin or User with drill access: My Drills, Admin Drills, Favorites
      return [
        Tab(
          child: _buildTabWithCount('My Drills', myDrillsCount),
        ),
        Tab(
          child: FutureBuilder<List<Drill>>(
            future: _drillRepository.fetchAdminDrills(),
            builder: (context, snapshot) {
              final adminDrillsCount = snapshot.data?.length ?? 0;
              return _buildTabWithCount('Admin Drills', adminDrillsCount);
            },
          ),
        ),
        Tab(
          child: FutureBuilder<List<Drill>>(
            future: _drillRepository.fetchFavoriteDrills(),
            builder: (context, snapshot) {
              final favoritesCount = snapshot.data?.length ?? 0;
              return _buildTabWithCount('Favorites', favoritesCount);
            },
          ),
        ),
      ];
    } else {
      // User without drill access: My Drills, Favorites (no Admin Drills)
      return [
        Tab(
          child: _buildTabWithCount('My Drills', myDrillsCount),
        ),
        Tab(
          child: FutureBuilder<List<Drill>>(
            future: _drillRepository.fetchFavoriteDrills(),
            builder: (context, snapshot) {
              final favoritesCount = snapshot.data?.length ?? 0;
              return _buildTabWithCount('Favorites', favoritesCount);
            },
          ),
        ),
      ];
    }
  }

  Widget _buildTabWithCount(String title, int count) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            constraints: const BoxConstraints(minWidth: 18),
            child: Text(
              count.toString(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildTabViews(DrillLibraryState state) {
    if (_isAdmin || _hasDrillAccess) {
      // Admin or User with drill access: My Drills, Admin Drills, Favorites
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
        _buildFilterButton(colorScheme),
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
              child: BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
                builder: (context, state) {
                  return TabBar(
                    controller: _tabController,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                    indicatorColor: colorScheme.primary,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: _buildTabsWithCounts(state),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),


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
                            child: FutureBuilder<bool>(
                              future: _drillRepository.isFavorite(drill.id),
                              builder: (context, snapshot) {
                                final isFavorite = snapshot.data ?? false;
                                return Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isFavorite
                                        ? Colors.red.withOpacity(0.1)
                                        : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: isFavorite ? Colors.red : colorScheme.onSurface.withOpacity(0.6),
                                    size: 16,
                                  ),
                                );
                              },
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





  

  Widget _buildMyDrillsView() {
    return BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
      builder: (context, state) {
        // Get user ID
        final userId = FirebaseAuth.instance.currentUser?.uid;
        
        // Filter drills: only user-created drills (not preset) and apply search/category/difficulty filters
        var myDrills = state.all.where((drill) =>
          !drill.isPreset && drill.createdBy == userId
        ).toList();
        
        // Apply search filter
        if (state.query != null && state.query!.isNotEmpty) {
          final queryLower = state.query!.toLowerCase();
          myDrills = myDrills.where((drill) =>
            drill.name.toLowerCase().contains(queryLower) ||
            drill.description.toLowerCase().contains(queryLower) ||
            drill.category.toLowerCase().contains(queryLower) ||
            drill.tags.any((tag) => tag.toLowerCase().contains(queryLower))
          ).toList();
        }
        
        // Apply category filter
        if (state.category != null && state.category!.isNotEmpty) {
          myDrills = myDrills.where((drill) =>
            drill.category.toLowerCase() == state.category!.toLowerCase()
          ).toList();
        }
        
        // Apply difficulty filter
        if (state.difficulty != null) {
          myDrills = myDrills.where((drill) =>
            drill.difficulty == state.difficulty
          ).toList();
        }
        
        print('🔍 My Drills: Found ${myDrills.length} drills after filtering');
        
        if (myDrills.isEmpty) {
          return _buildEmptyMyDrillsState();
        }

        return _buildDrillView(myDrills);
      },
    );
  }

  Widget _buildAdminDrillsView() {
    // Admin users have inherent access to admin drills, skip module access check
    if (_isAdmin) {
      print('🔍 Admin user detected - bypassing module access check');
      return BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
        builder: (context, state) {
          // Filter admin drills from the BLoC state
          final adminDrills = state.items.where((drill) => drill.createdByRole == 'admin').toList();
          print('🔍 Admin drills from BLoC: ${adminDrills.length} drills (filtered)');
          
          if (state.status == DrillLibraryStatus.loading || state.status == DrillLibraryStatus.filtering) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == DrillLibraryStatus.error) {
            print('🔴 Error in BLoC state: ${state.errorMessage}');
            return Center(
              child: Text('Error loading admin drills: ${state.errorMessage}'),
            );
          }
          
          if (adminDrills.isEmpty) {
            print('🔍 No admin drills found - showing empty state');
            return _buildEmptyAdminDrillsState();
          }

          print('🔍 Showing ${adminDrills.length} admin drills');
          return _buildDrillView(adminDrills);
        },
      );
    }

    // For non-admin users, check module access
    return FutureBuilder<bool>(
      future: getIt<SubscriptionPermissionService>().hasModuleAccess('admin_drills'),
      builder: (context, moduleAccessSnapshot) {
        if (moduleAccessSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final hasAccess = moduleAccessSnapshot.data ?? false;
        print('🔍 Admin drills module access check: $hasAccess');
        
        if (!hasAccess) {
          print('🔴 User does not have admin_drills module access - showing no access state');
          return _buildNoAccessState();
        }

        print('✅ User has admin_drills module access - proceeding to show drills');

        return BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
          builder: (context, state) {
            // Filter admin drills from the BLoC state
            final adminDrills = state.items.where((drill) => drill.createdByRole == 'admin').toList();
            print('🔍 Admin drills from BLoC: ${adminDrills.length} drills (filtered)');
            
            if (state.status == DrillLibraryStatus.loading || state.status == DrillLibraryStatus.filtering) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status == DrillLibraryStatus.error) {
              print('🔴 Error in BLoC state: ${state.errorMessage}');
              return Center(
                child: Text('Error loading admin drills: ${state.errorMessage}'),
              );
            }
            
            if (adminDrills.isEmpty) {
              print('🔍 No admin drills found - showing empty state');
              return _buildEmptyAdminDrillsState();
            }

            print('🔍 Showing ${adminDrills.length} admin drills');
            return _buildDrillView(adminDrills);
          },
        );
      },
    );
  }

  Widget _buildFavoriteDrillsView() {
    return BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
      builder: (context, state) {
        return FutureBuilder<List<Drill>>(
          future: _drillRepository.fetchFavoriteDrills(
            query: state.query,
            category: state.category,
            difficulty: state.difficulty,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              print('🔴 Error loading favorite drills: ${snapshot.error}');
              return Center(
                child: Text('Error loading favorite drills: ${snapshot.error}'),
              );
            }

            final favoriteDrills = snapshot.data ?? [];
            print('🔍 Favorite drills fetched: ${favoriteDrills.length} drills (filtered)');
            
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
            'Admin drills are premium content created by professional coaches.\nThey will appear here once admins create them.',
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
    print('🔷 Spark ⭐ Toggling favorite for drill: ${drill.id}');
    try {
      // Get current favorite status from repository (not from drill.favorite)
      final currentlyFavorite = await _drillRepository.isFavorite(drill.id);
      print('🔷 Spark 📊 Current favorite status: $currentlyFavorite');
      
      await _drillRepository.toggleFavorite(drill.id);
      print('🔷 Spark ✅ Successfully toggled favorite for drill: ${drill.id}');
      
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                currentlyFavorite ? Icons.favorite_border : Icons.favorite,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(currentlyFavorite
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
      print('🔷 Spark ❌ Error toggling favorite for drill: ${drill.id}, error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update favorite: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
int _getActiveFilterCount() {
    int count = 0;
    if (_selectedCategory.isNotEmpty) count++;
    if (_selectedDifficulty != null) count++;
    return count;
  }

  String _getDifficultyDisplayName(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return 'Beginner';
      case Difficulty.intermediate:
        return 'Intermediate';
      case Difficulty.advanced:
        return 'Advanced';
    }
  }

  Widget _buildFilterButton(ColorScheme colorScheme) {
    final filterCount = _getActiveFilterCount();
    
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showComprehensiveFilterBottomSheet(),
          tooltip: 'Filter drills',
        ),
        if (filterCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                '$filterCount',
                style: TextStyle(
                  color: colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _showComprehensiveFilterBottomSheet() {
    HapticFeedback.lightImpact();
    
    // Capture the parent context to access the BLoC
    final parentContext = context;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (builderContext, setModalState) {
          final theme = Theme.of(builderContext);
          final colorScheme = theme.colorScheme;
          
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Filter Drills',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = '';
                            _selectedDifficulty = null;
                          });
                          setModalState(() {});
                          parentContext.read<DrillLibraryBloc>().add(
                            const DrillLibraryFiltersChanged(
                              category: '',
                              difficulty: null,
                              searchQuery: '',
                            ),
                          );
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // Category Filter Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          // All Categories chip
                          FilterChip(
                            label: const Text('All Categories'),
                            selected: _selectedCategory.isEmpty,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = '';
                              });
                              setModalState(() {});
                              parentContext.read<DrillLibraryBloc>().add(
                                DrillLibraryFiltersChanged(
                                  category: '',
                                  difficulty: _selectedDifficulty,
                                  searchQuery: _searchController.text,
                                ),
                              );
                            },
                            selectedColor: colorScheme.primaryContainer,
                            checkmarkColor: colorScheme.onPrimaryContainer,
                          ),
                          // Dynamic category chips
                          ..._availableCategories.map((category) {
                            final isSelected = _selectedCategory == category.name;
                            return FilterChip(
                              label: Text(category.displayName),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = selected ? category.name : '';
                                });
                                setModalState(() {});
                                parentContext.read<DrillLibraryBloc>().add(
                                  DrillLibraryFiltersChanged(
                                    category: selected ? category.name : '',
                                    difficulty: _selectedDifficulty,
                                    searchQuery: _searchController.text,
                                  ),
                                );
                              },
                              avatar: isSelected ? null : Icon(
                                _getCategoryIcon(category.name),
                                size: 18,
                              ),
                              selectedColor: colorScheme.primaryContainer,
                              checkmarkColor: colorScheme.onPrimaryContainer,
                            );
                          }).toList(),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Difficulty Filter Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Difficulty Level',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // All Difficulties chip
                          FilterChip(
                            label: const Text('All Levels'),
                            selected: _selectedDifficulty == null,
                            onSelected: (selected) {
                              setState(() {
                                _selectedDifficulty = null;
                              });
                              setModalState(() {});
                              parentContext.read<DrillLibraryBloc>().add(
                                DrillLibraryFiltersChanged(
                                  category: _selectedCategory,
                                  difficulty: null,
                                  searchQuery: _searchController.text,
                                ),
                              );
                            },
                            selectedColor: colorScheme.primaryContainer,
                            checkmarkColor: colorScheme.onPrimaryContainer,
                          ),
                          // Difficulty level chips
                          ...Difficulty.values.map((difficulty) {
                            final isSelected = _selectedDifficulty == difficulty;
                            return FilterChip(
                              label: Text(_getDifficultyDisplayName(difficulty)),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedDifficulty = selected ? difficulty : null;
                                });
                                setModalState(() {});
                                parentContext.read<DrillLibraryBloc>().add(
                                  DrillLibraryFiltersChanged(
                                    category: _selectedCategory,
                                    difficulty: selected ? difficulty : null,
                                    searchQuery: _searchController.text,
                                  ),
                                );
                              },
                              avatar: isSelected ? null : Icon(
                                _getDifficultyIcon(difficulty),
                                size: 18,
                              ),
                              selectedColor: _getDifficultyColor(difficulty).withOpacity(0.2),
                              checkmarkColor: _getDifficultyColor(difficulty),
                            );
                          }).toList(),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Apply Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
        return Icons.fitness_center;
      case 'shooting':
        return Icons.sports_basketball;
      case 'passing':
        return Icons.swap_horiz;
      case 'dribbling':
        return Icons.sports_soccer;
      case 'defense':
        return Icons.shield;
      case 'agility':
        return Icons.directions_run;
      default:
        return Icons.sports;
    }
  }

  IconData _getDifficultyIcon(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return Icons.person;
      case Difficulty.intermediate:
        return Icons.trending_up;
      case Difficulty.advanced:
        return Icons.workspace_premium;
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
