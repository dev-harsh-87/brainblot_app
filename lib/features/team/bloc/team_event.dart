part of 'team_bloc.dart';

abstract class TeamEvent extends Equatable {
  const TeamEvent();
  @override
  List<Object?> get props => [];
}

class TeamStarted extends TeamEvent {
  const TeamStarted();
}

class _TeamUpdated extends TeamEvent {
  final Team? team;
  const _TeamUpdated(this.team);
  @override
  List<Object?> get props => [team];
}
