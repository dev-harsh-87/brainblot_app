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
import 'package:brainblot_app/features/sharing/services/user_profile_setup_service.dart';
import 'package:brainblot_app/core/services/preferences_service.dart';
import 'package:brainblot_app/core/services/app_initialization_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize edge-to-edge functionality
  EdgeToEdge.initialize();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppStorage.init();
  await configureDependencies();
  
  // Initialize database with default admin and subscription plans
  await AppInitializationService.initialize();
  
  // Check for auto-login
  await _checkAutoLogin();
  
  // Ensure current user has profile (if logged in)
  _ensureUserProfile();
  
  runApp(const CogniTrainApp());
}

Future<void> _checkAutoLogin() async {
  try {
    final prefs = await PreferencesService.getInstance();
    final shouldAutoLogin = await prefs.shouldAutoLogin();
    
    if (shouldAutoLogin) {
      final credentials = await prefs.getSavedCredentials();
      final email = credentials['email'];
      final password = credentials['password'];
      
      if (email != null && password != null) {
        print('🔄 Attempting auto-login for: $email');
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('✅ Auto-login successful');
      }
    }
  } catch (e) {
    print('⚠️ Auto-login failed: $e');
    // Clear saved credentials if auto-login fails
    try {
      final prefs = await PreferencesService.getInstance();
      await prefs.clearSavedCredentials();
    } catch (clearError) {
      print('⚠️ Failed to clear credentials: $clearError');
    }
  }
}

void _ensureUserProfile() {
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      try {
        final setupService = UserProfileSetupService();
        await setupService.ensureUserProfileExists();
        print('✅ User profile ensured for: ${user.email}');
      } catch (e) {
        print('⚠️ Profile creation error: $e');
      }
    }
  });
}

class CogniTrainApp extends StatelessWidget {
  const CogniTrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(getIt(), userRepo: getIt())..add(const AuthCheckRequested()),
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
