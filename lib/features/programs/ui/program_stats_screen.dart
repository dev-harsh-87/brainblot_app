import 'package:flutter/material.dart';
import 'package:brainblot_app/features/programs/services/program_progress_service.dart';
import 'package:brainblot_app/core/di/injection.dart';

class ProgramStatsScreen extends StatefulWidget {
  const ProgramStatsScreen({super.key});

  @override
  State<ProgramStatsScreen> createState() => _ProgramStatsScreenState();
}

class _ProgramStatsScreenState extends State<ProgramStatsScreen> {
  late final ProgramProgressService _progressService;
  ProgramStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _progressService = getIt<ProgramProgressService>();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      final stats = await _progressService.getProgramStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stats: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Statistics'),
        actions: [
          IconButton(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? const Center(child: Text('No statistics available'))
              : _buildStatsContent(),
    );
  }

  Widget _buildStatsContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Cards
          Text(
            'Overview',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Programs Started',
                  '${_stats!.totalProgramsStarted}',
                  Icons.play_circle_outline,
                  colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Programs Completed',
                  '${_stats!.totalProgramsCompleted}',
                  Icons.check_circle,
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
                  'Days Completed',
                  '${_stats!.totalDaysCompleted}',
                  Icons.calendar_today,
                  colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Completion Rate',
                  '${_stats!.completionRate.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  _stats!.completionRate >= 70 ? Colors.green : 
                  _stats!.completionRate >= 40 ? Colors.orange : Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Streaks Section
          Text(
            'Activity Streaks',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.orange, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  '${_stats!.currentStreak}',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Current Streak',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_stats!.currentStreak} ${_stats!.currentStreak == 1 ? 'day' : 'days'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 80,
                        color: colorScheme.outline.withOpacity(0.3),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.amber, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  '${_stats!.longestStreak}',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Longest Streak',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_stats!.longestStreak} ${_stats!.longestStreak == 1 ? 'day' : 'days'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Achievements Section
          Text(
            'Achievements',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          ..._buildAchievements(),

          const SizedBox(height: 32),

          // Motivational Section
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        color: colorScheme.onPrimaryContainer,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Keep Going!',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getMotivationalMessage(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.8),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAchievements() {
    final achievements = <Map<String, Object>>[];

    // First Program Achievement
    if (_stats!.totalProgramsStarted >= 1) {
      achievements.add({
        'title': 'First Steps',
        'description': 'Started your first program',
        'icon': Icons.rocket_launch,
        'color': Colors.blue,
        'unlocked': true,
      });
    }

    // First Completion Achievement
    if (_stats!.totalProgramsCompleted >= 1) {
      achievements.add({
        'title': 'Finisher',
        'description': 'Completed your first program',
        'icon': Icons.emoji_events,
        'color': Colors.amber,
        'unlocked': true,
      });
    }

    // Consistency Achievement
    if (_stats!.currentStreak >= 7) {
      achievements.add({
        'title': 'Consistent',
        'description': 'Maintained a 7-day streak',
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
        'unlocked': true,
      });
    }

    // Dedication Achievement
    if (_stats!.totalDaysCompleted >= 30) {
      achievements.add({
        'title': 'Dedicated',
        'description': 'Completed 30+ program days',
        'icon': Icons.star,
        'color': Colors.purple,
        'unlocked': true,
      });
    }

    // Champion Achievement
    if (_stats!.totalProgramsCompleted >= 5) {
      achievements.add({
        'title': 'Champion',
        'description': 'Completed 5+ programs',
        'icon': Icons.military_tech,
        'color': Colors.amber,
        'unlocked': true,
      });
    }

    // Add locked achievements
    if (_stats!.currentStreak < 7) {
      achievements.add({
        'title': 'Consistent',
        'description': 'Maintain a 7-day streak',
        'icon': Icons.local_fire_department,
        'color': Colors.grey,
        'unlocked': false,
      });
    }

    if (_stats!.totalDaysCompleted < 30) {
      achievements.add({
        'title': 'Dedicated',
        'description': 'Complete 30 program days',
        'icon': Icons.star,
        'color': Colors.grey,
        'unlocked': false,
      });
    }

    if (_stats!.totalProgramsCompleted < 5) {
      achievements.add({
        'title': 'Champion',
        'description': 'Complete 5 programs',
        'icon': Icons.military_tech,
        'color': Colors.grey,
        'unlocked': false,
      });
    }

    return achievements.map((achievement) => Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (achievement['color'] as Color).withOpacity((achievement['unlocked'] as bool) ? 0.1 : 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            achievement['icon'] as IconData,
            color: achievement['color'] as Color,
            size: 24,
          ),
        ),
        title: Text(
          achievement['title'] as String,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: (achievement['unlocked'] as bool) ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          achievement['description'] as String,
          style: TextStyle(
            color: (achievement['unlocked'] as bool) ? null : Colors.grey,
          ),
        ),
        trailing: (achievement['unlocked'] as bool)
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.lock, color: Colors.grey),
      ),
    )).toList();
  }

  String _getMotivationalMessage() {
    if (_stats!.totalProgramsCompleted == 0) {
      return 'You\'re on your journey! Complete your first program to unlock achievements and build momentum.';
    } else if (_stats!.completionRate >= 80) {
      return 'Outstanding dedication! You\'re crushing your goals with an ${_stats!.completionRate.toStringAsFixed(0)}% completion rate.';
    } else if (_stats!.completionRate >= 60) {
      return 'Great progress! You\'re building strong habits with a ${_stats!.completionRate.toStringAsFixed(0)}% completion rate.';
    } else if (_stats!.currentStreak >= 7) {
      return 'Fantastic streak! ${_stats!.currentStreak} days of consistency is building real momentum.';
    } else if (_stats!.totalDaysCompleted >= 10) {
      return 'You\'re making progress! ${_stats!.totalDaysCompleted} days completed shows real commitment.';
    } else {
      return 'Every day counts! Keep building your routine one program day at a time.';
    }
  }
}
