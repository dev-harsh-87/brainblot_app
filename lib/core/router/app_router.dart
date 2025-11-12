import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/admin/enhanced_admin_dashboard_screen.dart';
import 'package:spark_app/features/home/ui/modern_home_screen.dart';
import 'package:spark_app/features/programs/services/program_progress_service.dart';
import 'package:spark_app/features/settings/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/features/auth/login_screen.dart';
import 'package:spark_app/features/profile/profile_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spark_app/features/auth/bloc/auth_bloc.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/core/auth/auth_wrapper.dart';
import 'package:spark_app/core/router/go_router_refresh_stream.dart';
import 'package:spark_app/core/storage/app_storage.dart';
import 'package:spark_app/features/home/bloc/home_bloc.dart';
import 'package:spark_app/features/training/training_screen.dart';
import 'package:spark_app/features/drills/drill_library_screen.dart';
import 'package:spark_app/features/drills/ui/drill_detail_screen.dart';
import 'package:spark_app/features/drills/ui/drill_builder_screen.dart';
import 'package:spark_app/features/drills/ui/drill_runner_screen.dart';
import 'package:spark_app/features/drills/ui/drill_results_screen.dart';
import 'package:spark_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:spark_app/features/programs/programs_screen.dart';
import 'package:spark_app/features/programs/bloc/programs_bloc.dart';
import 'package:spark_app/features/programs/ui/program_day_screen.dart';
import 'package:spark_app/features/programs/ui/program_stats_screen.dart';
import 'package:spark_app/features/programs/domain/program.dart';
import 'package:spark_app/features/stats/stats_screen.dart';
import 'package:spark_app/features/stats/bloc/stats_bloc.dart';
import 'package:spark_app/features/settings/bloc/settings_bloc.dart';
import 'package:spark_app/features/auth/register_screen.dart';
import 'package:spark_app/features/auth/forgot_password_screen.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/domain/session_result.dart';
import 'package:spark_app/features/multiplayer/ui/multiplayer_selection_screen.dart';
import 'package:spark_app/features/multiplayer/ui/host_session_screen.dart';
import 'package:spark_app/features/multiplayer/ui/join_session_screen.dart';
import 'package:spark_app/core/auth/services/permission_service.dart';
import 'package:spark_app/features/subscription/ui/subscription_screen.dart';
import 'package:spark_app/features/subscription/ui/user_requests_screen.dart';
import 'package:spark_app/core/auth/guards/admin_guard.dart';
import 'package:spark_app/core/auth/models/user_role.dart';

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
  /// In debug mode, preserves last location for better development experience
  String _getInitialLocation() {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // In debug mode, try to restore last location for hot reload
    if (kDebugMode && currentUser != null) {
      try {
        final lastLocation = AppStorage.getString(_lastLocationKey);
        if (lastLocation != null && 
            lastLocation.isNotEmpty && 
            !_authRoutes.contains(lastLocation)) {
          debugPrint('[Router] Hot reload: Restoring location: $lastLocation');
          return lastLocation;
        }
      } catch (e) {
        debugPrint('[Router] Failed to restore location: $e');
      }
    }
    
    // Default routing based on auth state
    return currentUser != null ? '/' : '/login';
  }

  /// Saves current location for hot reload restoration (debug mode only)
  void _saveLocationForHotReload(String location) {
    if (!kDebugMode || _authRoutes.contains(location)) return;
    
    try {
      AppStorage.setString(_lastLocationKey, location);
    } catch (e) {
      debugPrint('[Router] Failed to save location: $e');
    }
  }

  /// Main redirect logic for authentication and route protection
  String? _handleRedirect(BuildContext context, GoRouterState state) {
    final currentLocation = state.uri.toString();
    final authState = _authBloc.state;
    final isAuthRoute = _authRoutes.contains(currentLocation);
    
    // Save location for hot reload (debug mode)
    _saveLocationForHotReload(currentLocation);
    
    // Don't redirect during authentication loading
    if (authState.status == AuthStatus.loading) {
      return null;
    }
    
    // Authenticated user trying to access auth routes -> redirect to home
    if (authState.status == AuthStatus.authenticated && isAuthRoute) {
      return '/';
    }
    
    // For hot reload: Check if Firebase Auth has a user before redirecting to login
    if (authState.status == AuthStatus.initial && !isAuthRoute) {
      // In debug mode, check if Firebase Auth still has a user (hot reload case)
      if (kDebugMode) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          // User is still logged in Firebase Auth, don't redirect to login
          // Let AuthBloc handle the state restoration
          debugPrint('[Router] Hot reload detected: User still in Firebase Auth, allowing navigation');
          return null;
        }
      }
      return '/login';
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
      // Authentication Routes
      ..._buildAuthRoutes(),
      
      // Main Application Routes
      _buildHomeRoute(),
      
      // Drill Routes
      ..._buildDrillRoutes(),
      
      // Program Routes
      ..._buildProgramRoutes(),
      
      // Multiplayer Routes
      _buildMultiplayerRoute(),
      
      // Admin Routes
      _buildAdminRoute(),
      
      // Subscription Routes
      ..._buildSubscriptionRoutes(),
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

  /// Main home route with nested routes
  GoRoute _buildHomeRoute() {
    return GoRoute(
      path: '/',
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
          child: const ModernHomeScreen(),
        ),
      ),
      routes: [
        GoRoute(
          path: 'training',
          name: 'training',
          builder: (context, state) => const TrainingScreen(),
        ),
        GoRoute(
          path: 'drills',
          name: 'drills',
          builder: (context, state) => BlocProvider.value(
            value: getIt<DrillLibraryBloc>(),
            child: const DrillLibraryScreen(),
          ),
        ),
        GoRoute(
          path: 'programs',
          name: 'programs',
          builder: (context, state) => BlocProvider.value(
            value: getIt<ProgramsBloc>(),
            child: const ProgramsScreen(),
          ),
        ),
        GoRoute(
          path: 'stats',
          name: 'stats',
          builder: (context, state) => BlocProvider(
            create: (_) => StatsBloc(getIt())..add(const StatsStarted()),
            child: const StatsScreen(),
          ),
        ),
        GoRoute(
          path: 'settings',
          name: 'settings',
          builder: (context, state) => BlocProvider.value(
            value: getIt<SettingsBloc>()..add(const SettingsStarted()),
            child: const SettingsScreen(),
          ),
        ),
        GoRoute(
          path: 'profile',
          name: 'profile',
          builder: (context, state) => MultiBlocProvider(
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
      ],
    );
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
      builder: (context, state) => BlocProvider.value(
        value: getIt<SettingsBloc>()..add(const SettingsStarted()),
        child: const MultiplayerSelectionScreen(),
      ),
      routes: [
        GoRoute(
          path: 'host',
          name: 'multiplayer-host',
          builder: (context, state) => BlocProvider.value(
            value: getIt<SettingsBloc>()..add(const SettingsStarted()),
            child: const HostSessionScreen(),
          ),
        ),
        GoRoute(
          path: 'join',
          name: 'multiplayer-join',
          builder: (context, state) => BlocProvider.value(
            value: getIt<SettingsBloc>()..add(const SettingsStarted()),
            child: const JoinSessionScreen(),
          ),
        ),
      ],
    );
  }

  /// Admin route (protected by AdminGuard)
  GoRoute _buildAdminRoute() {
    return GoRoute(
      path: '/admin',
      name: 'admin',
      builder: (context, state) => AdminGuard(
        permissionService: getIt<PermissionService>(),
        requiredRole: UserRole.admin,
        child: EnhancedAdminDashboardScreen(
          permissionService: getIt<PermissionService>(),
        ),
      ),
    );
  }

  /// Subscription routes
  List<GoRoute> _buildSubscriptionRoutes() {
    return [
      GoRoute(
        path: '/subscription',
        name: 'subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/user-requests',
        name: 'user-requests',
        builder: (context, state) => const UserRequestsScreen(),
      ),
    ];
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