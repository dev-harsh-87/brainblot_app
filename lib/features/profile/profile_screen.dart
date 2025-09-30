import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/settings/bloc/settings_bloc.dart';
import 'package:brainblot_app/features/stats/bloc/stats_bloc.dart';
import 'package:brainblot_app/features/team/bloc/team_bloc.dart';
import 'package:brainblot_app/features/team/domain/team.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _sportController = TextEditingController();
  final _goalsController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isEditing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _sportController.dispose();
    _goalsController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, settingsState) {
                return BlocBuilder<StatsBloc, StatsState>(
                  builder: (context, statsState) {
                    return BlocBuilder<TeamBloc, TeamState>(
                      builder: (context, teamState) {
                        if (settingsState.status == SettingsStatus.loading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final settings = settingsState.settings;
                        final sessions = statsState.sessions;
                        final team = teamState.team;

                        if (settings != null && !_isEditing) {
                          _nameController.text = settings.name;
                          _sportController.text = settings.sport;
                          _goalsController.text = settings.goals;
                        }

                        return Column(
                          children: [
                            _buildProfileHeader(settings, sessions),
                            const SizedBox(height: 24),
                            _buildStatsOverview(sessions),
                            const SizedBox(height: 24),
                            if (teamState.isInTeam && team != null) ...[
                              _buildTeamSection(team),
                              const SizedBox(height: 24),
                            ],
                            _buildProfileDetails(settings),
                            const SizedBox(height: 24),
                            _buildAchievements(sessions),
                            const SizedBox(height: 24),
                            _buildRecentActivity(sessions),
                            const SizedBox(height: 32),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isEditing ? Icons.check : Icons.edit,
            color: Colors.white,
          ),
          onPressed: () {
            if (_isEditing) {
              _saveProfile();
            }
            setState(() => _isEditing = !_isEditing);
          },
        ),
      ],
    );
  }

  Widget _buildProfileHeader(dynamic settings, List<dynamic> sessions) {
    final name = settings?.name ?? 'Athlete';
    final sport = settings?.sport ?? 'Training';
    final totalSessions = sessions.length;
    final avgAccuracy = sessions.isEmpty 
        ? 0.0 
        : sessions.map((s) => s.accuracy as num).reduce((a, b) => a + b) / sessions.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Profile Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  (name as String).isNotEmpty ? (name as String)[0].toUpperCase() : 'A',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (avgAccuracy > 0.8)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Name and Sport
          Text(
            name as String,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sport as String,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          
          // Quick Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickStat('Sessions', '$totalSessions', Icons.fitness_center),
              _buildQuickStat(
                'Accuracy', 
                '${(avgAccuracy * 100).toStringAsFixed(1)}%', 
                Icons.gps_fixed
              ),
              _buildQuickStat(
                'Level', 
                _calculateLevel(totalSessions), 
                Icons.trending_up
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsOverview(List<dynamic> sessions) {
    if (sessions.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No Training Data Yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete some training sessions to see your performance overview',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final avgReaction = sessions.map((s) => s.avgReactionMs as num).reduce((a, b) => a + b) / sessions.length;
    final avgAccuracy = sessions.map((s) => s.accuracy as num).reduce((a, b) => a + b) / sessions.length;
    final totalTime = sessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + (session.endedAt as DateTime).difference(session.startedAt as DateTime),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Avg Reaction',
                  '${avgReaction.toStringAsFixed(0)}ms',
                  Icons.timer,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Accuracy',
                  '${(avgAccuracy * 100).toStringAsFixed(1)}%',
                  Icons.gps_fixed,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Time',
                  _formatDuration(totalTime),
                  Icons.schedule,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Sessions',
                  '${sessions.length}',
                  Icons.fitness_center,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails(dynamic settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfileField(
                    'Name',
                    _nameController,
                    Icons.person,
                    'Enter your name',
                  ),
                  const SizedBox(height: 16),
                  _buildProfileField(
                    'Sport Focus',
                    _sportController,
                    Icons.sports_soccer,
                    'What sport do you train for?',
                  ),
                  const SizedBox(height: 16),
                  _buildProfileField(
                    'Goals',
                    _goalsController,
                    Icons.flag,
                    'What are your training goals?',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(
    String label,
    TextEditingController controller,
    IconData icon,
    String hint, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: _isEditing,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: !_isEditing,
            fillColor: _isEditing ? null : Colors.grey[50],
          ),
          onChanged: (_) {
            if (_isEditing) {
              _saveProfile();
            }
          },
        ),
      ],
    );
  }

  Widget _buildAchievements(List<dynamic> sessions) {
    final achievements = _calculateAchievements(sessions);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Achievements',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: achievements.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) => _buildAchievementCard(achievements[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement) {
    final isUnlocked = (achievement['unlocked'] ?? false) as bool;
    
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.amber[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked ? Colors.amber : Colors.grey[300]!,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            achievement['icon'] as IconData,
            color: isUnlocked ? Colors.amber[700] : Colors.grey[400],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            achievement['title'] as String,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? Colors.amber[700] : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            achievement['description'] as String,
            style: TextStyle(
              fontSize: 10,
              color: isUnlocked ? Colors.amber[600] : Colors.grey[400],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<dynamic> sessions) {
    final recentSessions = sessions.take(5).toList();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: recentSessions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Recent Activity',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Start training to see your activity here',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: recentSessions
                        .map((session) => _buildActivityItem(session))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(dynamic session) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Icon(
          Icons.fitness_center,
          color: Theme.of(context).primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        session.drill.name as String,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        DateFormat('MMM dd, yyyy • HH:mm').format(session.startedAt as DateTime),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${(session.avgReactionMs as num).toStringAsFixed(0)}ms',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            '${((session.accuracy as num) * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateLevel(int totalSessions) {
    if (totalSessions >= 100) return 'Expert';
    if (totalSessions >= 50) return 'Advanced';
    if (totalSessions >= 20) return 'Intermediate';
    if (totalSessions >= 5) return 'Beginner';
    return 'Rookie';
  }

  List<Map<String, dynamic>> _calculateAchievements(List<dynamic> sessions) {
    final totalSessions = sessions.length;
    final avgAccuracy = sessions.isEmpty 
        ? 0.0 
        : sessions.map((s) => s.accuracy as num).reduce((a, b) => a + b) / sessions.length;
    final avgReaction = sessions.isEmpty 
        ? 0.0 
        : sessions.map((s) => s.avgReactionMs as num).reduce((a, b) => a + b) / sessions.length;

    return [
      {
        'title': 'First Steps',
        'description': 'Complete first session',
        'icon': Icons.play_arrow,
        'unlocked': totalSessions >= 1,
      },
      {
        'title': 'Consistent',
        'description': '10 sessions completed',
        'icon': Icons.schedule,
        'unlocked': totalSessions >= 10,
      },
      {
        'title': 'Dedicated',
        'description': '50 sessions completed',
        'icon': Icons.fitness_center,
        'unlocked': totalSessions >= 50,
      },
      {
        'title': 'Sharp Shooter',
        'description': '90%+ accuracy',
        'icon': Icons.gps_fixed,
        'unlocked': avgAccuracy >= 0.9,
      },
      {
        'title': 'Lightning Fast',
        'description': 'Sub-300ms reaction',
        'icon': Icons.flash_on,
        'unlocked': avgReaction < 300 && avgReaction > 0,
      },
    ];
  }

  Widget _buildTeamSection(Team team) {
    final currentUser = team.members.firstWhere(
      (member) => member.id == 'current_user',
      orElse: () => team.members.first,
    );
    
    final sortedMembers = List<TeamMember>.from(team.members)
      ..sort((a, b) => a.avgRtMs.compareTo(b.avgRtMs));
    
    final userRank = sortedMembers.indexWhere((m) => m.id == currentUser.id) + 1;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.groups,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Team Performance',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${team.members.length} members',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRankColor(userRank),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '#$userRank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTeamStatCard(
                  'Your Avg RT',
                  '${currentUser.avgRtMs.toStringAsFixed(0)}ms',
                  Icons.timer,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTeamStatCard(
                  'Your Accuracy',
                  '${(currentUser.acc * 100).toStringAsFixed(1)}%',
                  Icons.gps_fixed,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Team Leaderboard',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to team screen using GoRouter
                  context.go('/team');
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...sortedMembers.take(3).map((member) {
            final rank = sortedMembers.indexOf(member) + 1;
            final isCurrentUser = member.id == currentUser.id;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrentUser 
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: isCurrentUser 
                  ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3))
                  : null,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _getRankColor(rank),
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              member.name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'You',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${member.avgRtMs.toStringAsFixed(0)}ms • ${(member.acc * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (rank <= 3)
                    Icon(
                      Icons.emoji_events,
                      color: _getRankColor(rank),
                      size: 20,
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTeamStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  void _saveProfile() {
    context.read<SettingsBloc>().add(SettingsProfileChanged(
      name: _nameController.text.trim(),
      sport: _sportController.text.trim(),
      goals: _goalsController.text.trim(),
    ));
  }
}
