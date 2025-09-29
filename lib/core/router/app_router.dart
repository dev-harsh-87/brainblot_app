import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:brainblot_app/features/auth/login_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/auth/bloc/auth_bloc.dart';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/features/home/home_dashboard_screen.dart';
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
import 'package:brainblot_app/features/stats/stats_screen.dart';
import 'package:brainblot_app/features/stats/bloc/stats_bloc.dart';
import 'package:brainblot_app/features/team/team_screen.dart';
import 'package:brainblot_app/features/team/bloc/team_bloc.dart';
import 'package:brainblot_app/features/settings/settings_screen.dart';
import 'package:brainblot_app/features/settings/bloc/settings_bloc.dart';
import 'package:brainblot_app/features/auth/register_screen.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/features/drills/domain/session_result.dart';

class AppRouter {
  AppRouter();

  final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (BuildContext context, GoRouterState state) => BlocProvider(
          create: (_) => AuthBloc(getIt()) ,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (BuildContext context, GoRouterState state) => BlocProvider(
          create: (_) => AuthBloc(getIt()),
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) => BlocProvider(
          create: (_) => HomeBloc(getIt(), getIt())..add(const HomeStarted()),
          child: const HomeDashboardScreen(),
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
            builder: (context, state) => BlocProvider(
              create: (_) => DrillLibraryBloc(getIt())..add(const DrillLibraryStarted()),
              child: const DrillLibraryScreen(),
            ),
          ),
          GoRoute(
            path: 'programs',
            name: 'programs',
            builder: (context, state) => BlocProvider(
              create: (_) => ProgramsBloc(getIt())..add(const ProgramsStarted()),
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
            path: 'team',
            name: 'team',
            builder: (context, state) => BlocProvider(
              create: (_) => TeamBloc(getIt())..add(const TeamStarted()),
              child: const TeamScreen(),
            ),
          ),
          GoRoute(
            path: 'settings',
            name: 'settings',
            builder: (context, state) => BlocProvider(
              create: (_) => SettingsBloc(getIt())..add(const SettingsStarted()),
              child: const SettingsScreen(),
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
          final drill = state.extra as Drill;
          return DrillRunnerScreen(drill: drill);
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
    ],
  );
}
