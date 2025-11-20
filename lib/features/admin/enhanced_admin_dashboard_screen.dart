import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/auth/services/permission_service.dart';
import 'package:spark_app/core/auth/guards/admin_guard.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/features/admin/ui/user_management_screen.dart';
import 'package:spark_app/features/admin/ui/subscription_management_screen.dart';
import 'package:spark_app/features/admin/ui/plan_requests_screen.dart';
import 'package:spark_app/features/admin/ui/screens/comprehensive_activity_screen.dart';
import 'package:spark_app/features/admin/ui/category_management_screen.dart';
import 'package:spark_app/features/admin/ui/stimulus_management_screen.dart';


class EnhancedAdminDashboardScreen extends StatelessWidget {
  final PermissionService permissionService;

  const EnhancedAdminDashboardScreen({
    super.key,
    required this.permissionService,
  });

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      permissionService: permissionService,
      requiredRole: UserRole.admin,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: RefreshIndicator(
          onRefresh: () async {
            // Trigger rebuild to refresh statistics
            (context as Element).markNeedsBuild();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildRealTimeStats(context),
                const SizedBox(height: 20),
                _buildManagementGrid(context),
                const SizedBox(height: 20),
                _buildRecentActivity(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Admin Dashboard'),
      elevation: 0,

    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, Admin',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your platform from this central hub',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildRealTimeStats(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        return FutureBuilder<QuerySnapshot>(
          future:
              FirebaseFirestore.instance.collection('subscription_plans').get(),
          builder: (context, planSnapshot) {
            final totalUsers = userSnapshot.data?.docs.length ?? 0;
            final activeUsers = userSnapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lastActive = _parseTimestamp(data['lastActiveAt']);
                  if (lastActive == null) return false;
                  final date = lastActive.toDate();
                  return date.isAfter(
                      DateTime.now().subtract(const Duration(days: 7)),);
                }).length ??
                0;

            final adminCount = userSnapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['role'] == 'admin';
                }).length ??
                0;

            final activePlans = planSnapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isActive'] == true;
                }).length ??
                0;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  context,
                  title: 'Total Users',
                  value: totalUsers.toString(),
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                _buildStatCard(
                  context,
                  title: 'Active Users',
                  value: activeUsers.toString(),
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
                _buildStatCard(
                  context,
                  title: 'Administrators',
                  value: adminCount.toString(),
                  icon: Icons.admin_panel_settings,
                  color: Colors.red,
                ),
                _buildStatCard(
                  context,
                  title: 'Active Plans',
                  value: activePlans.toString(),
                  icon: Icons.card_membership,
                  color: Colors.purple,
                ),
              ],
            );
          },
        );
      },
    );
  }

Widget _buildStatCard(
  BuildContext context, {
  required String title,
  required String value,
  String? subtitle,
  required IconData icon,
  required Color color,
}) {
  final theme = Theme.of(context);

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon container
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),

        // Text section
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}


  Widget _buildManagementGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Management Tools',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildManagementCard(
              context,
              title: 'User Management',
              description: 'Manage users, roles & permissions',
              icon: Icons.people_outline,
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              ),
            ),
            _buildManagementCard(
              context,
              title: 'Subscriptions',
              description: 'Manage plans & pricing',
              icon: Icons.card_membership_outlined,
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionManagementScreen(),
                ),
              ),
            ),
            _buildManagementCard(
              context,
              title: 'Drill Categories',
              description: 'Manage drill categories',
              icon: Icons.category_outlined,
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryManagementScreen(),
                ),
              ),
            ),
            _buildManagementCard(
              context,
              title: 'Plan Requests',
              description: 'Review subscription requests',
              icon: Icons.receipt_long_outlined,
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PlanRequestsScreen(),
                ),
              ),
            ),
            _buildManagementCard(
              context,
              title: 'Stimulus Management',
              description: 'Manage custom stimuli',
              icon: Icons.auto_awesome_outlined,
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StimulusManagementScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

Widget _buildManagementCard(
  BuildContext context, {
  required String title,
  required String description,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    splashColor: color.withOpacity(0.12),
    highlightColor: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),

          const SizedBox(height: 10),

          // Title
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),

          const SizedBox(height: 4),

          // Description
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: Colors.grey[600],
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}


  Widget _buildRecentActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.timeline, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ComprehensiveActivityScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
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
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No recent activity',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
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
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(4),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final displayName = data['displayName'] as String? ?? 'Unknown';
                  final email = data['email'] as String? ?? '';
                  final createdAt = _parseTimestamp(data['createdAt']);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.1)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withOpacity(0.8),
                              Colors.blue,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_add, color: Colors.white, size: 24),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'New user registration',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                createdAt != null
                                    ? _formatTimeAgo(createdAt.toDate())
                                    : 'Recently',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
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
