import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brainblot_app/core/auth/services/permission_service.dart';
import 'package:brainblot_app/core/auth/guards/admin_guard.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';

class AnalyticsScreen extends StatefulWidget {
  final PermissionService permissionService;

  const AnalyticsScreen({
    super.key,
    required this.permissionService,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      permissionService: widget.permissionService,
      requiredRole: UserRole.admin,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'System Overview',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _buildUserStats(),
              const SizedBox(height: 16),
              _buildSubscriptionStats(),
              const SizedBox(height: 16),
              _buildActivityStats(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserStats() {
    return FutureBuilder<QuerySnapshot>(
      future: _firestore.collection('users').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final users = snapshot.data!.docs;
        final totalUsers = users.length;
        final activeUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final lastActive = _parseTimestamp(data['lastActiveAt']);
          if (lastActive == null) return false;
          final daysSinceActive = DateTime.now().difference(lastActive.toDate()).inDays;
          return daysSinceActive <= 7;
        }).length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'User Statistics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      'Total Users',
                      totalUsers.toString(),
                      Colors.blue,
                    ),
                    _buildStatItem(
                      context,
                      'Active (7d)',
                      activeUsers.toString(),
                      Colors.green,
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

  Widget _buildSubscriptionStats() {
    return FutureBuilder<QuerySnapshot>(
      future: _firestore.collection('users').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final users = snapshot.data!.docs;
        final planCounts = <String, int>{};
        
        for (var doc in users) {
          final data = doc.data() as Map<String, dynamic>;
          final subscription = data['subscription'] as Map<String, dynamic>?;
          final plan = subscription?['plan'] as String? ?? 'free';
          planCounts[plan] = (planCounts[plan] ?? 0) + 1;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.card_membership, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      'Subscription Distribution',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...planCounts.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key.toUpperCase()),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          entry.value.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Activity Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Detailed activity metrics will be available soon.'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Timestamp? _parseTimestamp(dynamic timestampData) {
    if (timestampData == null) {
      return null;
    }
    
    if (timestampData is Timestamp) {
      return timestampData;
    }
    
    if (timestampData is String) {
      try {
        // Try to parse the string as DateTime and convert to Timestamp
        final dateTime = DateTime.parse(timestampData);
        return Timestamp.fromDate(dateTime);
      } catch (e) {
        // If parsing fails, return null
        return null;
      }
    }
    
    // If it's neither Timestamp nor String, return null
    return null;
  }
}