part of 'team_bloc.dart';

enum TeamStatus { initial, loading, loaded, error, joining, creating, leaving }

class TeamState extends Equatable {
  final TeamStatus status;
  final Team? team;
  final String? error;
  final bool isInTeam;
  
  const TeamState({
    required this.status, 
    required this.team, 
    this.error,
    this.isInTeam = false,
  });
  
  const TeamState.initial() : this(
    status: TeamStatus.initial, 
    team: null, 
    error: null,
    isInTeam: false,
  );

  TeamState copyWith({
    TeamStatus? status, 
    Team? team, 
    String? error,
    bool? isInTeam,
  }) => TeamState(
    status: status ?? this.status,
    team: team ?? this.team,
    error: error,
    isInTeam: isInTeam ?? this.isInTeam,
  );

  @override
  List<Object?> get props => [status, team, error, isInTeam];
}
