import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brainblot_app/core/auth/services/permission_service.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';
import 'package:brainblot_app/core/auth/guards/admin_guard.dart';

class UserManagementScreen extends StatefulWidget {
  final PermissionService permissionService;

  const UserManagementScreen({
    super.key,
    required this.permissionService,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      permissionService: widget.permissionService,
      requiredRole: UserRole.superAdmin,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          elevation: 0,
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _buildUserList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search users...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        var users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final email = (data['email'] as String? ?? '').toLowerCase();
          final displayName = (data['displayName'] as String? ?? '').toLowerCase();
          return email.contains(_searchQuery) || displayName.contains(_searchQuery);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index].data() as Map<String, dynamic>;
            return _buildUserCard(context, users[index].id, user);
          },
        );
      },
    );
  }

  Widget _buildUserCard(BuildContext context, String userId, Map<String, dynamic> userData) {
    final email = userData['email'] as String? ?? '';
    final displayName = userData['displayName'] as String? ?? 'Unknown';
    final role = userData['role'] as String? ?? 'user';
    final subscription = userData['subscription'] as Map<String, dynamic>?;
    final plan = subscription?['plan'] as String? ?? 'free';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(role),
          child: Text(
            displayName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildRoleBadge(role),
                const SizedBox(width: 8),
                _buildPlanBadge(plan),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleUserAction(context, userId, value, userData),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit_role',
              child: Text('Change Role'),
            ),
            const PopupMenuItem(
              value: 'edit_subscription',
              child: Text('Change Subscription'),
            ),
            const PopupMenuItem(
              value: 'view_details',
              child: Text('View Details'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete User'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getRoleColor(role).withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _getRoleColor(role),
        ),
      ),
    );
  }

  Widget _buildPlanBadge(String plan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        plan.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return Colors.red;
      case 'admin':
        return Colors.orange;
      case 'premium':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  void _handleUserAction(BuildContext context, String userId, String action, Map<String, dynamic> userData) {
    switch (action) {
      case 'edit_role':
        _showRoleDialog(context, userId, userData['role'] as String? ?? 'user');
        break;
      case 'edit_subscription':
        _showSubscriptionDialog(context, userId);
        break;
      case 'view_details':
        _showUserDetails(context, userData);
        break;
      case 'delete':
        _confirmDelete(context, userId);
        break;
    }
  }

  void _showRoleDialog(BuildContext context, String userId, String currentRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change User Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserRole.values.map((role) {
            return RadioListTile<String>(
              title: Text(role.displayName),
              value: role.value,
              groupValue: currentRole,
              onChanged: (value) async {
                if (value != null) {
                  try {
                    await widget.permissionService.updateUserRole(userId, role);
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
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSubscriptionDialog(BuildContext context, String userId) {
    final plans = ['free', 'premium', 'pro'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: plans.map((plan) {
            return ListTile(
              title: Text(plan.toUpperCase()),
              onTap: () async {
                try {
                  await _firestore.collection('users').doc(userId).update({
                    'subscription.plan': plan,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subscription updated')),
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
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', userData['email'] as String? ?? ''),
              _buildDetailRow('Display Name', userData['displayName'] as String? ?? ''),
              _buildDetailRow('Role', userData['role'] as String? ?? 'user'),
              const Divider(),
              const Text('Subscription:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._buildSubscriptionDetails(userData['subscription'] as Map<String, dynamic>?),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  List<Widget> _buildSubscriptionDetails(Map<String, dynamic>? subscription) {
    if (subscription == null) return [const Text('No subscription data')];
    
    return [
      _buildDetailRow('Plan', subscription['plan'] as String? ?? 'N/A'),
      _buildDetailRow('Status', subscription['status'] as String? ?? 'N/A'),
    ];
  }

  void _confirmDelete(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firestore.collection('users').doc(userId).delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User deleted')),
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}