import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:brainblot_app/core/services/auto_refresh_service.dart';
import 'package:brainblot_app/features/drills/domain/session_result.dart';
import 'package:brainblot_app/features/stats/bloc/stats_bloc.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin, AutoRefreshMixin {
  late TabController _tabController;
  String _selectedPeriod = '7d';
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    listenToAutoRefresh('sessions', () {
      if (mounted && !_disposed) {
        context.read<StatsBloc>().add(const StatsStarted());
      }
    });
    listenToAutoRefresh('stats', () {
      if (mounted && !_disposed) {
        context.read<StatsBloc>().add(const StatsStarted());
      }
    });
  }

  @override
  void dispose() {
    // Mark as disposed to prevent any context access
    _disposed = true;
    // Dispose tab controller first
    _tabController.dispose();
    // Then call super.dispose() to handle AutoRefreshMixin cleanup safely
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Performance Analytics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: const Color(0xFF6366F1),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.dashboard_outlined, size: 20),
                  text: 'Overview',
                ),
                Tab(
                  icon: Icon(Icons.trending_up, size: 20),
                  text: 'Performance',
                ),
                Tab(
                  icon: Icon(Icons.history, size: 20),
                  text: 'History',
                ),
              ],
            ),
          ),
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
            return RefreshIndicator(
              onRefresh: () async {
                if (mounted && !_disposed) {
                  context.read<StatsBloc>().add(const StatsStarted());
                  await Future<void>.delayed(const Duration(milliseconds: 500));
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: _buildEmptyState(),
                ),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  if (mounted && !_disposed) {
                    context.read<StatsBloc>().add(const StatsStarted());
                    await Future<void>.delayed(const Duration(milliseconds: 500));
                  }
                },
                child: _buildOverviewTab(sessions),
              ),
              RefreshIndicator(
                onRefresh: () async {
                  if (mounted && !_disposed) {
                    context.read<StatsBloc>().add(const StatsStarted());
                    await Future<void>.delayed(const Duration(milliseconds: 500));
                  }
                },
                child: _buildPerformanceTab(sessions),
              ),
              RefreshIndicator(
                onRefresh: () async {
                  if (mounted && !_disposed) {
                    context.read<StatsBloc>().add(const StatsStarted());
                    await Future<void>.delayed(const Duration(milliseconds: 500));
                  }
                },
                child: _buildHistoryTab(sessions),
              ),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Analytics Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Complete some training sessions to unlock\nyour performance insights and trends',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 8),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(List<SessionResult> sessions) {
    final stats = _calculateStats(sessions);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 24),
          _buildStatsCards(stats),
          const SizedBox(height: 32),
          _buildReactionTimeChart(sessions),
          const SizedBox(height: 32),
          _buildAccuracyChart(sessions),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(List<SessionResult> sessions) {
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

  Widget _buildHistoryTab(List<SessionResult> sessions) {
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
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    return Column(
      children: [
        // Main performance metrics row
        Row(
          children: [
            Expanded(
              child: _buildPrimaryStatCard(
                'Reaction Time',
                '${stats['avgReactionTime']?.toStringAsFixed(0) ?? '0'}',
                'ms',
                Icons.flash_on,
                const Color(0xFF6366F1),
                trend: stats['reactionTrend'] as double?,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPrimaryStatCard(
                'Accuracy',
                '${((stats['avgAccuracy'] ?? 0) * 100).toStringAsFixed(1)}',
                '%',
                Icons.center_focus_strong,
                const Color(0xFF10B981),
                trend: stats['accuracyTrend'] as double?,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Secondary metrics row
        Row(
          children: [
            Expanded(
              child: _buildSecondaryStatCard(
                'Sessions',
                '${stats['totalSessions'] ?? 0}',
                Icons.fitness_center,
                const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryStatCard(
                'Training Time',
                _formatDuration((stats['totalTime'] ?? Duration.zero) as Duration),
                Icons.schedule,
                const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryStatCard(String title, String value, String unit, IconData icon, Color color, {double? trend}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend > 0 ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(trend * 100).abs().toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionTimeChart(List<SessionResult> sessions) {
    if (sessions.isEmpty) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.show_chart,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Reaction Time Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                          FlSpot(i.toDouble(), sessions[i].avgReactionMs),
                      ],
                      isCurved: true,
                      color: const Color(0xFF6366F1),
                      barWidth: 4,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF6366F1),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6366F1).withOpacity(0.3),
                            const Color(0xFF6366F1).withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
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

  Widget _buildAccuracyChart(List<SessionResult> sessions) {
    if (sessions.isEmpty) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Accuracy Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                          FlSpot(i.toDouble(), sessions[i].accuracy),
                      ],
                      isCurved: true,
                      color: const Color(0xFF10B981),
                      barWidth: 4,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF10B981),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withOpacity(0.3),
                            const Color(0xFF10B981).withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
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

  Widget _buildPerformanceTrends(List<SessionResult> sessions) {
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

  Widget _buildDrillBreakdown(List<SessionResult> sessions) {
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

  Widget _buildProgressInsights(List<SessionResult> sessions) {
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

  Widget _buildSessionCard(SessionResult session) {
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
          session.drill.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${DateFormat('MMM dd, yyyy • HH:mm').format(session.startedAt)}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${session.avgReactionMs.toStringAsFixed(0)}ms'),
                const SizedBox(width: 16),
                Icon(Icons.gps_fixed, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${(session.accuracy * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
        trailing: _buildPerformanceIndicator(session),
      ),
    );
  }

  Widget _buildPerformanceIndicator(SessionResult session) {
    final accuracy = session.accuracy;
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

  Map<String, dynamic> _calculateStats(List<SessionResult> sessions) {
    if (sessions.isEmpty) return {};
    
    final reactionTimes = sessions.map((s) => s.avgReactionMs).toList();
    final accuracies = sessions.map((s) => s.accuracy).toList();
    
    final avgReaction = reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;
    final avgAccuracy = accuracies.reduce((a, b) => a + b) / accuracies.length;
    
    final totalTime = sessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.endedAt.difference(session.startedAt),
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
    
    // Ensure we have enough values to compare
    if (values.length < 6) {
      // For small datasets, compare first half vs second half
      final midPoint = values.length ~/ 2;
      final older = values.sublist(0, midPoint);
      final recent = values.sublist(midPoint);
      
      if (older.isEmpty || recent.isEmpty) return null;
      
      final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
      final olderAvg = older.reduce((a, b) => a + b) / older.length;
      
      final change = (recentAvg - olderAvg) / olderAvg;
      return higherIsBetter ? change : -change;
    }
    
    // For larger datasets, compare last 5 vs previous 5
    final recent = values.sublist(values.length - 5);
    final older = values.sublist(values.length - 10, values.length - 5);
    
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;
    
    final change = (recentAvg - olderAvg) / olderAvg;
    return higherIsBetter ? change : -change;
  }

  Map<String, dynamic> _calculateReactionTrend(List<SessionResult> sessions) {
    if (sessions.length < 2) return {'isPositive': false, 'percentage': 0.0};
    
    List<SessionResult> recent, older;
    
    if (sessions.length < 6) {
      final midPoint = sessions.length ~/ 2;
      older = sessions.sublist(0, midPoint);
      recent = sessions.sublist(midPoint);
    } else {
      recent = sessions.sublist(sessions.length - 5);
      older = sessions.sublist(sessions.length - 10, sessions.length - 5);
    }
    
    if (older.isEmpty || recent.isEmpty) return {'isPositive': false, 'percentage': 0.0};
    
    final recentAvg = recent.map((s) => s.avgReactionMs).reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.map((s) => s.avgReactionMs).reduce((a, b) => a + b) / older.length;
    
    final improvement = (olderAvg - recentAvg) / olderAvg * 100;
    
    return {
      'isPositive': improvement > 0,
      'percentage': improvement.abs(),
    };
  }

  Map<String, dynamic> _calculateAccuracyTrend(List<SessionResult> sessions) {
    if (sessions.length < 2) return {'isPositive': false, 'percentage': 0.0};
    
    List<SessionResult> recent, older;
    
    if (sessions.length < 6) {
      final midPoint = sessions.length ~/ 2;
      older = sessions.sublist(0, midPoint);
      recent = sessions.sublist(midPoint);
    } else {
      recent = sessions.sublist(sessions.length - 5);
      older = sessions.sublist(sessions.length - 10, sessions.length - 5);
    }
    
    if (older.isEmpty || recent.isEmpty) return {'isPositive': false, 'percentage': 0.0};
    
    final recentAvg = recent.map((s) => s.accuracy).reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.map((s) => s.accuracy).reduce((a, b) => a + b) / older.length;
    
    final improvement = (recentAvg - olderAvg) / olderAvg * 100;
    
    return {
      'isPositive': improvement > 0,
      'percentage': improvement.abs(),
    };
  }

  Map<String, dynamic> _calculateConsistencyTrend(List<SessionResult> sessions) {
    if (sessions.length < 2) return {'isPositive': false, 'percentage': 0.0};
    
    List<SessionResult> recent, older;
    
    if (sessions.length < 6) {
      final midPoint = sessions.length ~/ 2;
      older = sessions.sublist(0, midPoint);
      recent = sessions.sublist(midPoint);
    } else {
      recent = sessions.sublist(sessions.length - 5);
      older = sessions.sublist(sessions.length - 10, sessions.length - 5);
    }
    
    if (older.isEmpty || recent.isEmpty) return {'isPositive': false, 'percentage': 0.0};
    
    final recentVariance = _calculateVariance(recent.map((s) => s.avgReactionMs).toList());
    final olderVariance = _calculateVariance(older.map((s) => s.avgReactionMs).toList());
    
    if (olderVariance == 0) return {'isPositive': false, 'percentage': 0.0};
    
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

  Map<String, Map<String, dynamic>> _calculateDrillStats(List<SessionResult> sessions) {
    final drillGroups = <String, List<SessionResult>>{}; 
    
    for (final session in sessions) {
      final drillName = session.drill.name;
      drillGroups.putIfAbsent(drillName, () => []).add(session);
    }
    
    return drillGroups.map((name, sessions) {
      final avgReaction = sessions.map((s) => s.avgReactionMs).reduce((a, b) => a + b) / sessions.length;
      final avgAccuracy = sessions.map((s) => s.accuracy).reduce((a, b) => a + b) / sessions.length;
      
      return MapEntry(name, {
        'avgReaction': avgReaction,
        'avgAccuracy': avgAccuracy,
        'sessions': sessions.length,
      });
    });
  }

  List<Map<String, dynamic>> _generateInsights(List<SessionResult> sessions) {
    final insights = <Map<String, dynamic>>[];
    
    if (sessions.isEmpty) return insights;
    
    final stats = _calculateStats(sessions);
    final avgReaction = (stats['avgReactionTime'] ?? 0.0) as double;
    final avgAccuracy = (stats['avgAccuracy'] ?? 0.0) as double;
    
    // Reaction time insights
    if (avgReaction < 300) {
      insights.add({
        'icon': Icons.flash_on,
        'color': Colors.green,
        'text': 'Excellent reaction time! You\'re in the top tier of athletes.',
      });
    } else if (avgReaction < 400) {
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
    if (avgAccuracy > 0.9) {
      insights.add({
        'icon': Icons.star,
        'color': Colors.amber,
        'text': 'Outstanding accuracy! Your precision is exceptional.',
      });
    } else if (avgAccuracy > 0.7) {
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
