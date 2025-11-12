import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/features/auth/domain/device_session.dart';
import 'package:spark_app/features/auth/services/multi_device_session_service.dart';
import 'package:spark_app/features/auth/ui/device_sessions_screen.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:go_router/go_router.dart';

/// Dialog shown when user logs in on a new device while already logged in elsewhere
/// Provides options to manage existing sessions
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

  Future<void> _logoutFromAllOtherDevices() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await _sessionService.logoutFromAllOtherDevices();
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop();
        widget.onContinue?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Logged out from all other devices')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to logout: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _viewAllSessions() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DeviceSessionsScreen(),
      ),
    );
  }

  void _continueWithCurrentLogin() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    widget.onContinue?.call();
  }

  void _cancelLogin() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    widget.onCancel?.call();
  }

  Widget _buildSessionPreview(DeviceSession session, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                session.deviceIcon,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.deviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${session.platform} • ${session.formattedLastActive}',
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
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
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
    final otherSessions = widget.existingSessions.where((s) => !s.isCurrentDevice).toList();

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
              // Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.devices,
                  size: 32,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'Multiple Device Login Detected',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              Text(
                'You are already logged in on ${otherSessions.length} other device${otherSessions.length > 1 ? 's' : ''}. What would you like to do?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Session previews (show up to 3)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    children: otherSessions
                        .take(3)
                        .map((session) => _buildSessionPreview(session, colorScheme))
                        .toList(),
                  ),
                ),
              ),
              
              if (otherSessions.length > 3) ...[
                const SizedBox(height: 8),
                Text(
                  'and ${otherSessions.length - 3} more device${otherSessions.length - 3 > 1 ? 's' : ''}...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Action buttons
              Column(
                children: [
                  // Continue with current login
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _continueWithCurrentLogin,
                      icon: const Icon(Icons.login),
                      label: const Text('Continue on This Device'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Logout from all other devices
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _logoutFromAllOtherDevices,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout),
                      label: Text(_isLoading 
                          ? 'Logging out...' 
                          : 'Logout All Other Devices',),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // View all sessions
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _viewAllSessions,
                      icon: const Icon(Icons.manage_accounts),
                      label: const Text('Manage All Sessions'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Cancel
                  TextButton(
                    onPressed: _isLoading ? null : _cancelLogin,
                    child: const Text('Cancel Login'),
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