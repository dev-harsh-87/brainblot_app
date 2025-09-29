part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class HomeStarted extends HomeEvent {
  const HomeStarted();
}

class _SessionsUpdated extends HomeEvent {
  final List<SessionResult> items;
  const _SessionsUpdated(this.items);
  @override
  List<Object?> get props => [items];
}
