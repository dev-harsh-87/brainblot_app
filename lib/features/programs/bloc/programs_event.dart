part of 'programs_bloc.dart';

abstract class ProgramsEvent extends Equatable {
  const ProgramsEvent();
  @override
  List<Object?> get props => [];
}

class ProgramsStarted extends ProgramsEvent {
  const ProgramsStarted();
}

class ProgramsActivateRequested extends ProgramsEvent {
  final Program program;
  const ProgramsActivateRequested(this.program);
  @override
  List<Object?> get props => [program];
}

class _ProgramsUpdated extends ProgramsEvent {
  final List<Program> programs;
  const _ProgramsUpdated(this.programs);
  @override
  List<Object?> get props => [programs];
}

class _ActiveUpdated extends ProgramsEvent {
  final ActiveProgram? active;
  const _ActiveUpdated(this.active);
  @override
  List<Object?> get props => [active];
}

class ProgramsCreateRequested extends ProgramsEvent {
  final Program program;
  const ProgramsCreateRequested(this.program);
  @override
  List<Object?> get props => [program];
}

class ProgramsUpdateRequested extends ProgramsEvent {
  final Program program;
  const ProgramsUpdateRequested(this.program);
  @override
  List<Object?> get props => [program];
}

class ProgramsDeleteRequested extends ProgramsEvent {
  final String programId;
  const ProgramsDeleteRequested(this.programId);
  @override
  List<Object?> get props => [programId];
}

class ProgramsSeedDefaultRequested extends ProgramsEvent {
  const ProgramsSeedDefaultRequested();
}

class _ProgramsErrorOccurred extends ProgramsEvent {
  final String error;
  const _ProgramsErrorOccurred(this.error);
  
  @override
  List<Object?> get props => [error];
}
