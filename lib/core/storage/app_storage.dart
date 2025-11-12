import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class AppStorage {
  static bool _inited = false;
  static Box? _settingsBox;
  
  static Future<void> init() async {
    if (_inited) return;
    if (!kIsWeb) {
      final Directory dir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(dir.path);
    } else {
      await Hive.initFlutter();
    }
    // Open boxes used across the app
    await Hive.openBox('drills');
    await Hive.openBox('sessions');
    _settingsBox = await Hive.openBox('settings');
    _inited = true;
  }
  
  // String storage methods for development navigation preservation
  static String? getString(String key) {
    try {
      final value = _settingsBox?.get(key);
      return value is String ? value : null;
    } catch (e) {
      print('AppStorage.getString error: $e');
      return null;
    }
  }
  
  static Future<void> setString(String key, String value) async {
    try {
      await _settingsBox?.put(key, value);
    } catch (e) {
      print('AppStorage.setString error: $e');
    }
  }
  
  static Future<void> remove(String key) async {
    try {
      await _settingsBox?.delete(key);
    } catch (e) {
      print('AppStorage.remove error: $e');
    }
  }
}
