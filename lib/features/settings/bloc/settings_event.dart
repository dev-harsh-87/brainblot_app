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
  final String? name;
  final String? sport;
  final String? goals;
  const SettingsProfileChanged({this.name, this.sport, this.goals});
  @override
  List<Object?> get props => [name, sport, goals];
}

class SettingsToggled extends SettingsEvent {
  final bool? sound;
  final bool? vibration;
  final bool? highBrightness;
  final bool? darkMode;
  final bool? notifications;
  final String? colorblindMode;
  const SettingsToggled({this.sound, this.vibration, this.highBrightness, this.darkMode, this.notifications, this.colorblindMode});
  
  @override
  List<Object?> get props => [sound, vibration, highBrightness, darkMode, notifications, colorblindMode];
}

class SettingsColorblindChanged extends SettingsEvent {
  final String mode; // 'none', 'protanopia', 'deuteranopia', 'tritanopia'
  const SettingsColorblindChanged(this.mode);
  @override
  List<Object?> get props => [mode];
}
