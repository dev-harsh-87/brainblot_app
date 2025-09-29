part of 'settings_bloc.dart';

enum SettingsStatus { initial, loading, loaded }

class SettingsState extends Equatable {
  final SettingsStatus status;
  final UserSettings? settings;
  const SettingsState({required this.status, required this.settings});
  const SettingsState.initial() : this(status: SettingsStatus.initial, settings: null);

  SettingsState copyWith({SettingsStatus? status, UserSettings? settings}) => SettingsState(
        status: status ?? this.status,
        settings: settings ?? this.settings,
      );

  @override
  List<Object?> get props => [status, settings];
}
