// Placeholder Firebase options. Replace with real values using FlutterFire CLI.
// flutterfire configure --project=<your-project>

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE',
    appId: 'REPLACE',
    messagingSenderId: 'REPLACE',
    projectId: 'REPLACE',
    authDomain: 'REPLACE',
    storageBucket: 'REPLACE',
    measurementId: 'REPLACE',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDcIvHlP8NitTJHRe9ThBmMAad-mLw8oNU',
    appId: '1:1055105336856:android:6eda36592f09e30c50e56d',
    messagingSenderId: '1055105336856',
    projectId: 'brain-bolt-training',
    storageBucket: 'brain-bolt-training.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC83iG9qjApIpUys8nj6Pias3K7_ICeeGs',
    appId: '1:1055105336856:ios:bd5e942bb9abb9d150e56d',
    messagingSenderId: '1055105336856',
    projectId: 'brain-bolt-training',
    storageBucket: 'brain-bolt-training.firebasestorage.app',
    iosBundleId: 'com.tbg.brainblotApp',
  );

  static const FirebaseOptions macos = ios;
  static const FirebaseOptions windows = AndroidLike.windows;
  static const FirebaseOptions linux = AndroidLike.linux;
}

// Minimal stand-ins for desktop; replace if you add desktop Firebase.
class AndroidLike {
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE',
    appId: 'REPLACE',
    messagingSenderId: 'REPLACE',
    projectId: 'REPLACE',
  );
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE',
    appId: 'REPLACE',
    messagingSenderId: 'REPLACE',
    projectId: 'REPLACE',
  );
}