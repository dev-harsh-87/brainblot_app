import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/theme/app_theme.dart';

class RecentActivityScreen extends StatefulWidget {
  const RecentActivityScreen({super.key});

  @override
  State<RecentActivityScreen> createState() => _RecentActivityScreenState();
}

class _RecentActivityScreenState extends State<RecentActivityScreen> {
  final _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all';
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Activity'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildActivityList()),
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
            _buildFilterChip('All Activity', 'all', Icons.all_inclusive),
            const SizedBox(width: 8),
            _buildFilterChip('New Users', 'new_users', Icons.person_add),
            const SizedBox(width: 8),
            _buildFilterChip('Active Today', 'active_today', Icons.trending_up),
            const SizedBox(width: 8),
            _buildFilterChip('This Week', 'this_week', Icons.calendar_today),
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
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading activity',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                const SizedBox(height: 8),
                Text(
                  'Activity will appear here as users join and interact',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final user = AppUser.fromFirestore(doc);
            
            return _buildActivityCard(user, data);
          },
        );
      },
    );
  }

  Widget _buildActivityCard(AppUser user, Map<String, dynamic> data) {
    final createdAt = _parseTimestamp(data['createdAt']);
    final lastActiveAt = _parseTimestamp(data['lastActiveAt']);
    final roleColor = AppTheme.getRoleColor(user.role.value);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: roleColor.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () => _showUserDetailsDialog(user, data),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // User Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          roleColor.withOpacity(0.8),
                          roleColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: roleColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(lastActiveAt),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildInfoChip(
                              user.role.displayName,
                              roleColor,
                              Icons.admin_panel_settings,
                            ),
                            const SizedBox(width: 8),
                            _buildInfoChip(
                              user.subscription.plan.toUpperCase(),
                              AppTheme.getSubscriptionColor(user.subscription.plan),
                              Icons.card_membership,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              // Activity Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActivityInfo(
                    'Joined',
                    createdAt != null ? _formatTimeAgo(createdAt.toDate()) : 'Unknown',
                    Icons.person_add_outlined,
                  ),
                  if (lastActiveAt != null)
                    _buildActivityInfo(
                      'Last Active',
                      _formatTimeAgo(lastActiveAt.toDate()),
                      Icons.access_time,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Timestamp? lastActiveAt) {
    if (lastActiveAt == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Inactive',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    final lastActive = lastActiveAt.toDate();
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    
    final isActive = difference.inMinutes < 30;
    final color = isActive ? Colors.green : Colors.orange;
    final label = isActive ? 'Active' : 'Away';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityInfo(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showUserDetailsDialog(AppUser user, Map<String, dynamic> data) {
    final createdAt = _parseTimestamp(data['createdAt']);
    final lastActiveAt = _parseTimestamp(data['lastActiveAt']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.displayName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user.email),
              _buildDetailRow('Role', user.role.displayName),
              _buildDetailRow('Subscription', user.subscription.plan.toUpperCase()),
              _buildDetailRow('Status', user.subscription.status.toUpperCase()),
              if (createdAt != null)
                _buildDetailRow('Joined', _formatDate(createdAt.toDate())),
              if (lastActiveAt != null)
                _buildDetailRow('Last Active', _formatDate(lastActiveAt.toDate())),
              if (data['createdBy'] != null)
                _buildDetailRow(
                  'Created By',
                  (data['createdBy']['adminName'] as String?) ?? 'Unknown',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    var query = _firestore.collection('users').orderBy('createdAt', descending: true);

    switch (_selectedFilter) {
      case 'new_users':
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        query = _firestore
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
            .orderBy('createdAt', descending: true);
        break;
      case 'active_today':
        final today = DateTime.now().subtract(const Duration(hours: 24));
        query = _firestore
            .collection('users')
            .where('lastActiveAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
            .orderBy('lastActiveAt', descending: true);
        break;
      case 'this_week':
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        query = _firestore
            .collection('users')
            .where('lastActiveAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
            .orderBy('lastActiveAt', descending: true);
        break;
      default:
        query = _firestore.collection('users').orderBy('createdAt', descending: true);
    }

    return query.limit(50).snapshots();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('All Activity'),
              value: 'all',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('New Users'),
              subtitle: const Text('Users joined in last 7 days'),
              value: 'new_users',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Active Today'),
              subtitle: const Text('Users active in last 24 hours'),
              value: 'active_today',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('This Week'),
              subtitle: const Text('Users active in last 7 days'),
              value: 'this_week',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
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
      return _formatDate(date);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}