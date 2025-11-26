import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/features/subscription/domain/subscription_plan.dart';
import 'package:spark_app/features/subscription/data/subscription_plan_repository.dart';
import 'package:spark_app/core/auth/services/permission_manager.dart';

class UserPermissionManagementScreen extends StatefulWidget {
  final AppUser user;

  const UserPermissionManagementScreen({
    super.key,
    required this.user,
  });

  @override
  State<UserPermissionManagementScreen> createState() => _UserPermissionManagementScreenState();
}

class _UserPermissionManagementScreenState extends State<UserPermissionManagementScreen> {
  final _subscriptionPlanRepository = SubscriptionPlanRepository();
  
  bool _isLoading = false;
  List<SubscriptionPlan> _availablePlans = [];
  UserRole _selectedRole = UserRole.user;
  String? _selectedPlanId;
  List<String> _customModuleAccess = [];
  
  // Available modules that can be granted
  final Map<String, String> _availableModules = {
    'drills': 'Basic Drills',
    'profile': 'User Profile',
    'stats': 'Statistics',
    'analysis': 'Analysis',
    'admin_drills': 'Admin Drill Management',
    'admin_programs': 'Admin Program Management',
    'programs': 'Programs',
    'multiplayer': 'Multiplayer Sessions',
    'user_management': 'User Management',
    'team_management': 'Team Management',
    'bulk_operations': 'Bulk Operations',
    'subscription': 'Subscription Management',
    'admin_user_management': 'Admin User Management',
    'admin_subscription_management': 'Admin Subscription Management',
    'admin_plan_requests': 'Admin Plan Requests',
    'admin_category_management': 'Admin Category Management',
    'admin_stimulus_management': 'Admin Stimulus Management',
    'admin_comprehensive_activity': 'Admin Activity Monitoring',
  };

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.role;
    _selectedPlanId = widget.user.subscription.plan;
    _customModuleAccess = List<String>.from(widget.user.subscription.moduleAccess);
    _loadSubscriptionPlans();
  }

  Future<void> _loadSubscriptionPlans() async {
    try {
      final plans = await _subscriptionPlanRepository.getAllPlans();
      setState(() {
        _availablePlans = plans;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading plans: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage ${widget.user.displayName}'),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveChanges,
            icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfoCard(),
            const SizedBox(height: 24),
            _buildRoleManagement(),
            const SizedBox(height: 24),
            _buildSubscriptionManagement(),
            const SizedBox(height: 24),
            _buildModulePermissions(),
            const SizedBox(height: 24),
            _buildPermissionPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.getRoleColor(widget.user.role.value).withOpacity(0.1),
              child: Text(
                widget.user.displayName.isNotEmpty 
                    ? widget.user.displayName[0].toUpperCase() 
                    : 'U',
                style: TextStyle(
                  color: AppTheme.getRoleColor(widget.user.role.value),
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.email,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusChip(
                        widget.user.role.displayName,
                        AppTheme.getRoleColor(widget.user.role.value),
                        Icons.admin_panel_settings,
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                        widget.user.subscription.plan.toUpperCase(),
                        AppTheme.getSubscriptionColor(widget.user.subscription.plan),
                        Icons.card_membership,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildRoleManagement() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, color: AppTheme.goldPrimary),
                const SizedBox(width: 8),
                const Text(
                  'Role Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Select the user\'s role to determine their base permissions:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...UserRole.values.map((role) => RadioListTile<UserRole>(
              title: Text(role.displayName),
              subtitle: Text(_getRoleDescription(role)),
              value: role,
              groupValue: _selectedRole,
              onChanged: (value) {
                setState(() {
                  _selectedRole = value!;
                  _updateModuleAccessForRole(value);
                });
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionManagement() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_membership, color: AppTheme.goldPrimary),
                const SizedBox(width: 8),
                const Text(
                  'Subscription Plan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Choose a subscription plan to automatically grant module access:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (_availablePlans.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              ..._availablePlans.map((plan) => RadioListTile<String>(
                title: Text(plan.name),
                subtitle: Text('${plan.features.length} features • \$${plan.price}/${plan.billingPeriod}'),
                value: plan.id,
                groupValue: _selectedPlanId,
                onChanged: (value) {
                  setState(() {
                    _selectedPlanId = value;
                    if (value != null) {
                      final selectedPlan = _availablePlans.firstWhere((p) => p.id == value);
                      _customModuleAccess = List<String>.from(selectedPlan.moduleAccess);
                    }
                  });
                },
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildModulePermissions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: AppTheme.goldPrimary),
                const SizedBox(width: 8),
                const Text(
                  'Custom Module Permissions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Fine-tune module access by enabling/disabling specific permissions:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ..._availableModules.entries.map((entry) => CheckboxListTile(
              title: Text(entry.value),
              subtitle: Text('Module: ${entry.key}'),
              value: _customModuleAccess.contains(entry.key),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    if (!_customModuleAccess.contains(entry.key)) {
                      _customModuleAccess.add(entry.key);
                    }
                  } else {
                    _customModuleAccess.remove(entry.key);
                  }
                });
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: AppTheme.goldPrimary),
                const SizedBox(width: 8),
                const Text(
                  'Permission Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'The user will have access to the following modules:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (_customModuleAccess.isEmpty)
              Text(
                'No modules selected',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _customModuleAccess.map((module) => Chip(
                  label: Text(_availableModules[module] ?? module),
                  backgroundColor: AppTheme.successColor.withOpacity(0.1),
                  side: BorderSide(color: AppTheme.successColor.withOpacity(0.3)),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Full system access with administrative privileges';
      case UserRole.user:
        return 'Standard user with limited access based on subscription';
    }
  }

  void _updateModuleAccessForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        _customModuleAccess = List<String>.from(_availableModules.keys);
        break;
      case UserRole.user:
        _customModuleAccess = ['drills', 'profile', 'stats', 'analysis'];
        break;
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      // Update user role and subscription
      // Get current user data first
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final currentSubscription = userData['subscription'] as Map<String, dynamic>? ?? {};
      
      // Update the entire subscription object
      final updatedSubscription = Map<String, dynamic>.from(currentSubscription);
      updatedSubscription['plan'] = _selectedPlanId;
      updatedSubscription['moduleAccess'] = _customModuleAccess;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .update({
        'role': _selectedRole.value,
        'subscription': updatedSubscription,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If the updated user is currently logged in, refresh their permissions
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == widget.user.id) {
        try {
          await PermissionManager.instance.refreshPermissions();
          print('🔄 Updated user permissions manually refreshed');
        } catch (e) {
          print('⚠️ Failed to manually refresh updated user permissions: $e');
          // Don't throw - the automatic refresh via listener should still work
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User permissions updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}