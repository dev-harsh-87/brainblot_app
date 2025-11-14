import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/theme/app_theme.dart';

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
  String _selectedFilter = 'all';
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
      final plansSnapshot = await _firestore
          .collection('subscription_plans')
          .get();

      for (var doc in plansSnapshot.docs) {
        final data = doc.data();
        final createdAt = _parseTimestamp(data['createdAt']);
        if (createdAt != null) {
          activities.add(ActivityItem(
            id: doc.id,
            type: ActivityType.planCreated,
            title: 'Subscription plan created',
            subtitle: data['name'] as String? ?? 'Unknown',
            timestamp: createdAt.toDate(),
            data: data,
          ),);
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
              subtitle: '${data['userName']} → ${data['requestedPlan']}',
              timestamp: createdAt.toDate(),
              data: data,
            ),);
          }
        }
      } catch (e) {
        debugPrint('Error loading plan requests: $e');
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
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildActivityList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all', Icons.all_inclusive),
            const SizedBox(width: 8),
            _buildFilterChip('Users', 'users', Icons.person),
            const SizedBox(width: 8),
            _buildFilterChip('Plans', 'plans', Icons.card_membership),
      
            const SizedBox(width: 8),
            _buildFilterChip('Requests', 'requests', Icons.receipt_long),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: AppTheme.primaryColor,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.primaryColor,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.3),
      ),
    );
  }

  Widget _buildActivityList() {
    final filteredActivities = _getFilteredActivities();

    if (filteredActivities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No activity found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredActivities.length,
      itemBuilder: (context, index) {
        return _buildActivityCard(filteredActivities[index]);
      },
    );
  }

  List<ActivityItem> _getFilteredActivities() {
    switch (_selectedFilter) {
      case 'users':
        return _activities.where((a) => 
          a.type == ActivityType.userRegistered || 
          a.type == ActivityType.userUpdated,
        ).toList();
      case 'plans':
        return _activities.where((a) => 
          a.type == ActivityType.planCreated || 
          a.type == ActivityType.planUpdated ||
          a.type == ActivityType.planDeleted,
        ).toList();
      case 'requests':
        return _activities.where((a) => a.type == ActivityType.planRequest).toList();
      default:
        return _activities;
    }
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
          child: Icon(config.icon, color: Colors.white, size: 24),
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
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatTimeAgo(activity.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
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
          color: Colors.blue,
          label: 'USER',
        );
      case ActivityType.planCreated:
      case ActivityType.planUpdated:
      case ActivityType.planDeleted:
        return ActivityConfig(
          icon: Icons.card_membership,
          color: Colors.purple,
          label: 'PLAN',
        );
      case ActivityType.planRequest:
        return ActivityConfig(
          icon: Icons.receipt_long,
          color: Colors.amber,
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