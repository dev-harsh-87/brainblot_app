import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spark_app/features/settings/data/settings_repository.dart';

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
    
    try {
      final loaded = await _repo.load();
      emit(state.copyWith(status: SettingsStatus.loaded, settings: loaded));
      
      _sub?.cancel();
      _sub = _repo.watch().listen((s) {
        emit(state.copyWith(settings: s));
      });
    } catch (e) {
      emit(state.copyWith(status: SettingsStatus.loaded, settings: UserSettings.defaults));
    }
  }

  Future<void> _onProfileChanged(SettingsProfileChanged event, Emitter<SettingsState> emit) async {
    final currentSettings = state.settings ?? UserSettings.defaults;
    final s = currentSettings.copyWith(
      name: event.name ?? currentSettings.name,
      sport: event.sport ?? currentSettings.sport,
      goals: event.goals ?? currentSettings.goals,
    );
    
    // Emit the new state immediately for UI responsiveness
    emit(state.copyWith(settings: s));
    
    // Save to repository
    try {
      await _repo.save(s);
    } catch (e) {
      // Handle error silently or show user feedback
    }
  }

  Future<void> _onToggled(SettingsToggled event, Emitter<SettingsState> emit) async {
    final currentSettings = state.settings ?? UserSettings.defaults;
    final updatedSettings = currentSettings.copyWith(
      sound: event.sound ?? currentSettings.sound,
      vibration: event.vibration ?? currentSettings.vibration,
      highBrightness: event.highBrightness ?? currentSettings.highBrightness,
      darkMode: event.darkMode ?? currentSettings.darkMode,
      notifications: event.notifications ?? currentSettings.notifications,
      colorblindMode: event.colorblindMode ?? currentSettings.colorblindMode,
    );
    
    // Emit the new state immediately for UI responsiveness
    emit(state.copyWith(settings: updatedSettings));
    
    // Save to repository
    try {
      await _repo.save(updatedSettings);
    } catch (e) {
      // Handle error silently or show user feedback
    }
  }

  Future<void> _onColorblindChanged(SettingsColorblindChanged event, Emitter<SettingsState> emit) async {
    final currentSettings = state.settings ?? UserSettings.defaults;
    final updatedSettings = currentSettings.copyWith(colorblindMode: event.mode);
    
    // Emit the new state immediately for UI responsiveness
    emit(state.copyWith(settings: updatedSettings));
    
    // Save to repository
    try {
      await _repo.save(updatedSettings);
    } catch (e) {
      // Handle error silently or show user feedback
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
