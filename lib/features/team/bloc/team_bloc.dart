import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/team/data/team_repository.dart';
import 'package:brainblot_app/features/team/domain/team.dart';
import 'package:brainblot_app/features/drills/data/session_repository.dart';
import 'package:brainblot_app/features/settings/data/settings_repository.dart';

part 'team_event.dart';
part 'team_state.dart';

class TeamBloc extends Bloc<TeamEvent, TeamState> {
  final TeamRepository _teamRepo;
  final SessionRepository _sessionRepo;
  final SettingsRepository _settingsRepo;
  StreamSubscription<Team?>? _sub;

  TeamBloc(this._teamRepo, this._sessionRepo, this._settingsRepo) : super(const TeamState.initial()) {
    on<TeamStarted>(_onStarted);
    on<TeamJoinRequested>(_onJoinRequested);
    on<TeamCreateRequested>(_onCreateRequested);
    on<TeamLeaveRequested>(_onLeaveRequested);
    on<TeamStatsUpdateRequested>(_onStatsUpdateRequested);
    on<_TeamUpdated>(_onUpdated);
  }

  Future<void> _onStarted(TeamStarted event, Emitter<TeamState> emit) async {
    emit(state.copyWith(status: TeamStatus.loading));
    try {
      await _teamRepo.loadUserTeam();
      _sub?.cancel();
      _sub = _teamRepo.watchTeam().listen((t) => add(_TeamUpdated(t)));
    } catch (e) {
      emit(state.copyWith(status: TeamStatus.error, error: e.toString()));
    }
  }

  Future<void> _onJoinRequested(TeamJoinRequested event, Emitter<TeamState> emit) async {
    emit(state.copyWith(status: TeamStatus.joining));
    try {
      final settings = await _settingsRepo.load();
      final userStats = await _getUserStats();
      
      final member = TeamMember(
        id: 'current_user',
        name: settings.name.isNotEmpty ? settings.name : 'Unknown User',
        avgRtMs: userStats['avgReactionTime'] ?? 0.0,
        acc: userStats['avgAccuracy'] ?? 0.0,
      );
      
      await _teamRepo.joinTeam(event.inviteCode, member);
    } catch (e) {
      emit(state.copyWith(status: TeamStatus.error, error: e.toString()));
    }
  }

  Future<void> _onCreateRequested(TeamCreateRequested event, Emitter<TeamState> emit) async {
    emit(state.copyWith(status: TeamStatus.creating));
    try {
      final settings = await _settingsRepo.load();
      final userStats = await _getUserStats();
      
      final member = TeamMember(
        id: 'current_user',
        name: settings.name.isNotEmpty ? settings.name : 'Unknown User',
        avgRtMs: userStats['avgReactionTime'] ?? 0.0,
        acc: userStats['avgAccuracy'] ?? 0.0,
      );
      
      await _teamRepo.createTeam(event.teamName, member);
    } catch (e) {
      emit(state.copyWith(status: TeamStatus.error, error: e.toString()));
    }
  }

  Future<void> _onLeaveRequested(TeamLeaveRequested event, Emitter<TeamState> emit) async {
    emit(state.copyWith(status: TeamStatus.leaving));
    try {
      await _teamRepo.leaveTeam();
    } catch (e) {
      emit(state.copyWith(status: TeamStatus.error, error: e.toString()));
    }
  }

  Future<void> _onStatsUpdateRequested(TeamStatsUpdateRequested event, Emitter<TeamState> emit) async {
    try {
      final userStats = await _getUserStats();
      await _teamRepo.updateMemberStats(
        'current_user',
        userStats['avgReactionTime'] ?? 0.0,
        userStats['avgAccuracy'] ?? 0.0,
      );
    } catch (e) {
      // Silently fail stats update to avoid disrupting user experience
    }
  }

  void _onUpdated(_TeamUpdated event, Emitter<TeamState> emit) {
    final isInTeam = event.team != null && event.team!.members.any((m) => m.id == 'current_user');
    emit(state.copyWith(
      status: TeamStatus.loaded, 
      team: event.team,
      isInTeam: isInTeam,
      error: null,
    ));
  }

  Future<Map<String, double>> _getUserStats() async {
    try {
      // Since we can't directly get all sessions, we'll use a stream subscription
      // For now, return default values and update this when we have access to session data
      return {'avgReactionTime': 300.0, 'avgAccuracy': 0.85};
    } catch (e) {
      return {'avgReactionTime': 0.0, 'avgAccuracy': 0.0};
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
