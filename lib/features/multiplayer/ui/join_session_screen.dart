import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/ui/drill_runner_screen.dart';
import 'package:spark_app/features/multiplayer/domain/connection_session.dart';
import 'package:spark_app/features/multiplayer/services/session_sync_service.dart';

/// Screen for joining a multiplayer training session
class JoinSessionScreen extends StatefulWidget {
  const JoinSessionScreen({super.key});

  @override
  State<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends State<JoinSessionScreen>
    with TickerProviderStateMixin {
  late final SessionSyncService _syncService;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  
  ConnectionSession? _session;
  bool _isLoading = false;
  bool _isConnected = false;
  String _statusMessage = 'Enter session code to join';
  
  StreamSubscription<ConnectionSession>? _sessionSubscription;
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<dynamic>? _drillEventSubscription;

  @override
  void initState() {
    super.initState();
    _syncService = getIt<SessionSyncService>();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ),);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ),);

    _initialize();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _statusSubscription?.cancel();
    _drillEventSubscription?.cancel();
    _codeController.dispose();
    _codeFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _syncService.initialize();
      _setupListeners();
      await _animationController.forward();
      
      if (mounted) {
        setState(() {
          _statusMessage = 'Ready to join session';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Initialization failed: $e';
      });
    }
  }


  void _setupListeners() {
    _sessionSubscription = _syncService.getSessionStream().listen((session) {
      setState(() {
        _session = session;
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
  }

  void _handleDrillEvent(dynamic event) {
    // Handle drill synchronization events
    if (!mounted) return;
    
    try {
      if (event is DrillStartedEvent) {
        // Host started a drill - automatically navigate to drill runner
        _navigateToDrillRunner(event.drill);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Drill started: ${event.drill.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
      } else if (event is DrillStoppedEvent) {
        // Host stopped the drill - return to join screen if in drill runner
        _returnFromDrillRunner();
        
        // Update UI to show stopped state
        setState(() {
          // Force UI refresh to show updated drill status
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drill stopped by host'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        
      } else if (event is DrillPausedEvent) {
        // Update UI to show paused state
        setState(() {
          // Force UI refresh to show updated drill status
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drill paused by host'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        
      } else if (event is DrillResumedEvent) {
        // Update UI to show resumed state
        setState(() {
          // Force UI refresh to show updated drill status
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drill resumed by host'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
      } else if (event is ChatReceivedEvent) {
        // Handle chat messages if needed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${event.sender}: ${event.message}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling drill event: $e');
    }
  }

  void _navigateToDrillRunner(Drill drill) {
    // Navigate to drill runner with multiplayer context
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/drill-runner-multiplayer'),
        builder: (context) => DrillRunnerScreen(
          drill: drill,
          isMultiplayerMode: true,
          isHost: false, // Participant has no control
          onDrillComplete: (result) {
            // Handle drill completion in multiplayer context
            if (mounted) {
              // Pop back to join session screen
              Navigator.of(context).pop();
              
              // Force UI refresh to show updated drill status
              setState(() {
                // This will trigger a rebuild and show the updated drill status
              });
              
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
              
              // Ensure we're back on the join session screen
              _returnToJoinSessionScreen();
            }
          },
        ),
      ),
    );
  }

  void _returnFromDrillRunner() {
    // Return to join screen if currently in drill runner
    try {
      // Force UI refresh to show updated drill status
      if (mounted) {
        setState(() {
          // This will trigger a rebuild and show the updated drill status
        });
      }
      
      // Check if we need to navigate back from drill runner
      // This is handled automatically by the drill completion callback
      debugPrint('Drill runner returned to join session screen');
    } catch (e) {
      debugPrint('Error returning from drill runner: $e');
    }
  }

  void _returnToJoinSessionScreen() {
    try {
      // Force UI refresh to show updated drill status
      if (mounted) {
        setState(() {
          // This will trigger a rebuild and show the updated drill status
        });
      }
      
      debugPrint('Returned to join session screen after drill completion');
    } catch (e) {
      debugPrint('Error returning to join session screen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Join Session',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 18 : 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          onPressed: () async {
            if (_isConnected) {
              await _syncService.disconnect();
            }
            if (mounted) context.pop();
          },
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
        actions: [
          if (_isConnected)
            IconButton(
              onPressed: _disconnectSession,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Leave Session',
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildContent(context),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (!_isConnected) {
      return _buildJoinState(context);
    }

    return _buildConnectedState(context);
  }

  Widget _buildJoinState(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final padding = isSmallScreen ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context),
          SizedBox(height: isSmallScreen ? 24 : 32),

          // Code Input
          _buildCodeInput(context),
          SizedBox(height: isSmallScreen ? 16 : 24),

          // Join Button
          _buildJoinButton(context),
          SizedBox(height: isSmallScreen ? 24 : 32),

          // Status
          _buildStatusCard(context),
          SizedBox(height: isSmallScreen ? 16 : 24),

          // Instructions
          _buildInstructions(context),
        ],
      ),
    );
  }

  Widget _buildConnectedState(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final padding = isSmallScreen ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session Info
          _buildSessionInfo(context),
          SizedBox(height: isSmallScreen ? 16 : 24),

          // Participants
          _buildParticipantsList(context),
          SizedBox(height: isSmallScreen ? 16 : 24),

          // Current Drill Status
          _buildDrillStatus(context),
          SizedBox(height: isSmallScreen ? 16 : 24),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.3),
            colorScheme.secondaryContainer.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.login_rounded,
              color: Colors.green,
              size: isSmallScreen ? 24 : 28,
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join Training Session',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 20 : null,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter the 6-digit code from your host',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: isSmallScreen ? 13 : null,
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

  // Removed WiFi warning since Firebase works over the internet

  Widget _buildCodeInput(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session Code',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 15 : null,
          ),
        ),
        SizedBox(height: isSmallScreen ? 10 : 12),
        TextFormField(
          controller: _codeController,
          focusNode: _codeFocusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 28 : null,
            letterSpacing: isSmallScreen ? 6 : 8,
            fontFamily: 'monospace',
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.3),
              letterSpacing: isSmallScreen ? 6 : 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
              borderSide: BorderSide(
                color: colorScheme.outline,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 24,
              vertical: isSmallScreen ? 16 : 20,
            ),
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildJoinButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCodeValid = _codeController.text.length == 6;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (isCodeValid && !_isLoading) ? _handleJoinButtonPress : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
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
                  const Icon(
                    Icons.login_rounded,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Join Session',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Removed permission button since Firebase doesn't need special permissions

  Widget _buildStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
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
              Icons.info_outline_rounded,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: theme.textTheme.titleSmall?.copyWith(
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
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Column(
      children: [
        // Connection Requirements
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withOpacity(0.1),
                colorScheme.secondaryContainer.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.cloud_rounded,
                      color: colorScheme.primary,
                      size: isSmallScreen ? 18 : 20,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    child: Text(
                      'Connection Requirements',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 15 : null,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              _buildRequirementItem(
                context,
                Icons.wifi_rounded,
                'Internet Connection',
                'Both devices need internet access to connect via Firebase',
                colorScheme.primary,
                isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 8 : 12),
              _buildRequirementItem(
                context,
                Icons.cloud_sync_rounded,
                'Firebase Sync',
                'Real-time synchronization works anywhere with internet',
                colorScheme.primary,
                isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 8 : 12),
              _buildRequirementItem(
                context,
                Icons.security_rounded,
                'Secure Connection',
                'All data is encrypted and synced through Firebase',
                colorScheme.primary,
                isSmallScreen,
              ),
            ],
          ),
        ),
        
        SizedBox(height: isSmallScreen ? 16 : 20),
        
        // Step-by-step Instructions
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
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
                    Icons.list_alt_rounded,
                    color: colorScheme.primary,
                    size: isSmallScreen ? 18 : 20,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Text(
                    'How to Join',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 15 : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              _buildStepItem(context, '1', 'Check Internet', 'Ensure your device has internet connection', isSmallScreen),
              _buildStepItem(context, '2', 'Get Session Code', 'Ask the host for the 6-digit session code', isSmallScreen),
              _buildStepItem(context, '3', 'Enter Code', 'Type the code in the field above', isSmallScreen),
              _buildStepItem(context, '4', 'Join Session', 'Tap "Join Session" and wait for connection', isSmallScreen),
              _buildStepItem(context, '5', 'Start Training', 'Wait for host to begin synchronized drills', isSmallScreen),
              _buildStepItem(context, '6', 'Follow Host', 'Your device will automatically sync with host actions', isSmallScreen),
            ],
          ),
        ),

      ],
    );
  }

  Widget _buildRequirementItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
    bool isSmallScreen,
  ) {
    final theme = Theme.of(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: color,
            size: isSmallScreen ? 16 : 18,
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 13 : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: isSmallScreen ? 11 : null,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(
    BuildContext context,
    String stepNumber,
    String title,
    String description,
    bool isSmallScreen,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isSmallScreen ? 24 : 28,
            height: isSmallScreen ? 24 : 28,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 13 : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: isSmallScreen ? 11 : null,
                    color: colorScheme.onSurface.withOpacity(0.7),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootItem(
    BuildContext context,
    String problem,
    String solutions,
    bool isSmallScreen,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          problem,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 13 : null,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          solutions,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: isSmallScreen ? 11 : null,
            color: colorScheme.onSurface.withOpacity(0.7),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionInfo(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green,
            Colors.green.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
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
                  Icons.check_circle_rounded,
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
                      'Connected to Session',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Host: ${_session?.hostName ?? 'Unknown'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Session: ${_session?.sessionId ?? '------'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
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
    final hostName = _session?.hostName ?? 'Host';

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
                'Participants (${participants.length + 1})',
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

  Widget _buildDrillStatus(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentDrill = _syncService.currentDrill;
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
                Icons.psychology_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Current Drill',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (currentDrill == null)
            Text(
              'Waiting for host to select a drill...',
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
                                    width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentDrill.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currentDrill.category} • ${currentDrill.difficulty.name} • ${currentDrill.durationSec}s',
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
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getDrillStatusColor(isActive, isPaused).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getDrillStatusIcon(isActive, isPaused),
                        color: _getDrillStatusColor(isActive, isPaused),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getDrillStatusText(isActive, isPaused),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _getDrillStatusColor(isActive, isPaused),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Show info message for participants
                if (isActive && !isPaused) ...[
                  const SizedBox(height: 12),
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
                            'Drill is running! You should be in the drill screen.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

 

 

  Color _getDrillStatusColor(bool isActive, bool isPaused) {
    if (!isActive) return Colors.grey;
    if (isPaused) return Colors.orange;
    return Colors.green;
  }

  IconData _getDrillStatusIcon(bool isActive, bool isPaused) {
    if (!isActive) return Icons.stop_circle_rounded;
    if (isPaused) return Icons.pause_circle_rounded;
    return Icons.play_circle_rounded;
  }

  String _getDrillStatusText(bool isActive, bool isPaused) {
    if (!isActive) return 'Stopped';
    if (isPaused) return 'Paused';
    return 'Active';
  }

  Future<void> _joinSession() async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    debugPrint('🔗 JOIN: Attempting to join session with code: $code');

    // Firebase doesn't require special permissions like Bluetooth
    debugPrint('🔗 JOIN: Using Firebase - no special permissions needed');

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Searching for session...';
      });

      final session = await _syncService.joinSession(code);
      
      setState(() {
        _session = session;
        _isConnected = true;
        _isLoading = false;
        _statusMessage = 'Connected to session';
      });

      HapticFeedback.mediumImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined session: ${session.sessionId}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Provide more specific error messages
      String errorMessage = 'Failed to join session';
      String statusMessage = 'Connection failed';
      
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('timeout') || errorString.contains('timed out')) {
        errorMessage = 'Session not found - check the code and internet connection';
        statusMessage = 'Session not found';
      } else if (errorString.contains('network') || errorString.contains('internet')) {
        errorMessage = 'Network connection failed - check your internet';
        statusMessage = 'Network issue';
      } else if (errorString.contains('firebase')) {
        errorMessage = 'Firebase connection failed - try again later';
        statusMessage = 'Firebase issue';
      } else if (errorString.contains('full')) {
        errorMessage = 'Session is full - cannot join';
        statusMessage = 'Session full';
      } else if (errorString.contains('not found')) {
        errorMessage = 'Session not found - verify the code is correct';
        statusMessage = 'Invalid session code';
      }
      
      setState(() {
        _statusMessage = statusMessage;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _joinSession(),
            ),
          ),
        );
      }
    }
  }
  

  Future<void> _disconnectSession() async {
    try {
      await _syncService.disconnect();
      setState(() {
        _session = null;
        _isConnected = false;
        _statusMessage = 'Disconnected from session';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Left session'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  /// Handle join button press - Firebase doesn't need special permissions
  Future<void> _handleJoinButtonPress() async {
    await _joinSession();
  }

}
