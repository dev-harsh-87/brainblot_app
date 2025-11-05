import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spark_app/features/drills/data/session_repository.dart';
import 'package:spark_app/features/drills/domain/session_result.dart';

part 'stats_event.dart';
part 'stats_state.dart';

class StatsBloc extends Bloc<StatsEvent, StatsState> {
  final SessionRepository _repo;
  StreamSubscription<List<SessionResult>>? _sub;

  StatsBloc(this._repo) : super(const StatsState.initial()) {
    on<StatsStarted>(_onStarted);
    on<_SessionsUpdated>(_onUpdated);
  }

  Future<void> _onStarted(StatsStarted event, Emitter<StatsState> emit) async {
    emit(state.copyWith(status: StatsStatus.loading));
    _sub?.cancel();
    _sub = _repo.watchAll().listen((list) => add(_SessionsUpdated(list)));
  }

  void _onUpdated(_SessionsUpdated event, Emitter<StatsState> emit) {
    final sessions = List<SessionResult>.from(event.items);
    sessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    emit(state.copyWith(status: StatsStatus.loaded, sessions: sessions));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
