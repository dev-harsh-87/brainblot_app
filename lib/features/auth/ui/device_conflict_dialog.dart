import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/features/auth/domain/device_session.dart';
import 'package:spark_app/features/auth/services/multi_device_session_service.dart';
import 'package:spark_app/core/di/injection.dart';

/// Dialog shown when user logs in on a new device while already logged in elsewhere
/// Shows single device info and allows logout from previous device
class DeviceConflictDialog extends StatefulWidget {
  final List<DeviceSession> existingSessions;
  final VoidCallback? onContinue;
  final VoidCallback? onCancel;

  const DeviceConflictDialog({
    super.key,
    required this.existingSessions,
    this.onContinue,
    this.onCancel,
  });

  @override
  State<DeviceConflictDialog> createState() => _DeviceConflictDialogState();
}

class _DeviceConflictDialogState extends State<DeviceConflictDialog> with TickerProviderStateMixin {
  late final MultiDeviceSessionService _sessionService;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sessionService = getIt<MultiDeviceSessionService>();
    _initializeAnimations();
    HapticFeedback.mediumImpact();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _logoutFromPreviousDevice() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      // Add timeout to prevent indefinite loading
      await _sessionService.logoutFromAllOtherDevices().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Logout operation timed out. Please try again.');
        },
      );
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        // Close dialog first
        Navigator.of(context).pop();
        
        // Small delay to ensure dialog closes before continuing
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Then trigger continue callback
        widget.onContinue?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Successfully logged out from other devices')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _isLoading = false);
        
        String errorMessage = 'Failed to logout from other devices';
        if (e.toString().contains('timeout')) {
          errorMessage = 'Operation timed out. Please check your connection and try again.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _logoutFromPreviousDevice,
            ),
          ),
        );
      }
    }
  }

  void _cancelLogin() async {
    HapticFeedback.lightImpact();
    
    // Close dialog first
    Navigator.of(context).pop();
    
    // Small delay to ensure dialog closes
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Then trigger cancel callback which will logout
    widget.onCancel?.call();
  }

  Widget _buildDeviceInfo(DeviceSession session, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.error.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                session.deviceIcon,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.deviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.platform,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last active: ${session.formattedLastActive}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (session.isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Online',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final previousDevice = widget.existingSessions.first;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  size: 40,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Device Already Logged In',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Description
              Text(
                'Your account is currently logged in on another device. You can only be logged in on one device at a time.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Device Info
              _buildDeviceInfo(previousDevice, colorScheme),
              const SizedBox(height: 32),
              
              // Action buttons
              Column(
                children: [
                  // Logout and continue button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _logoutFromPreviousDevice,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.logout),
                      label: Text(_isLoading 
                          ? 'Logging out...' 
                          : 'Logout Previous Device & Continue'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _cancelLogin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel Login'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show the device conflict dialog
  static Future<void> show(
    BuildContext context, {
    required List<DeviceSession> existingSessions,
    VoidCallback? onContinue,
    VoidCallback? onCancel,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeviceConflictDialog(
        existingSessions: existingSessions,
        onContinue: onContinue,
        onCancel: onCancel,
      ),
    );
  }
}