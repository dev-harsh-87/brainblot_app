part of 'settings_bloc.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class SettingsStarted extends SettingsEvent {
  const SettingsStarted();
}

class SettingsProfileChanged extends SettingsEvent {
  final String name;
  final String sport;
  final String goals;
  const SettingsProfileChanged({required this.name, required this.sport, required this.goals});
  @override
  List<Object?> get props => [name, sport, goals];
}

class SettingsToggled extends SettingsEvent {
  final bool? sound;
  final bool? vibration;
  final bool? highBrightness;
  final bool? darkMode;
  final bool? notifications;
  const SettingsToggled({this.sound, this.vibration, this.highBrightness, this.darkMode, this.notifications});
}

class SettingsColorblindChanged extends SettingsEvent {
  final String mode; // 'none', 'protanopia', 'deuteranopia', 'tritanopia'
  const SettingsColorblindChanged(this.mode);
  @override
  List<Object?> get props => [mode];
}
