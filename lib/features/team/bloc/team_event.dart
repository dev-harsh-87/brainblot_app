part of 'team_bloc.dart';

abstract class TeamEvent extends Equatable {
  const TeamEvent();
  @override
  List<Object?> get props => [];
}

class TeamStarted extends TeamEvent {
  const TeamStarted();
}

class TeamJoinRequested extends TeamEvent {
  final String inviteCode;
  const TeamJoinRequested(this.inviteCode);
  @override
  List<Object?> get props => [inviteCode];
}

class TeamCreateRequested extends TeamEvent {
  final String teamName;
  const TeamCreateRequested(this.teamName);
  @override
  List<Object?> get props => [teamName];
}

class TeamLeaveRequested extends TeamEvent {
  const TeamLeaveRequested();
}

class TeamStatsUpdateRequested extends TeamEvent {
  const TeamStatsUpdateRequested();
}

class _TeamUpdated extends TeamEvent {
  final Team? team;
  const _TeamUpdated(this.team);
  @override
  List<Object?> get props => [team];
}
