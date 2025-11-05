import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/core/ui/edge_to_edge.dart';

/// Immersive training screen with full edge-to-edge experience
class ImmersiveTrainingScreen extends StatefulWidget {
  const ImmersiveTrainingScreen({super.key});

  @override
  State<ImmersiveTrainingScreen> createState() => _ImmersiveTrainingScreenState();
}

class _ImmersiveTrainingScreenState extends State<ImmersiveTrainingScreen> {
  bool _isImmersive = false;
  bool _isTrainingActive = false;

  @override
  void initState() {
    super.initState();
    // Set dark system UI for training environment
    WidgetsBinding.instance.addPostFrameCallback((_) {
      EdgeToEdge.setDarkSystemUI(context);
    });
  }

  @override
  void dispose() {
    // Restore normal system UI when leaving
    EdgeToEdge.showSystemUI();
    super.dispose();
  }

  void _toggleImmersiveMode() {
    setState(() {
      _isImmersive = !_isImmersive;
    });

    if (_isImmersive) {
      EdgeToEdge.hideSystemUI();
    } else {
      EdgeToEdge.showSystemUI();
      EdgeToEdge.setDarkSystemUI(context);
    }
  }

  void _startTraining() {
    setState(() {
      _isTrainingActive = true;
      _isImmersive = true;
    });
    
    // Enter full immersive mode for training
    EdgeToEdge.toggleImmersiveMode();
    
    // Provide haptic feedback
    HapticFeedback.mediumImpact();
  }

  void _stopTraining() {
    setState(() {
      _isTrainingActive = false;
      _isImmersive = false;
    });
    
    // Exit immersive mode
    EdgeToEdge.showSystemUI();
    EdgeToEdge.setDarkSystemUI(context);
    
    // Provide haptic feedback
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: EdgeToEdgeContainer(
        backgroundColor: Colors.black,
        handleStatusBar: !_isImmersive,
        handleNavigationBar: !_isImmersive,
        child: Stack(
          children: [
            // Training Content Area
            Positioned.fill(
              child: _buildTrainingContent(context),
            ),
            
            // Top Controls (hidden in immersive mode)
            if (!_isImmersive)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopControls(context),
              ),
            
            // Bottom Controls (always accessible via gesture in immersive mode)
            Positioned(
              bottom: _isImmersive ? -60 : 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: _isImmersive ? _stopTraining : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  transform: Matrix4.translationValues(
                    0, 
                    _isImmersive ? 60 : 0, 
                    0
                  ),
                  child: _buildBottomControls(context),
                ),
              ),
            ),
            
            // Immersive Mode Indicator
            if (_isImmersive)
              Positioned(
                top: 20,
                right: 20,
                child: _buildImmersiveIndicator(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingContent(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            Colors.blue.shade900.withOpacity(0.3),
            Colors.black,
            Colors.black,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Training Target/Content
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.cyan.withOpacity(0.8),
                    Colors.blue.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: Colors.cyan,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  _isTrainingActive ? 'FOCUS' : 'READY',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Training Status
            Text(
              _isTrainingActive 
                  ? 'Training in Progress...' 
                  : 'Tap to Start Training',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                letterSpacing: 1,
              ),
            ),
            
            if (_isImmersive && _isTrainingActive) ...[
              const SizedBox(height: 20),
              Text(
                'Tap bottom area to exit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white38,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
              ),
            ),
            
            Expanded(
              child: Text(
                'Immersive Training',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            IconButton(
              onPressed: _toggleImmersiveMode,
              icon: Icon(
                _isImmersive 
                    ? Icons.fullscreen_exit_rounded 
                    : Icons.fullscreen_rounded,
                color: Colors.white,
              ),
              tooltip: _isImmersive ? 'Exit Fullscreen' : 'Enter Fullscreen',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Settings Button
            _buildControlButton(
              context,
              icon: Icons.settings_rounded,
              label: 'Settings',
              onPressed: () {
                // Open settings
              },
            ),
            
            // Main Action Button
            _buildMainActionButton(context),
            
            // Immersive Toggle
            _buildControlButton(
              context,
              icon: _isImmersive 
                  ? Icons.fullscreen_exit_rounded 
                  : Icons.fullscreen_rounded,
              label: _isImmersive ? 'Exit' : 'Immersive',
              onPressed: _toggleImmersiveMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActionButton(BuildContext context) {
    return GestureDetector(
      onTap: _isTrainingActive ? _stopTraining : _startTraining,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: _isTrainingActive
                ? [Colors.red.shade400, Colors.red.shade700]
                : [Colors.green.shade400, Colors.green.shade700],
          ),
          boxShadow: [
            BoxShadow(
              color: (_isTrainingActive ? Colors.red : Colors.green)
                  .withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          _isTrainingActive 
              ? Icons.stop_rounded 
              : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: Colors.white70,
            size: 24,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            shape: const CircleBorder(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white60,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildImmersiveIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.cyan,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'IMMERSIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
