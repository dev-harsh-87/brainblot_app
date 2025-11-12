import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/core/router/app_router.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/core/ui/edge_to_edge.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:spark_app/firebase_options.dart';
import 'package:spark_app/core/storage/app_storage.dart';
import 'package:spark_app/features/auth/bloc/auth_bloc.dart';
import 'package:spark_app/core/auth/auth_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/subscription/services/subscription_fix_service.dart';
import 'package:spark_app/core/services/fcm_token_service.dart';

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
  
  // Initialize FCM token service
  await FCMTokenService.instance.initialize();
  
  // Fix subscription for current user if logged in
  _fixSubscriptionOnStartup();
  
  runApp(const CogniTrainApp());
}

/// Fix subscription synchronization on app startup
void _fixSubscriptionOnStartup() {
  // Run after a short delay to ensure auth is ready
  Future.delayed(const Duration(seconds: 2), () async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print('🔧 Running subscription fix for logged-in user...');
      try {
        final fixService = SubscriptionFixService();
        await fixService.fixCurrentUserSubscription();
        print('✅ Subscription fix completed');
      } catch (e) {
        print('❌ Subscription fix failed: $e');
      }
    }
  });
}


class CogniTrainApp extends StatelessWidget {
  const CogniTrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final authBloc = AuthBloc(
          getIt(),
          userRepo: getIt(),
          sessionService: getIt(),
        );
        
        // AuthBloc now initializes with correct state based on Firebase Auth
        // No need for explicit auth check - SessionManagementService handles it
        print('🔄 App initialization: AuthBloc created with initial state');
        
        return authBloc;
      },
      child: Builder(
        builder: (context) {
          final appRouter = AppRouter(context.read<AuthBloc>());
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Spark - Cognitive Training',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            routerConfig: appRouter.router,
            builder: (context, child) {
              return NavigationStateTracker(
                child: AuthWrapper(child: child ?? const SizedBox.shrink()),
              );
            },
          );
        },
      ),
    );
  }
}

/// Widget to track navigation state for hot reload preservation (debug mode only)
class NavigationStateTracker extends StatefulWidget {
  final Widget child;
  
  const NavigationStateTracker({super.key, required this.child});

  @override
  State<NavigationStateTracker> createState() => _NavigationStateTrackerState();
}

class _NavigationStateTrackerState extends State<NavigationStateTracker> {
  @override
  void initState() {
    super.initState();
    
    // Clear navigation state on fresh app start (not hot reload)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode) {
        try {
          // Only clear if this is a fresh start, not a hot reload
          final lastLocation = AppStorage.getString('last_navigation_location');
          if (lastLocation != null) {
            print('[NAVIGATION] Found preserved location: $lastLocation');
            // Clear it after a delay to prevent infinite loops
            Future.delayed(const Duration(seconds: 5), () {
              AppStorage.remove('last_navigation_location');
            });
          }
        } catch (e) {
          print('[NAVIGATION] State tracking error: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
