import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:spark_app/core/services/enhanced_ios_permission_service.dart';

/// Enhanced iOS permission dialog that provides clear guidance and multiple options
class IOSPermissionDialog extends StatefulWidget {
  final String title;
  final String message;
  final bool needsSettings;
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;

  const IOSPermissionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.needsSettings,
    this.onPermissionGranted,
    this.onPermissionDenied,
  });

  /// Show the iOS permission dialog
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required bool needsSettings,
    VoidCallback? onPermissionGranted,
    VoidCallback? onPermissionDenied,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => IOSPermissionDialog(
        title: title,
        message: message,
        needsSettings: needsSettings,
        onPermissionGranted: onPermissionGranted,
        onPermissionDenied: onPermissionDenied,
      ),
    );
  }

  @override
  State<IOSPermissionDialog> createState() => _IOSPermissionDialogState();
}

class _IOSPermissionDialogState extends State<IOSPermissionDialog> {
  bool _isRequesting = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.security,
            color: Colors.blue,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
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
              widget.message,
              style: const TextStyle(fontSize: 16),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.needsSettings) ...[
              const SizedBox(height: 16),
              _buildSettingsInstructions(),
            ],
            if (_isRequesting) ...[
              const SizedBox(height: 16),
              const Center(
                child: Column(
                  children: [
                    CupertinoActivityIndicator(),
                    SizedBox(height: 8),
                    Text(
                      'Requesting permissions...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildSettingsInstructions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Settings Required',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'To enable permissions:\n'
            '1. Tap "Open Settings" below\n'
            '2. Find "Spark" in the app list\n'
            '3. Enable Bluetooth and Location\n'
            '4. Return to Spark and try again',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    if (_isRequesting) {
      return [];
    }

    final actions = <Widget>[];

    // Cancel/Skip button
    actions.add(
      TextButton(
        onPressed: () {
          widget.onPermissionDenied?.call();
          Navigator.of(context).pop(false);
        },
        child: const Text('Skip'),
      ),
    );

    if (widget.needsSettings) {
      // Open Settings button
      actions.add(
        ElevatedButton.icon(
          onPressed: _openSettings,
          icon: const Icon(Icons.settings, size: 18),
          label: const Text('Open Settings'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      );
    } else {
      // Try Again button
      actions.add(
        ElevatedButton.icon(
          onPressed: _requestPermissions,
          icon: const Icon(Icons.security, size: 18),
          label: const Text('Grant Permissions'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    return actions;
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isRequesting = true;
      _statusMessage = 'Requesting permissions...';
    });

    try {
      final result = await EnhancedIOSPermissionService.requestPermissions(
        forceNativeDialog: true,
      );

      setState(() {
        _isRequesting = false;
        _statusMessage = result.message;
      });

      if (result.success) {
        widget.onPermissionGranted?.call();
        Navigator.of(context).pop(true);
      } else {
        // Update dialog to show settings option if needed
        if (result.needsSettings && !widget.needsSettings) {
          Navigator.of(context).pop(false);
          // Show new dialog with settings option
          IOSPermissionDialog.show(
            context,
            title: widget.title,
            message: result.message,
            needsSettings: true,
            onPermissionGranted: widget.onPermissionGranted,
            onPermissionDenied: widget.onPermissionDenied,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isRequesting = false;
        _statusMessage = 'Error requesting permissions: $e';
      });
    }
  }

  Future<void> _openSettings() async {
    setState(() {
      _statusMessage = 'Opening Settings...';
    });

    try {
      final opened = await EnhancedIOSPermissionService.openSettings();
      
      if (opened) {
        setState(() {
          _statusMessage = 'Settings opened. Please enable permissions and return to Spark.';
        });
        
        // Close dialog after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(false);
          }
        });
      } else {
        setState(() {
          _statusMessage = 'Could not open Settings. Please open Settings manually.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error opening Settings: $e';
      });
    }
  }
}

/// Simplified permission request dialog for quick use
class SimplePermissionDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  const SimplePermissionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onAllow,
    required this.onDeny,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SimplePermissionDialog(
        title: title,
        message: message,
        onAllow: () => Navigator.of(context).pop(true),
        onDeny: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: onDeny,
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: onAllow,
          child: const Text('Allow'),
        ),
      ],
    );
  }
}

/// Permission status indicator widget
class PermissionStatusIndicator extends StatefulWidget {
  final bool showDetails;

  const PermissionStatusIndicator({
    super.key,
    this.showDetails = false,
  });

  @override
  State<PermissionStatusIndicator> createState() => _PermissionStatusIndicatorState();
}

class _PermissionStatusIndicatorState extends State<PermissionStatusIndicator> {
  Map<String, dynamic>? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await EnhancedIOSPermissionService.getDetailedStatus();
      setState(() {
        _status = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = {'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Checking permissions...'),
        ],
      );
    }

    if (_status == null || _status!.containsKey('error')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Text('Permission check failed: ${_status?['error'] ?? 'Unknown error'}'),
        ],
      );
    }

    final allGranted = _status!['allGranted'] == true;
    final granted = Map<String, bool>.from((_status!['granted'] as Map?) ?? {});
    final denied = Map<String, bool>.from((_status!['denied'] as Map?) ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              allGranted ? Icons.check_circle : Icons.warning,
              color: allGranted ? Colors.green : Colors.orange,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              allGranted ? 'All permissions granted' : 'Permissions needed',
              style: TextStyle(
                color: allGranted ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (widget.showDetails && !allGranted) ...[
          const SizedBox(height: 8),
          ...granted.entries.map((entry) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, color: Colors.green, size: 14),
              const SizedBox(width: 4),
              Text('${entry.key}: Granted', style: const TextStyle(fontSize: 12)),
            ],
          ),),
          ...denied.entries.map((entry) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close, color: Colors.red, size: 14),
              const SizedBox(width: 4),
              Text('${entry.key}: Denied', style: const TextStyle(fontSize: 12)),
            ],
          ),),
        ],
      ],
    );
  }
}