import 'package:brainblot_app/features/stats/bloc/stats_bloc.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = '7d';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Analytics'),
        elevation: 0,
        actions: const [],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Overview'),
            Tab(icon: Icon(Icons.trending_up), text: 'Performance'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: BlocBuilder<StatsBloc, StatsState>(
        builder: (context, state) {
          if (state.status == StatsStatus.loading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading analytics...'),
                ],
              ),
            );
          }

          final sessions = state.sessions;
          if (sessions.isEmpty) {
            return _buildEmptyState();
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(sessions),
              _buildPerformanceTab(sessions),
              _buildHistoryTab(sessions),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Data Yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some training sessions to see your analytics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(List<dynamic> sessions) {
    final stats = _calculateStats(sessions);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 20),
          _buildStatsCards(stats),
          const SizedBox(height: 24),
          _buildReactionTimeChart(sessions),
          const SizedBox(height: 24),
          _buildAccuracyChart(sessions),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(List<dynamic> sessions) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPerformanceTrends(sessions),
          const SizedBox(height: 24),
          _buildDrillBreakdown(sessions),
          const SizedBox(height: 24),
          _buildProgressInsights(sessions),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(List<dynamic> sessions) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Session History',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${sessions.length} sessions',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildSessionCard(sessions[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodButton('7d', '7 Days'),
          _buildPeriodButton('30d', '30 Days'),
          _buildPeriodButton('90d', '90 Days'),
          _buildPeriodButton('all', 'All Time'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String value, String label) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard(
          'Avg Reaction Time',
          '${stats['avgReactionTime']?.toStringAsFixed(0) ?? '0'}ms',
          Icons.timer,
          Colors.blue,
          trend: stats['reactionTrend'] as double?,
        ),
        _buildStatCard(
          'Accuracy',
          '${((stats['avgAccuracy'] ?? 0) * 100).toStringAsFixed(1)}%',
          Icons.gps_fixed,
          Colors.green,
          trend: stats['accuracyTrend'] as double?,
        ),
        _buildStatCard(
          'Total Sessions',
          '${stats['totalSessions'] ?? 0}',
          Icons.fitness_center,
          Colors.orange,
        ),
        _buildStatCard(
          'Training Time',
          _formatDuration((stats['totalTime'] ?? Duration.zero) as Duration),
          Icons.schedule,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {double? trend}) {
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
              if (trend != null)
                Icon(
                  trend > 0 ? Icons.trending_up : Icons.trending_down,
                  color: trend > 0 ? Colors.green : Colors.red,
                  size: 16,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
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

  Widget _buildReactionTimeChart(List<dynamic> sessions) {
    if (sessions.isEmpty) return const SizedBox();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reaction Time Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 50,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}ms',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < sessions.length; i++)
                          FlSpot(i.toDouble(), (sessions[i].avgReactionMs as num).toDouble()),
                      ],
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccuracyChart(List<dynamic> sessions) {
    if (sessions.isEmpty) return const SizedBox();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Accuracy Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          '${(value * 100).toInt()}%',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: 1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < sessions.length; i++)
                          FlSpot(i.toDouble(), sessions[i].accuracy as double),
                      ],
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTrends(List<dynamic> sessions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Trends',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTrendItem('Reaction Time', _calculateReactionTrend(sessions)),
            _buildTrendItem('Accuracy', _calculateAccuracyTrend(sessions)),
            _buildTrendItem('Consistency', _calculateConsistencyTrend(sessions)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendItem(String label, Map<String, dynamic> trend) {
    final isPositive = (trend['isPositive'] ?? false) as bool;
    final percentage = (trend['percentage'] ?? 0.0) as double;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: isPositive ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrillBreakdown(List<dynamic> sessions) {
    final drillStats = _calculateDrillStats(sessions);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Drill Performance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...drillStats.entries.map((entry) => _buildDrillStatItem(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrillStatItem(String drillName, Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              drillName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              '${stats['avgReaction']?.toStringAsFixed(0) ?? '0'}ms',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${((stats['avgAccuracy'] ?? 0) * 100).toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${stats['sessions'] ?? 0}x',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressInsights(List<dynamic> sessions) {
    final insights = _generateInsights(sessions);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Insights',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    insight['icon'] as IconData,
                    color: insight['color'] as Color,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight['text'] as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(dynamic session) {
    return Card(
      child: ListTile(
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${DateFormat('MMM dd, yyyy • HH:mm').format(session.startedAt as DateTime)}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${(session.avgReactionMs as num).toStringAsFixed(0)}ms'),
                const SizedBox(width: 16),
                Icon(Icons.gps_fixed, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${((session.accuracy as num) * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
        trailing: _buildPerformanceIndicator(session),
      ),
    );
  }

  Widget _buildPerformanceIndicator(dynamic session) {
    final accuracy = session.accuracy as double;
    Color color;
    if (accuracy >= 0.9) {
      color = Colors.green;
    } else if (accuracy >= 0.7) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
    
    return Container(
      width: 8,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Map<String, dynamic> _calculateStats(List<dynamic> sessions) {
    if (sessions.isEmpty) return {};
    
    final reactionTimes = sessions.map((s) => (s.avgReactionMs as num).toDouble()).toList();
    final accuracies = sessions.map((s) => (s.accuracy as num).toDouble()).toList();
    
    final avgReaction = reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;
    final avgAccuracy = accuracies.reduce((a, b) => a + b) / accuracies.length;
    
    final totalTime = sessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + (session.endedAt as DateTime).difference(session.startedAt as DateTime),
    );
    
    return {
      'avgReactionTime': avgReaction,
      'avgAccuracy': avgAccuracy,
      'totalSessions': sessions.length,
      'totalTime': totalTime,
      'reactionTrend': _calculateTrend(reactionTimes, false),
      'accuracyTrend': _calculateTrend(accuracies, true),
    };
  }

  double? _calculateTrend(List<double> values, bool higherIsBetter) {
    if (values.length < 2) return null;
    
    final recent = values.sublist(max(0, values.length - 5));
    final older = values.sublist(0, min(5, values.length - 5));
    
    if (older.isEmpty) return null;
    
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;
    
    final change = (recentAvg - olderAvg) / olderAvg;
    return higherIsBetter ? change : -change;
  }

  Map<String, dynamic> _calculateReactionTrend(List<dynamic> sessions) {
    if (sessions.length < 2) return {'isPositive': false, 'percentage': 0.0};
    
    final recent = sessions.sublist(max(0, sessions.length - 5));
    final older = sessions.sublist(0, min(5, sessions.length - 5));
    
    if (older.isEmpty) return {'isPositive': false, 'percentage': 0.0};
    
    final recentAvg = recent.map((s) => s.avgReactionMs as num).reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.map((s) => s.avgReactionMs as num).reduce((a, b) => a + b) / older.length;
    
    final improvement = (olderAvg - recentAvg) / olderAvg * 100;
    
    return {
      'isPositive': improvement > 0,
      'percentage': improvement.abs(),
    };
  }

  Map<String, dynamic> _calculateAccuracyTrend(List<dynamic> sessions) {
    if (sessions.length < 2) return {'isPositive': false, 'percentage': 0.0};
    
    final recent = sessions.sublist(max(0, sessions.length - 5));
    final older = sessions.sublist(0, min(5, sessions.length - 5));
    
    if (older.isEmpty) return {'isPositive': false, 'percentage': 0.0};
    
    final recentAvg = recent.map((s) => s.accuracy as num).reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.map((s) => s.accuracy as num).reduce((a, b) => a + b) / older.length;
    
    final improvement = (recentAvg - olderAvg) / olderAvg * 100;
    
    return {
      'isPositive': improvement > 0,
      'percentage': improvement.abs(),
    };
  }

  Map<String, dynamic> _calculateConsistencyTrend(List<dynamic> sessions) {
    if (sessions.length < 2) return {'isPositive': false, 'percentage': 0.0};
    
    final recent = sessions.sublist(max(0, sessions.length - 5));
    final older = sessions.sublist(0, min(5, sessions.length - 5));
    
    if (older.isEmpty) return {'isPositive': false, 'percentage': 0.0};
    
    final recentVariance = _calculateVariance(recent.map((s) => (s.avgReactionMs as num).toDouble()).toList());
    final olderVariance = _calculateVariance(older.map((s) => (s.avgReactionMs as num).toDouble()).toList());
    
    final improvement = (olderVariance - recentVariance) / olderVariance * 100;
    
    return {
      'isPositive': improvement > 0,
      'percentage': improvement.abs(),
    };
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  Map<String, Map<String, dynamic>> _calculateDrillStats(List<dynamic> sessions) {
    final drillGroups = <String, List<dynamic>>{}; 
    
    for (final session in sessions) {
      final drillName = session.drill.name as String;
      drillGroups.putIfAbsent(drillName, () => []).add(session);
    }
    
    return drillGroups.map((name, sessions) {
      final avgReaction = sessions.map((s) => s.avgReactionMs as num).reduce((a, b) => a + b) / sessions.length;
      final avgAccuracy = sessions.map((s) => s.accuracy as num).reduce((a, b) => a + b) / sessions.length;
      
      return MapEntry(name, {
        'avgReaction': avgReaction,
        'avgAccuracy': avgAccuracy,
        'sessions': sessions.length,
      });
    });
  }

  List<Map<String, dynamic>> _generateInsights(List<dynamic> sessions) {
    final insights = <Map<String, dynamic>>[];
    
    if (sessions.isEmpty) return insights;
    
    final stats = _calculateStats(sessions);
    final avgReaction = stats['avgReactionTime'] ?? 0;
    final avgAccuracy = stats['avgAccuracy'] ?? 0;
    
    // Reaction time insights
    if ((avgReaction as num) < 300) {
      insights.add({
        'icon': Icons.flash_on,
        'color': Colors.green,
        'text': 'Excellent reaction time! You\'re in the top tier of athletes.',
      });
    } else if ((avgReaction as num) < 400) {
      insights.add({
        'icon': Icons.trending_up,
        'color': Colors.blue,
        'text': 'Good reaction time. Focus on consistency to improve further.',
      });
    } else {
      insights.add({
        'icon': Icons.fitness_center,
        'color': Colors.orange,
        'text': 'Keep training regularly to improve your reaction time.',
      });
    }
    
    // Accuracy insights
    if ((avgAccuracy as num) > 0.9) {
      insights.add({
        'icon': Icons.star,
        'color': Colors.amber,
        'text': 'Outstanding accuracy! Your precision is exceptional.',
      });
    } else if ((avgAccuracy as num) > 0.7) {
      insights.add({
        'icon': Icons.gps_fixed,
        'color': Colors.green,
        'text': 'Good accuracy. Try to maintain focus during longer sessions.',
      });
    }
    
    // Training frequency
    if (sessions.length >= 10) {
      insights.add({
        'icon': Icons.schedule,
        'color': Colors.purple,
        'text': 'Great training consistency! Regular practice shows dedication.',
      });
    }
    
    return insights;
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}
