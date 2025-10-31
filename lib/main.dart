import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/core/router/app_router.dart';
import 'package:brainblot_app/core/theme/app_theme.dart';
import 'package:brainblot_app/core/ui/edge_to_edge.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:brainblot_app/firebase_options.dart';
import 'package:brainblot_app/core/storage/app_storage.dart';
import 'package:brainblot_app/features/auth/bloc/auth_bloc.dart';
import 'package:brainblot_app/core/auth/auth_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize edge-to-edge functionality
  EdgeToEdge.initialize();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize app storage
  await AppStorage.init();
  
  // Configure dependency injection
  await configureDependencies();
  
  // Profile creation is now handled by SessionManagementService
  
  runApp(const CogniTrainApp());
}


class CogniTrainApp extends StatelessWidget {
  const CogniTrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(
        getIt(),
        userRepo: getIt(),
        sessionService: getIt(),
      )..add(const AuthCheckRequested()),
      child: Builder(
        builder: (context) {
          final appRouter = AppRouter(context.read<AuthBloc>());
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'BrainBlot - Cognitive Training',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            routerConfig: appRouter.router,
            builder: (context, child) {
              return AuthWrapper(child: child ?? const SizedBox.shrink());
            },
          );
        },
      ),
    );
  }
}
