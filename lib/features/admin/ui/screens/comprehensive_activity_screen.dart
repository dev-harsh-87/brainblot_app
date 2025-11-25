import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/core/widgets/app_loader.dart';

enum ActivityType {
  userRegistered,
  userUpdated,
  planCreated,
  planUpdated,
  planDeleted,
  planRequest,
}

class ActivityItem {
  final String id;
  final ActivityType type;
  final String title;
  final String? subtitle;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.timestamp,
    required this.data,
  });
}

class ComprehensiveActivityScreen extends StatefulWidget {
  const ComprehensiveActivityScreen({super.key});

  @override
  State<ComprehensiveActivityScreen> createState() => _ComprehensiveActivityScreenState();
}

class _ComprehensiveActivityScreenState extends State<ComprehensiveActivityScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<ActivityItem> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    
    try {
      final activities = <ActivityItem>[];

      // Load users
      final usersSnapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final createdAt = _parseTimestamp(data['createdAt']);
        if (createdAt != null) {
          activities.add(ActivityItem(
            id: doc.id,
            type: ActivityType.userRegistered,
            title: 'New user registered',
            subtitle: data['displayName'] as String? ?? 'Unknown',
            timestamp: createdAt.toDate(),
            data: data,
          ),);
        }
      }

      // Load subscription plans
      try {
        final plansSnapshot = await _firestore
            .collection('subscription_plans')
            .orderBy('createdAt', descending: true)
            .limit(30)
            .get();

        for (var doc in plansSnapshot.docs) {
          final data = doc.data();
          final createdAt = _parseTimestamp(data['createdAt']);
          if (createdAt != null) {
            activities.add(ActivityItem(
              id: doc.id,
              type: ActivityType.planCreated,
              title: 'Subscription plan created',
              subtitle: data['name'] as String? ?? data['title'] as String? ?? 'Unknown Plan',
              timestamp: createdAt.toDate(),
              data: data,
            ));
          }
        }
      } catch (e) {
        debugPrint('Error loading subscription plans: $e');
        // Try alternative query without ordering if createdAt field doesn't exist or isn't indexed
        try {
          final plansSnapshot = await _firestore
              .collection('subscription_plans')
              .limit(30)
              .get();

          for (var doc in plansSnapshot.docs) {
            final data = doc.data();
            // Try different timestamp field names
            final createdAt = _parseTimestamp(data['createdAt']) ??
                             _parseTimestamp(data['created_at']) ??
                             _parseTimestamp(data['timestamp']);
            
            final timestamp = createdAt?.toDate() ?? DateTime.now();
            
            activities.add(ActivityItem(
              id: doc.id,
              type: ActivityType.planCreated,
              title: 'Subscription plan created',
              subtitle: data['name'] as String? ?? data['title'] as String? ?? 'Unknown Plan',
              timestamp: timestamp,
              data: data,
            ));
          }
        } catch (e2) {
          debugPrint('Error loading subscription plans (fallback): $e2');
        }
      }

      // Load plan requests
      try {
        final requestsSnapshot = await _firestore
            .collection('plan_requests')
            .orderBy('createdAt', descending: true)
            .limit(30)
            .get();

        for (var doc in requestsSnapshot.docs) {
          final data = doc.data();
          final createdAt = _parseTimestamp(data['createdAt']);
          if (createdAt != null) {
            activities.add(ActivityItem(
              id: doc.id,
              type: ActivityType.planRequest,
              title: 'Plan upgrade requested',
              subtitle: '${data['userName'] ?? data['user_name'] ?? 'Unknown User'} → ${data['requestedPlan'] ?? data['requested_plan'] ?? 'Unknown Plan'}',
              timestamp: createdAt.toDate(),
              data: data,
            ));
          }
        }
      } catch (e) {
        debugPrint('Error loading plan requests: $e');
        // Try alternative query without ordering if createdAt field doesn't exist or isn't indexed
        try {
          final requestsSnapshot = await _firestore
              .collection('plan_requests')
              .limit(30)
              .get();

          for (var doc in requestsSnapshot.docs) {
            final data = doc.data();
            // Try different timestamp field names
            final createdAt = _parseTimestamp(data['createdAt']) ??
                             _parseTimestamp(data['created_at']) ??
                             _parseTimestamp(data['timestamp']) ??
                             _parseTimestamp(data['requestedAt']);
            
            final timestamp = createdAt?.toDate() ?? DateTime.now();
            
            activities.add(ActivityItem(
              id: doc.id,
              type: ActivityType.planRequest,
              title: 'Plan upgrade requested',
              subtitle: '${data['userName'] ?? data['user_name'] ?? 'Unknown User'} → ${data['requestedPlan'] ?? data['requested_plan'] ?? 'Unknown Plan'}',
              timestamp: timestamp,
              data: data,
            ));
          }
        } catch (e2) {
          debugPrint('Error loading plan requests (fallback): $e2');
        }
      }

      // Sort all activities by timestamp
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading activities: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Activity Log'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivities,
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoader.fullScreen(message: 'Loading activities...')
          : _buildActivityList(),
    );
  }

  Widget _buildActivityList() {
    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: context.colors.onSurface.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'No activity found',
              style: TextStyle(fontSize: 18, color: context.colors.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(_activities[index]);
      },
    );
  }

  Widget _buildActivityCard(ActivityItem activity) {
    final config = _getActivityConfig(activity.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: config.color.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                config.color.withOpacity(0.8),
                config.color,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: config.color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(config.icon, color: AppTheme.whitePure, size: 24),
        ),
        title: Text(
          activity.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activity.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                activity.subtitle!,
                style: TextStyle(
                  color: context.colors.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: context.colors.onSurface.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(
                  _formatTimeAgo(activity.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: config.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: config.color.withOpacity(0.3)),
          ),
          child: Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  ActivityConfig _getActivityConfig(ActivityType type) {
    switch (type) {
      case ActivityType.userRegistered:
      case ActivityType.userUpdated:
        return ActivityConfig(
          icon: Icons.person,
          color: AppTheme.infoColor,
          label: 'USER',
        );
      case ActivityType.planCreated:
      case ActivityType.planUpdated:
      case ActivityType.planDeleted:
        return ActivityConfig(
          icon: Icons.card_membership,
          color: AppTheme.instituteColor,
          label: 'PLAN',
        );
      case ActivityType.planRequest:
        return ActivityConfig(
          icon: Icons.receipt_long,
          color: AppTheme.warningColor,
          label: 'REQUEST',
        );
    }
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
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class ActivityConfig {
  final IconData icon;
  final Color color;
  final String label;

  ActivityConfig({
    required this.icon,
    required this.color,
    required this.label,
  });
}