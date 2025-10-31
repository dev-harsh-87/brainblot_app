import 'package:flutter/material.dart';
import 'package:brainblot_app/core/auth/services/permission_service.dart';
import 'package:brainblot_app/core/auth/services/session_management_service.dart';
import 'package:brainblot_app/core/utils/create_super_admin.dart';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simple debug screen to test role functionality
class DebugRoleTestScreen extends StatefulWidget {
  const DebugRoleTestScreen({super.key});

  @override
  State<DebugRoleTestScreen> createState() => _DebugRoleTestScreenState();
}

class _DebugRoleTestScreenState extends State<DebugRoleTestScreen> {
  String _status = 'Ready to test...';
  bool _isLoading = false;
  final PermissionService _permissionService = getIt<PermissionService>();
  final SessionManagementService _sessionService = getIt<SessionManagementService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role System Debug'),
        backgroundColor: Colors.red[100],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Role System Test',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _createAdminUser,
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Create Admin User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loginAsAdmin,
                      icon: const Icon(Icons.login),
                      label: const Text('Login as Admin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _checkCurrentRole,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Check Current Role'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testPermissions,
                      icon: const Icon(Icons.security),
                      label: const Text('Test Permissions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAdminUser() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating admin user...';
    });

    try {
      await CreateAdmin.create();
      setState(() {
        _status = 'SUCCESS: Admin user created!\nEmail: admin@brainblot.com\nPassword: Admin@123456';
      });
    } catch (e) {
      setState(() {
        _status = 'ERROR: Failed to create admin user\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loginAsAdmin() async {
    setState(() {
      _isLoading = true;
      _status = 'Logging in as admin...';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'admin@brainblot.com',
        password: 'Admin@123456',
      );

      // Wait for session to establish
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _status = 'SUCCESS: Logged in as admin!';
      });
    } catch (e) {
      setState(() {
        _status = 'ERROR: Failed to login as admin\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentRole() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking current role...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final isLoggedIn = _sessionService.isLoggedIn();
      final isAdmin = await _permissionService.isAdmin();
      final userRole = await _permissionService.getCurrentUserRole();
      final sessionFeatures = _sessionService.getSessionFeatures();

      setState(() {
        _status = '''ROLE CHECK RESULTS:
Current User: ${currentUser?.email ?? 'Not logged in'}
Session Active: $isLoggedIn
Is Admin: $isAdmin
User Role: ${userRole.displayName} (${userRole.value})
Session Features:
  - isLoggedIn: ${sessionFeatures['isLoggedIn']}
  - isAdmin: ${sessionFeatures['isAdmin']}
  - plan: ${sessionFeatures['plan']}''';
      });
    } catch (e) {
      setState(() {
        _status = 'ERROR: Failed to check role\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPermissions() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing permissions...';
    });

    try {
      final canManageUsers = _sessionService.canManageUsers();
      final canAccessAdminContent = _sessionService.canAccessAdminContent();
      final canCreatePrograms = _sessionService.canCreatePrograms();
      final moduleAccess = _sessionService.getModuleAccess();

      setState(() {
        _status = '''PERMISSION TEST RESULTS:
Can Manage Users: $canManageUsers
Can Access Admin Content: $canAccessAdminContent
Can Create Programs: $canCreatePrograms
Module Access: ${moduleAccess.join(', ')}''';
      });
    } catch (e) {
      setState(() {
        _status = 'ERROR: Failed to test permissions\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
      _status = 'Logging out...';
    });

    try {
      await FirebaseAuth.instance.signOut();
      setState(() {
        _status = 'SUCCESS: Logged out!';
      });
    } catch (e) {
      setState(() {
        _status = 'ERROR: Failed to logout\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}