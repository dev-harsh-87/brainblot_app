import 'package:flutter/material.dart';
import 'package:spark_app/core/utils/admin_test_utility.dart';

/// Debug screen for testing admin account functionality
class AdminDebugScreen extends StatefulWidget {
  const AdminDebugScreen({super.key});

  @override
  State<AdminDebugScreen> createState() => _AdminDebugScreenState();
}

class _AdminDebugScreenState extends State<AdminDebugScreen> {
  String _output = 'Ready to test admin account functionality...';
  bool _isLoading = false;

  void _updateOutput(String message) {
    setState(() {
      _output = message;
    });
  }

  void _appendOutput(String message) {
    setState(() {
      _output += '\n$message';
    });
  }

  Future<void> _runTest(String testName, Future<void> Function() testFunction) async {
    setState(() {
      _isLoading = true;
      _output = 'Running $testName...\n';
    });

    try {
      await testFunction();
      _appendOutput('\n✅ $testName completed successfully!');
    } catch (e) {
      _appendOutput('\n❌ $testName failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Debug Console'),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Account Debug Console',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use these tools to test and debug admin account functionality.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _runTest(
                    'Admin Account Creation Test',
                    AdminTestUtility.testAdminAccount,
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Test Admin Account'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _runTest(
                    'Manual Admin Creation',
                    AdminTestUtility.manuallyCreateAdminAccount,
                  ),
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Create Admin'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _runTest(
                    'Admin Status Check',
                    AdminTestUtility.getAdminAccountStatus,
                  ),
                  icon: const Icon(Icons.info),
                  label: const Text('Check Status'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _runTest(
                    'Admin Account Reset',
                    AdminTestUtility.resetAdminAccount,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Admin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Admin Credentials Card
            Card(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Admin Credentials',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCredentialRow('Email', 'admin@gmail.com', Icons.email),
                    const SizedBox(height: 8),
                    _buildCredentialRow('Password', 'Admin@1234', Icons.lock),
                    const SizedBox(height: 8),
                    _buildCredentialRow('Role', 'admin', Icons.security),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Output Console
            Expanded(
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.terminal,
                            size: 20,
                            color: colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Console Output',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_isLoading)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        child: SingleChildScrollView(
                          child: Text(
                            _output,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            // Copy to clipboard functionality could be added here
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copied: $value'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy, size: 16),
          tooltip: 'Copy $label',
        ),
      ],
    );
  }
}