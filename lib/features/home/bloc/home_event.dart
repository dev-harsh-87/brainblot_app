part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class HomeStarted extends HomeEvent {
  const HomeStarted();
}

class HomeRefreshRequested extends HomeEvent {
  const HomeRefreshRequested();
}

class HomeRetryRequested extends HomeEvent {
  const HomeRetryRequested();
}

class _SessionsUpdated extends HomeEvent {
  final List<SessionResult> items;
  const _SessionsUpdated(this.items);
  @override
  List<Object?> get props => [items];
}

class _HomeErrorOccurred extends HomeEvent {
  final String error;
  const _HomeErrorOccurred(this.error);
  @override
  List<Object?> get props => [error];
}
