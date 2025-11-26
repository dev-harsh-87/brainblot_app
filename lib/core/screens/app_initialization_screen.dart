import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'package:spark_app/core/services/database_initialization_service.dart';
import 'package:spark_app/core/services/category_initialization_service.dart';
import 'package:spark_app/core/auth/services/permission_manager.dart';

/// App initialization splash screen that handles all startup tasks
/// Shows before login screen and handles admin account creation, categories, etc.
class AppInitializationScreen extends StatefulWidget {
  const AppInitializationScreen({super.key});

  @override
  State<AppInitializationScreen> createState() => _AppInitializationScreenState();
}

class _AppInitializationScreenState extends State<AppInitializationScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late Animation<double> _logoAnimation;
  late Animation<double> _progressAnimation;
  
  String _currentStep = 'Starting up...';
  double _progress = 0.0;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
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

  Future<void> _initializeApp() async {
    try {
      // Step 1: Initialize Firebase connection
      _updateProgress('Connecting to Firebase...', 0.1);
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 2: Create admin account if needed
      _updateProgress('Setting up admin account...', 0.25);
      await _createAdminAccountIfNeeded();
      
      // Step 3: Initialize categories
      _updateProgress('Loading drill categories...', 0.5);
      await _initializeCategoriesIfNeeded();
      
      // Check if user is authenticated for permission initialization
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        // Step 4: Initialize permissions for authenticated users
        _updateProgress('Loading user profile...', 0.7);
        await Future.delayed(const Duration(milliseconds: 300));
        
        _updateProgress('Analyzing subscription...', 0.8);
        await Future.delayed(const Duration(milliseconds: 300));
        
        _updateProgress('Analyzing permissions...', 0.9);
        final permissionManager = PermissionManager.instance;
        await permissionManager.initializePermissions();
        
        // Log permission summary for debugging
        final debugInfo = permissionManager.getDebugInfo();
        AppLogger.success('Permission initialization complete: $debugInfo', tag: 'AppInit');
      } else {
        // Step 4: Complete initialization for non-authenticated users
        _updateProgress('Finalizing setup...', 0.9);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Step 5: Ready
      _updateProgress('Ready!', 1.0);
      await Future.delayed(const Duration(milliseconds: 500));
      
      AppLogger.success('App initialization completed successfully', tag: 'AppInit');
      
      // Navigate based on authentication state
      if (mounted) {
        if (currentUser != null) {
          // User is authenticated and permissions are loaded, go directly to home
          context.go('/home');
        } else {
          // No user, go to login
          context.go('/login');
        }
      }
      
    } catch (e, stackTrace) {
      AppLogger.error('App initialization failed', error: e, stackTrace: stackTrace, tag: 'AppInit');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  /// Create admin account if it doesn't exist
  Future<void> _createAdminAccountIfNeeded() async {
    try {
      AppLogger.info('🚀 Starting database initialization process...', tag: 'AppInit');
      
      final dbService = DatabaseInitializationService();
      
      // Check if database is already initialized
      final isInitialized = await dbService.isDatabaseInitialized();
      if (isInitialized) {
        AppLogger.success('✅ Database already initialized', tag: 'AppInit');
        return;
      }
      
      // Initialize database with default admin and subscription plans
      await dbService.initializeDatabase();
      AppLogger.success('🎉 Database initialized successfully!', tag: 'AppInit');
      
    } catch (e) {
      AppLogger.error('❌ Database initialization failed', error: e, tag: 'AppInit');
      // Don't throw - let the app continue even if initialization fails
    }
  }

  /// Initialize default categories if needed
  Future<void> _initializeCategoriesIfNeeded() async {
    try {
      AppLogger.info('🏷️ Checking if categories need initialization...', tag: 'AppInit');
      
      final categoryService = CategoryInitializationService();
      final needsInit = await categoryService.needsInitialization();
      
      if (needsInit) {
        AppLogger.info('📝 Initializing default drill categories...', tag: 'AppInit');
        await categoryService.initializeDefaultCategories();
        AppLogger.success('✅ Default categories initialized successfully!', tag: 'AppInit');
      } else {
        AppLogger.info('✅ Drill categories already exist', tag: 'AppInit');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to initialize categories', error: e, tag: 'AppInit');
      // Don't throw - let the app continue even if category initialization fails
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
              
              // Animated Logo
              AnimatedBuilder(
                animation: _logoAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.psychology,
                        size: 60,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // App Name
              Text(
                'Spark',
                style: theme.textTheme.headlineLarge?.copyWith(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {
                              // Skip initialization and go to login
                              context.go('/login');
                            },
                            child: const Text('Skip'),
                          ),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                _hasError = false;
                                _errorMessage = null;
                                _progress = 0.0;
                                _currentStep = 'Retrying...';
                              });
                              _initializeApp();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
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
                'Setting up your cognitive training environment...',
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