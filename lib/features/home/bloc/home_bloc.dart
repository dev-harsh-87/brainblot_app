import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/data/session_repository.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/features/drills/domain/session_result.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/bloc/bloc_utils.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final DrillRepository _drills;
  final SessionRepository _sessions;
  StreamSubscription<List<SessionResult>>? _subSessions;

  HomeBloc(this._drills, this._sessions) : super(const HomeState.initial()) {
    on<HomeStarted>(_onStarted);
    on<_SessionsUpdated>(_onSessionsUpdated);
    on<HomeRefreshRequested>(_onRefreshRequested);
    on<HomeRetryRequested>(_onRetryRequested);
    on<_HomeErrorOccurred>(_onErrorOccurred);
    
    // Auto-start loading home data
    add(const HomeStarted());
  }

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    await BlocUtils.executeWithErrorHandling(
      () async {
        emit(state.copyWith(
          status: HomeStatus.loading,
          errorMessage: null,
        ));

        // Get recommended drill: first from repository for now
        final all = await _drills.fetchAll();
        final recommended = all.isNotEmpty ? all.first : null;

        // Set up sessions subscription
        _subSessions?.cancel();
        _subSessions = _sessions.watchAll().listen(
          (list) => add(_SessionsUpdated(list)),
          onError: (Object error) => add(_HomeErrorOccurred(error.toString())),
        );

        emit(state.copyWith(
          status: HomeStatus.loaded,
          recommended: recommended,
          errorMessage: null,
          lastUpdated: DateTime.now(),
        ));
      },
      emit,
      (error) => state.copyWith(
        status: HomeStatus.error,
        errorMessage: error.message,
      ),
    );
  }

  void _onSessionsUpdated(_SessionsUpdated event, Emitter<HomeState> emit) {
    // Show latest 5 sessions
    final latest = List<SessionResult>.from(event.items);
    latest.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    emit(state.copyWith(
      recent: latest.take(5).toList(),
      errorMessage: null,
      lastUpdated: DateTime.now(),
    ));
  }

  Future<void> _onRefreshRequested(HomeRefreshRequested event, Emitter<HomeState> emit) async {
    await BlocUtils.executeWithErrorHandling(
      () async {
        emit(state.copyWith(
          status: HomeStatus.refreshing,
          isRefreshing: true,
          errorMessage: null,
        ));

        // Refresh recommended drill
        final all = await _drills.fetchAll();
        final recommended = all.isNotEmpty ? all.first : null;

        // Restart sessions subscription
        _subSessions?.cancel();
        _subSessions = _sessions.watchAll().listen(
          (list) => add(_SessionsUpdated(list)),
          onError: (Object error) => add(_HomeErrorOccurred(error.toString())),
        );

        emit(state.copyWith(
          status: HomeStatus.loaded,
          recommended: recommended,
          isRefreshing: false,
          errorMessage: null,
          lastUpdated: DateTime.now(),
        ));
      },
      emit,
      (error) => state.copyWith(
        status: HomeStatus.error,
        errorMessage: error.message,
        isRefreshing: false,
      ),
    );
  }

  Future<void> _onRetryRequested(HomeRetryRequested event, Emitter<HomeState> emit) async {
    // Retry by restarting the home loading
    add(const HomeStarted());
  }

  void _onErrorOccurred(_HomeErrorOccurred event, Emitter<HomeState> emit) {
    emit(state.copyWith(
      status: HomeStatus.error,
      errorMessage: event.error,
      isRefreshing: false,
    ));
  }

  @override
  Future<void> close() {
    _subSessions?.cancel();
    return super.close();
  }
}
