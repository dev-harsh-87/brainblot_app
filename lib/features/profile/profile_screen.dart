import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/auth/bloc/auth_bloc.dart';
import 'package:spark_app/features/settings/bloc/settings_bloc.dart';
import 'package:spark_app/core/auth/services/session_management_service.dart';
import 'package:spark_app/features/settings/data/settings_repository.dart';
import 'package:spark_app/features/stats/bloc/stats_bloc.dart';
import 'package:spark_app/features/drills/domain/session_result.dart';
import 'package:spark_app/features/profile/services/profile_service.dart';
import 'package:spark_app/features/sharing/domain/user_profile.dart';
import 'package:spark_app/features/settings/ui/settings_screen.dart';
import 'package:spark_app/features/auth/ui/device_sessions_screen.dart';
import 'package:spark_app/core/ui/edge_to_edge.dart';
import 'package:spark_app/core/services/auto_refresh_service.dart';
import 'package:spark_app/core/utils/app_logger.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutoRefreshMixin {
  late final ProfileService _profileService;
  UserProfile? _userProfile;
  Map<String, dynamic> _userStats = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profileService = getIt<ProfileService>();
    
    // Add a small delay to ensure auth state is fully settled
    Future.delayed(const Duration(milliseconds: 300), _loadUserData);
    
    // Setup auto-refresh listeners
    listenToMultipleAutoRefresh({
      AutoRefreshService.profile: _loadUserData,
      AutoRefreshService.stats: _loadUserData,
      AutoRefreshService.sessions: _loadUserData,
    });
  }

  Future<void> _loadUserData() async {
    // Check if user is authenticated before loading
    if (_profileService.currentUserId == null) {
      AppLogger.warning('Cannot load profile data - user not authenticated', tag: 'ProfileScreen');
      setState(() {
        _isLoading = false;
        _error = 'User not authenticated';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _profileService.getCurrentUserProfile();
      final stats = await _profileService.getUserStats();
      
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _userStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load profile data', error: e, tag: 'ProfileScreen');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: _isLoading
              ? _buildLoadingState(context)
              : _error != null
                  ? _buildErrorState(context)
                  : _buildProfileContent(context),
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
        'Profile',
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
        IconButton(
          icon: Icon(
            Icons.edit_rounded,
            color: colorScheme.onPrimary,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            _showEditProfileDialog();
          },
          tooltip: 'Edit Profile',
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            color: colorScheme.onPrimary,
          ),
          onSelected: (value) {
            switch (value) {
              case 'settings':
                context.go('/settings');
                break;
              case 'device_sessions':
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DeviceSessionsScreen(),
                  ),
                );
                break;
              case 'change_password':
                _showChangePasswordDialog();
                break;
              case 'delete_account':
                _showDeleteAccountDialog();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings_rounded),
                title: Text('Settings'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'device_sessions',
              child: ListTile(
                leading: Icon(Icons.devices),
                title: Text('Device Sessions'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'change_password',
              child: ListTile(
                leading: Icon(Icons.lock_rounded),
                title: Text('Change Password'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete_account',
              child: ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: Text('Delete Account', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
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
                    'Loading profile...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Getting your account information',
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

  Widget _buildErrorState(BuildContext context) {
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
              'Failed to load profile',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error occurred',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _loadUserData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context) {
    return BlocBuilder<StatsBloc, StatsState>(
      builder: (context, statsState) {
        final sessions = statsState.sessions;
        
        return Column(
          children: [
            _buildEnhancedProfileHeader(context),
            const SizedBox(height: 24),
            _buildModernUserInfoSection(context),
            const SizedBox(height: 24),
            _buildModernStatsOverview(context, sessions),
            const SizedBox(height: 24),
            _buildModernAchievements(context, sessions),
            const SizedBox(height: 24),
            _buildModernRecentActivity(context, sessions),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildEnhancedProfileHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = _userProfile;
    
    if (profile == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withOpacity(0.8),
            colorScheme.secondaryContainer.withOpacity(0.6),
            colorScheme.tertiaryContainer.withOpacity(0.4),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Compact Profile Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.transparent,
                  child: Text(
                    _profileService.getUserInitials(profile.displayName),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Profile Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.withOpacity(0.15), Colors.blue.withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Active User',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  Widget _buildModernUserInfoSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = _userProfile;
    
    if (profile == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.15),
                      colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Account Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Compact Horizontal Layout
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // First Row - Member Since & Last Active
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnhancedInfoItem(
                          context,
                          'Member Since',
                          DateFormat('MMM dd, yyyy').format(profile.createdAt),
                          Icons.calendar_today_rounded,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildEnhancedInfoItem(
                          context,
                          'Last Active',
                          DateFormat('MMM dd, yyyy').format(profile.lastActiveAt),
                          Icons.access_time_rounded,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Second Row - Sessions & Drills & Programs
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnhancedInfoItem(
                          context,
                          'Sessions',
                          '${_userStats['totalSessions'] ?? 0}',
                          Icons.fitness_center_rounded,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildEnhancedInfoItem(
                          context,
                          'Drills',
                          '${_userStats['totalDrills'] ?? 0}',
                          Icons.psychology_rounded,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildEnhancedInfoItem(
                          context,
                          'Programs',
                          '${_userStats['totalPrograms'] ?? 0}',
                          Icons.schedule_rounded,
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                iconColor.withOpacity(0.15),
                iconColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: iconColor.withOpacity(0.2),
            ),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedInfoItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            iconColor.withOpacity(0.08),
            iconColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  iconColor.withOpacity(0.2),
                  iconColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: iconColor.withOpacity(0.3),
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatsOverview(BuildContext context, List<SessionResult> sessions) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (sessions.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_rounded,
                size: 24,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Training Data Yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete your first session to see analytics',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/drills');
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text('Start'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 32),
              ),
            ),
          ],
        ),
      );
    }

    final avgReaction = sessions.map((s) => s.avgReactionMs).reduce((a, b) => a + b) / sessions.length;
    final avgAccuracy = sessions.map((s) => s.accuracy).reduce((a, b) => a + b) / sessions.length;
    final totalTime = sessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.endedAt.difference(session.startedAt),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.15),
                      colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Performance',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Compact Horizontal Layout
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildCompactStatItem(
                      context,
                      'Reaction',
                      '${avgReaction.toStringAsFixed(0)}ms',
                      Icons.timer_rounded,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCompactStatItem(
                      context,
                      'Accuracy',
                      '${(avgAccuracy * 100).toStringAsFixed(0)}%',
                      Icons.gps_fixed_rounded,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCompactStatItem(
                      context,
                      'Time',
                      _formatDuration(totalTime),
                      Icons.schedule_rounded,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCompactStatItem(
                      context,
                      'Best',
                      sessions.isNotEmpty ? '${(sessions.map((s) => s.accuracy).reduce((a, b) => a > b ? a : b) * 100).toStringAsFixed(0)}%' : '-',
                      Icons.emoji_events_rounded,
                      Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.2),
            ),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildModernAchievements(BuildContext context, List<SessionResult> sessions) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    try {
      final achievements = _calculateAchievements(sessions);
      
      if (achievements.isEmpty) {
        return const SizedBox.shrink();
      }
      
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.withOpacity(0.15),
                        Colors.amber.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Achievements',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 115,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < achievements.length - 1 ? 10 : 0,
                    ),
                    child: _buildCompactAchievementCard(context, achievements[index]),
                  );
                },
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildCompactAchievementCard(BuildContext context, Map<String, dynamic> achievement) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    try {
      final isUnlocked = (achievement['unlocked'] ?? false) as bool;
      final title = (achievement['title'] ?? 'Achievement') as String;
      final icon = (achievement['icon'] ?? Icons.star_rounded) as IconData;
      
      return Container(
        width: 105,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: isUnlocked 
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber.withOpacity(0.15),
                    Colors.amber.withOpacity(0.05),
                  ],
                )
              : null,
          color: isUnlocked ? null : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnlocked ? Colors.amber.withOpacity(0.3) : colorScheme.outline.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isUnlocked ? [
            BoxShadow(
              color: Colors.amber.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: isUnlocked
                    ? LinearGradient(
                        colors: [
                          Colors.amber.withOpacity(0.3),
                          Colors.amber.withOpacity(0.1),
                        ],
                      )
                    : null,
                color: isUnlocked ? null : colorScheme.outline.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isUnlocked ? Colors.amber.shade700 : colorScheme.onSurface.withOpacity(0.5),
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isUnlocked ? Colors.amber.shade700 : colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (achievement['description'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      achievement['description'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isUnlocked ? Colors.amber.shade600 : colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 9,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildModernRecentActivity(BuildContext context, List<SessionResult> sessions) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recentSessions = sessions.take(3).toList();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.secondary.withOpacity(0.15),
                      colorScheme.secondary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.secondary.withOpacity(0.2),
                  ),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: colorScheme.secondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Recent Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: recentSessions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Recent Activity',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Complete sessions to see activity',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: recentSessions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final session = entry.value;
                      return Column(
                        children: [
                          _buildCompactActivityItem(context, session),
                          if (index < recentSessions.length - 1)
                            Divider(
                              height: 1,
                              color: colorScheme.outline.withOpacity(0.1),
                              indent: 16,
                              endIndent: 16,
                            ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActivityItem(BuildContext context, SessionResult session) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.15),
                  colorScheme.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              color: colorScheme.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.drill.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM dd, yyyy').format(session.startedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.15),
                      Colors.blue.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '${session.avgReactionMs.toStringAsFixed(0)}ms',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.15),
                      Colors.green.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '${(session.accuracy * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper Methods
  List<Map<String, dynamic>> _calculateAchievements(List<SessionResult> sessions) {
    try {
      final totalSessions = sessions.length;
      
      double avgAccuracy = 0.0;
      double avgReaction = 0.0;
      
      if (sessions.isNotEmpty) {
        try {
          avgAccuracy = sessions.map((s) => s.accuracy).reduce((a, b) => a + b) / sessions.length;
          avgReaction = sessions.map((s) => s.avgReactionMs).reduce((a, b) => a + b) / sessions.length;
        } catch (e) {
          avgAccuracy = 0.0;
          avgReaction = 0.0;
        }
      }

      return [
        {
          'title': 'First Steps',
          'description': 'Complete first session',
          'icon': Icons.play_arrow_rounded,
          'unlocked': totalSessions >= 1,
        },
        {
          'title': 'Consistent',
          'description': '10 sessions completed',
          'icon': Icons.schedule_rounded,
          'unlocked': totalSessions >= 10,
        },
        {
          'title': 'Dedicated',
          'description': '50 sessions completed',
          'icon': Icons.fitness_center_rounded,
          'unlocked': totalSessions >= 50,
        },
        {
          'title': 'Sharp Shooter',
          'description': '90%+ accuracy',
          'icon': Icons.gps_fixed_rounded,
          'unlocked': avgAccuracy >= 0.9,
        },
        {
          'title': 'Lightning Fast',
          'description': 'Sub-300ms reaction',
          'icon': Icons.flash_on_rounded,
          'unlocked': avgReaction < 300 && avgReaction > 0,
        },
      ];
    } catch (e) {
      return [];
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  // Dialog Methods (keeping original simple versions)
  void _showEditProfileDialog() {
    final profile = _userProfile;
    if (profile == null) return;

    final displayNameController = TextEditingController(text: profile.displayName);
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Edit Profile'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Display name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Display name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setState(() => isLoading = true);
                  
                  try {
                    await _profileService.updateProfile(
                      displayName: displayNameController.text.trim(),
                    );
                    
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Profile updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadUserData();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Failed to update profile: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => isLoading = false);
                  }
                }
              },
              child: isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Change Password'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrentPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => obscureCurrentPassword = !obscureCurrentPassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Current password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => obscureNewPassword = !obscureNewPassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'New password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (value != newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setState(() => isLoading = true);
                  
                  try {
                    await _profileService.updatePassword(
                      currentPasswordController.text,
                      newPasswordController.text,
                    );
                    
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Password updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Failed to update password: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => isLoading = false);
                  }
                }
              },
              child: isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              const Text('Delete Account', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      Text(
                        'This action cannot be undone!',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Deleting your account will permanently remove:\n'
                        '• Your profile and account data\n'
                        '• All your created drills and programs\n'
                        '• Your training sessions and statistics\n'
                        '• All sharing permissions and invitations',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Enter your password to confirm:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required to delete account';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setState(() => isLoading = true);
                  
                  try {
                    await _profileService.deleteProfile();
                    
                    if (mounted) {
                      Navigator.of(context).pop();
                      // Navigate to auth screen and clear all routes
                      context.read<AuthBloc>().add(const AuthLogoutRequested());
                      context.go('/auth');
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Account deleted successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Failed to delete account: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => isLoading = false);
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Delete Account', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
