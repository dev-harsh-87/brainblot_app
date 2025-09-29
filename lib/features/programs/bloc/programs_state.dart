part of 'programs_bloc.dart';

enum ProgramsStatus { initial, loading, loaded }

class ProgramsState extends Equatable {
  final ProgramsStatus status;
  final List<Program> programs;
  final ActiveProgram? active;

  const ProgramsState({required this.status, required this.programs, this.active});
  const ProgramsState.initial() : this(status: ProgramsStatus.initial, programs: const [], active: null);

  ProgramsState copyWith({ProgramsStatus? status, List<Program>? programs, ActiveProgram? active}) => ProgramsState(
        status: status ?? this.status,
        programs: programs ?? this.programs,
        active: active ?? this.active,
      );

  @override
  List<Object?> get props => [status, programs, active];
}
