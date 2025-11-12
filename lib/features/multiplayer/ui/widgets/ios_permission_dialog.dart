import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spark_app/core/services/ios_permission_service.dart';

/// Enhanced permission dialog specifically designed for iOS permission flow
class IOSPermissionDialog extends StatefulWidget {
  final VoidCallback? onPermissionsGranted;
  final VoidCallback? onDismiss;

  const IOSPermissionDialog({
    super.key,
    this.onPermissionsGranted,
    this.onDismiss,
  });

  @override
  State<IOSPermissionDialog> createState() => _IOSPermissionDialogState();
}

class _IOSPermissionDialogState extends State<IOSPermissionDialog> {
  bool _isLoading = false;
  String _statusMessage = '';
  Map<String, dynamic>? _permissionDetails;

  @override
  void initState() {
    super.initState();
    _loadPermissionStatus();
  }

  Future<void> _loadPermissionStatus() async {
    final details = await IOSPermissionService.getDetailedStatus();
    if (mounted) {
      setState(() {
        _permissionDetails = details;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(
            Icons.settings_rounded,
            color: Colors.blue,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'iOS Permissions Required',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multiplayer features require Bluetooth and Location permissions.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            
            // Permission Status
            if (_permissionDetails != null) _buildPermissionStatus(),
            
            const SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Follow these steps:',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStep('1', 'Tap "Open iOS Settings" below'),
                  _buildStep('2', 'Look for "Spark" in the app list'),
                  _buildStep('3', 'If you see it, enable any permissions shown'),
                  const SizedBox(height: 8),
                  Text(
                    'If Spark is not in the app list:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStep('A', 'Go to Settings > Privacy & Security'),
                  _buildStep('B', 'Tap "Bluetooth" → Enable for Spark'),
                  _buildStep('C', 'Go back, tap "Location Services"'),
                  _buildStep('D', 'Enable Location for Spark'),
                  _buildStep('E', 'Return to Spark and try again'),
                ],
              ),
            ),
            
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  _statusMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.orange[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () {
            widget.onDismiss?.call();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _checkPermissions,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Check Again'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _openSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Open iOS Settings'),
        ),
      ],
    );
  }

  Widget _buildPermissionStatus() {
    final bluetooth = _permissionDetails!['bluetooth'] as Map<String, dynamic>?;
    final location = _permissionDetails!['location'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Status:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (bluetooth != null)
            _buildPermissionStatusRow('Bluetooth', bluetooth['isGranted'] as bool),
          if (location != null)
            _buildPermissionStatusRow('Location', location['isGranted'] as bool),
        ],
      ),
    );
  }

  Widget _buildPermissionStatusRow(String name, bool isGranted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.cancel,
            color: isGranted ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$name: ${isGranted ? 'Granted' : 'Denied'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening iOS Settings...';
    });

    try {
      final opened = await IOSPermissionService.openSettings();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = opened 
              ? 'Settings opened. Please enable permissions and return to Spark.'
              : 'Could not open Settings. Please open Settings manually.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error opening Settings: $e';
        });
      }
    }
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking permissions...';
    });

    try {
      final granted = await IOSPermissionService.arePermissionsGranted();
      await _loadPermissionStatus();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = granted 
              ? 'All permissions granted!' 
              : 'Some permissions are still missing.';
        });

        if (granted) {
          widget.onPermissionsGranted?.call();
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error checking permissions: $e';
        });
      }
    }
  }
}