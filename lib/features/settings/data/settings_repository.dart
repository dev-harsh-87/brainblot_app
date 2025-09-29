import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class UserSettings {
  final String name;
  final String sport;
  final String goals;
  final bool sound;
  final bool vibration;
  final bool highBrightness;
  final bool darkMode;
  final String colorblindMode; // 'none', 'protanopia', 'deuteranopia', 'tritanopia'
  final bool notifications;

  const UserSettings({
    required this.name,
    required this.sport,
    required this.goals,
    required this.sound,
    required this.vibration,
    required this.highBrightness,
    required this.darkMode,
    required this.colorblindMode,
    required this.notifications,
  });

  UserSettings copyWith({
    String? name,
    String? sport,
    String? goals,
    bool? sound,
    bool? vibration,
    bool? highBrightness,
    bool? darkMode,
    String? colorblindMode,
    bool? notifications,
  }) => UserSettings(
        name: name ?? this.name,
        sport: sport ?? this.sport,
        goals: goals ?? this.goals,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        highBrightness: highBrightness ?? this.highBrightness,
        darkMode: darkMode ?? this.darkMode,
        colorblindMode: colorblindMode ?? this.colorblindMode,
        notifications: notifications ?? this.notifications,
      );

  static const _kName = 'settings.name';
  static const _kSport = 'settings.sport';
  static const _kGoals = 'settings.goals';
  static const _kSound = 'settings.sound';
  static const _kVibration = 'settings.vibration';
  static const _kHighBrightness = 'settings.high_brightness';
  static const _kDarkMode = 'settings.dark_mode';
  static const _kColorblind = 'settings.colorblind';
  static const _kNotifications = 'settings.notifications';

  static const UserSettings defaults = UserSettings(
    name: '',
    sport: '',
    goals: '',
    sound: true,
    vibration: true,
    highBrightness: true,
    darkMode: false,
    colorblindMode: 'none',
    notifications: true,
  );
}

abstract class SettingsRepository {
  Future<UserSettings> load();
  Future<void> save(UserSettings settings);
  Stream<UserSettings> watch();
}

class SharedPrefsSettingsRepository implements SettingsRepository {
  final _ctrl = StreamController<UserSettings>.broadcast();

  @override
  Future<UserSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    return UserSettings(
      name: sp.getString(UserSettings._kName) ?? UserSettings.defaults.name,
      sport: sp.getString(UserSettings._kSport) ?? UserSettings.defaults.sport,
      goals: sp.getString(UserSettings._kGoals) ?? UserSettings.defaults.goals,
      sound: sp.getBool(UserSettings._kSound) ?? UserSettings.defaults.sound,
      vibration: sp.getBool(UserSettings._kVibration) ?? UserSettings.defaults.vibration,
      highBrightness: sp.getBool(UserSettings._kHighBrightness) ?? UserSettings.defaults.highBrightness,
      darkMode: sp.getBool(UserSettings._kDarkMode) ?? UserSettings.defaults.darkMode,
      colorblindMode: sp.getString(UserSettings._kColorblind) ?? UserSettings.defaults.colorblindMode,
      notifications: sp.getBool(UserSettings._kNotifications) ?? UserSettings.defaults.notifications,
    );
  }

  @override
  Future<void> save(UserSettings s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(UserSettings._kName, s.name);
    await sp.setString(UserSettings._kSport, s.sport);
    await sp.setString(UserSettings._kGoals, s.goals);
    await sp.setBool(UserSettings._kSound, s.sound);
    await sp.setBool(UserSettings._kVibration, s.vibration);
    await sp.setBool(UserSettings._kHighBrightness, s.highBrightness);
    await sp.setBool(UserSettings._kDarkMode, s.darkMode);
    await sp.setString(UserSettings._kColorblind, s.colorblindMode);
    await sp.setBool(UserSettings._kNotifications, s.notifications);
    _ctrl.add(s);
  }

  @override
  Stream<UserSettings> watch() => _ctrl.stream;
}
