

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/di/injection.dart';
import '../../drills/domain/drill.dart';
import '../../drills/data/firebase_drill_repository.dart';
import '../../drills/ui/drill_runner_screen.dart';
import '../domain/connection_session.dart';
import '../services/professional_permission_manager.dart';
import '../services/session_sync_service.dart';

/// Screen for hosting a multiplayer training session
class HostSessionScreen extends StatefulWidget {
  const HostSessionScreen({super.key});

  @override
  State<HostSessionScreen> createState() => _HostSessionScreenState();
}

class _HostSessionScreenState extends State<HostSessionScreen>
    with TickerProviderStateMixin {
  late final SessionSyncService _syncService;
  late final FirebaseDrillRepository _drillRepository;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  ConnectionSession? _session;
  List<Drill> _availableDrills = [];
  Drill? _selectedDrill;
  bool _isLoading = false;
  bool _isHosting = false;
  String _statusMessage = 'Initializing...';
  bool _permissionsGranted = false;

  StreamSubscription<ConnectionSession>? _sessionSubscription;
  StreamSubscription<String>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _syncService = getIt<SessionSyncService>();
    _drillRepository = getIt<FirebaseDrillRepository>();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _initialize();
  }

  @override
  void dispose() {
    // Cancel all subscriptions to prevent memory leaks
    _sessionSubscription?.cancel();
    _statusSubscription?.cancel();
    
    // Dispose animation controller
    _animationController.dispose();
    
    // Disconnect from session if still connected
    if (_isHosting && _session != null) {
      _syncService.disconnect().catchError((e) {
        debugPrint('Error disconnecting during dispose: $e');
      });
    }
    
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _statusMessage = 'Initializing service...';
        });
      }

      await _syncService.initialize();
      await _loadDrills();
      await _checkPermissions(); // Check permissions on init

      _setupListeners();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = _permissionsGranted
              ? 'Ready to host session'
              : 'Permissions required - tap "Check Permissions"';
        });
      }

      _animationController.forward();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Initialization failed: $e';
        });
      }
    }
  }

  Future<void> _checkPermissions() async {
    try {
      debugPrint('🔐 HOST: Checking permissions using Professional Permission Manager...');
      
      // Use the professional permission manager for consistent permission checking
      _permissionsGranted = await ProfessionalPermissionManager.areAllPermissionsGranted();
      
      debugPrint('🔐 HOST: All permissions granted: $_permissionsGranted');
      
      if (!_permissionsGranted) {
        // Get detailed status for better error messages
        final status = await ProfessionalPermissionManager.getPermissionStatus();
        
        if (status.hasPermissionIssues) {
          if (mounted) {
            setState(() {
              _statusMessage = 'Some permissions are permanently denied. Please enable them in Settings.';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _statusMessage = 'Permissions required for multiplayer features. Tap "Check Permissions" to grant them.';
            });
          }
        }
        
        debugPrint('🔐 HOST: Permission status: $status');
      }
    } catch (e) {
      debugPrint('🔐 HOST: ❌ Error checking permissions: $e');
      _permissionsGranted = false;
      if (mounted) {
        setState(() {
          _statusMessage = 'Error checking permissions: $e';
        });
      }
    }
  }

  void _setupListeners() {
    _sessionSubscription = _syncService.getSessionStream().listen((session) {
      if (mounted) {
        setState(() {
          _session = session;
        });
      }
    });

    _statusSubscription = _syncService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _statusMessage = status;
        });
      }
    });
  }

  Future<void> _loadDrills() async {
    try {
      final drills = await _drillRepository.fetchAll();
      if (mounted) {
        setState(() {
          _availableDrills = drills.where((drill) => !drill.isPreset).toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load drills: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Host Session',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          onPressed: () async {
            if (_isHosting) {
              await _syncService.disconnect();
            }
            if (mounted) context.pop();
          },
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        actions: [
          if (_isHosting)
            IconButton(
              onPressed: _disconnectSession,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'End Session',
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: _buildContent(context),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (!_isHosting) {
      return _buildSetupState(context);
    }

    return _buildHostingState(context);
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSetupState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Permission Warning (if not granted)
          if (!_permissionsGranted)
            _buildPermissionWarning(context),

          if (!_permissionsGranted)
            const SizedBox(height: 16),

          // Status Card
          _buildStatusCard(context),
          const SizedBox(height: 24),

          // Host Button
          _buildHostButton(context),
          const SizedBox(height: 32),

          // Instructions
          _buildInstructions(context),
        ],
      ),
    );
  }

  Widget _buildPermissionWarning(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Permissions Required',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isIOS
                ? 'Bluetooth and Location permissions are required. Please enable them in Settings to use multiplayer features.'
                : 'Bluetooth and Location permissions are required. Please grant them to use multiplayer features.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handlePermissionRequest(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.settings, size: 20),
              label: Text(isIOS ? 'Request Permissions' : 'Grant Permissions'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleHostButtonPress,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _permissionsGranted ? Icons.wifi_tethering_rounded : Icons.security_rounded,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _permissionsGranted ? 'Start Hosting Session' : 'Request Permissions & Host',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (!_permissionsGranted) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handlePermissionRequest,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: colorScheme.primary),
              ),
              icon: Icon(
                Icons.settings_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              label: Text(
                'Check Permissions Only',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHostingState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Info
          _buildSessionInfo(context),
          const SizedBox(height: 24),

          // Participants
          _buildParticipantsList(context),
          const SizedBox(height: 24),

          // Drill Selection
          _buildDrillSelection(context),
          const SizedBox(height: 24),

          // Drill Controls
          if (_selectedDrill != null) _buildDrillControls(context),
        ],
      ),
    );
  }

  Widget _buildDrillSelection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Select Drill',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_availableDrills.isEmpty)
            Text(
              'No drills available. Create some drills first.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            )
          else
            DropdownButtonFormField<Drill>(
              value: _selectedDrill,
              decoration: InputDecoration(
                hintText: 'Choose a drill to start training',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _availableDrills.map((drill) {
                return DropdownMenuItem(
                  value: drill,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        drill.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${drill.category} • ${drill.difficulty.name} • ${drill.durationSec}s',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (drill) {
                if (mounted) {
                  setState(() {
                    _selectedDrill = drill;
                  });
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDrillControls(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = _syncService.isDrillActive;
    final isPaused = _syncService.isDrillPaused;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Host Controls - Manage All Participants',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_rounded,
                  color: Colors.blue[700],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your actions control the drill for all connected participants automatically.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Selected drill info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedDrill!.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_selectedDrill!.category} • ${_selectedDrill!.difficulty.name} • ${_selectedDrill!.durationSec}s',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Control buttons
          Row(
            children: [
              if (!isActive)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startDrill,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start for All Participants'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else ...[
                if (!isPaused)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pauseDrill,
                      icon: const Icon(Icons.pause_rounded),
                      label: const Text('Pause All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _resumeDrill,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Resume All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stopDrill,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectSession() async {
    try {
      await _syncService.disconnect();
      if (mounted) {
        setState(() {
          _session = null;
          _isHosting = false;
          _selectedDrill = null;
          _statusMessage = 'Session ended';
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session ended'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  void _copySessionCode() {
    if (_session?.sessionId != null) {
      Clipboard.setData(ClipboardData(text: _session!.sessionId));
      HapticFeedback.lightImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session code copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _startDrill() async {
    if (_selectedDrill == null) return;

    try {
      // Start drill for all participants first
      await _syncService.startDrillForAll(_selectedDrill!);
      
      // Navigate host to drill runner as well
      _navigateHostToDrillRunner(_selectedDrill!);
      
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start drill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateHostToDrillRunner(Drill drill) {
    // Navigate host to drill runner with multiplayer context
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/drill-runner-host'),
        builder: (context) => DrillRunnerScreen(
          drill: drill,
          isMultiplayerMode: true,
          onDrillComplete: (result) {
            // Handle drill completion for host
            if (mounted) {
              Navigator.of(context).pop();
              // Show completion feedback with stats
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Drill completed: ${drill.name}'),
                      Text(
                        'Your Score: ${result.hits}/${result.totalStimuli} (${(result.accuracy * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _pauseDrill() async {
    try {
      await _syncService.pauseDrillForAll();
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pause drill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resumeDrill() async {
    try {
      await _syncService.resumeDrillForAll();
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resume drill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopDrill() async {
    try {
      await _syncService.stopDrillForAll();
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop drill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSessionInfo(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.wifi_tethering_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Active - You\'re the Host',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Share this code with participants to join',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _session?.sessionId ?? '------',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => _copySessionCode(),
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Copy Code',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to copy and share with participants',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final participants = _session?.participantNames ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Participants (${participants.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (participants.isEmpty)
            Text(
              'Waiting for participants to join...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...participants.map((name) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  // ... (keep all other existing _build methods: _buildStatusCard, _buildInstructions,
  // _buildHostingState, _buildSessionInfo, _buildParticipantsList,
  // _buildDrillSelection, _buildDrillControls - they remain unchanged)

  Widget _buildStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.wifi_tethering_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Host Status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'How to host',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '1. Tap "Start Hosting Session" to create a new session\n'
                '2. Share the 6-digit session code with participants\n'
                '3. Wait for participants to join your session\n'
                '4. Select a drill and start training together\n'
                '5. Control drill timing for all connected devices',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startHosting() async {
    // Re-check permissions before hosting
    await _checkPermissions();

    if (!_permissionsGranted) {
      _showPermissionDialog();
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _statusMessage = 'Starting host session...';
        });
      }

      final session = await _syncService.startHostSession();

      if (mounted) {
        setState(() {
          _session = session;
          _isHosting = true;
          _isLoading = false;
          _statusMessage = 'Session active: ${session.sessionId}';
        });
      }

      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Failed to start hosting: $e';
        });
      }

      if (mounted) {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('permission') ||
            errorString.contains('required permissions not granted') ||
            errorString.contains('bluetooth') ||
            errorString.contains('location')) {
          _showPermissionDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start hosting: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Check Permissions',
                onPressed: () => _showPermissionDialog(),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _handlePermissionRequest() async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    
    if (mounted) {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Requesting permissions...';
      });
    }

    try {
      // Use the professional permission manager for all platforms
      final result = await ProfessionalPermissionManager.requestPermissions();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = result.message;
          _permissionsGranted = result.success;
        });
      }

      if (result.success) {
        // Permissions granted successfully
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissions granted! You can now host sessions.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (result.needsSettings) {
          // Show professional permission screen for permanently denied permissions
          debugPrint('🔧 HOST: Showing permission dialog (needsSettings: ${result.needsSettings})');
          _showPermissionDialog();
        } else {
          // Show a simple message for denied permissions
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Try Again',
                  onPressed: () => _handlePermissionRequest(),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error requesting permissions: $e';
          _permissionsGranted = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permissions: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => _showPermissionDialog(),
            ),
          ),
        );
      }
    }
  }

  void _showPermissionDialog() async {
    debugPrint('🔐 HOST: Showing permission dialog...');
    
    try {
      // Use the professional permission manager for all platforms
      final result = await ProfessionalPermissionManager.requestPermissions(
        showRationale: true,
      );
      
      debugPrint('🔐 HOST: Permission request result: $result');
      
      // Refresh permission status after request
      await _checkPermissions();
      
      if (mounted) {
        setState(() {
          if (result.success) {
            _statusMessage = 'All permissions granted! Ready to host session.';
          } else if (result.needsSettings) {
            _statusMessage = 'Please enable permissions in Settings and try again.';
          } else {
            _statusMessage = 'Some permissions were not granted. Please try again.';
          }
        });
      }
      
      // If permissions still not granted and need settings, show settings dialog
      if (!result.success && result.needsSettings && mounted) {
        _showSettingsDialog();
      }
      
    } catch (e) {
      debugPrint('🔐 HOST: ❌ Error requesting permissions: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Error requesting permissions: $e';
        });
      }
    }
  }
  
  void _showSettingsDialog() {
    if (!mounted) return;
    
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Permissions Required',
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
                  'To use multiplayer features, please grant these permissions:',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                _buildPermissionItem('📶 Bluetooth', 'Connect with nearby devices'),
                _buildPermissionItem('📡 Bluetooth Scan', 'Discover other devices'),
                _buildPermissionItem('🔗 Bluetooth Connect', 'Establish connections'),
                _buildPermissionItem('📍 Location', 'Required for Bluetooth discovery'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Refresh permission status
                _checkPermissions().then((_) {
                  if (mounted) setState(() {});
                });
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                if (isIOS) {
                  // For iOS, always open settings
                  await openAppSettings();

                  // Show snackbar with reminder
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'After enabling permissions, return to Spark and try again',
                        ),
                        duration: const Duration(seconds: 5),
                        action: SnackBarAction(
                          label: 'Refresh',
                          onPressed: () async {
                            await _checkPermissions();
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    );
                  }
                } else {
                  // For Android, first try to request permissions
                  try {
                    final bluetoothService = _syncService.getBluetoothService();
                    final granted = await bluetoothService.requestPermissions();
                    
                    if (granted) {
                      // Permissions granted, show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Permissions granted! You can now host sessions.'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    } else {
                      // Some permissions denied, open settings
                      await openAppSettings();
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Please enable all permissions in Settings and return to Spark',
                            ),
                            duration: const Duration(seconds: 5),
                            action: SnackBarAction(
                              label: 'Refresh',
                              onPressed: () async {
                                await _checkPermissions();
                                if (mounted) setState(() {});
                              },
                            ),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    // If permission request fails, open settings
                    await openAppSettings();
                  }
                }

                // Refresh permissions after delay
                await Future.delayed(const Duration(seconds: 1));
                await _checkPermissions();
                if (mounted) setState(() {});
              },
              icon: Icon(isIOS ? Icons.open_in_new : Icons.settings),
              label: Text(isIOS ? 'Open iOS Settings' : 'Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIOSStep(String number, String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String title, String description) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle host button press - request permissions first if needed, then start hosting
  Future<void> _handleHostButtonPress() async {
    if (!_permissionsGranted) {
      // First request permissions
      await _handlePermissionRequest();
      
      // Check if permissions were granted after the request
      if (!_permissionsGranted) {
        // Permissions still not granted, show message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissions are required to host a session. Please grant them and try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }
    
    // Permissions are granted, start hosting
    await _startHosting();
  }
}