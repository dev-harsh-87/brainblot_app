  import 'package:flutter/material.dart';
  import 'package:brainblot_app/core/di/injection.dart';
  import 'package:brainblot_app/core/router/app_router.dart';
  import 'package:brainblot_app/core/theme/app_theme.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:brainblot_app/firebase_options.dart';
  import 'package:brainblot_app/core/storage/app_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppStorage.init();
  await configureDependencies();
  runApp(const CogniTrainApp());
}

class CogniTrainApp extends StatelessWidget {
  const CogniTrainApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CogniTrain',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter.router,
    );
  }
}
