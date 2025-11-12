import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/theme/app_theme.dart';

class ComprehensiveAnalyticsScreen extends StatefulWidget {
  const ComprehensiveAnalyticsScreen({super.key});

  @override
  State<ComprehensiveAnalyticsScreen> createState() => _ComprehensiveAnalyticsScreenState();
}

class _ComprehensiveAnalyticsScreenState extends State<ComprehensiveAnalyticsScreen> {
  final _firestore = FirebaseFirestore.instance;
  String _selectedPeriod = '7d';
  bool _isLoading = true;
  
  Map<String, dynamic> _metrics = {};

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    
    try {
      final metrics = <String, dynamic>{};
      
      // User Metrics
      final usersSnapshot = await _firestore.collection('users').get();
      final users = usersSnapshot.docs;
      metrics['totalUsers'] = users.length;
      
      final now = DateTime.now();
      final activeUsers = users.where((doc) {
        final data = doc.data();
        final lastActive = _parseTimestamp(data['lastActiveAt']);
        if (lastActive == null) return false;
        return lastActive.toDate().isAfter(now.subtract(const Duration(days: 7)));
      }).length;
      metrics['activeUsers'] = activeUsers;
      
      final newUsersThisMonth = users.where((doc) {
        final data = doc.data();
        final created = _parseTimestamp(data['createdAt']);
        if (created == null) return false;
        final date = created.toDate();
        return date.year == now.year && date.month == now.month;
      }).length;
      metrics['newUsersThisMonth'] = newUsersThisMonth;
      
      final adminCount = users.where((doc) => doc.data()['role'] == 'admin').length;
      metrics['adminCount'] = adminCount;
      
      // Subscription Metrics
      final freeUsers = users.where((doc) {
        final sub = doc.data()['subscription'] as Map<String, dynamic>?;
        return sub?['plan'] == 'free';
      }).length;
      metrics['freeUsers'] = freeUsers;
      
      final playerUsers = users.where((doc) {
        final sub = doc.data()['subscription'] as Map<String, dynamic>?;
        return sub?['plan'] == 'player';
      }).length;
      metrics['playerUsers'] = playerUsers;
      
      final instituteUsers = users.where((doc) {
        final sub = doc.data()['subscription'] as Map<String, dynamic>?;
        return sub?['plan'] == 'institute';
      }).length;
      metrics['instituteUsers'] = instituteUsers;
      
      final estimatedRevenue = (playerUsers * 9.99) + (instituteUsers * 29.99);
      metrics['estimatedRevenue'] = estimatedRevenue;
      
      // Content Metrics
      int totalDrills = 0;
      int totalPrograms = 0;
      
      for (var userDoc in users) {
        final drillsSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('drills')
            .get();
        totalDrills += drillsSnapshot.docs.length;
        
        final programsSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('programs')
            .get();
        totalPrograms += programsSnapshot.docs.length;
      }
      
      metrics['totalDrills'] = totalDrills;
      metrics['totalPrograms'] = totalPrograms;
      
      // Plan Requests
      final planRequestsSnapshot = await _firestore.collection('plan_requests').get();
      metrics['totalPlanRequests'] = planRequestsSnapshot.docs.length;
      
      final pendingRequests = planRequestsSnapshot.docs.where((doc) => 
        doc.data()['status'] == 'pending',
      ).length;
      metrics['pendingRequests'] = pendingRequests;
      
      // Subscription Plans
      final plansSnapshot = await _firestore.collection('subscription_plans').get();
      metrics['totalPlans'] = plansSnapshot.docs.length;
      
      setState(() {
        _metrics = metrics;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading metrics: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Analytics & Insights'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMetrics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildPeriodSelector(),
                    const SizedBox(height: 24),
                    _buildKeyMetrics(),
                    const SizedBox(height: 24),
                    _buildUserAnalytics(),
                    const SizedBox(height: 24),
                    _buildSubscriptionBreakdown(),
                    const SizedBox(height: 24),
                    _buildContentMetrics(),
                    const SizedBox(height: 24),
                    _buildRevenueCard(),
                    const SizedBox(height: 24),
                    _buildEngagementMetrics(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.analytics, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Platform Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comprehensive metrics and insights',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPeriodChip('24h', '24 Hours'),
          const SizedBox(width: 8),
          _buildPeriodChip('7d', '7 Days'),
          const SizedBox(width: 8),
          _buildPeriodChip('30d', '30 Days'),
          const SizedBox(width: 8),
          _buildPeriodChip('90d', '90 Days'),
          const SizedBox(width: 8),
          _buildPeriodChip('all', 'All Time'),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String value, String label) {
    final isSelected = _selectedPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPeriod = value;
        });
      },
      selectedColor: AppTheme.primaryColor,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.primaryColor,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.3),
      ),
    );
  }

  Widget _buildKeyMetrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Users',
          _metrics['totalUsers']?.toString() ?? '0',
          Icons.people,
          Colors.blue,
          '+${_metrics['newUsersThisMonth'] ?? 0} this month',
        ),
        _buildMetricCard(
          'Active Users',
          _metrics['activeUsers']?.toString() ?? '0',
          Icons.trending_up,
          Colors.green,
          'Last 7 days',
        ),
        _buildMetricCard(
          'Total Drills',
          _metrics['totalDrills']?.toString() ?? '0',
          Icons.sports_tennis,
          Colors.orange,
          'Across all users',
        ),
        _buildMetricCard(
          'Total Programs',
          _metrics['totalPrograms']?.toString() ?? '0',
          Icons.calendar_today,
          Colors.purple,
          'Across all users',
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
                    Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserAnalytics() {
    return _buildSection(
      'User Analytics',
      Icons.people,
      Colors.blue,
      [
        _buildStatRow('Total Users', _metrics['totalUsers']?.toString() ?? '0', Colors.blue),
        _buildStatRow('Active (7 days)', _metrics['activeUsers']?.toString() ?? '0', Colors.green),
        _buildStatRow('New This Month', _metrics['newUsersThisMonth']?.toString() ?? '0', Colors.orange),
        _buildStatRow('Administrators', _metrics['adminCount']?.toString() ?? '0', Colors.red),
      ],
    );
  }

  Widget _buildSubscriptionBreakdown() {
    final freeUsers = (_metrics['freeUsers'] as int?) ?? 0;
    final playerUsers = (_metrics['playerUsers'] as int?) ?? 0;
    final instituteUsers = (_metrics['instituteUsers'] as int?) ?? 0;
    final total = freeUsers + playerUsers + instituteUsers;
    
    return _buildSection(
      'Subscription Breakdown',
      Icons.card_membership,
      Colors.purple,
      [
        _buildProgressBar(
          'Free Plan',
          freeUsers,
          total,
          AppTheme.freeColor,
        ),
        _buildProgressBar(
          'Player Plan',
          playerUsers,
          total,
          AppTheme.playerColor,
        ),
        _buildProgressBar(
          'Institute Plan',
          instituteUsers,
          total,
          AppTheme.instituteColor,
        ),
      ],
    );
  }

  Widget _buildContentMetrics() {
    return _buildSection(
      'Content Metrics',
      Icons.library_books,
      Colors.orange,
      [
        _buildStatRow('Total Drills', _metrics['totalDrills']?.toString() ?? '0', Colors.orange),
        _buildStatRow('Total Programs', _metrics['totalPrograms']?.toString() ?? '0', Colors.purple),
        _buildStatRow('Subscription Plans', _metrics['totalPlans']?.toString() ?? '0', Colors.blue),
        _buildStatRow('Plan Requests', _metrics['totalPlanRequests']?.toString() ?? '0', Colors.amber),
      ],
    );
  }

  Widget _buildRevenueCard() {
    final revenue = _metrics['estimatedRevenue'] ?? 0.0;
    final monthlyRevenue = revenue;
    final yearlyRevenue = revenue * 12;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade600,
            Colors.green.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                child: const Icon(Icons.attach_money, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Text(
                'Revenue Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly (Est.)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${monthlyRevenue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yearly (Est.)',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${yearlyRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementMetrics() {
    return _buildSection(
      'Engagement Metrics',
      Icons.timeline,
      Colors.teal,
      [
        _buildStatRow('Pending Plan Requests', _metrics['pendingRequests']?.toString() ?? '0', Colors.amber),
        _buildStatRow('Active Subscriptions', ((_metrics['playerUsers'] ?? 0) + (_metrics['instituteUsers'] ?? 0)).toString(), Colors.green),
        _buildStatRow('Free Users', _metrics['freeUsers']?.toString() ?? '0', Colors.grey),
        _buildStatRow('Conversion Rate', '${_calculateConversionRate()}%', Colors.blue),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total * 100) : 0.0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$value (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: total > 0 ? value / total : 0,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateConversionRate() {
    final total = (_metrics['totalUsers'] as int?) ?? 0;
    if (total == 0) return '0.0';
    
    final playerUsers = (_metrics['playerUsers'] as int?) ?? 0;
    final instituteUsers = (_metrics['instituteUsers'] as int?) ?? 0;
    final paid = playerUsers + instituteUsers;
    return ((paid / total) * 100).toStringAsFixed(1);
  }

  Timestamp? _parseTimestamp(dynamic timestampData) {
    if (timestampData == null) return null;
    if (timestampData is Timestamp) return timestampData;
    if (timestampData is String) {
      try {
        final dateTime = DateTime.parse(timestampData);
        return Timestamp.fromDate(dateTime);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}