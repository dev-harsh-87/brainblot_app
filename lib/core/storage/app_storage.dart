import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class AppStorage {
  static bool _inited = false;
  static Future<void> init() async {
    if (_inited) return;
    if (!kIsWeb) {
      Directory dir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(dir.path);
    } else {
      await Hive.initFlutter();
    }
    // Open boxes used across the app
    await Hive.openBox('drills');
    await Hive.openBox('sessions');
    _inited = true;
  }
}
