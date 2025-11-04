import 'package:brainblot_app/features/admin/enhanced_admin_dashboard_screen.dart';
import 'package:brainblot_app/features/home/ui/modern_home_screen.dart';

import 'package:brainblot_app/features/programs/services/program_progress_service.dart';
import 'package:brainblot_app/features/settings/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:brainblot_app/features/auth/login_screen.dart';
import 'package:brainblot_app/features/profile/profile_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/auth/bloc/auth_bloc.dart';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/core/auth/auth_wrapper.dart';
import 'package:brainblot_app/core/router/go_router_refresh_stream.dart';
import 'package:brainblot_app/features/home/bloc/home_bloc.dart';
import 'package:brainblot_app/features/training/training_screen.dart';
import 'package:brainblot_app/features/drills/drill_library_screen.dart';
import 'package:brainblot_app/features/drills/ui/drill_detail_screen.dart';
import 'package:brainblot_app/features/drills/ui/drill_builder_screen.dart';
import 'package:brainblot_app/features/drills/ui/drill_runner_screen.dart';
import 'package:brainblot_app/features/drills/ui/drill_results_screen.dart';
import 'package:brainblot_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:brainblot_app/features/programs/programs_screen.dart';
import 'package:brainblot_app/features/programs/bloc/programs_bloc.dart';
import 'package:brainblot_app/features/programs/ui/program_day_screen.dart';
import 'package:brainblot_app/features/programs/ui/program_stats_screen.dart';
import 'package:brainblot_app/features/programs/domain/program.dart';
import 'package:brainblot_app/features/stats/stats_screen.dart';
import 'package:brainblot_app/features/stats/bloc/stats_bloc.dart';
import 'package:brainblot_app/features/settings/bloc/settings_bloc.dart';
import 'package:brainblot_app/features/auth/register_screen.dart';
import 'package:brainblot_app/features/auth/forgot_password_screen.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/features/drills/domain/session_result.dart';
import 'package:brainblot_app/features/multiplayer/ui/multiplayer_selection_screen.dart';
import 'package:brainblot_app/features/multiplayer/ui/host_session_screen.dart';
import 'package:brainblot_app/features/multiplayer/ui/join_session_screen.dart';
import 'package:brainblot_app/core/auth/services/permission_service.dart';
import 'package:brainblot_app/features/subscription/ui/subscription_screen.dart';
import 'package:brainblot_app/features/subscription/ui/user_requests_screen.dart';
import 'package:brainblot_app/core/auth/guards/admin_guard.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';

class AppRouter {
  final AuthBloc _authBloc;
  
  AppRouter(this._authBloc);

  late final GoRouter router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final authState = _authBloc.state;
      final isAuthRoute = state.uri.toString() == '/login' ||
                         state.uri.toString() == '/register' ||
                         state.uri.toString() == '/forgot-password';
      
      if (authState.status == AuthStatus.authenticated && isAuthRoute) {
        return '/';
      }
      
      if (authState.status == AuthStatus.initial && !isAuthRoute) {
        return '/login';
      }
      
      // Admin routes will be protected by AdminGuard widgets
      return null;
    },
    refreshListenable: GoRouterRefreshStream(_authBloc.stream),
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (BuildContext context, GoRouterState state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (BuildContext context, GoRouterState state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) => AuthGuard(
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => HomeBloc(getIt(), getIt())..add(const HomeStarted()),
              ),
              BlocProvider.value(
                value: getIt<DrillLibraryBloc>(),
              ),
              BlocProvider.value(
                value: getIt<ProgramsBloc>(),
              ),
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
      ),
      // Standalone routes for drills that may be navigated with extras
      GoRoute(
        path: '/drill-detail',
        name: 'drill-detail',
        builder: (context, state) {
          final drill = state.extra as Drill;
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
          if (state.extra is Map<String, dynamic>) {
            final extras = state.extra as Map<String, dynamic>;
            final drill = extras['drill'] as Drill;
            final programId = extras['programId'] as String?;
            final programDayNumber = extras['programDayNumber'] as int?;
            return DrillRunnerScreen(
              drill: drill,
              programId: programId,
              programDayNumber: programDayNumber,
            );
          } else {
            final drill = state.extra as Drill;
            return DrillRunnerScreen(drill: drill);
          }
        },
      ),
      GoRoute(
        path: '/drill-results',
        name: 'drill-results',
        builder: (context, state) {
          final result = state.extra as SessionResult;
          return DrillResultsScreen(result: result);
        },
      ),
      // Program routes
      GoRoute(
        path: '/program-day',
        name: 'program-day',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          final program = extras['program'] as Program;
          final dayNumber = extras['dayNumber'] as int;
          final progress = extras['progress'] as ProgramProgress?;
          return ProgramDayScreen(
            program: program,
            dayNumber: dayNumber,
            progress: progress,
          );
        },
      ),
      GoRoute(
        path: '/program-stats',
        name: 'program-stats',
        builder: (context, state) => const ProgramStatsScreen(),
      ),
      // Multiplayer routes
      GoRoute(
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
      ),
      // Admin routes - Protected with AdminGuard
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => AdminGuard(
          permissionService: getIt<PermissionService>(),
          requiredRole: UserRole.admin,
          child: EnhancedAdminDashboardScreen(
            permissionService: getIt<PermissionService>(),
          ),
        ),
      ),
      // Subscription routes
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
    ],
  );
}
