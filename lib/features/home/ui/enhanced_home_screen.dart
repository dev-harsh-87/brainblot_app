import 'package:brainblot_app/features/auth/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/core/services/auto_refresh_service.dart';
import 'package:brainblot_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:brainblot_app/features/programs/bloc/programs_bloc.dart';
import 'package:brainblot_app/features/profile/services/profile_service.dart';
import 'package:brainblot_app/features/sharing/domain/user_profile.dart';

/// Enhanced home screen with comprehensive auto-refresh functionality
class EnhancedHomeScreen extends StatefulWidget {
  const EnhancedHomeScreen({super.key});

  @override
  State<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends State<EnhancedHomeScreen> 
    with AutoRefreshMixin, TickerProviderStateMixin {
  
  late final ProfileService _profileService;
  late final AutoRefreshService _autoRefreshService;
  late AnimationController _refreshAnimationController;
  late Animation<double> _refreshAnimation;
  
  UserProfile? _userProfile;
  Map<String, dynamic> _quickStats = {};
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _profileService = getIt<ProfileService>();
    _autoRefreshService = getIt<AutoRefreshService>();
    
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _refreshAnimation = CurvedAnimation(
      parent: _refreshAnimationController,
      curve: Curves.easeInOut,
    );
    
    _loadHomeData();
    _setupAutoRefresh();
  }

  void _setupAutoRefresh() {
    // Listen to multiple auto-refresh triggers
    listenToMultipleAutoRefresh({
      AutoRefreshService.drills: _refreshHomeData,
      AutoRefreshService.programs: _refreshHomeData,
      AutoRefreshService.sessions: _refreshHomeData,
      AutoRefreshService.stats: _refreshHomeData,
      AutoRefreshService.profile: _refreshUserProfile,
    });
  }

  Future<void> _loadHomeData() async {
    await Future.wait([
      _loadUserProfile(),
      _loadQuickStats(),
    ]);
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
      // Handle error silently for home screen
    }
  }

  Future<void> _loadQuickStats() async {
    try {
      final stats = await _profileService.getUserStats();
      if (mounted) {
        setState(() {
          _quickStats = stats;
        });
      }
    } catch (e) {
      // Handle error silently for home screen
    }
  }

  Future<void> _refreshHomeData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    _refreshAnimationController.repeat();
    
    try {
      await _loadHomeData();
      
      // Also refresh BLoCs
      if (mounted) {
        context.read<DrillLibraryBloc>().add(DrillLibraryRefreshRequested());
        context.read<ProgramsBloc>().add(ProgramsRefreshRequested());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();
      }
    }
  }

  Future<void> _refreshUserProfile() async {
    await _loadUserProfile();
  }

  @override
  void dispose() {
    _refreshAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _refreshHomeData,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildWelcomeSection(context),
                  const SizedBox(height: 24),
                  _buildQuickStats(context),
                  const SizedBox(height: 24),
                  _buildQuickActions(context),
                  const SizedBox(height: 24),
                  _buildRecentActivity(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildAutoRefreshFab(context),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          children: [
            Text(
              'BrainBlot',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            if (_isRefreshing)
              SizedBox(
                width: 16,
                height: 16,
                child: AnimatedBuilder(
                  animation: _refreshAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _refreshAnimation.value * 2 * 3.14159,
                      child: Icon(
                        Icons.refresh_rounded,
                        color: colorScheme.onPrimary,
                        size: 16,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.secondary.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(onPressed: (){
          context.read<AuthBloc>().add(const AuthLogoutRequested());
        }, icon: Icon(Icons.logout)),
        IconButton(
          onPressed: () => context.push('/multiplayer'),
          icon: Icon(
            Icons.wifi_tethering_rounded,
            color: colorScheme.onPrimary,
            size: 24,
          ),
          tooltip: 'Multiplayer Training',
        ),
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: Icon(
            Icons.settings_rounded,
            color: colorScheme.onPrimary,
            size: 24,
          ),
          tooltip: 'Settings',
        ),
        IconButton(
          onPressed: () => context.push('/profile'),
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.onPrimary,
            child: Text(
              _userProfile != null 
                  ? _profileService.getUserInitials(_userProfile!.displayName)
                  : 'U',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          tooltip: 'Profile',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.3),
            colorScheme.secondaryContainer.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back${_userProfile?.displayName.isNotEmpty == true ? ', ${_userProfile!.displayName}' : ''}!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to train your cognitive abilities?',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              'Total Sessions',
              '${_quickStats['totalSessions'] ?? 0}',
              Icons.fitness_center_rounded,
              Colors.purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              'Drills Created',
              '${_quickStats['totalDrills'] ?? 0}',
              Icons.psychology_rounded,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              'Programs',
              '${_quickStats['totalPrograms'] ?? 0}',
              Icons.schedule_rounded,
              Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
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
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  context,
                  'Create Drill',
                  'Design a new training drill',
                  Icons.add_circle_rounded,
                  Colors.blue,
                  () {
                    context.go('/drills');
                    context.triggerAutoRefresh(AutoRefreshService.drills);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  context,
                  'New Program',
                  'Start a training program',
                  Icons.playlist_add_rounded,
                  Colors.green,
                  () {
                    context.go('/programs');
                    context.triggerAutoRefresh(AutoRefreshService.programs);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  context,
                  'My Stats',
                  'View training progress',
                  Icons.analytics_rounded,
                  Colors.purple,
                  () {
                    context.push('/stats');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  context,
                  'Explore',
                  'Discover new content',
                  Icons.explore_rounded,
                  Colors.orange,
                  () {
                    // Navigate to explore/browse section
                    // This could be sharing screen or community features
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your recent activities will appear here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoRefreshFab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton(
      onPressed: () {
        HapticFeedback.mediumImpact();
        _autoRefreshService.triggerGlobalRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔄 Refreshing all data...'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      child: AnimatedBuilder(
        animation: _refreshAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _refreshAnimation.value * 2 * 3.14159,
            child: const Icon(Icons.refresh_rounded),
          );
        },
      ),
    );
  }
}
