import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/theme/app_theme.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Insights'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserAnalytics(),
            const SizedBox(height: 24),
            _buildSubscriptionAnalytics(),
            const SizedBox(height: 24),
            _buildActivityAnalytics(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAnalytics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        final totalUsers = users.length;
        
        final adminUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] == 'admin';
        }).length;

        final activeUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final lastActive = data['lastActiveAt'];
          if (lastActive == null) return false;
          final timestamp = lastActive is Timestamp
              ? lastActive.toDate()
              : DateTime.tryParse(lastActive.toString());
          if (timestamp == null) return false;
          return timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7)));
        }).length;

        final newUsersThisMonth = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final created = data['createdAt'];
          if (created == null) return false;
          final timestamp = created is Timestamp
              ? created.toDate()
              : DateTime.tryParse(created.toString());
          if (timestamp == null) return false;
          final now = DateTime.now();
          return timestamp.year == now.year && timestamp.month == now.month;
        }).length;

        return Card(
          elevation: 2,
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.people, color: Colors.blue, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'User Analytics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.8,
                  children: [
                    _buildStatCard(
                      'Total Users',
                      totalUsers.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Active (7 days)',
                      activeUsers.toString(),
                      Icons.trending_up,
                      Colors.green,
                    ),
                    _buildStatCard(
                      'Administrators',
                      adminUsers.toString(),
                      Icons.admin_panel_settings,
                      Colors.red,
                    ),
                    _buildStatCard(
                      'New This Month',
                      newUsersThisMonth.toString(),
                      Icons.person_add,
                      Colors.orange,
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

  Widget _buildSubscriptionAnalytics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        
        final freeUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sub = data['subscription'] as Map<String, dynamic>?;
          return sub?['plan'] == 'free';
        }).length;

        final playerUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sub = data['subscription'] as Map<String, dynamic>?;
          return sub?['plan'] == 'player';
        }).length;

        final instituteUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sub = data['subscription'] as Map<String, dynamic>?;
          return sub?['plan'] == 'institute';
        }).length;

        final totalRevenue = (playerUsers * 9.99) + (instituteUsers * 29.99);

        return Card(
          elevation: 2,
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.card_membership,
                          color: Colors.purple, size: 28,),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Subscription Analytics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.8,
                  children: [
                    _buildStatCard(
                      'Free Plan',
                      freeUsers.toString(),
                      Icons.card_membership,
                      AppTheme.freeColor,
                    ),
                    _buildStatCard(
                      'Player Plan',
                      playerUsers.toString(),
                      Icons.card_membership,
                      AppTheme.playerColor,
                    ),
                    _buildStatCard(
                      'Institute Plan',
                      instituteUsers.toString(),
                      Icons.card_membership,
                      AppTheme.instituteColor,
                    ),
                    _buildStatCard(
                      'Est. Revenue',
                      '\$${totalRevenue.toStringAsFixed(2)}',
                      Icons.attach_money,
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

  Widget _buildActivityAnalytics() {
    return Card(
      elevation: 2,
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.timeline, color: Colors.orange, size: 28),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('No recent activity'),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final displayName = data['displayName'] as String? ?? 'Unknown';
                    final createdAt = data['createdAt'];
                    
                    String timeAgo = 'Recently';
                    if (createdAt != null) {
                      final timestamp = createdAt is Timestamp
                          ? createdAt.toDate()
                          : DateTime.tryParse(createdAt.toString());
                      if (timestamp != null) {
                        timeAgo = _formatTimeAgo(timestamp);
                      }
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        child: const Icon(Icons.person_add,
                            color: Colors.blue, size: 20,),
                      ),
                      title: const Text(
                        'New user registered',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(displayName),
                      trailing: Text(
                        timeAgo,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}