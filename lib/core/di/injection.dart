import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/features/auth/data/auth_repository.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/data/session_repository.dart';
import 'package:brainblot_app/features/drills/data/hive_drill_repository.dart';
import 'package:brainblot_app/features/drills/data/hive_session_repository.dart';
import 'package:brainblot_app/features/programs/data/program_repository.dart';
import 'package:brainblot_app/features/team/data/team_repository.dart';
import 'package:brainblot_app/features/settings/data/settings_repository.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Repositories
  getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository(FirebaseAuth.instance));
  getIt.registerLazySingleton<DrillRepository>(() => HiveDrillRepository());
  getIt.registerLazySingleton<SessionRepository>(() => HiveSessionRepository());
  getIt.registerLazySingleton<ProgramRepository>(() => InMemoryProgramRepository());
  getIt.registerLazySingleton<TeamRepository>(() => InMemoryTeamRepository());
  getIt.registerLazySingleton<SettingsRepository>(() => SharedPrefsSettingsRepository());
}
