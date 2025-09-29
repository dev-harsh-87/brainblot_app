import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/data/session_repository.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/features/drills/domain/session_result.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final DrillRepository _drills;
  final SessionRepository _sessions;
  StreamSubscription<List<SessionResult>>? _subSessions;

  HomeBloc(this._drills, this._sessions) : super(const HomeState.initial()) {
    on<HomeStarted>(_onStarted);
    on<_SessionsUpdated>(_onSessionsUpdated);
  }

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    // Recommended drill: first from repository for now
    final all = await _drills.fetchAll();
    final recommended = all.isNotEmpty ? all.first : null;
    emit(state.copyWith(status: HomeStatus.loaded, recommended: recommended));

    _subSessions?.cancel();
    _subSessions = _sessions.watchAll().listen((list) => add(_SessionsUpdated(list)));
  }

  void _onSessionsUpdated(_SessionsUpdated event, Emitter<HomeState> emit) {
    // Show latest 5 sessions
    final latest = List<SessionResult>.from(event.items);
    latest.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    emit(state.copyWith(recent: latest.take(5).toList()));
  }

  @override
  Future<void> close() {
    _subSessions?.cancel();
    return super.close();
  }
}
