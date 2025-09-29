import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/team/data/team_repository.dart';
import 'package:brainblot_app/features/team/domain/team.dart';

part 'team_event.dart';
part 'team_state.dart';

class TeamBloc extends Bloc<TeamEvent, TeamState> {
  final TeamRepository _repo;
  StreamSubscription<Team?>? _sub;

  TeamBloc(this._repo) : super(const TeamState.initial()) {
    on<TeamStarted>(_onStarted);
    on<_TeamUpdated>(_onUpdated);
  }

  Future<void> _onStarted(TeamStarted event, Emitter<TeamState> emit) async {
    emit(state.copyWith(status: TeamStatus.loading));
    await _repo.createOrLoadDefault();
    _sub?.cancel();
    _sub = _repo.watchTeam().listen((t) => add(_TeamUpdated(t)));
  }

  void _onUpdated(_TeamUpdated event, Emitter<TeamState> emit) {
    emit(state.copyWith(status: TeamStatus.loaded, team: event.team));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
