part of 'team_bloc.dart';

enum TeamStatus { initial, loading, loaded }

class TeamState extends Equatable {
  final TeamStatus status;
  final Team? team;
  const TeamState({required this.status, required this.team});
  const TeamState.initial() : this(status: TeamStatus.initial, team: null);

  TeamState copyWith({TeamStatus? status, Team? team}) => TeamState(
        status: status ?? this.status,
        team: team ?? this.team,
      );

  @override
  List<Object?> get props => [status, team];
}
