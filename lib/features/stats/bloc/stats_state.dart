part of 'stats_bloc.dart';

enum StatsStatus { initial, loading, loaded }

class StatsState extends Equatable {
  final StatsStatus status;
  final List<SessionResult> sessions;
  const StatsState({required this.status, required this.sessions});
  const StatsState.initial() : this(status: StatsStatus.initial, sessions: const []);

  StatsState copyWith({StatsStatus? status, List<SessionResult>? sessions}) => StatsState(
        status: status ?? this.status,
        sessions: sessions ?? this.sessions,
      );

  @override
  List<Object?> get props => [status, sessions];
}
