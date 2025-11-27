import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/core/auth/services/permission_manager.dart';
import 'package:spark_app/core/widgets/app_loader.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Professional splash screen that initializes and analyzes permissions at startup
/// This eliminates the need for permission checks throughout the app
class PermissionSplashScreen extends StatefulWidget {
  const PermissionSplashScreen({super.key});

  @override
  State<PermissionSplashScreen> createState() => _PermissionSplashScreenState();
}

class _PermissionSplashScreenState extends State<PermissionSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late Animation<double> _logoAnimation;
  late Animation<double> _progressAnimation;
  
  String _currentStep = 'Initializing...';
  double _progress = 0.0;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePermissions();
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _logoController.forward();
  }

  Future<void> _initializePermissions() async {
    try {
      final permissionManager = PermissionManager.instance;
      
      // Step 1: Initialize service
      _updateProgress('Connecting to authentication...', 0.1);
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 2: Initialize permission manager
      _updateProgress('Loading user profile...', 0.3);
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Step 3: Analyze permissions
      _updateProgress('Analyzing subscription...', 0.5);
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Step 4: Initialize all permissions
      _updateProgress('Analyzing permissions...', 0.7);
      await permissionManager.initializePermissions();
      
      // Step 5: Complete
      _updateProgress('Optimizing performance...', 0.9);
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Step 6: Ready
      _updateProgress('Ready!', 1.0);
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Log permission summary for debugging
      final debugInfo = permissionManager.getDebugInfo();
      AppLogger.success('Permission initialization complete: $debugInfo', tag: 'PermissionSplash');
      
      // Navigate to main app
      if (mounted) {
        context.go('/home');
      }
      
    } catch (e, stackTrace) {
      AppLogger.error('Permission initialization failed', error: e, stackTrace: stackTrace, tag: 'PermissionSplash');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _updateProgress(String step, double progress) {
    if (mounted) {
      setState(() {
        _currentStep = step;
        _progress = progress;
      });
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // Enhanced Animated Logo
              AnimatedBuilder(
                animation: _logoAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoAnimation.value,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 8,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.15),
                            blurRadius: 60,
                            spreadRadius: 15,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.surface,
                              colorScheme.surfaceContainerHighest.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: Image.asset(
                            "assets/images/logo.png",
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback if logo image is not found
                              return Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Icon(
                                  Icons.psychology_outlined,
                                  size: 50,
                                  color: colorScheme.onPrimary,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // App Name
              Text(
                'Spark App',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Cognitive Training Platform',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              
              const Spacer(),
              
              // Error State
              if (_hasError) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Initialization Failed',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _errorMessage ?? 'Unknown error occurred',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _errorMessage = null;
                            _progress = 0.0;
                            _currentStep = 'Retrying...';
                          });
                          _initializePermissions();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Progress Indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: colorScheme.outline.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Current Step
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _progressAnimation.value,
                            child: Text(
                              _currentStep,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Progress Percentage
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const Spacer(),
              
              // Footer
              Text(
                'Initializing your personalized experience...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}