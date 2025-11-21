import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/features/auth/data/auth_repository.dart';
import 'package:spark_app/features/auth/data/firebase_user_repository.dart';
import 'package:spark_app/features/drills/data/drill_repository.dart';
import 'package:spark_app/features/drills/data/drill_category_repository.dart';
import 'package:spark_app/features/drills/data/session_repository.dart';
import 'package:spark_app/features/drills/data/firebase_drill_repository.dart';
import 'package:spark_app/features/drills/data/firebase_session_repository.dart';
import 'package:spark_app/features/drills/data/hive_drill_repository.dart';
import 'package:spark_app/features/drills/data/hive_session_repository.dart';
import 'package:spark_app/features/programs/data/program_repository.dart';
import 'package:spark_app/features/programs/data/firebase_program_repository.dart';

import 'package:spark_app/features/programs/services/drill_assignment_service.dart';
import 'package:spark_app/features/programs/services/program_progress_service.dart';
import 'package:spark_app/features/settings/bloc/settings_bloc.dart';
import 'package:spark_app/features/settings/data/settings_repository.dart';
import 'package:spark_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:spark_app/features/programs/bloc/programs_bloc.dart';
import 'package:spark_app/features/sharing/services/sharing_service.dart';
import 'package:spark_app/features/profile/services/profile_service.dart';
import 'package:spark_app/core/services/auto_refresh_service.dart';
import 'package:spark_app/features/drills/services/drill_creation_service.dart';
import 'package:spark_app/features/programs/services/program_creation_service.dart';
import 'package:spark_app/features/multiplayer/services/session_sync_service.dart';
import 'package:spark_app/features/multiplayer/services/firebase_session_sync_service.dart';
import 'package:spark_app/core/auth/services/permission_service.dart';
import 'package:spark_app/core/auth/services/subscription_permission_service.dart';
import 'package:spark_app/features/subscription/data/subscription_plan_repository.dart';
import 'package:spark_app/features/subscription/services/subscription_sync_service.dart';
import 'package:spark_app/core/services/fcm_token_service.dart';
import 'package:spark_app/core/auth/services/session_management_service.dart';
import 'package:spark_app/core/auth/services/user_management_service.dart';
import 'package:spark_app/features/auth/services/multi_device_session_service.dart';
import 'package:spark_app/features/auth/services/simple_session_service.dart';
import 'package:spark_app/core/services/subscription_migration_service.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'package:spark_app/features/admin/services/custom_stimulus_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  AppLogger.info('Starting Firebase dependency injection configuration');
  
  // Core Firebase instances
  final firebaseAuth = FirebaseAuth.instance;
  final firebaseFirestore = FirebaseFirestore.instance;
  
  // Authentication and User Management
  getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository(firebaseAuth));
  getIt.registerLazySingleton<FirebaseUserRepository>(() => FirebaseUserRepository(
    firestore: firebaseFirestore,
    auth: firebaseAuth,
  ),);
  
  // Professional Firebase Repositories
  AppLogger.debug('Registering Firebase repositories');
  
  getIt.registerLazySingleton<DrillRepository>(() {
    final repo = FirebaseDrillRepository(
      firestore: firebaseFirestore,
      auth: firebaseAuth,
    );
    AppLogger.debug('Created FirebaseDrillRepository instance');
    return repo;
  });
  
  // Also register the concrete type for cases where it's needed specifically
  getIt.registerLazySingleton<FirebaseDrillRepository>(() {
    return getIt<DrillRepository>() as FirebaseDrillRepository;
  });

  getIt.registerLazySingleton<DrillCategoryRepository>(() {
    final repo = DrillCategoryRepository(
      firestore: firebaseFirestore,
    );
    AppLogger.debug('Created DrillCategoryRepository instance');
    return repo;
  });
  
  getIt.registerLazySingleton<SessionRepository>(() {
    final repo = FirebaseSessionRepository(
      firestore: firebaseFirestore,
      auth: firebaseAuth,
    );
    AppLogger.debug('Created FirebaseSessionRepository instance');
    return repo;
  });
  
  getIt.registerLazySingleton<ProgramRepository>(() {
    final repo = FirebaseProgramRepository(
      firestore: firebaseFirestore,
      auth: firebaseAuth,
    );
    return repo;
  });
  
  // Fallback Local Repositories (for offline support)
  getIt.registerLazySingleton<DrillRepository>(() => HiveDrillRepository(), instanceName: 'local');
  getIt.registerLazySingleton<SessionRepository>(() => HiveSessionRepository(), instanceName: 'local');
  
  // Services
  AppLogger.debug('Registering services');
  getIt.registerLazySingleton<DrillAssignmentService>(() => DrillAssignmentService(getIt<DrillRepository>()));
  getIt.registerLazySingleton<ProgramProgressService>(() => ProgramProgressService());
  
  // Settings
  getIt.registerLazySingleton<SettingsRepository>(() => SharedPrefsSettingsRepository());
  getIt.registerLazySingleton<SettingsBloc>(() => SettingsBloc(getIt<SettingsRepository>()));
  
  // Drill Library BLoC
  getIt.registerLazySingleton<DrillLibraryBloc>(() => DrillLibraryBloc(getIt<DrillRepository>()));
  
  // Programs BLoC
  getIt.registerLazySingleton<ProgramsBloc>(() => ProgramsBloc(getIt<ProgramRepository>()));
  
  // Sharing Service
  getIt.registerLazySingleton<SharingService>(() => SharingService());
  
  // Profile Service
  getIt.registerLazySingleton<ProfileService>(() => ProfileService(
    firestore: firebaseFirestore,
    auth: firebaseAuth,
  ),);

  // Auto Refresh Service
  getIt.registerLazySingleton<AutoRefreshService>(() => AutoRefreshService());

  // FCM Token Service
  getIt.registerLazySingleton<FCMTokenService>(() => FCMTokenService.instance);

  // Creation Services with Auto-Refresh
  getIt.registerLazySingleton<DrillCreationService>(() => DrillCreationService());
  getIt.registerLazySingleton<ProgramCreationService>(() => ProgramCreationService());

  // Admin Services
  getIt.registerLazySingleton<CustomStimulusService>(() => CustomStimulusService());

  // Multiplayer Services - Firebase-based (replaces Bluetooth)
  getIt.registerLazySingleton<SessionSyncService>(() => FirebaseSessionSyncService());
  
  // RBAC Services
  AppLogger.debug('Registering RBAC services');
  getIt.registerLazySingleton<PermissionService>(() => PermissionService(
    firestore: firebaseFirestore,
    auth: firebaseAuth,
  ),);
  getIt.registerLazySingleton<SubscriptionPlanRepository>(() => SubscriptionPlanRepository(
    firestore: firebaseFirestore,
  ),);
  
  // Register Subscription Sync Service
  getIt.registerLazySingleton<SubscriptionSyncService>(() => SubscriptionSyncService(
    firestore: firebaseFirestore,
    planRepository: getIt<SubscriptionPlanRepository>(),
  ),);
  
// Register Session Management Service (singleton for app-wide session tracking)
  getIt.registerLazySingleton<SessionManagementService>(() => SessionManagementService(
    auth: firebaseAuth,
    firestore: firebaseFirestore,
    permissionService: getIt<PermissionService>(),
    subscriptionSync: getIt<SubscriptionSyncService>(),
  ),);
  
  
  // Register Subscription Permission Service
  getIt.registerLazySingleton<SubscriptionPermissionService>(() => SubscriptionPermissionService(
    auth: firebaseAuth,
    firestore: firebaseFirestore,
  ),);

  // Register Subscription Migration Service
  getIt.registerLazySingleton<SubscriptionMigrationService>(() => SubscriptionMigrationService(
    firestore: firebaseFirestore,
  ),);

// Register User Management Service
  getIt.registerLazySingleton<UserManagementService>(() => UserManagementService());

  // Register Multi-Device Session Service
  getIt.registerLazySingleton<MultiDeviceSessionService>(() => MultiDeviceSessionService(
    firestore: firebaseFirestore,
    auth: firebaseAuth,
  ));

  // Register Simple Session Service (if needed as fallback)
  getIt.registerLazySingleton<SimpleSessionService>(() => SimpleSessionService(
    firestore: firebaseFirestore,
    auth: firebaseAuth,
  ));
  
  AppLogger.info('Firebase dependency injection configuration completed successfully');
  AppLogger.debug('Available repositories: Firebase (primary), Hive (local fallback)');
  AppLogger.debug('RBAC system initialized with PermissionService and SubscriptionPlanRepository');
  AppLogger.debug('Session management service registered - centralized auth handling enabled');
}
