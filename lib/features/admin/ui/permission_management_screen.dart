import 'package:flutter/material.dart';
import 'package:brainblot_app/core/auth/services/permission_service.dart';
import 'package:brainblot_app/core/auth/guards/admin_guard.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';
import 'package:brainblot_app/core/auth/models/permission.dart';

class PermissionManagementScreen extends StatelessWidget {
  final PermissionService permissionService;

  const PermissionManagementScreen({
    super.key,
    required this.permissionService,
  });

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      permissionService: permissionService,
      requiredRole: UserRole.admin,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Permission Management'),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Role Permissions',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ...UserRole.values.map((role) => _buildRoleCard(context, role)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, UserRole role) {
    final permissions = role.permissions;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(role),
          child: Icon(
            _getRoleIcon(role),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          role.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${permissions.length} permissions'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permissions:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: permissions.map((permission) => Chip(
                    label: Text(
                      permission.displayName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.green.withOpacity(0.1),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.user:
        return Colors.blue;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.user:
        return Icons.person;
    }
  }
}