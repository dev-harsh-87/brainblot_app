import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/core/auth/auth_wrapper.dart';
import 'package:spark_app/core/auth/screens/permission_splash_screen.dart';
import 'package:spark_app/core/auth/services/permission_service.dart';
import 'package:spark_app/core/widgets/permission_based_screen.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/core/router/go_router_refresh_stream.dart';
import 'package:spark_app/core/storage/app_storage.dart';
import 'package:spark_app/core/widgets/main_navigation.dart';
import 'package:spark_app/core/screens/app_initialization_screen.dart';
import 'package:spark_app/features/admin/enhanced_admin_dashboard_screen.dart';
import 'package:spark_app/features/auth/bloc/auth_bloc.dart';
import 'package:spark_app/features/auth/forgot_password_screen.dart';
import 'package:spark_app/features/auth/login_screen.dart';
import 'package:spark_app/features/auth/register_screen.dart';
import 'package:spark_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/domain/session_result.dart';
import 'package:spark_app/features/drills/drill_library_screen.dart';
import 'package:spark_app/features/drills/ui/drill_builder_screen.dart';
import 'package:spark_app/features/drills/ui/drill_detail_screen.dart';
import 'package:spark_app/features/drills/ui/drill_results_screen.dart';
import 'package:spark_app/features/drills/ui/drill_runner_screen.dart';
import 'package:spark_app/features/home/bloc/home_bloc.dart';
import 'package:spark_app/features/home/ui/home_screen.dart';
import 'package:spark_app/features/multiplayer/ui/host_session_screen.dart';
import 'package:spark_app/features/multiplayer/ui/join_session_screen.dart';
import 'package:spark_app/features/multiplayer/ui/multiplayer_selection_screen.dart';
import 'package:spark_app/features/profile/profile_screen.dart';
import 'package:spark_app/features/programs/bloc/programs_bloc.dart';
import 'package:spark_app/features/programs/domain/program.dart';
import 'package:spark_app/features/programs/programs_screen.dart';
import 'package:spark_app/features/programs/services/program_progress_service.dart';
import 'package:spark_app/features/programs/ui/program_creation_dialog.dart';
import 'package:spark_app/features/programs/ui/program_day_screen.dart';
import 'package:spark_app/features/programs/ui/program_stats_screen.dart';
import 'package:spark_app/features/settings/bloc/settings_bloc.dart';
import 'package:spark_app/features/settings/ui/settings_screen.dart';
import 'package:spark_app/features/stats/bloc/stats_bloc.dart';
import 'package:spark_app/features/stats/stats_screen.dart';
import 'package:spark_app/features/subscription/ui/subscription_screen.dart';
import 'package:spark_app/features/subscription/ui/user_requests_screen.dart';
import 'package:spark_app/features/training/training_screen.dart';
import 'package:spark_app/features/admin/ui/user_management_screen.dart';
import 'package:spark_app/features/admin/ui/screens/user_permission_management_screen.dart';
import 'package:spark_app/features/admin/ui/subscription_management_screen.dart';
import 'package:spark_app/features/admin/ui/plan_requests_screen.dart';
import 'package:spark_app/features/admin/ui/category_management_screen.dart';
import 'package:spark_app/features/admin/ui/stimulus_management_screen.dart';
import 'package:spark_app/features/admin/ui/screens/comprehensive_activity_screen.dart';
import 'package:spark_app/features/admin/ui/user_admin_dashboard_screen.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/auth/services/permission_manager.dart';


/// Main application router configuration
/// Handles all navigation, authentication guards, and hot reload support
class AppRouter {
  final AuthBloc _authBloc;
  
  // Storage key for preserving navigation state during hot reload
  static const String _lastLocationKey = 'last_navigation_location';
  
  // Auth routes that don't require authentication
  static const Set<String> _authRoutes = {
    '/login',
    '/register',
    '/forgot-password',
  };

  AppRouter(this._authBloc);

  /// Determines the initial route based on authentication state
  /// Always starts at initialization screen first
  String _getInitialLocation() {
    // Always start at initialization screen to handle app setup
    return '/init';
  }

  /// Saves current location for hot reload restoration (debug mode only)
  /// Disabled to ensure app always starts at home screen
  void _saveLocationForHotReload(String location) {
    // Disabled - we want the app to always start at home screen on restart
    // This prevents unwanted navigation to drill creation or other screens
    return;
  }

  /// Main redirect logic for authentication and route protection
  String? _handleRedirect(BuildContext context, GoRouterState state) {
    final currentLocation = state.uri.toString();
    final authState = _authBloc.state;
    final isAuthRoute = _authRoutes.contains(currentLocation);
    final isInitRoute = currentLocation == '/init';
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // Save location for hot reload (debug mode)
    _saveLocationForHotReload(currentLocation);
    
    // Always allow access to initialization screen
    if (isInitRoute) {
      return null;
    }
    
    // Don't redirect during authentication loading
    if (authState.status == AuthStatus.loading) {
      return null;
    }
    
    // User is not authenticated - redirect to login (not initialization)
    if (authState.status == AuthStatus.initial && !isAuthRoute) {
      return '/login';
    }
    
    // Authenticated user trying to access auth routes -> redirect to home
    if (authState.status == AuthStatus.authenticated && isAuthRoute) {
      return '/home';
    }
    
    // Allow navigation (admin routes protected by AdminGuard)
    return null;
  }

  late final GoRouter router = GoRouter(
    initialLocation: _getInitialLocation(),
    redirect: _handleRedirect,
    refreshListenable: GoRouterRefreshStream(_authBloc.stream),
    debugLogDiagnostics: kDebugMode,
    routes: _buildRoutes(),
  );

  /// Builds all application routes
  List<RouteBase> _buildRoutes() {
    return [
      // App Initialization Screen (first screen)
      GoRoute(
        path: '/init',
        name: 'init',
        builder: (context, state) => const AppInitializationScreen(),
      ),
      
      // Permission Splash Screen Route (for authenticated users)
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const PermissionSplashScreen(),
      ),
      
      // Authentication Routes (outside shell)
      ..._buildAuthRoutes(),
      
      // Main Application Shell with Bottom Navigation
      ShellRoute(
        builder: (context, state, child) {
          return MainNavigation(
            currentPath: state.uri.path,
            child: child,
          );
        },
        routes: [
          // Main tabs with bottom navigation
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => AuthGuard(
              child: MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) => HomeBloc(getIt(), getIt())..add(const HomeStarted()),
                  ),
                  BlocProvider.value(value: getIt<DrillLibraryBloc>()),
                  BlocProvider.value(value: getIt<ProgramsBloc>()),
                ],
                child: const HomeScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/drills',
            name: 'drills',
            builder: (context, state) {
              final categoryId = state.uri.queryParameters['category'];
              return PermissionBasedScreen(
                requiredModule: 'drills',
                child: BlocProvider.value(
                  value: getIt<DrillLibraryBloc>(),
                  child: DrillLibraryScreen(initialCategory: categoryId),
                ),
              );
            },
          ),
          GoRoute(
            path: '/programs',
            name: 'programs',
            builder: (context, state) => PermissionBasedScreen(
              requiredModule: 'programs',
              child: BlocProvider.value(
                value: getIt<ProgramsBloc>(),
                child: const ProgramsScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/subscription',
            name: 'subscription',
            builder: (context, state) => PermissionBasedScreen(
              requiredModule: 'subscription',
              child: const SubscriptionScreen(),
            ),
          ),
          GoRoute(
            path: '/admin',
            name: 'admin',
            builder: (context, state) {
              // Check if user should see admin content
              final permissionManager = PermissionManager.instance;
              final shouldShowAdminContent = permissionManager.isAdmin ||
                  permissionManager.shouldShowAdminContent ||
                  permissionManager.canAccessAdminUserManagement ||
                  permissionManager.canAccessAdminSubscriptionManagement ||
                  permissionManager.canAccessAdminPlanRequests ||
                  permissionManager.canAccessAdminCategoryManagement ||
                  permissionManager.canAccessAdminStimulusManagement ||
                  permissionManager.canAccessAdminComprehensiveActivity;

              if (!shouldShowAdminContent) {
                return PermissionBasedScreen(
                  requireAdmin: true,
                  child: Container(), // This will show access denied
                );
              }

              // Show full admin dashboard for admins, user admin dashboard for others
              // Use the unified admin dashboard that shows "Available" tags
              return const UserAdminDashboardScreen();
            },
            routes: [
              GoRoute(
                path: '/users',
                name: 'admin-users',
                builder: (context, state) => PermissionBasedScreen(
                  requiredModule: 'admin_user_management',
                  child: const UserManagementScreen(),
                ),
                routes: [
                  GoRoute(
                    path: '/permissions/:userId',
                    name: 'user-permissions',
                    builder: (context, state) {
                      final userId = state.pathParameters['userId']!;
                      return PermissionBasedScreen(
                        requireAdmin: true,
                        child: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Scaffold(
                                body: Center(child: CircularProgressIndicator()),
                              );
                            }
                            
                            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                              return Scaffold(
                                appBar: AppBar(title: const Text('User Not Found')),
                                body: const Center(
                                  child: Text('User not found or error loading user data'),
                                ),
                              );
                            }
                            
                            final userData = snapshot.data!.data() as Map<String, dynamic>;
                            final user = AppUser.fromFirestore(snapshot.data!);
                            
                            return UserPermissionManagementScreen(user: user);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/subscriptions',
                name: 'admin-subscriptions',
                builder: (context, state) => PermissionBasedScreen(
                  requiredModule: 'admin_subscription_management',
                  child: const SubscriptionManagementScreen(),
                ),
              ),
              GoRoute(
                path: '/plan-requests',
                name: 'admin-plan-requests',
                builder: (context, state) => PermissionBasedScreen(
                  requiredModule: 'admin_plan_requests',
                  child: const PlanRequestsScreen(),
                ),
              ),
              GoRoute(
                path: '/categories',
                name: 'admin-categories',
                builder: (context, state) => PermissionBasedScreen(
                  requiredModule: 'admin_category_management',
                  child: const CategoryManagementScreen(),
                ),
              ),
              GoRoute(
                path: '/stimulus',
                name: 'admin-stimulus',
                builder: (context, state) => PermissionBasedScreen(
                  requiredModule: 'admin_stimulus_management',
                  child: const StimulusManagementScreen(),
                ),
              ),
              GoRoute(
                path: '/activity',
                name: 'admin-activity',
                builder: (context, state) => PermissionBasedScreen(
                  requiredModule: 'admin_comprehensive_activity',
                  child: const ComprehensiveActivityScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      
      // Routes outside the shell (full screen)
      GoRoute(
        path: '/',
        redirect: (context, state) => '/home',
      ),
      
      // Drill Routes (full screen)
      ..._buildDrillRoutes(),
      
      // Program Routes (full screen)
      ..._buildProgramRoutes(),
      
      // Multiplayer Routes (full screen)
      _buildMultiplayerRoute(),
      
      // Profile and Settings (full screen)
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => PermissionBasedScreen(
          requiredModule: 'profile',
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(
                value: getIt<SettingsBloc>()..add(const SettingsStarted()),
              ),
              BlocProvider(
                create: (_) => StatsBloc(getIt())..add(const StatsStarted()),
              ),
            ],
            child: const ProfileScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => BlocProvider.value(
          value: getIt<SettingsBloc>()..add(const SettingsStarted()),
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/stats',
        name: 'stats',
        builder: (context, state) => PermissionBasedScreen(
          requiredModule: 'stats',
          child: BlocProvider(
            create: (_) => StatsBloc(getIt())..add(const StatsStarted()),
            child: const StatsScreen(),
          ),
        ),
      ),
      
      // Other Subscription Routes
      GoRoute(
        path: '/user-requests',
        name: 'user-requests',
        builder: (context, state) => const UserRequestsScreen(),
      ),
    ];
  }

  /// Authentication routes (login, register, forgot password)
  List<GoRoute> _buildAuthRoutes() {
    return [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
    ];
  }

  /// Drill-related routes
  List<GoRoute> _buildDrillRoutes() {
    return [
      GoRoute(
        path: '/drill-detail',
        name: 'drill-detail',
        builder: (context, state) {
          final drill = state.extra as Drill?;
          if (drill == null) {
            return _buildErrorScreen(context, 'Drill data not found');
          }
          return DrillDetailScreen(drill: drill);
        },
      ),
      GoRoute(
        path: '/drill-builder',
        name: 'drill-builder',
        builder: (context, state) {
          final drill = state.extra as Drill?;
          return DrillBuilderScreen(initial: drill);
        },
      ),
      GoRoute(
        path: '/drill-runner',
        name: 'drill-runner',
        builder: (context, state) {
          final extras = state.extra;
          
          if (extras is Map<String, dynamic>) {
            final drill = extras['drill'] as Drill?;
            if (drill == null) {
              return _buildErrorScreen(context, 'Drill data not found');
            }
            return DrillRunnerScreen(
              drill: drill,
              programId: extras['programId'] as String?,
              programDayNumber: extras['programDayNumber'] as int?,
            );
          }
          
          if (extras is Drill) {
            return DrillRunnerScreen(drill: extras);
          }
          
          return _buildErrorScreen(context, 'Invalid drill data');
        },
      ),
      GoRoute(
        path: '/drill-results',
        name: 'drill-results',
        builder: (context, state) {
          final extras = state.extra;
          
          // Handle hot reload case - redirect to home
          if (extras == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go('/');
              }
            });
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          // Handle new detailed results format
          if (extras is Map<String, dynamic>) {
            final result = extras['result'] as SessionResult?;
            final detailedSetResults = extras['detailedSetResults'] as List<dynamic>?;
            
            if (result == null) {
              return _buildErrorScreen(context, 'Results not found');
            }
            
            return DrillResultsScreen(
              result: result,
              detailedSetResults: detailedSetResults,
            );
          }
          
          // Handle legacy format (just SessionResult)
          if (extras is SessionResult) {
            return DrillResultsScreen(result: extras);
          }
          
          return _buildErrorScreen(context, 'Invalid results data');
        },
      ),
    ];
  }

  /// Program-related routes
  List<GoRoute> _buildProgramRoutes() {
    return [
      GoRoute(
        path: '/program-builder',
        name: 'program-builder',
        builder: (context, state) {
          final program = state.extra as Program?;
          return BlocProvider.value(
            value: getIt<ProgramsBloc>(),
            child: ProgramCreationScreen(initial: program),
          );
        },
      ),
      GoRoute(
        path: '/program-day',
        name: 'program-day',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>?;
          if (extras == null) {
            return _buildErrorScreen(context, 'Program data not found');
          }
          
          return ProgramDayScreen(
            program: extras['program'] as Program,
            dayNumber: extras['dayNumber'] as int,
            progress: extras['progress'] as ProgramProgress?,
          );
        },
      ),
      GoRoute(
        path: '/program-stats',
        name: 'program-stats',
        builder: (context, state) => const ProgramStatsScreen(),
      ),
    ];
  }

  /// Multiplayer routes
  GoRoute _buildMultiplayerRoute() {
    return GoRoute(
      path: '/multiplayer',
      name: 'multiplayer',
      builder: (context, state) => PermissionBasedScreen(
        requiredModule: 'multiplayer',
        child: BlocProvider.value(
          value: getIt<SettingsBloc>()..add(const SettingsStarted()),
          child: const MultiplayerSelectionScreen(),
        ),
      ),
      routes: [
        GoRoute(
          path: 'host',
          name: 'multiplayer-host',
          builder: (context, state) => PermissionBasedScreen(
            requiredModule: 'multiplayer',
            child: BlocProvider.value(
              value: getIt<SettingsBloc>()..add(const SettingsStarted()),
              child: const HostSessionScreen(),
            ),
          ),
        ),
        GoRoute(
          path: 'join',
          name: 'multiplayer-join',
          builder: (context, state) => PermissionBasedScreen(
            requiredModule: 'multiplayer',
            child: BlocProvider.value(
              value: getIt<SettingsBloc>()..add(const SettingsStarted()),
              child: const JoinSessionScreen(),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds an error screen when navigation data is missing
  Widget _buildErrorScreen(BuildContext context, String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home),
              label: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}