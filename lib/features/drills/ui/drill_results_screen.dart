import 'package:spark_app/features/drills/domain/session_result.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math' as math;

class DrillResultsScreen extends StatefulWidget {
  final SessionResult result;
  const DrillResultsScreen({super.key, required this.result});

  @override
  State<DrillResultsScreen> createState() => _DrillResultsScreenState();
}

class _DrillResultsScreenState extends State<DrillResultsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _chartAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));
    
    _chartAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _chartAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _chartAnimationController.forward();
    });
    
    // Haptic feedback for completion
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _chartAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final drill = widget.result.drill;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Session Complete!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getPerformanceColor(widget.result.accuracy).withOpacity(0.8),
                      _getPerformanceColor(widget.result.accuracy).withOpacity(0.4),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getPerformanceIcon(widget.result.accuracy),
                                  size: 60,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _getPerformanceMessage(widget.result.accuracy),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drill Info
                          _buildDrillInfoCard(),
                          const SizedBox(height: 20),
                          
                          // Performance Overview
                          _buildPerformanceOverview(),
                          const SizedBox(height: 20),
                          
                          // Detailed Statistics
                          _buildDetailedStats(),
                          const SizedBox(height: 20),
                          
                          // Performance Breakdown
                          _buildPerformanceBreakdown(),
                          const SizedBox(height: 32),
                          
                          // Action Buttons
                          _buildActionButtons(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrillInfoCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final drill = widget.result.drill;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(drill.category),
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drill.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(drill.difficulty).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        drill.difficulty.name.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getDifficultyColor(drill.difficulty),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      drill.category.toUpperCase(),
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
    );
  }

  Widget _buildPerformanceOverview() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Overview',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Accuracy',
                '${(widget.result.accuracy * 100).toStringAsFixed(1)}%',
                Icons.gps_fixed,
                _getPerformanceColor(widget.result.accuracy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Avg Reaction',
                '${widget.result.avgReactionMs.toStringAsFixed(0)}ms',
                Icons.timer,
                colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Hits',
                '${widget.result.hits}',
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _chartAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_chartAnimation.value * 0.2),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailedStats() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detailed Statistics',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow('Duration', '${(widget.result.durationMs / 1000).toStringAsFixed(1)}s'),
          _buildStatRow('Total Stimuli', '${widget.result.totalStimuli}'),
          _buildStatRow('Successful Hits', '${widget.result.hits}'),
          _buildStatRow('Missed Stimuli', '${widget.result.misses}'),
          _buildStatRow('Fastest Reaction', '${_getFastestReaction()}ms'),
          _buildStatRow('Slowest Reaction', '${_getSlowestReaction()}ms'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBreakdown() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return Row(
                children: [
                  Expanded(
                    flex: (widget.result.hits * _chartAnimation.value).round(),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (widget.result.misses > 0) ...[
                    const SizedBox(width: 4),
                    Expanded(
                      flex: (widget.result.misses * _chartAnimation.value).round(),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Hits', Colors.green, widget.result.hits),
              _buildLegendItem('Misses', Colors.red, widget.result.misses),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ($count)',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _retryDrill,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareResults,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _backToHome,
            child: const Text('Back to Home'),
          ),
        ),
      ],
    );
  }

  Color _getPerformanceColor(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.6) return Colors.orange;
    return Colors.red;
  }

  IconData _getPerformanceIcon(double accuracy) {
    if (accuracy >= 0.8) return Icons.emoji_events;
    if (accuracy >= 0.6) return Icons.thumb_up;
    return Icons.trending_up;
  }

  String _getPerformanceMessage(double accuracy) {
    if (accuracy >= 0.9) return 'Excellent Performance!';
    if (accuracy >= 0.8) return 'Great Job!';
    if (accuracy >= 0.6) return 'Good Effort!';
    return 'Keep Practicing!';
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
      case 'soccer': return Icons.sports_soccer;
      case 'basketball': return Icons.sports_basketball;
      case 'tennis': return Icons.sports_tennis;
      case 'fitness': return Icons.fitness_center;
      case 'hockey': return Icons.sports_hockey;
      case 'volleyball': return Icons.sports_volleyball;
      case 'football': return Icons.sports_football;
      default: return Icons.psychology;
    }
  }

  int _getFastestReaction() {
    if (widget.result.events.isEmpty) return 0;
    final correctEvents = widget.result.events
        .where((e) => e.correct)
        .map((e) => e.reactionTimeMs ?? 0)
        .where((time) => time > 0)
        .toList();
    if (correctEvents.isEmpty) return 0;
    return correctEvents.reduce(math.min);
  }

  int _getSlowestReaction() {
    if (widget.result.events.isEmpty) return 0;
    final correctEvents = widget.result.events
        .where((e) => e.correct)
        .map((e) => e.reactionTimeMs ?? 0)
        .where((time) => time > 0)
        .toList();
    if (correctEvents.isEmpty) return 0;
    return correctEvents.reduce(math.max);
  }

  // Action button implementations
  void _retryDrill() {
    HapticFeedback.mediumImpact();
    
    // Navigate back to drill runner with the same drill
    context.go('/drill-runner', extra: widget.result.drill);
  }

  void _shareResults() async {
    HapticFeedback.lightImpact();
    
    try {
      final drill = widget.result.drill;
      final accuracy = (widget.result.accuracy * 100).toStringAsFixed(1);
      final avgReaction = widget.result.avgReactionMs.toStringAsFixed(0);
      final duration = (widget.result.durationMs / 1000).toStringAsFixed(0);
      
      final shareText = '''
🧠 Spark Drill Results 🧠

📋 Drill: ${drill.name}
🎯 Category: ${drill.category.toUpperCase()}
⭐ Difficulty: ${drill.difficulty.name.toUpperCase()}

📊 Performance:
• Accuracy: $accuracy%
• Hits: ${widget.result.hits}/${widget.result.totalStimuli}
• Avg Reaction: ${avgReaction}ms
• Duration: ${duration}s

${_getPerformanceEmoji(widget.result.accuracy)} ${_getPerformanceMessage(widget.result.accuracy)}

#Spark #ReactionTraining #CognitiveTraining
      '''.trim();

      await Share.share(
        shareText,
        subject: 'My Spark Drill Results - ${drill.name}',
      );
    } catch (e) {
      // Fallback to clipboard if sharing fails
      await Clipboard.setData(ClipboardData(
        text: 'Spark Drill Results: ${widget.result.drill.name} - Accuracy: ${(widget.result.accuracy * 100).toStringAsFixed(1)}%'
      ));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Results copied to clipboard!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _backToHome() {
    HapticFeedback.lightImpact();
    
    // Navigate back to home screen (drill library)
    context.go('/');
  }

  String _getPerformanceEmoji(double accuracy) {
    if (accuracy >= 0.9) return '🏆';
    if (accuracy >= 0.8) return '🎉';
    if (accuracy >= 0.7) return '👍';
    if (accuracy >= 0.6) return '💪';
    return '🎯';
  }
  
}
