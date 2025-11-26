import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/auth/services/user_management_service.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/features/admin/ui/screens/user_form_screen.dart';
import 'package:get_it/get_it.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _userManagementService = GetIt.instance<UserManagementService>();
  final _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  UserRole? _filterRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
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
          _buildSearchBar(),
          Expanded(child: _buildUserList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: context.colors.primary,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.colors.surfaceContainerHighest,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search users by name or email...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: context.colors.surface,
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        print('📊 User stream state: ${snapshot.connectionState}');
        
        if (snapshot.hasError) {
          print('❌ User stream error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⏳ Waiting for user data...');
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          print('📭 No snapshot data received');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: context.colors.onSurface.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text(
                  'No data received',
                  style: TextStyle(fontSize: 18, color: context.colors.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
          );
        }

        final totalDocs = snapshot.data!.docs.length;
        print('📄 Total user documents: $totalDocs');
        
        if (totalDocs == 0) {
          print('📭 No user documents found');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: context.colors.onSurface.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(fontSize: 18, color: context.colors.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
          );
        }

        final users = snapshot.data!.docs.where((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            print('👤 Processing user doc ${doc.id}: ${data.keys.toList()}');
            
            final displayName = (data['displayName'] as String? ?? '').toLowerCase();
            final email = (data['email'] as String? ?? '').toLowerCase();
            final matchesSearch = _searchQuery.isEmpty ||
                displayName.contains(_searchQuery) ||
                email.contains(_searchQuery);

            final role = UserRole.fromString(data['role'] as String? ?? 'user');
            final matchesFilter = _filterRole == null || role == _filterRole;

            final passes = matchesSearch && matchesFilter;
            print('✅ User ${doc.id} passes filter: $passes (search: $matchesSearch, role: $matchesFilter)');
            
            return passes;
          } catch (e) {
            print('❌ Error processing user doc ${doc.id}: $e');
            return false;
          }
        }).toList();
        
        print('📋 Filtered users count: ${users.length}');

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: context.colors.onSurface.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text(
                  'No users match your search',
                  style: TextStyle(fontSize: 18, color: context.colors.onSurface.withOpacity(0.6)),
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
            final data = doc.data() as Map<String, dynamic>;
            
            try {
              final user = AppUser.fromFirestore(doc);
              return _buildUserCard(user, data);
            } catch (e) {
              print('Error parsing user document ${doc.id}: $e');
              // Return a placeholder card for malformed documents
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(Icons.error, color: context.colors.error),
                  title: Text('Error loading user: ${doc.id}'),
                  subtitle: Text('Data parsing error: $e'),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildUserCard(AppUser user, Map<String, dynamic> data) {
    final roleColor = AppTheme.getRoleColor(user.role.value);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: roleColor.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => _showUserDetailsDialog(user, data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: roleColor.withOpacity(0.1),
                    child: Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            color: context.colors.onSurface.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleUserAction(value, user, data),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'manage_user',
                        child: Row(
                          children: [
                            Icon(Icons.manage_accounts, size: 20),
                            SizedBox(width: 8),
                            Text('Edit User'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: context.colors.error),
                            const SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: context.colors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    user.role.displayName,
                    roleColor,
                    Icons.admin_panel_settings,
                  ),
                  _buildChip(
                    user.subscription.plan.toUpperCase(),
                    AppTheme.getSubscriptionColor(user.subscription.plan),
                    Icons.card_membership,
                  ),
                  if (data['createdBy'] != null)
                    _buildChip(
                      'Admin Created',
                      AppTheme.warningColor,
                      Icons.verified_user,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Users'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<UserRole?>(
              title: const Text('All Users'),
              value: null,
              groupValue: _filterRole,
              onChanged: (value) {
                setState(() => _filterRole = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<UserRole?>(
              title: const Text('Admins'),
              value: UserRole.admin,
              groupValue: _filterRole,
              onChanged: (value) {
                setState(() => _filterRole = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<UserRole?>(
              title: const Text('Regular Users'),
              value: UserRole.user,
              groupValue: _filterRole,
              onChanged: (value) {
                setState(() => _filterRole = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateUserDialog() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const UserFormScreen(),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User created successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  void _handleUserAction(String action, AppUser user, Map<String, dynamic> data) {
    switch (action) {
      case 'manage_user':
        _showManageSubscriptionDialog(user);
        break;
      case 'delete':
        _showDeleteConfirmation(user);
        break;
    }
  }

  void _showUserDetailsDialog(AppUser user, Map<String, dynamic> data) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.getRoleColor(user.role.value).withOpacity(0.1),
              child: Text(
                user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: AppTheme.getRoleColor(user.role.value),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user.displayName,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user.email),
              _buildDetailRow('Role', user.role.displayName),
              _buildDetailRow('Subscription Plan', user.subscription.plan.toUpperCase()),
              _buildDetailRow('Subscription Status', user.subscription.status.toUpperCase()),
              if (user.subscription.moduleAccess.isNotEmpty)
                _buildDetailRow('Module Access', user.subscription.moduleAccess.join(', ')),
              if (user.subscription.expiresAt != null)
                _buildDetailRow('Expires At', _formatDate(user.subscription.expiresAt!)),
              _buildDetailRow('Account Status', user.subscription.isActive() ? 'Active' : 'Inactive'),
              _buildDetailRow('Created', user.createdAt != null ? _formatDate(user.createdAt!) : 'N/A'),
              if (user.lastActiveAt != null)
                _buildDetailRow('Last Active', _formatDate(user.lastActiveAt!)),
              if (data['createdBy'] != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Admin Created User',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Created By',
                  (data['createdBy']['adminName'] as String?) ?? 'Unknown Admin',
                ),
                if (data['createdBy']['adminEmail'] != null)
                  _buildDetailRow(
                    'Admin Email',
                    data['createdBy']['adminEmail'] as String,
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showManageSubscriptionDialog(user);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit User'),
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

  






  void _showManageSubscriptionDialog(AppUser user) async {
    final subscriptionData = {
      'planId': user.subscription.plan, // UserFormScreen expects 'planId'
      'plan': user.subscription.plan,   // Keep for compatibility
      'status': user.subscription.status,
      'moduleAccess': user.subscription.moduleAccess,
      'expiresAt': user.subscription.expiresAt?.toIso8601String(),
    };
    
    final userData = {
      'displayName': user.displayName,
      'email': user.email,
      'role': user.role.value,
      'subscription': subscriptionData,
    };
    
    // Debug logging
    print('🔍 UserManagement: Passing user data: $userData');
    print('🔍 UserManagement: User subscription plan: ${user.subscription.plan}');
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => UserFormScreen(
          userId: user.id,
          existingUserData: userData,
          isEdit: true,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User updated successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }




  void _showDeleteConfirmation(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete "${user.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteUser(user.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await _userManagementService.deleteUser(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: ${e.toString()}'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}