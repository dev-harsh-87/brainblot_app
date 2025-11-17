import 'package:flutter/material.dart';
import 'package:spark_app/features/multiplayer/services/professional_permission_manager.dart';
import 'package:spark_app/core/utils/ios_permission_helper.dart';

/// Universal permission dialog for multiplayer features
/// Explains why location permission is needed and guides users through the process
class MultiplayerPermissionDialog extends StatefulWidget {
  final VoidCallback? onPermissionsGranted;
  final VoidCallback? onDismiss;

  const MultiplayerPermissionDialog({
    super.key,
    this.onPermissionsGranted,
    this.onDismiss,
  });

  @override
  State<MultiplayerPermissionDialog> createState() => _MultiplayerPermissionDialogState();
}

class _MultiplayerPermissionDialogState extends State<MultiplayerPermissionDialog> {
  bool _isLoading = false;
  String _statusMessage = '';
  PermissionStatusReport? _permissionStatus;

  @override
  void initState() {
    super.initState();
    _loadPermissionStatus();
  }

  Future<void> _loadPermissionStatus() async {
    final status = await ProfessionalPermissionManager.getPermissionStatus();
    if (mounted) {
      setState(() {
        _permissionStatus = status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isIOS = IOSPermissionHelper.isIOS;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: Colors.blue,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Location Permission Required',
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
            // Why location is needed
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.1),
                    Colors.green.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Why do we need location?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'To join multiplayer training sessions, your device needs to discover nearby devices using Bluetooth. Android requires location permission for Bluetooth device discovery.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.security, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your location is never stored or shared. We only use it to find nearby training partners.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Permission Status
            if (_permissionStatus != null) _buildPermissionStatus(),
            
            const SizedBox(height: 16),
            
            // Platform-specific instructions
            _buildInstructions(isIOS),
            
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('granted') || _statusMessage.contains('success')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage.contains('granted') || _statusMessage.contains('success')
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusMessage.contains('granted') || _statusMessage.contains('success')
                          ? Icons.check_circle
                          : Icons.info,
                      color: _statusMessage.contains('granted') || _statusMessage.contains('success')
                          ? Colors.green
                          : Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _statusMessage.contains('granted') || _statusMessage.contains('success')
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
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
          onPressed: _isLoading ? null : _requestPermissions,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(isIOS ? 'Open Settings' : 'Grant Permissions'),
        ),
      ],
    );
  }

  Widget _buildPermissionStatus() {
    final theme = Theme.of(context);
    
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
            'Current Permission Status:',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...ProfessionalPermissionManager.requiredPermissions.map((permission) {
            final isGranted = _permissionStatus!.grantedPermissions.contains(permission);
            final isPermanentlyDenied = _permissionStatus!.permanentlyDeniedPermissions.contains(permission);
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    isPermanentlyDenied 
                        ? Icons.block 
                        : isGranted 
                            ? Icons.check_circle 
                            : Icons.cancel,
                    color: isPermanentlyDenied 
                        ? Colors.red 
                        : isGranted 
                            ? Colors.green 
                            : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${ProfessionalPermissionManager.getPermissionDisplayName(permission)}: ${isPermanentlyDenied ? 'Blocked' : isGranted ? 'Granted' : 'Not Granted'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildInstructions(bool isIOS) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                isIOS ? 'iOS Instructions:' : 'Android Instructions:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isIOS) ...[
            _buildStep('1', 'Tap "Open Settings" below'),
            _buildStep('2', 'Find "Spark" in the app list'),
            _buildStep('3', 'Enable Bluetooth and Location permissions'),
            _buildStep('4', 'Return to Spark and try joining again'),
          ] else ...[
            _buildStep('1', 'Tap "Grant Permissions" below'),
            _buildStep('2', 'Allow Location access when prompted'),
            _buildStep('3', 'Allow Bluetooth permissions if asked'),
            _buildStep('4', 'If permissions are blocked, go to Settings > Apps > Spark > Permissions'),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Requesting permissions...';
    });

    try {
      final result = await ProfessionalPermissionManager.requestPermissions();
      await _loadPermissionStatus();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = result.message;
        });

        if (result.success) {
          widget.onPermissionsGranted?.call();
          Navigator.of(context).pop();
        } else if (result.needsSettings) {
          setState(() {
            _statusMessage = 'Some permissions need to be enabled in Settings. Please tap "Open Settings" and enable the required permissions.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error requesting permissions: $e';
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
      final granted = await ProfessionalPermissionManager.areAllPermissionsGranted();
      await _loadPermissionStatus();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = granted 
              ? 'All permissions granted! You can now join multiplayer sessions.' 
              : 'Some permissions are still missing. Please grant them to continue.';
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