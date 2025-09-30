import 'dart:async';
import 'dart:collection';
import 'package:brainblot_app/features/programs/data/firebase_program_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
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
    print('🏗️ ProgramsBloc: Initializing with repository type: ${_repo.runtimeType}');
    print('🔍 ProgramsBloc: Is FirebaseProgramRepository? ${_repo is FirebaseProgramRepository}');
    
    // Event handlers
    on<ProgramsStarted>(_onStarted);
    on<_ProgramsUpdated>(_onProgramsUpdated);
    on<_ActiveUpdated>(_onActiveUpdated);
    on<_ProgramsErrorOccurred>(_onError);
    on<ProgramsActivateRequested>(_onActivate);
    on<ProgramsCreateRequested>(_onCreateProgram);
    on<ProgramsUpdateRequested>(_onUpdateProgram);
    on<ProgramsDeleteRequested>(_onDeleteProgram);
    on<ProgramsSeedDefaultRequested>(_onSeedDefault);
    
    // Initial load
    add(const ProgramsStarted());
  }

  Future<void> _onStarted(ProgramsStarted event, Emitter<ProgramsState> emit) async {
    print('🚀 ProgramsBloc: Starting programs initialization');
    try {
      emit(state.copyWith(status: ProgramsStatus.loading));
      print('📊 ProgramsBloc: Emitted loading state');
      
      // Cancel any existing subscriptions
      await _subPrograms?.cancel();
      await _subActive?.cancel();
      print('🔄 ProgramsBloc: Cancelled existing subscriptions');
      
      // Seed default programs if using Firebase repository
      if (_repo is FirebaseProgramRepository) {
        print('🌱 ProgramsBloc: Using Firebase repository, seeding default programs');
        try {
          await (_repo as FirebaseProgramRepository).seedDefaultPrograms();
          print('✅ ProgramsBloc: Default programs seeded successfully');
        } catch (e) {
          // Seeding failed, but continue with normal operation
          print('❌ ProgramsBloc: Failed to seed default programs: $e');
        }
      } else {
        print('📦 ProgramsBloc: Using non-Firebase repository');
      }
      
      // Set up new subscriptions with error handling
      print('🔗 ProgramsBloc: Setting up stream subscriptions');
      _subPrograms = _repo.watchAll().listen(
        (programs) {
          print('📊 ProgramsBloc: Received ${programs.length} programs from repository');
          if (!isClosed) {
            add(_ProgramsUpdated(programs));
          } else {
            print('⚠️ ProgramsBloc: BLoC is closed, skipping programs update');
          }
        },
        onError: (error) {
          print('❌ ProgramsBloc: Error in programs stream: $error');
          if (!isClosed) {
            add(_ProgramsErrorOccurred('Failed to load programs: $error'));
          }
        },
        cancelOnError: false,
      );
      
      _subActive = _repo.watchActive().listen(
        (active) {
          print('🎯 ProgramsBloc: Received active program: ${active?.programId ?? "none"}');
          if (!isClosed) {
            add(_ActiveUpdated(active));
          } else {
            print('⚠️ ProgramsBloc: BLoC is closed, skipping active update');
          }
        },
        onError: (error) {
          print('❌ ProgramsBloc: Error in active program stream: $error');
          if (!isClosed) {
            add(_ProgramsErrorOccurred('Failed to load active program: $error'));
          }
        },
        cancelOnError: false,
      );
      
      // Initial load with timeout
      try {
        final initialPrograms = await _repo.watchAll().first.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (!isClosed) {
              add(const _ProgramsErrorOccurred('Connection timeout. Please check your internet connection.'));
            }
            return [];
          },
        );
        
        emit(state.copyWith(
          status: ProgramsStatus.loaded,
          programs: initialPrograms,
          errorMessage: null,
        ));
      } on TimeoutException {
        emit(state.copyWith(
          status: ProgramsStatus.error,
          errorMessage: 'Connection timeout. Please check your internet connection.',
        ));
      } catch (e) {
        emit(state.copyWith(
          status: ProgramsStatus.error,
          errorMessage: 'Failed to load initial programs: ${e.toString()}',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: 'Failed to initialize programs: ${e.toString()}',
      ));
    }
  }

  void _onProgramsUpdated(_ProgramsUpdated event, Emitter<ProgramsState> emit) {
    // Only update if the programs list has actually changed
    if (state.programs.length != event.programs.length || 
        !const ListEquality().equals(state.programs, event.programs)) {
      emit(state.copyWith(
        status: ProgramsStatus.loaded,
        programs: List.unmodifiable(event.programs),
      ));
    }
  }

  void _onActiveUpdated(_ActiveUpdated event, Emitter<ProgramsState> emit) {
    // Only update if the active program has actually changed
    if (state.active?.programId != event.active?.programId ||
        state.active?.currentDay != event.active?.currentDay) {
      emit(state.copyWith(
        status: ProgramsStatus.loaded,
        active: event.active,
        errorMessage: null,
      ));
    }
  }
  
  void _onError(_ProgramsErrorOccurred event, Emitter<ProgramsState> emit) {
    emit(state.copyWith(
      status: ProgramsStatus.error,
      errorMessage: event.error,
    ));
  }

  Future<void> _onActivate(ProgramsActivateRequested event, Emitter<ProgramsState> emit) async {
    try {
      await _repo.setActive(ActiveProgram(
        programId: event.program.id, 
        currentDay: 1,
        startedAt: DateTime.now(),
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: 'Failed to activate program: ${e.toString()}',
      ));
    }
  }

  Future<void> _onCreateProgram(ProgramsCreateRequested event, Emitter<ProgramsState> emit) async {
    print('🎯 ProgramsBloc: Starting program creation');
    print('📝 Program: ${event.program.name} (${event.program.category}, ${event.program.totalDays} days)');
    
    emit(state.copyWith(status: ProgramsStatus.creating));
    print('📊 ProgramsBloc: Emitted creating state');
    
    try {
      await _repo.createProgram(event.program);
      print('✅ ProgramsBloc: Program created successfully in repository');
      
      // Don't refresh the entire programs list, the stream subscription will handle updates
      emit(state.copyWith(
        status: ProgramsStatus.loaded,
        errorMessage: null,
      ));
      print('📊 ProgramsBloc: Emitted loaded state after creation');
    } catch (e) {
      print('❌ ProgramsBloc: Error creating program: $e');
      emit(state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: 'Failed to create program: ${e.toString()}',
      ));
      print('📊 ProgramsBloc: Emitted error state');
    }
  }

  Future<void> _onUpdateProgram(ProgramsUpdateRequested event, Emitter<ProgramsState> emit) async {
    try {
      if (_repo is FirebaseProgramRepository) {
        await (_repo as FirebaseProgramRepository).updateProgram(event.program);
      } else {
        emit(state.copyWith(
          status: ProgramsStatus.error,
          errorMessage: 'Program update not supported with current repository',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: 'Failed to update program: ${e.toString()}',
      ));
    }
  }

  Future<void> _onDeleteProgram(ProgramsDeleteRequested event, Emitter<ProgramsState> emit) async {
    try {
      if (_repo is FirebaseProgramRepository) {
        await (_repo as FirebaseProgramRepository).deleteProgram(event.programId);
      } else {
        emit(state.copyWith(
          status: ProgramsStatus.error,
          errorMessage: 'Program deletion not supported with current repository',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: 'Failed to delete program: ${e.toString()}',
      ));
    }
  }

  Future<void> _onSeedDefault(ProgramsSeedDefaultRequested event, Emitter<ProgramsState> emit) async {
    try {
      if (_repo is FirebaseProgramRepository) {
        await (_repo as FirebaseProgramRepository).seedDefaultPrograms();
      }
    } catch (e) {
      emit(state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: 'Failed to seed default programs: ${e.toString()}',
      ));
    }
  }

  @override
  Future<void> close() async {
    await _subPrograms?.cancel();
    await _subActive?.cancel();
    _subPrograms = null;
    _subActive = null;
    return super.close();
  }
}
