import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/programs/data/program_repository.dart';
import 'package:brainblot_app/features/programs/domain/program.dart';

part 'programs_event.dart';
part 'programs_state.dart';

class ProgramsBloc extends Bloc<ProgramsEvent, ProgramsState> {
  final ProgramRepository _repo;
  StreamSubscription<List<Program>>? _subPrograms;
  StreamSubscription<ActiveProgram?>? _subActive;

  ProgramsBloc(this._repo) : super(const ProgramsState.initial()) {
    on<ProgramsStarted>(_onStarted);
    on<_ProgramsUpdated>(_onProgramsUpdated);
    on<_ActiveUpdated>(_onActiveUpdated);
    on<ProgramsActivateRequested>(_onActivate);
  }

  Future<void> _onStarted(ProgramsStarted event, Emitter<ProgramsState> emit) async {
    emit(state.copyWith(status: ProgramsStatus.loading));
    _subPrograms?.cancel();
    _subActive?.cancel();
    _subPrograms = _repo.watchAll().listen((list) => add(_ProgramsUpdated(list)));
    _subActive = _repo.watchActive().listen((active) => add(_ActiveUpdated(active)));
  }

  void _onProgramsUpdated(_ProgramsUpdated event, Emitter<ProgramsState> emit) {
    emit(state.copyWith(status: ProgramsStatus.loaded, programs: event.programs));
  }

  void _onActiveUpdated(_ActiveUpdated event, Emitter<ProgramsState> emit) {
    emit(state.copyWith(active: event.active));
  }

  Future<void> _onActivate(ProgramsActivateRequested event, Emitter<ProgramsState> emit) async {
    await _repo.setActive(ActiveProgram(programId: event.program.id, currentDay: 1));
  }

  @override
  Future<void> close() {
    _subPrograms?.cancel();
    _subActive?.cancel();
    return super.close();
  }
}
