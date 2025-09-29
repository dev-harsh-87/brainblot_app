part of 'stats_bloc.dart';

abstract class StatsEvent extends Equatable {
  const StatsEvent();
  @override
  List<Object?> get props => [];
}

class StatsStarted extends StatsEvent {
  const StatsStarted();
}

class _SessionsUpdated extends StatsEvent {
  final List<SessionResult> items;
  const _SessionsUpdated(this.items);
  @override
  List<Object?> get props => [items];
}
