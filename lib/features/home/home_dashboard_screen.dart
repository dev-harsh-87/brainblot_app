import 'package:brainblot_app/features/home/bloc/home_bloc.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:brainblot_app/features/auth/bloc/auth_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state.status == HomeStatus.initial) {
              return const Center(child: CircularProgressIndicator());
            }
            
            return CustomScrollView(
              slivers: [
                // Welcome Header
                SliverToBoxAdapter(
                  child: _WelcomeHeader(),
                ),
                
                // Quick Start Section
                SliverToBoxAdapter(
                  child: _QuickStartSection(recommended: state.recommended),
                ),
                
                // Stats Overview
                SliverToBoxAdapter(
                  child: _StatsOverview(recentSessions: state.recent),
                ),
                
                // Recent Activity
                SliverToBoxAdapter(
                  child: _RecentActivity(sessions: state.recent),
                ),
                
                // Navigation Grid
                SliverToBoxAdapter(
                  child: _NavigationGrid(),
                ),
                
                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Welcome Header Widget
class _WelcomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final hour = now.hour;
    final user = FirebaseAuth.instance.currentUser;
    
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }
    
    // Get user's display name or email
    String userName = 'User';
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      userName = user.displayName!.split(' ').first; // First name only
    } else if (user?.email != null) {
      userName = user!.email!.split('@').first; // Username from email
    }
    
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $userName!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.stars,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    BlocBuilder<HomeBloc, HomeState>(
                      builder: (context, state) {
                        // Calculate points from recent sessions
                        final totalPoints = _calculateUserPoints(state.recent);
                        return Text(
                          '$totalPoints Points',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: BlocBuilder<HomeBloc, HomeState>(
                        builder: (context, state) {
                          final status = _getAppStatus(state.recent);
                          return Text(
                            status,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to train your brain?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthBloc>().add(const AuthLogoutRequested());
              } else if (value == 'profile') {
                context.go('/profile');
              } else if (value == 'settings') {
                context.go('/settings');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: colorScheme.onSurface),
                    const SizedBox(width: 8),
                    const Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: colorScheme.onSurface),
                    const SizedBox(width: 8),
                    const Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: colorScheme.error)),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primary,
              backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                  ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                  : null,
              child: FirebaseAuth.instance.currentUser?.photoURL == null
                  ? Icon(
                      Icons.person,
                      color: colorScheme.onPrimary,
                      size: 28,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// Quick Start Section Widget
class _QuickStartSection extends StatelessWidget {
  final Drill? recommended;
  
  const _QuickStartSection({required this.recommended});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Start',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.play_circle_filled,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recommended?.name ?? 'No Recommendation',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (recommended != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${recommended!.category} • ${recommended!.difficulty.name}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (recommended == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Create a custom drill to get personalized recommendations',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: recommended == null 
                          ? () => context.go('/drills')
                          : () => context.go('/drill-runner', extra: recommended),
                      icon: Icon(recommended == null ? Icons.add : Icons.play_arrow),
                      label: Text(recommended == null ? 'Browse Drills' : 'Start Training'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
}

// Stats Overview Widget
class _StatsOverview extends StatelessWidget {
  final List<dynamic> recentSessions;
  
  const _StatsOverview({required this.recentSessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Calculate stats from recent sessions
    final totalSessions = recentSessions.length;
    final avgAccuracy = totalSessions > 0 
        ? recentSessions.map((s) => (s.accuracy as num).toDouble()).reduce((a, b) => a + b) / totalSessions
        : 0.0;
    final avgReactionTime = totalSessions > 0
        ? recentSessions.map((s) => (s.avgReactionMs as num).toDouble()).reduce((a, b) => a + b) / totalSessions
        : 0.0;
    
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.stars,
                  title: 'Points',
                  value: _calculateUserPoints(recentSessions).toString(),
                  subtitle: 'Total earned',
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.trending_up,
                  title: 'Sessions',
                  value: totalSessions.toString(),
                  subtitle: 'Completed',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.psychology,
                  title: 'Accuracy',
                  value: '${(avgAccuracy * 100).toStringAsFixed(0)}%',
                  subtitle: 'Average score',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.timer,
                  title: 'Reaction',
                  value: '${avgReactionTime.toStringAsFixed(0)}ms',
                  subtitle: 'Average time',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color? color;
  
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color ?? colorScheme.primary,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Recent Activity Widget
class _RecentActivity extends StatelessWidget {
  final List<dynamic> sessions;
  
  const _RecentActivity({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (sessions.isNotEmpty)
                TextButton(
                  onPressed: () => context.go('/stats'),
                  child: const Text('View All'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No sessions yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Start your first drill to see activity here',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...sessions.take(3).map((session) => _ActivityItem(session: session)),
        ],
      ),
    );
  }
}

// Activity Item Widget
class _ActivityItem extends StatelessWidget {
  final dynamic session;
  
  const _ActivityItem({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.psychology,
            color: colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          session.drill.name.toString(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Accuracy: ${((session.accuracy as num).toDouble() * 100).toStringAsFixed(0)}% • Avg RT: ${(session.avgReactionMs as num).toDouble().toStringAsFixed(0)}ms',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }
}

// Navigation Grid Widget
class _NavigationGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _NavTile(
                label: 'Drill Library',
                icon: Icons.library_books,
                onTap: () => context.go('/drills'),
              ),
              _NavTile(
                label: 'Programs',
                icon: Icons.calendar_today,
                onTap: () => context.go('/programs'),
              ),
              _NavTile(
                label: 'Statistics',
                icon: Icons.insights,
                onTap: () => context.go('/stats'),
              ),
              _NavTile(
                label: 'Profile',
                icon: Icons.person,
                onTap: () => context.go('/profile'),
              ),
              _NavTile(
                label: 'Settings',
                icon: Icons.settings,
                onTap: () => context.go('/settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Updated Navigation Tile Widget
class _NavTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  
  const _NavTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper functions for points calculation and app status
int _calculateUserPoints(List<dynamic> sessions) {
  if (sessions.isEmpty) return 0;
  
  int totalPoints = 0;
  for (final session in sessions) {
    // Points calculation based on performance
    // Base points for completion
    int sessionPoints = 10;
    
    // Bonus points for accuracy (0-50 points based on accuracy percentage)
    final accuracy = (session.accuracy as num).toDouble();
    sessionPoints += (accuracy * 50).round();
    
    // Bonus points for reaction time (faster = more points)
    final reactionTime = (session.avgReactionMs as num).toDouble();
    if (reactionTime < 300) {
      sessionPoints += 20; // Very fast
    } else if (reactionTime < 500) {
      sessionPoints += 15; // Fast
    } else if (reactionTime < 700) {
      sessionPoints += 10; // Average
    } else if (reactionTime < 1000) {
      sessionPoints += 5; // Slow
    }
    // No bonus for very slow (>1000ms)
    
    totalPoints += sessionPoints;
  }
  
  return totalPoints;
}

String _getAppStatus(List<dynamic> sessions) {
  if (sessions.isEmpty) {
    return 'Getting Started';
  }
  
  final totalSessions = sessions.length;
  final avgAccuracy = sessions.map((s) => (s.accuracy as num).toDouble()).reduce((a, b) => a + b) / totalSessions;
  final avgReactionTime = sessions.map((s) => (s.avgReactionMs as num).toDouble()).reduce((a, b) => a + b) / totalSessions;
  
  // Determine status based on performance metrics
  if (totalSessions >= 10 && avgAccuracy >= 0.8 && avgReactionTime <= 500.0) {
    return 'Expert Level';
  } else if (totalSessions >= 5 && avgAccuracy >= 0.7 && avgReactionTime <= 700.0) {
    return 'Advanced';
  } else if (totalSessions >= 3 && avgAccuracy >= 0.6) {
    return 'Improving';
  } else if (totalSessions >= 1) {
    return 'Beginner';
  } else {
    return 'New User';
  }
}
