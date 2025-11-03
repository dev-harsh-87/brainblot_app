import "package:flutter/material.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:brainblot_app/core/auth/services/permission_service.dart";
import "package:brainblot_app/core/auth/guards/admin_guard.dart";
import "package:brainblot_app/core/auth/models/user_role.dart";
import "package:brainblot_app/features/admin/ui/user_management_screen.dart";
import "package:brainblot_app/features/admin/ui/subscription_management_screen.dart";
import "package:brainblot_app/features/admin/ui/analytics_screen.dart";
import "package:brainblot_app/features/admin/ui/plan_requests_screen.dart";


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
        appBar: _buildAppBar(context),
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
                const SizedBox(height: 24),
                _buildRealTimeStats(context),
                const SizedBox(height: 24),
                _buildQuickActions(context),
                const SizedBox(height: 24),
                _buildManagementGrid(context),
                const SizedBox(height: 24),
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
      title: const Text("Admin Dashboard"),
      elevation: 0,

    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome, Admin",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          "Manage your platform from this central hub",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildRealTimeStats(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("users").snapshots(),
      builder: (context, userSnapshot) {
        return FutureBuilder<QuerySnapshot>(
          future:
              FirebaseFirestore.instance.collection("subscription_plans").get(),
          builder: (context, planSnapshot) {
            final totalUsers = userSnapshot.data?.docs.length ?? 0;
            final activeUsers = userSnapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lastActive = _parseTimestamp(data["lastActiveAt"]);
                  if (lastActive == null) return false;
                  final date = lastActive.toDate();
                  return date.isAfter(
                      DateTime.now().subtract(const Duration(days: 7)));
                }).length ??
                0;

            final adminCount = userSnapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data["role"] == "admin";
                }).length ??
                0;

            final activePlans = planSnapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data["isActive"] == true;
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
                  title: "Total Users",
                  value: totalUsers.toString(),
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                _buildStatCard(
                  context,
                  title: "Active Users",
                  value: activeUsers.toString(),
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
                _buildStatCard(
                  context,
                  title: "Administrators",
                  value: adminCount.toString(),
                  icon: Icons.admin_panel_settings,
                  color: Colors.red,
                ),
                _buildStatCard(
                  context,
                  title: "Active Plans",
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

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildQuickActionChip(
                context,
                "Add User",
                Icons.person_add,
                Colors.blue,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildQuickActionChip(
                context,
                "Manage Plans",
                Icons.add_card,
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionManagementScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildQuickActionChip(
                context,
                "View Analytics",
                Icons.analytics,
                Colors.purple,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildQuickActionChip(
                context,
                "Plan Requests",
                Icons.receipt_long,
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlanRequestsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionChip(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Management Tools",
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
          childAspectRatio: 1.3,
          children: [
            _buildManagementCard(
              context,
              title: "User Management",
              description: "Manage users, roles & permissions",
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
              title: "Subscriptions",
              description: "Manage plans & pricing",
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
              title: "Plan Requests",
              description: "Review subscription requests",
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
              title: "Analytics",
              description: "View insights & reports",
              icon: Icons.analytics_outlined,
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
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
            Text(
              "Recent Activity",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Full activity log coming soon")),
                );
              },
              child: const Text("View All"),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .orderBy("createdAt", descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "No recent activity",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final displayName =
                      data["displayName"] as String? ?? "Unknown";
                  final createdAt = _parseTimestamp(data["createdAt"]);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child:
                          const Icon(Icons.person_add, color: Colors.blue, size: 20),
                    ),
                    title: const Text(
                      "New user registered",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(displayName),
                    trailing: createdAt != null
                        ? Text(
                            _formatTimeAgo(createdAt.toDate()),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          )
                        : null,
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
      return "Just now";
    } else if (difference.inHours < 1) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inDays < 1) {
      return "${difference.inHours}h ago";
    } else if (difference.inDays < 7) {
      return "${difference.inDays}d ago";
    } else {
      return "${(difference.inDays / 7).floor()}w ago";
    }
  }
}
