import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:brainblot_app/core/auth/services/permission_service.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';
import 'package:brainblot_app/core/auth/models/app_user.dart';
import 'package:brainblot_app/core/auth/guards/admin_guard.dart';

class EnhancedUserManagementScreen extends StatefulWidget {
  final PermissionService permissionService;

  const EnhancedUserManagementScreen({
    super.key,
    required this.permissionService,
  });

  @override
  State<EnhancedUserManagementScreen> createState() => _EnhancedUserManagementScreenState();
}

class _EnhancedUserManagementScreenState extends State<EnhancedUserManagementScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  
  String _searchQuery = '';
  String _selectedRole = 'all';
  String _selectedPlan = 'all';
  String _sortBy = 'createdAt';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Helper method to determine if a field contains date data
  bool _isDateField(String fieldName) {
    return fieldName == 'createdAt' || fieldName == 'lastActiveAt' || fieldName.contains('Date') || fieldName.contains('At');
  }

  // Helper method to safely parse timestamp from various formats
  Timestamp? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is String) {
      try {
        // Try parsing ISO string format
        final dateTime = DateTime.parse(value);
        return Timestamp.fromDate(dateTime);
      } catch (e) {
        // If parsing fails, return null
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      permissionService: widget.permissionService,
      requiredRole: UserRole.admin,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildFiltersSection(),
            _buildStatsBar(),
            Expanded(child: _buildUsersList()),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateUserDialog(),
          icon: const Icon(Icons.person_add),
          label: const Text('Add User'),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('User Management'),
      elevation: 0,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'All Users'),
          Tab(text: 'Active'),
          Tab(text: 'Recently Added'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.download),
          tooltip: 'Export Users',
          onPressed: _exportUsers,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Role',
                  _selectedRole,
                  ['all', 'admin', 'user'],
                  (value) => setState(() => _selectedRole = value),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Plan',
                  _selectedPlan,
                  ['all', 'free', 'player', 'institute'],
                  (value) => setState(() => _selectedPlan = value),
                ),
                const SizedBox(width: 8),
                _buildSortChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, List<String> options, Function(String) onChanged) {
    return PopupMenuButton<String>(
      child: Chip(
        avatar: const Icon(Icons.filter_list, size: 18),
        label: Text('$label: ${value.toUpperCase()}'),
        deleteIcon: value != 'all' ? const Icon(Icons.close, size: 18) : null,
        onDeleted: value != 'all' ? () => onChanged('all') : null,
      ),
      onSelected: onChanged,
      itemBuilder: (context) => options.map((option) => PopupMenuItem(
        value: option,
        child: Text(option.toUpperCase()),
      )).toList(),
    );
  }

  Widget _buildSortChip() {
    return PopupMenuButton<String>(
      child: Chip(
        avatar: Icon(
          _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
          size: 18,
        ),
        label: Text('Sort: ${_sortBy.toUpperCase()}'),
      ),
      onSelected: (value) => setState(() {
        if (value == _sortBy) {
          _sortAscending = !_sortAscending;
        } else {
          _sortBy = value;
          _sortAscending = false;
        }
      }),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'createdAt', child: Text('Created Date')),
        const PopupMenuItem(value: 'displayName', child: Text('Name')),
        const PopupMenuItem(value: 'email', child: Text('Email')),
        const PopupMenuItem(value: 'lastActiveAt', child: Text('Last Active')),
      ],
    );
  }

  Widget _buildStatsBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final users = snapshot.data!.docs;
        final totalUsers = users.length;
        final adminCount = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] == 'admin';
        }).length;
        final activeToday = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final lastActive = data['lastActiveAt'];
          if (lastActive == null) return false;
          final date = (lastActive as Timestamp).toDate();
          return date.isAfter(DateTime.now().subtract(const Duration(days: 1)));
        }).length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Users', totalUsers.toString(), Icons.people, Colors.blue),
              _buildStatItem('Admins', adminCount.toString(), Icons.admin_panel_settings, Colors.red),
              _buildStatItem('Active Today', activeToday.toString(), Icons.online_prediction, Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
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
                Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first user to get started',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        var users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = (data['email'] as String? ?? '').toLowerCase();
          final displayName = (data['displayName'] as String? ?? '').toLowerCase();
          final role = data['role'] as String? ?? 'user';
          final plan = (data['subscription'] as Map<String, dynamic>?)?['plan'] as String? ?? 'free';

          final matchesSearch = _searchQuery.isEmpty ||
              email.contains(_searchQuery) ||
              displayName.contains(_searchQuery);
          final matchesRole = _selectedRole == 'all' || role == _selectedRole;
          final matchesPlan = _selectedPlan == 'all' || plan == _selectedPlan;

          return matchesSearch && matchesRole && matchesPlan;
        }).toList();

        // Sort users
        users.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          dynamic aValue = aData[_sortBy];
          dynamic bValue = bData[_sortBy];
          
          // Handle null values first
          if (aValue == null && bValue == null) return 0;
          if (aValue == null) return 1;
          if (bValue == null) return -1;
          
          // Handle Timestamp conversion
          if (aValue is Timestamp) aValue = aValue.toDate();
          if (bValue is Timestamp) bValue = bValue.toDate();
          
          // Handle String representations of dates (ISO format or other formats)
          if (aValue is String && _isDateField(_sortBy)) {
            try {
              aValue = DateTime.parse(aValue);
            } catch (e) {
              // If parsing fails, treat as string comparison
            }
          }
          if (bValue is String && _isDateField(_sortBy)) {
            try {
              bValue = DateTime.parse(bValue);
            } catch (e) {
              // If parsing fails, treat as string comparison
            }
          }
          
          // Ensure both values are the same type for comparison
          if (aValue.runtimeType != bValue.runtimeType) {
            // Convert both to strings for safe comparison
            aValue = aValue.toString();
            bValue = bValue.toString();
          }
          
          // Safe comparison with type checking
          int comparison = 0;
          try {
            if (aValue is Comparable && bValue is Comparable) {
              comparison = _sortAscending
                  ? Comparable.compare(aValue, bValue)
                  : Comparable.compare(bValue, aValue);
            } else {
              // Fallback to string comparison
              comparison = _sortAscending
                  ? aValue.toString().compareTo(bValue.toString())
                  : bValue.toString().compareTo(aValue.toString());
            }
          } catch (e) {
            // Ultimate fallback to string comparison
            comparison = _sortAscending
                ? aValue.toString().compareTo(bValue.toString())
                : bValue.toString().compareTo(aValue.toString());
          }
          
          return comparison;
        });

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No users match your filters',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _selectedRole = 'all';
                      _selectedPlan = 'all';
                      _searchController.clear();
                    });
                  },
                  child: const Text('Clear Filters'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final doc = users[index];
            final userData = doc.data() as Map<String, dynamic>;
            return _buildEnhancedUserCard(context, doc.id, userData);
          },
        );
      },
    );
  }

  Widget _buildEnhancedUserCard(BuildContext context, String userId, Map<String, dynamic> userData) {
    final email = userData['email'] as String? ?? '';
    final displayName = userData['displayName'] as String? ?? 'Unknown';
    final role = userData['role'] as String? ?? 'user';
    final profileImageUrl = userData['profileImageUrl'] as String?;
    final subscription = userData['subscription'] as Map<String, dynamic>?;
    final plan = subscription?['plan'] as String? ?? 'free';
    final status = subscription?['status'] as String? ?? 'active';
    final stats = userData['stats'] as Map<String, dynamic>?;
    final createdAt = _parseTimestamp(userData['createdAt']);
    final lastActiveAt = _parseTimestamp(userData['lastActiveAt']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showUserDetailsDialog(userId, userData),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: _getRoleColor(role),
                backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                child: profileImageUrl == null
                    ? Text(
                        displayName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastActiveAt != null)
                          _buildActivityIndicator(lastActiveAt.toDate()),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildBadge(role.toUpperCase(), _getRoleColor(role)),
                        _buildBadge(plan.toUpperCase(), _getPlanColor(plan)),
                        _buildBadge(status.toUpperCase(), _getStatusColor(status)),
                        if (stats != null)
                          _buildStatsBadge(stats),
                      ],
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Joined ${_formatDate(createdAt.toDate())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleUserAction(context, userId, value, userData),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 20),
                        SizedBox(width: 12),
                        Text('View Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 12),
                        Text('Edit User'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'change_role',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 20),
                        SizedBox(width: 12),
                        Text('Change Role'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'change_subscription',
                    child: Row(
                      children: [
                        Icon(Icons.card_membership, size: 20),
                        SizedBox(width: 12),
                        Text('Change Subscription'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete User', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatsBadge(Map<String, dynamic> stats) {
    final totalSessions = stats['totalSessions'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up, size: 12, color: Colors.purple),
          const SizedBox(width: 4),
          Text(
            '$totalSessions sessions',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityIndicator(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    
    Color indicatorColor;
    String tooltip;
    
    if (difference.inMinutes < 5) {
      indicatorColor = Colors.green;
      tooltip = 'Online now';
    } else if (difference.inHours < 1) {
      indicatorColor = Colors.orange;
      tooltip = 'Active recently';
    } else if (difference.inDays < 7) {
      indicatorColor = Colors.blue;
      tooltip = 'Active this week';
    } else {
      indicatorColor = Colors.grey;
      tooltip = 'Inactive';
    }
    
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: indicatorColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: indicatorColor.withOpacity(0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Color _getPlanColor(String plan) {
    switch (plan) {
      case 'free':
        return Colors.grey;
      case 'player':
        return Colors.blue;
      case 'institute':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  void _handleUserAction(BuildContext context, String userId, String action, Map<String, dynamic> userData) {
    switch (action) {
      case 'view':
        _showUserDetailsDialog(userId, userData);
        break;
      case 'edit':
        _showEditUserDialog(userId, userData);
        break;
      case 'change_role':
        _showRoleDialog(context, userId, userData['role'] as String? ?? 'user');
        break;
      case 'change_subscription':
        _showSubscriptionDialog(context, userId, userData);
        break;
      case 'delete':
        _confirmDelete(context, userId, userData['displayName'] as String? ?? 'this user');
        break;
    }
  }

  void _showCreateUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.user;
    String selectedPlan = 'free';
    bool _obscurePassword = true;
    bool _isCreating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.admin_panel_settings),
                  ),
                  items: UserRole.values.map((role) => DropdownMenuItem(
                    value: role,
                    child: Text(role.displayName),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedRole = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPlan,
                  decoration: const InputDecoration(
                    labelText: 'Subscription Plan',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.card_membership),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'free', child: Text('Free')),
                    DropdownMenuItem(value: 'player', child: Text('Player')),
                    DropdownMenuItem(value: 'institute', child: Text('Institute')),
                  ],
                  onChanged: (value) => setState(() => selectedPlan = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isCreating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isCreating ? null : () async {
                if (nameController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }

                if (passwordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters long')),
                  );
                  return;
                }

                setState(() => _isCreating = true);

                try {
                  // Store the current admin user info BEFORE creating new user
                  final currentUser = _auth.currentUser;
                  final currentAdminId = currentUser?.uid;
                  final currentAdminEmail = currentUser?.email;
                  final currentAdminName = currentUser?.displayName;
                  
                  // We need to get admin credentials to re-authenticate later
                  if (currentAdminEmail == null) {
                    throw Exception('No admin user found');
                  }
                  
                  // Create Firebase Auth account for the new user
                  final userCredential = await _auth.createUserWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );

                  // Update display name in Firebase Auth
                  await userCredential.user?.updateDisplayName(nameController.text);

                  // Create subscription object
                  UserSubscription subscription;
                  switch (selectedPlan) {
                    case 'player':
                      subscription = UserSubscription.player();
                      break;
                    case 'institute':
                      subscription = UserSubscription.institute();
                      break;
                    default:
                      subscription = UserSubscription.free();
                  }

                  // Create user document in Firestore using the Firebase Auth UID
                  final newUser = AppUser(
                    id: userCredential.user!.uid,
                    email: emailController.text.trim(),
                    displayName: nameController.text,
                    role: selectedRole,
                    subscription: subscription,
                    preferences: const UserPreferences(),
                    stats: const UserStats(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  // Add the user data to Firestore with admin tracking
                  final userData = newUser.toFirestore();
                  userData['createdBy'] = {
                    'adminId': currentAdminId,
                    'adminEmail': currentAdminEmail,
                    'adminName': currentAdminName ?? 'Unknown Admin',
                    'createdAt': FieldValue.serverTimestamp(),
                  };

                  await _firestore.collection('users').doc(newUser.id).set(userData);

                  // Sign out the newly created user
                  await _auth.signOut();

                  // Important: Show a dialog to re-authenticate the admin
                  if (context.mounted) {
                    Navigator.pop(context);
                    _showAdminReauthDialog(currentAdminEmail, nameController.text, emailController.text.trim());
                  }
                } catch (e) {
                  setState(() => _isCreating = false);
                  
                  String errorMessage = 'Error creating user';
                  if (e is FirebaseAuthException) {
                    switch (e.code) {
                      case 'email-already-in-use':
                        errorMessage = 'Email is already registered';
                        break;
                      case 'invalid-email':
                        errorMessage = 'Invalid email address';
                        break;
                      case 'weak-password':
                        errorMessage = 'Password is too weak';
                        break;
                      default:
                        errorMessage = 'Authentication error: ${e.message}';
                    }
                  } else {
                    errorMessage = 'Error: $e';
                  }
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminReauthDialog(String adminEmail, String createdUserName, String createdUserEmail) {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing without authentication
      builder: (context) => _AdminReauthDialog(
        adminEmail: adminEmail,
        createdUserName: createdUserName,
        createdUserEmail: createdUserEmail,
        passwordController: passwordController,
        auth: _auth,
      ),
    );
  }

  void _showEditUserDialog(String userId, Map<String, dynamic> userData) {
    final nameController = TextEditingController(text: userData['displayName'] as String? ?? '');
    final emailController = TextEditingController(text: userData['email'] as String? ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('users').doc(userId).update({
                  'displayName': nameController.text,
                  'email': emailController.text,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User updated successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUserDetailsDialog(String userId, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getRoleColor(userData['role'] as String? ?? 'user'),
              child: Text(
                (userData['displayName'] as String? ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userData['displayName'] as String? ?? 'Unknown',
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    userData['email'] as String? ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailSection('Account Information', [
                _buildDetailRow('User ID', userId),
                _buildDetailRow('Role', (userData['role'] as String? ?? 'user').toUpperCase()),
                if (userData['createdAt'] != null)
                  _buildDetailRow('Joined', DateFormat('MMM d, yyyy').format((userData['createdAt'] as Timestamp).toDate())),
                if (userData['lastActiveAt'] != null)
                  _buildDetailRow('Last Active', DateFormat('MMM d, yyyy HH:mm').format((userData['lastActiveAt'] as Timestamp).toDate())),
              ]),
              const Divider(height: 24),
              _buildDetailSection('Subscription', _buildSubscriptionDetails(userData['subscription'] as Map<String, dynamic>?)),
              const Divider(height: 24),
              _buildDetailSection('Statistics', _buildStatsDetails(userData['stats'] as Map<String, dynamic>?)),
              const Divider(height: 24),
              _buildDetailSection('Preferences', _buildPreferencesDetails(userData['preferences'] as Map<String, dynamic>?)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showEditUserDialog(userId, userData);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSubscriptionDetails(Map<String, dynamic>? subscription) {
    if (subscription == null) {
      return [const Text('No subscription data', style: TextStyle(color: Colors.grey))];
    }

    return [
      _buildDetailRow('Plan', (subscription['plan'] as String? ?? 'free').toUpperCase()),
      _buildDetailRow('Status', (subscription['status'] as String? ?? 'active').toUpperCase()),
      if (subscription['expiresAt'] != null)
        _buildDetailRow('Expires', DateFormat('MMM d, yyyy').format((subscription['expiresAt'] as Timestamp).toDate())),
      if (subscription['moduleAccess'] != null)
        _buildDetailRow('Modules', (subscription['moduleAccess'] as List).length.toString()),
    ];
  }

  List<Widget> _buildStatsDetails(Map<String, dynamic>? stats) {
    if (stats == null) {
      return [const Text('No statistics available', style: TextStyle(color: Colors.grey))];
    }

    return [
      _buildDetailRow('Total Sessions', (stats['totalSessions'] as int? ?? 0).toString()),
      _buildDetailRow('Drills Completed', (stats['totalDrillsCompleted'] as int? ?? 0).toString()),
      _buildDetailRow('Programs Completed', (stats['totalProgramsCompleted'] as int? ?? 0).toString()),
      _buildDetailRow('Avg Accuracy', '${(stats['averageAccuracy'] as num? ?? 0).toStringAsFixed(1)}%'),
      _buildDetailRow('Streak Days', (stats['streakDays'] as int? ?? 0).toString()),
    ];
  }

  List<Widget> _buildPreferencesDetails(Map<String, dynamic>? preferences) {
    if (preferences == null) {
      return [const Text('No preferences set', style: TextStyle(color: Colors.grey))];
    }

    return [
      _buildDetailRow('Theme', (preferences['theme'] as String? ?? 'system').toUpperCase()),
      _buildDetailRow('Language', (preferences['language'] as String? ?? 'en').toUpperCase()),
      _buildDetailRow('Notifications', (preferences['notifications'] as bool? ?? false) ? 'Enabled' : 'Disabled'),
      _buildDetailRow('Sound', (preferences['soundEnabled'] as bool? ?? false) ? 'Enabled' : 'Disabled'),
    ];
  }

  void _showRoleDialog(BuildContext context, String userId, String currentRole) {
    UserRole selectedRole = UserRole.fromString(currentRole);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change User Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: UserRole.values.map((role) {
              return RadioListTile<UserRole>(
                title: Text(role.displayName),
                subtitle: Text(role == UserRole.admin
                    ? 'Full system access and management capabilities'
                    : 'Standard user with subscription-based access'),
                value: role,
                groupValue: selectedRole,
                onChanged: (value) => setState(() => selectedRole = value!),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await widget.permissionService.updateUserRole(userId, selectedRole);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Role updated successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionDialog(BuildContext context, String userId, Map<String, dynamic> userData) {
    final currentSubscription = userData['subscription'] as Map<String, dynamic>?;
    String selectedPlan = currentSubscription?['plan'] as String? ?? 'free';
    String selectedStatus = currentSubscription?['status'] as String? ?? 'active';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Subscription'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedPlan,
                decoration: const InputDecoration(
                  labelText: 'Plan',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'free', child: Text('Free')),
                  DropdownMenuItem(value: 'player', child: Text('Player')),
                  DropdownMenuItem(value: 'institute', child: Text('Institute')),
                ],
                onChanged: (value) => setState(() => selectedPlan = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                ],
                onChanged: (value) => setState(() => selectedStatus = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  UserSubscription newSubscription;
                  switch (selectedPlan) {
                    case 'player':
                      newSubscription = UserSubscription.player();
                      break;
                    case 'institute':
                      newSubscription = UserSubscription.institute();
                      break;
                    default:
                      newSubscription = UserSubscription.free();
                  }

                  newSubscription = newSubscription.copyWith(status: selectedStatus);

                  await _firestore.collection('users').doc(userId).update({
                    'subscription': newSubscription.toJson(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subscription updated successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String userId, String displayName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete $displayName? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('users').doc(userId).delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportUsers() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _AdminReauthDialog extends StatefulWidget {
  final String adminEmail;
  final String createdUserName;
  final String createdUserEmail;
  final TextEditingController passwordController;
  final FirebaseAuth auth;

  const _AdminReauthDialog({
    required this.adminEmail,
    required this.createdUserName,
    required this.createdUserEmail,
    required this.passwordController,
    required this.auth,
  });

  @override
  State<_AdminReauthDialog> createState() => _AdminReauthDialogState();
}

class _AdminReauthDialogState extends State<_AdminReauthDialog> {
  bool _obscurePassword = true;
  bool _isReauthenticating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Admin Re-authentication Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'User "${widget.createdUserName}" has been created successfully!\n\nPlease re-enter your admin password to continue:',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Admin Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            autofocus: true,
            onSubmitted: (_) => _handleAdminReauth(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('User Created Successfully:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('Email: ${widget.createdUserEmail}', style: const TextStyle(fontSize: 12)),
                      const Text('The user can now log in with their credentials.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: _isReauthenticating ? null : _handleAdminReauth,
          child: _isReauthenticating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Continue as Admin'),
        ),
      ],
    );
  }

  Future<void> _handleAdminReauth() async {
    if (widget.passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your admin password')),
      );
      return;
    }

    setState(() => _isReauthenticating = true);

    try {
      // Re-authenticate the admin
      await widget.auth.signInWithEmailAndPassword(
        email: widget.adminEmail,
        password: widget.passwordController.text,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back, Admin!'),
                const SizedBox(height: 4),
                Text('User "${widget.createdUserName}" created successfully:', style: const TextStyle(fontSize: 12)),
                Text('Email: ${widget.createdUserEmail}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                const Text('The user can now log in with their credentials.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isReauthenticating = false);
      
      String errorMessage = 'Incorrect password';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'wrong-password':
            errorMessage = 'Incorrect admin password';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid admin email';
            break;
          case 'user-not-found':
            errorMessage = 'Admin account not found';
            break;
          default:
            errorMessage = 'Authentication error: ${e.message}';
        }
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}