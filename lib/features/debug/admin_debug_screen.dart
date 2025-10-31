import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/core/utils/create_super_admin.dart' as create_admin;

/// Debug screen to check and create Super Admin account
class AdminDebugScreen extends StatefulWidget {
  const AdminDebugScreen({super.key});

  @override
  State<AdminDebugScreen> createState() => _AdminDebugScreenState();
}

class _AdminDebugScreenState extends State<AdminDebugScreen> {
  String _status = 'Checking...';
  bool _isLoading = true;
  Map<String, dynamic>? _adminData;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking database...';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Check for super admin in Firestore
      final querySnapshot = await firestore
          .collection('users')
          .where('email', isEqualTo: 'admin@brainblot.com')
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _status = 'Admin NOT found in database';
          _adminData = null;
          _isLoading = false;
        });
      } else {
        final doc = querySnapshot.docs.first;
        setState(() {
          _status = 'Admin found!';
          _adminData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error checking: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createAdmin() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating Super Admin...';
    });

    try {
      await create_admin.CreateAdmin.create();
      await _checkAdmin();
    } catch (e) {
      setState(() {
        _status = 'Error creating Super Admin: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing login...';
    });

    try {
      final auth = FirebaseAuth.instance;
      final credentials = create_admin.CreateAdmin.getCredentials();
      
      await auth.signInWithEmailAndPassword(
        email: credentials['email']!,
        password: credentials['password']!,
      );

      setState(() {
        _status = 'Login successful!';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Super Admin login successful!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _status = 'Login failed: $e';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final credentials = create_admin.CreateAdmin.getCredentials();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Debug'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Card(
                    color: _adminData != null ? Colors.green[50] : Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _status,
                            style: TextStyle(
                              fontSize: 16,
                              color: _adminData != null ? Colors.green[900] : Colors.orange[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Credentials Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Super Admin Credentials',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _buildCredentialRow('Email:', credentials['email']!),
                          const SizedBox(height: 8),
                          _buildCredentialRow('Password:', credentials['password']!),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data Card (if exists)
                  if (_adminData != null) ...[
                    Card(
                      color: Colors.purple[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Database Record',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            _buildDataRow('ID:', _adminData!['id']?.toString()),
                            _buildDataRow('Email:', _adminData!['email']?.toString()),
                            _buildDataRow('Display Name:', _adminData!['displayName']?.toString()),
                            _buildDataRow('Role:', _adminData!['role']?.toString()),
                            _buildDataRow('Created:', _adminData!['createdAt']?.toString() ?? 'N/A'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons
                  if (_adminData == null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _createAdmin,
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Create Super Admin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _testLogin,
                        icon: const Icon(Icons.login),
                        label: const Text('Test Login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _checkAdmin,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}