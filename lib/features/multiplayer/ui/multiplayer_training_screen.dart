import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../drills/domain/drill.dart';
import '../../drills/ui/drill_runner_screen.dart';
import '../domain/connection_session.dart';
import '../services/session_sync_service.dart';

/// Screen for synchronized multiplayer training
class MultiplayerTrainingScreen extends StatefulWidget {
  final ConnectionSession session;
  final bool isHost;

  const MultiplayerTrainingScreen({
    super.key,
    required this.session,
    required this.isHost,
  });

  @override
  State<MultiplayerTrainingScreen> createState() => _MultiplayerTrainingScreenState();
}

class _MultiplayerTrainingScreenState extends State<MultiplayerTrainingScreen>
    with TickerProviderStateMixin {
  late final SessionSyncService _syncService;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  ConnectionSession? _currentSession;
  Drill? _currentDrill;
  bool _isDrillActive = false;
  bool _isDrillPaused = false;
  String _statusMessage = '';
  List<String> _chatMessages = [];
  
  StreamSubscription<ConnectionSession>? _sessionSubscription;
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription? _drillEventSubscription;

  @override
  void initState() {
    super.initState();
    _syncService = getIt<SessionSyncService>();
    _currentSession = widget.session;
    
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

    _setupListeners();
    _animationController.forward();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _statusSubscription?.cancel();
    _drillEventSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _setupListeners() {
    _sessionSubscription = _syncService.getSessionStream().listen((session) {
      setState(() {
        _currentSession = session;
      });
    });

    _statusSubscription = _syncService.statusStream.listen((status) {
      setState(() {
        _statusMessage = status;
      });
    });

    _drillEventSubscription = _syncService.drillEventStream.listen((event) {
      _handleDrillEvent(event);
    });

    // Update current drill and status from sync service
    _currentDrill = _syncService.currentDrill;
    _isDrillActive = _syncService.isDrillActive;
    _isDrillPaused = _syncService.isDrillPaused;
  }

  void _handleDrillEvent(dynamic event) {
    if (event is DrillStartedEvent) {
      setState(() {
        _currentDrill = event.drill;
        _isDrillActive = true;
        _isDrillPaused = false;
      });
      
      // Navigate to drill runner for synchronized training
      _navigateToDrillRunner(event.drill);
      
    } else if (event is DrillStoppedEvent) {
      setState(() {
        _currentDrill = null;
        _isDrillActive = false;
        _isDrillPaused = false;
      });
      
      // Return to multiplayer screen if in drill runner
      if (mounted && ModalRoute.of(context)?.settings.name != '/multiplayer-training') {
        context.pop();
      }
      
    } else if (event is DrillPausedEvent) {
      setState(() {
        _isDrillPaused = true;
      });
      
    } else if (event is DrillResumedEvent) {
      setState(() {
        _isDrillPaused = false;
      });
      
    } else if (event is ChatReceivedEvent) {
      setState(() {
        _chatMessages.add('${event.sender}: ${event.message}');
      });
      
      // Show chat message as snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${event.sender}: ${event.message}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _navigateToDrillRunner(Drill drill) {
    // Navigate to drill runner with multiplayer context
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DrillRunnerScreen(
          drill: drill,
          isMultiplayerMode: true,
          onDrillComplete: (result) {
            // Handle drill completion in multiplayer context
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.isHost ? 'Hosting Session' : 'Training Session',
          style: const TextStyle(
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
            await _syncService.disconnect();
            if (mounted) context.pop();
          },
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        actions: [
          IconButton(
            onPressed: _showSessionInfo,
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Session Info',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Status
          _buildSessionStatus(context),
          const SizedBox(height: 24),

          // Current Drill Status
          _buildCurrentDrillStatus(context),
          const SizedBox(height: 24),

          // Participants List
          _buildParticipantsList(context),
          const SizedBox(height: 24),

          // Training Instructions
          _buildTrainingInstructions(context),
          
          if (_chatMessages.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildChatHistory(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionStatus(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = widget.isHost ? Colors.blue : Colors.green;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor,
            statusColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
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
                child: Icon(
                  widget.isHost ? Icons.wifi_tethering_rounded : Icons.people_rounded,
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
                      widget.isHost ? 'Hosting Session' : 'Connected to Session',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Session: ${_currentSession?.sessionId ?? 'Unknown'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentDrillStatus(BuildContext context) {
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
                'Current Training',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_currentDrill == null)
            Text(
              widget.isHost 
                  ? 'Select a drill to start synchronized training'
                  : 'Waiting for host to start training...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        _currentDrill!.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_currentDrill!.category} • ${_currentDrill!.difficulty.name} • ${_currentDrill!.durationSec}s',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getDrillStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getDrillStatusIcon(),
                        color: _getDrillStatusColor(),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getDrillStatusText(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _getDrillStatusColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final participants = _currentSession?.participantNames ?? [];
    final hostName = _currentSession?.hostName ?? 'Host';

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
                'Training Partners (${participants.length + 1})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Host
          _buildParticipantItem(context, hostName, isHost: true),
          
          // Other participants
          ...participants.map((name) => _buildParticipantItem(context, name)),
        ],
      ),
    );
  }

  Widget _buildParticipantItem(BuildContext context, String name, {bool isHost = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isHost 
                ? colorScheme.primary.withOpacity(0.2)
                : colorScheme.secondary.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : (isHost ? 'H' : 'P'),
              style: TextStyle(
                color: isHost ? colorScheme.primary : colorScheme.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isHost ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'HOST',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrainingInstructions(BuildContext context) {
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
                'Training Instructions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.isHost
                ? '• You control the training session for all participants\n'
                  '• Select drills from the host screen to start synchronized training\n'
                  '• All participants will automatically start the same drill\n'
                  '• Use pause/resume controls to manage the session\n'
                  '• End the session when training is complete'
                : '• Follow the host\'s drill timing and instructions\n'
                  '• Your drill will start/stop/pause automatically\n'
                  '• Train simultaneously with all participants\n'
                  '• Stay connected for the best synchronized experience\n'
                  '• The host controls all drill timing',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatHistory(BuildContext context) {
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
                Icons.chat_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Recent Messages',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ...(_chatMessages.take(5).map((message) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ))),
        ],
      ),
    );
  }

  Color _getDrillStatusColor() {
    if (!_isDrillActive) return Colors.grey;
    if (_isDrillPaused) return Colors.orange;
    return Colors.green;
  }

  IconData _getDrillStatusIcon() {
    if (!_isDrillActive) return Icons.stop_circle_rounded;
    if (_isDrillPaused) return Icons.pause_circle_rounded;
    return Icons.play_circle_rounded;
  }

  String _getDrillStatusText() {
    if (!_isDrillActive) return 'Ready to Start';
    if (_isDrillPaused) return 'Paused by Host';
    return 'Training Active';
  }

  void _showSessionInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session ID: ${_currentSession?.sessionId ?? 'Unknown'}'),
            Text('Host: ${_currentSession?.hostName ?? 'Unknown'}'),
            Text('Participants: ${(_currentSession?.participantNames.length ?? 0) + 1}'),
            Text('Status: ${_currentSession?.status.displayName ?? 'Unknown'}'),
            if (_currentDrill != null)
              Text('Current Drill: ${_currentDrill!.name}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
