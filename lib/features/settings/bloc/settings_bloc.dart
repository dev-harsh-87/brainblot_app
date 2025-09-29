import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/settings/data/settings_repository.dart';

part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository _repo;
  StreamSubscription<UserSettings>? _sub;

  SettingsBloc(this._repo) : super(const SettingsState.initial()) {
    on<SettingsStarted>(_onStarted);
    on<SettingsProfileChanged>(_onProfileChanged);
    on<SettingsToggled>(_onToggled);
    on<SettingsColorblindChanged>(_onColorblindChanged);
  }

  Future<void> _onStarted(SettingsStarted event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(status: SettingsStatus.loading));
    final loaded = await _repo.load();
    emit(state.copyWith(status: SettingsStatus.loaded, settings: loaded));
    _sub?.cancel();
    _sub = _repo.watch().listen((s) => emit(state.copyWith(settings: s)));
  }

  Future<void> _onProfileChanged(SettingsProfileChanged event, Emitter<SettingsState> emit) async {
    final s = (state.settings ?? UserSettings.defaults).copyWith(
      name: event.name,
      sport: event.sport,
      goals: event.goals,
    );
    await _repo.save(s);
  }

  Future<void> _onToggled(SettingsToggled event, Emitter<SettingsState> emit) async {
    final s = (state.settings ?? UserSettings.defaults).copyWith(
      sound: event.sound ?? (state.settings?.sound ?? true),
      vibration: event.vibration ?? (state.settings?.vibration ?? true),
      highBrightness: event.highBrightness ?? (state.settings?.highBrightness ?? true),
      darkMode: event.darkMode ?? (state.settings?.darkMode ?? false),
      notifications: event.notifications ?? (state.settings?.notifications ?? true),
    );
    await _repo.save(s);
  }

  Future<void> _onColorblindChanged(SettingsColorblindChanged event, Emitter<SettingsState> emit) async {
    final s = (state.settings ?? UserSettings.defaults).copyWith(colorblindMode: event.mode);
    await _repo.save(s);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
