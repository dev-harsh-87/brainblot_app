import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brainblot_app/features/auth/data/auth_repository.dart';
import 'package:brainblot_app/features/auth/data/firebase_user_repository.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/data/session_repository.dart';
import 'package:brainblot_app/features/drills/data/firebase_drill_repository.dart';
import 'package:brainblot_app/features/drills/data/firebase_session_repository.dart';
import 'package:brainblot_app/features/drills/data/hive_drill_repository.dart';
import 'package:brainblot_app/features/drills/data/hive_session_repository.dart';
import 'package:brainblot_app/features/programs/data/program_repository.dart';
import 'package:brainblot_app/features/programs/data/firebase_program_repository.dart';

import 'package:brainblot_app/features/programs/services/drill_assignment_service.dart';
import 'package:brainblot_app/features/programs/services/program_progress_service.dart';
import 'package:brainblot_app/features/settings/bloc/settings_bloc.dart';
import 'package:brainblot_app/features/settings/data/settings_repository.dart';
import 'package:brainblot_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:brainblot_app/features/programs/bloc/programs_bloc.dart';
import 'package:brainblot_app/features/sharing/services/sharing_service.dart';
import 'package:brainblot_app/features/profile/services/profile_service.dart';
import 'package:brainblot_app/core/services/auto_refresh_service.dart';
import 'package:brainblot_app/features/drills/services/drill_creation_service.dart';
import 'package:brainblot_app/features/programs/services/program_creation_service.dart';
import 'package:brainblot_app/features/multiplayer/services/bluetooth_connection_service.dart';
import 'package:brainblot_app/features/multiplayer/services/session_sync_service.dart';
import 'package:brainblot_app/core/auth/services/permission_service.dart';
import 'package:brainblot_app/core/auth/services/subscription_permission_service.dart';
import 'package:brainblot_app/features/subscription/data/subscription_plan_repository.dart';
import 'package:brainblot_app/core/auth/services/session_management_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  print('🔧 DI: Starting professional Firebase dependency injection configuration');
  
  // Core Firebase instances
  final firebaseAuth = FirebaseAuth.instance;
  final firebaseFirestore = FirebaseFirestore.instance;
  
  // Authentication and User Management
  getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository(firebaseAuth));
  getIt.registerLazySingleton<FirebaseUserRepository>(() => FirebaseUserRepository(
    firestore: firebaseFirestore,
    auth: firebaseAuth,
  ));
  
  // Professional Firebase Repositories
  print('🔧 DI: Registering professional Firebase repositories');
  
  getIt.registerLazySingleton<DrillRepository>(() {
    final repo = FirebaseDrillRepository(
      firestore: firebaseFirestore,
      auth: firebaseAuth,
    );
    print('🔧 DI: Created FirebaseDrillRepository instance');
    return repo;
  });
  
  // Also register the concrete type for cases where it's needed specifically
  getIt.registerLazySingleton<FirebaseDrillRepository>(() {
    return getIt<DrillRepository>() as FirebaseDrillRepository;
  });
  
  getIt.registerLazySingleton<SessionRepository>(() {
    final repo = FirebaseSessionRepository(
      firestore: firebaseFirestore,
      auth: firebaseAuth,
    );
    print('🔧 DI: Created FirebaseSessionRepository instance');
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
  print('🔧 DI: Registering services');
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
  ));

  // Auto Refresh Service
  getIt.registerLazySingleton<AutoRefreshService>(() => AutoRefreshService());

  // Creation Services with Auto-Refresh
  getIt.registerLazySingleton<DrillCreationService>(() => DrillCreationService());
  getIt.registerLazySingleton<ProgramCreationService>(() => ProgramCreationService());

  // Multiplayer Services
  getIt.registerLazySingleton<BluetoothConnectionService>(() => BluetoothConnectionService());
  getIt.registerLazySingleton<SessionSyncService>(() => SessionSyncService(getIt<BluetoothConnectionService>()));
  
  // RBAC Services
  print('🔧 DI: Registering RBAC services');
  getIt.registerLazySingleton<PermissionService>(() => PermissionService(
    firestore: firebaseFirestore,
    auth: firebaseAuth,
  ));
  getIt.registerLazySingleton<SubscriptionPlanRepository>(() => SubscriptionPlanRepository(
    firestore: firebaseFirestore,
  ));
// Register Session Management Service (singleton for app-wide session tracking)
  getIt.registerLazySingleton<SessionManagementService>(() => SessionManagementService(
    auth: firebaseAuth,
    firestore: firebaseFirestore,
    permissionService: getIt<PermissionService>(),
  ));
  
  // Register Subscription Permission Service
  getIt.registerLazySingleton<SubscriptionPermissionService>(() => SubscriptionPermissionService(
    auth: firebaseAuth,
    firestore: firebaseFirestore,
  ));
  
  print('🔧 DI: Professional Firebase dependency injection configuration completed successfully');
  print('🔧 DI: Available repositories: Firebase (primary), Hive (local fallback)');
  print('🔧 DI: RBAC system initialized with PermissionService and SubscriptionPlanRepository');
  print("🔧 DI: Session management service registered - centralized auth handling enabled");
}
