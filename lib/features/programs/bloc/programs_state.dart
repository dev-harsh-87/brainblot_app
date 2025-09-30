part of 'programs_bloc.dart';

enum ProgramsStatus { initial, loading, loaded, creating, error }

class ProgramsState extends Equatable {
  final ProgramsStatus status;
  final List<Program> programs;
  final ActiveProgram? active;
  final String? errorMessage;

  const ProgramsState({
    required this.status, 
    required this.programs, 
    this.active,
    this.errorMessage,
  });
  
  const ProgramsState.initial() : this(
    status: ProgramsStatus.initial, 
    programs: const [], 
    active: null,
    errorMessage: null,
  );

  ProgramsState copyWith({
    ProgramsStatus? status, 
    List<Program>? programs, 
    ActiveProgram? active,
    String? errorMessage,
  }) => ProgramsState(
        status: status ?? this.status,
        programs: programs ?? this.programs,
        active: active ?? this.active,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [status, programs, active, errorMessage];
}
