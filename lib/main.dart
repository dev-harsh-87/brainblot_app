import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/core/router/app_router.dart';
import 'package:brainblot_app/core/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:brainblot_app/firebase_options.dart';
import 'package:brainblot_app/core/storage/app_storage.dart';
import 'package:brainblot_app/features/auth/bloc/auth_bloc.dart';
import 'package:brainblot_app/core/auth/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppStorage.init();
  await configureDependencies();
  runApp(const CogniTrainApp());
}

class CogniTrainApp extends StatelessWidget {
  const CogniTrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(getIt())..add(const AuthCheckRequested()),
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
