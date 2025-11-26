import 'package:spark_app/features/drills/domain/session_result.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'dart:math' as math;
import 'package:spark_app/core/theme/app_theme.dart';

// Data class to hold rep performance information
class RepPerformanceData {
  final int setNumber;
  final int repNumber;
  final double accuracy;
  final int hits;
  final int totalStimuli;
  final double avgReactionTime;
  final List<ReactionEvent> events;

  const RepPerformanceData({
    required this.setNumber,
    required this.repNumber,
    required this.accuracy,
    required this.hits,
    required this.totalStimuli,
    required this.avgReactionTime,
    required this.events,
  });
}

class DrillResultsScreen extends StatefulWidget {
  final SessionResult result;
  final List<dynamic>? detailedSetResults; // Optional detailed results from drill runner
  const DrillResultsScreen({super.key, required this.result, this.detailedSetResults});

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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ),);
    
    _slideAnimation = Tween<double>(
      begin: 60.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ),);
    
    _chartAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _chartAnimationController,
      curve: Curves.elasticOut,
    ),);
    
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
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
          // Modern Hero Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'Session Complete',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  color: _getPerformanceColor(widget.result.accuracy).withOpacity(0.6),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: 40,
                      right: 20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 80,
                      left: 30,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    // Main content
                    Center(
                      child: AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    _getPerformanceIcon(widget.result.accuracy),
                                    size: 56,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getPerformanceMessage(widget.result.accuracy),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
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
          
          // Content with improved spacing
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drill Overview Card
                          _buildDrillOverviewCard(),
                          const SizedBox(height: 24),
                          
                          // Performance Summary
                          _buildPerformanceSummary(),
                          const SizedBox(height: 24),
                          
                          // Detailed Statistics
                          _buildDetailedStatsCard(),
                          const SizedBox(height: 24),
                          
                          // Rep-wise Performance Analysis
                          _buildRepWiseAnalysis(),
                          const SizedBox(height: 32),
                          
                          // Action Buttons
                          _buildActionSection(),
                          const SizedBox(height: 24),
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

  Widget _buildDrillOverviewCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final drill = widget.result.drill;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.goldPrimary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _getCategoryIcon(drill.category),
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
                      drill.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      drill.category.toUpperCase(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildDrillStat('Difficulty', drill.difficulty.name, _getDifficultyColor(drill.difficulty)),
                const SizedBox(width: 24),
                _buildDrillStat('Configuration', '${drill.sets}×${drill.reps}', colorScheme.secondary),
                const SizedBox(width: 24),
                _buildDrillStat('Duration', '${(widget.result.durationMs / 1000).toStringAsFixed(1)}s', colorScheme.tertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrillStat(String label, String value, Color color) {
    final theme = Theme.of(context);
    
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSummary() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accuracy = widget.result.accuracy;
    final accuracyColor = _getPerformanceColor(accuracy);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accuracyColor.withOpacity(0.1),
            accuracyColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accuracyColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Performance Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Accuracy',
                  '${(accuracy * 100).toStringAsFixed(1)}%',
                  Icons.gps_fixed,
                  accuracyColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Reaction Time',
                  '${widget.result.avgReactionMs.toStringAsFixed(0)}ms',
                  Icons.timer_outlined,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Hits',
                  '${widget.result.hits}',
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Total Stimuli',
                  '${widget.result.drill.numberOfStimuli}',
                  Icons.psychology,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
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
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStatsCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: colorScheme.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Detailed Statistics',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatRow('Sets Completed', '${widget.result.drill.sets}', Icons.layers),
          _buildStatRow('Reps per Set', '${widget.result.drill.reps}', Icons.repeat),
          _buildStatRow('Successful Hits', '${widget.result.hits}', Icons.check_circle),
          _buildStatRow('Missed Stimuli', '${widget.result.misses}', Icons.cancel),
          _buildStatRow('Fastest Reaction', '${_getFastestReaction()}ms', Icons.flash_on),
          _buildStatRow('Slowest Reaction', '${_getSlowestReaction()}ms', Icons.schedule),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepWiseAnalysis() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final drill = widget.result.drill;
    
    // Ensure we have valid drill configuration
    final totalSets = math.max(drill.sets, 1);
    final totalReps = math.max(drill.reps, 1);
    final events = widget.result.events;
    final stimuliPerRep = math.max(drill.numberOfStimuli, 1);
    
    // Create a structured approach to organize data by sets and reps
    final List<List<RepPerformanceData>> setBasedReps = [];
    
    // Check if we have detailed set results from the drill runner
    if (widget.detailedSetResults != null && widget.detailedSetResults!.isNotEmpty) {
      AppLogger.debug('Received detailed set results: ${widget.detailedSetResults!.length} sets', tag: 'DrillResults');
      for (var setData in widget.detailedSetResults!) {
        AppLogger.debug('Set ${setData['setNumber']}: ${(setData['reps'] as List).length} reps', tag: 'DrillResults');
      }
      
      // Use the detailed results from the drill runner
      for (int setIndex = 0; setIndex < totalSets; setIndex++) {
        final List<RepPerformanceData> repsInThisSet = [];
        
        for (int repIndex = 0; repIndex < totalReps; repIndex++) {
          // Try to find matching detailed data
          Map<String, dynamic>? repData;
          
          if (setIndex < widget.detailedSetResults!.length) {
            final setData = widget.detailedSetResults![setIndex] as Map<String, dynamic>?;
            if (setData != null && setData['reps'] != null) {
              final repsData = setData['reps'] as List;
              if (repIndex < repsData.length) {
                repData = repsData[repIndex] as Map<String, dynamic>?;
              }
            }
          }
          
          if (repData != null) {
            final repPerformance = RepPerformanceData(
              setNumber: setIndex + 1,
              repNumber: repIndex + 1,
              accuracy: (repData['accuracy'] as double?) ?? 0.0,
              hits: (repData['hits'] as int?) ?? 0,
              totalStimuli: (repData['totalStimuli'] as int?) ?? stimuliPerRep,
              avgReactionTime: (repData['avgReactionTime'] as double?) ?? 0.0,
              events: [],
            );
            
            repsInThisSet.add(repPerformance);
          } else {
            repsInThisSet.add(RepPerformanceData(
              setNumber: setIndex + 1,
              repNumber: repIndex + 1,
              accuracy: 0.0,
              hits: 0,
              totalStimuli: stimuliPerRep,
              avgReactionTime: 0.0,
              events: [],
            ),);
          }
        }
        setBasedReps.add(repsInThisSet);
      }
    } else if (events.isNotEmpty) {
      // Fallback: try to divide events evenly across sets and reps
      final totalExpectedEvents = totalSets * totalReps * stimuliPerRep;
      final actualEventsPerRep = events.length / (totalSets * totalReps);
      
      for (int setIndex = 0; setIndex < totalSets; setIndex++) {
        final List<RepPerformanceData> repsInThisSet = [];
        
        for (int repIndex = 0; repIndex < totalReps; repIndex++) {
          final globalRepIndex = (setIndex * totalReps) + repIndex;
          final eventStartIndex = (globalRepIndex * actualEventsPerRep).round();
          final eventEndIndex = math.min(
            ((globalRepIndex + 1) * actualEventsPerRep).round(),
            events.length,
          );
          
          if (eventStartIndex < events.length) {
            final repEvents = events.sublist(eventStartIndex, eventEndIndex);
            final repHits = repEvents.where((e) => e.correct).length;
            final repAccuracy = repEvents.isNotEmpty ? repHits / repEvents.length : 0.0;
            final repReactionTimes = repEvents
                .where((e) => e.correct && e.reactionTimeMs != null)
                .map((e) => e.reactionTimeMs!)
                .toList();
            final avgRepReaction = repReactionTimes.isNotEmpty
                ? repReactionTimes.reduce((a, b) => a + b) / repReactionTimes.length
                : 0.0;
            
            final repData = RepPerformanceData(
              setNumber: setIndex + 1,
              repNumber: repIndex + 1,
              accuracy: repAccuracy,
              hits: repHits,
              totalStimuli: repEvents.length,
              avgReactionTime: avgRepReaction,
              events: repEvents,
            );
            
            repsInThisSet.add(repData);
          } else {
            repsInThisSet.add(RepPerformanceData(
              setNumber: setIndex + 1,
              repNumber: repIndex + 1,
              accuracy: 0.0,
              hits: 0,
              totalStimuli: 0,
              avgReactionTime: 0.0,
              events: [],
            ),);
          }
        }
        setBasedReps.add(repsInThisSet);
      }
    } else {
      // Create empty structure based on drill configuration
      for (int setIndex = 0; setIndex < totalSets; setIndex++) {
        final List<RepPerformanceData> repsInThisSet = [];
        
        for (int repIndex = 0; repIndex < totalReps; repIndex++) {
          repsInThisSet.add(RepPerformanceData(
            setNumber: setIndex + 1,
            repNumber: repIndex + 1,
            accuracy: 0.0,
            hits: 0,
            totalStimuli: stimuliPerRep,
            avgReactionTime: 0.0,
            events: [],
          ),);
        }
        setBasedReps.add(repsInThisSet);
      }
    }
    
    // Flatten the set-based structure for insights calculations
    final allReps = setBasedReps.expand((set) => set).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.insights,
                  color: colorScheme.tertiary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rep-wise Performance Analysis',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Detailed breakdown across ${allReps.length} repetitions',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (allReps.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildPerformanceInsights(allReps),
            const SizedBox(height: 24),
            _buildSetBasedDisplay(setBasedReps),
          ] else ...[
            const SizedBox(height: 24),
            _buildEmptyState(),
          ],
        ],
      ),
    );
  }

  Widget _buildPerformanceInsights(List<RepPerformanceData> allReps) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Calculate insights - normalize accuracy values (handle both decimal 0-1 and percentage 0-100)
    final normalizedAccuracies = allReps.map((r) => r.accuracy > 1 ? r.accuracy / 100 : r.accuracy).toList();
    final avgAccuracy = normalizedAccuracies.reduce((a, b) => a + b) / normalizedAccuracies.length;
    final avgReactionTime = allReps
        .where((r) => r.avgReactionTime > 0)
        .map((r) => r.avgReactionTime)
        .fold(0.0, (a, b) => a + b) /
        allReps.where((r) => r.avgReactionTime > 0).length;
    final bestRep = allReps.reduce((a, b) {
      final aAcc = a.accuracy > 1 ? a.accuracy / 100 : a.accuracy;
      final bAcc = b.accuracy > 1 ? b.accuracy / 100 : b.accuracy;
      return aAcc > bAcc ? a : b;
    });
    final totalHits = allReps.map((r) => r.hits).reduce((a, b) => a + b);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.3),
            colorScheme.primaryContainer.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Insights',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickInsight(
                  'Avg Accuracy',
                  '${(avgAccuracy * 100).toStringAsFixed(1)}%',
                  Icons.trending_up,
                  _getPerformanceColor(avgAccuracy),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickInsight(
                  'Best Rep',
                  'Set ${bestRep.setNumber} Rep ${bestRep.repNumber}',
                  Icons.star,
                  Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInsight(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
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
    );
  }

  Widget _buildSetBasedDisplay(List<List<RepPerformanceData>> setBasedReps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: setBasedReps.asMap().entries.map((setEntry) {
        final setIndex = setEntry.key;
        final repsInSet = setEntry.value;
        
        return Container(
          margin: EdgeInsets.only(bottom: setIndex < setBasedReps.length - 1 ? 20 : 0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSetHeader(setIndex + 1, repsInSet),
              const SizedBox(height: 12),
              _buildRepsDisplay(repsInSet),
              const SizedBox(height: 16),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSetHeader(int setNumber, List<RepPerformanceData> reps) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final setAvgAccuracy = reps.isNotEmpty
        ? reps.map((r) => r.accuracy > 1 ? r.accuracy / 100 : r.accuracy).reduce((a, b) => a + b) / reps.length
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.08),
            colorScheme.primary.withOpacity(0.03),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.layers,
              color: colorScheme.onPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set $setNumber',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${reps.length} repetitions completed',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _getPerformanceColor(setAvgAccuracy),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(setAvgAccuracy * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Accuracy',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepsDisplay(List<RepPerformanceData> reps) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repetition Performance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: reps.map((rep) => _buildRepCard(rep)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRepCard(RepPerformanceData rep) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final normalizedAccuracy = rep.accuracy > 1 ? rep.accuracy / 100 : rep.accuracy;
    final accuracyColor = _getPerformanceColor(normalizedAccuracy);
    
    return AnimatedBuilder(
      animation: _chartAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.95 + (_chartAnimation.value * 0.05),
          child: Container(

            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accuracyColor.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accuracyColor.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rep number and accuracy row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accuracyColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Rep ${rep.repNumber}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accuracyColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(normalizedAccuracy * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accuracyColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Stats section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hits',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${rep.hits}/${widget.result.drill.numberOfStimuli}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Time',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${rep.avgReactionTime.toStringAsFixed(0)}ms',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline,
              color: colorScheme.onSurface.withOpacity(0.5),
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No detailed rep data available',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This session didn\'t capture rep-level performance data',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What\'s Next?',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _retryDrill,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Back to Home'),
          ),
        ),
      ],
    );
  }

  // Helper methods remain the same
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
    if (accuracy >= 0.9) return 'Outstanding Performance!';
    if (accuracy >= 0.8) return 'Excellent Work!';
    if (accuracy >= 0.6) return 'Great Progress!';
    return 'Keep Training!';
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
    context.go('/drill-runner', extra: widget.result.drill);
  }

  void _backToHome() {
    HapticFeedback.lightImpact();
    context.go('/');
  }

}
