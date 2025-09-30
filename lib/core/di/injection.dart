import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brainblot_app/features/auth/data/auth_repository.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/data/session_repository.dart';
import 'package:brainblot_app/features/drills/data/hive_drill_repository.dart';
import 'package:brainblot_app/features/drills/data/hive_session_repository.dart';
import 'package:brainblot_app/features/programs/data/program_repository.dart';
import 'package:brainblot_app/features/programs/data/firebase_program_repository.dart';
import 'package:brainblot_app/features/programs/services/drill_assignment_service.dart';
import 'package:brainblot_app/features/programs/services/program_progress_service.dart';
import 'package:brainblot_app/features/team/data/team_repository.dart';
import 'package:brainblot_app/features/settings/data/settings_repository.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  print('🔧 DI: Starting dependency injection configuration');
  
  // Repositories
  getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository(FirebaseAuth.instance));
  getIt.registerLazySingleton<DrillRepository>(() => HiveDrillRepository());
  getIt.registerLazySingleton<SessionRepository>(() => HiveSessionRepository());
  
  print('🔧 DI: Registering ProgramRepository as FirebaseProgramRepository');
  getIt.registerLazySingleton<ProgramRepository>(() {
    final repo = FirebaseProgramRepository();
    print('🔧 DI: Created FirebaseProgramRepository instance: ${repo.runtimeType}');
    return repo;
  });
  
  // Services
  getIt.registerLazySingleton<DrillAssignmentService>(() => DrillAssignmentService(getIt<DrillRepository>()));
  getIt.registerLazySingleton<ProgramProgressService>(() => ProgramProgressService());
  
  getIt.registerLazySingleton<TeamRepository>(() => InMemoryTeamRepository());
  getIt.registerLazySingleton<SettingsRepository>(() => SharedPrefsSettingsRepository());
  
  print('🔧 DI: Dependency injection configuration completed');
  
  print('🔧 DI: Dependency injection configuration completed');
}
