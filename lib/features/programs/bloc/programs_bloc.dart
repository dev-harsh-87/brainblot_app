import 'dart:async';
import 'package:spark_app/features/programs/data/firebase_program_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:spark_app/features/programs/data/program_repository.dart';
import 'package:spark_app/features/programs/domain/program.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'package:spark_app/core/bloc/bloc_utils.dart';

part 'programs_event.dart';
part 'programs_state.dart';

class ProgramsBloc extends Bloc<ProgramsEvent, ProgramsState> {
  final ProgramRepository _repo;
  StreamSubscription<List<Program>>? _subPrograms;
  StreamSubscription<ActiveProgram?>? _subActive;

  ProgramsBloc(this._repo) : super(const ProgramsState.initial()) {
    AppLogger.info('ProgramsBloc: Initializing with repository type: ${_repo.runtimeType}', tag: 'ProgramsBloc');
    AppLogger.debug('ProgramsBloc: Is FirebaseProgramRepository? ${_repo is FirebaseProgramRepository}', tag: 'ProgramsBloc');
    
    // Event handlers
    on<ProgramsStarted>(_onStarted);
    on<_ProgramsUpdated>(_onProgramsUpdated);
    on<_ActiveUpdated>(_onActiveUpdated);
    on<_CompletedProgramsUpdated>(_onCompletedProgramsUpdated);
    on<_ProgramsErrorOccurred>(_onError);
    on<ProgramsActivateRequested>(_onActivate);
    on<ProgramsCreateRequested>(_onCreateProgram);
    on<ProgramsUpdateRequested>(_onUpdateProgram);
    on<ProgramsDeleteRequested>(_onDeleteProgram);
    on<ProgramsSeedDefaultRequested>(_onSeedDefault);
    on<ProgramsRefreshRequested>(_onRefreshRequested);
    on<ProgramsCategoryFilterChanged>(_onCategoryFilterChanged);
    on<ProgramsQueryChanged>(_onQueryChanged);
    on<ProgramsRetryRequested>(_onRetryRequested);
    
    // Initial load
    add(const ProgramsStarted());
  }

  Future<void> _onStarted(ProgramsStarted event, Emitter<ProgramsState> emit) async {
    await BlocUtils.executeWithErrorHandling(
      () async {
        emit(state.copyWith(
          status: ProgramsStatus.loading,
        ),);
        
        // Cancel any existing subscriptions
        await _subPrograms?.cancel();
        await _subActive?.cancel();
        
        // Seeding disabled - only show user-created programs
        AppLogger.info('Loading user-created programs only...', tag: 'ProgramsBloc');
        
        // Set up new subscriptions with error handling
        _subPrograms = _repo.watchAll().listen(
          (programs) {
            if (!isClosed) {
              add(_ProgramsUpdated(programs));
            }
          },
          onError: (Object error) {
            if (!isClosed) {
              add(_ProgramsErrorOccurred(error.toString()));
            }
          },
          cancelOnError: false,
        );
        
        _subActive = _repo.watchActive().listen(
          (active) {
            if (!isClosed) {
              add(_ActiveUpdated(active));
            }
          },
          onError: (Object error) {
            if (!isClosed) {
              add(_ProgramsErrorOccurred('Failed to load active program: $error'));
            }
          },
          cancelOnError: false,
        );
        
        // Load completed programs
        _loadCompletedPrograms();
      },
      emit,
      (error) => state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: error.message,
      ),
    );
  }

  Future<void> _loadCompletedPrograms() async {
    try {
      if (_repo is FirebaseProgramRepository) {
        final firebaseRepo = _repo as FirebaseProgramRepository;
        // Get current user ID - you'll need to get this from auth
        final userId = await _getCurrentUserId();
        if (userId != null) {
          final completedPrograms = await firebaseRepo.getCompletedPrograms(userId);
          if (!isClosed) {
            add(_CompletedProgramsUpdated(completedPrograms));
          }
        }
      }
    } catch (e) {
      AppLogger.error('Failed to load completed programs: $e', tag: 'ProgramsBloc');
    }
  }

  Future<String?> _getCurrentUserId() async {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      AppLogger.error('Failed to get current user ID: $e', tag: 'ProgramsBloc');
      return null;
    }
  }

  void _onProgramsUpdated(_ProgramsUpdated event, Emitter<ProgramsState> emit) {
    // Only update if the programs list has actually changed
    if (state.programs.length != event.programs.length ||
        !const ListEquality<Program>().equals(state.programs, event.programs)) {
      emit(state.copyWith(
        status: ProgramsStatus.loaded,
        programs: List.unmodifiable(event.programs),
        lastUpdated: DateTime.now(),
      ),);
    }
  }

  void _onActiveUpdated(_ActiveUpdated event, Emitter<ProgramsState> emit) {
    // Only update if the active program has actually changed
    if (state.active?.programId != event.active?.programId ||
        state.active?.currentDay != event.active?.currentDay) {
      emit(state.copyWith(
        status: ProgramsStatus.loaded,
        active: event.active,
        lastUpdated: DateTime.now(),
      ),);
    }
  }
  
  void _onCompletedProgramsUpdated(
    _CompletedProgramsUpdated event,
    Emitter<ProgramsState> emit,
  ) {
    emit(state.copyWith(
      completedPrograms: event.completedPrograms,
    ));
  }

  void _onError(_ProgramsErrorOccurred event, Emitter<ProgramsState> emit) {
    emit(state.copyWith(
      status: ProgramsStatus.error,
      errorMessage: event.error,
      isRefreshing: false,
    ),);
  }

  Future<void> _onActivate(ProgramsActivateRequested event, Emitter<ProgramsState> emit) async {
    await BlocUtils.executeWithErrorHandling(
      () async {
        emit(state.copyWith(
          status: ProgramsStatus.activating,
          programBeingModified: event.program,
        ),);
        
        await _repo.setActive(ActiveProgram(
          programId: event.program.id, 
          currentDay: 1,
          startedAt: DateTime.now(),
        ),);
        
        emit(state.copyWith(
          status: ProgramsStatus.loaded,
          lastUpdated: DateTime.now(),
        ),);
      },
      emit,
      (error) => state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: 'Failed to activate program: ${error.message}',
      ),
    );
  }

  Future<void> _onCreateProgram(ProgramsCreateRequested event, Emitter<ProgramsState> emit) async {
    await BlocUtils.executeWithErrorHandling(
      () async {
        emit(state.copyWith(
          status: ProgramsStatus.creating,
          programBeingModified: event.program,
        ),);
        
        await _repo.createProgram(event.program);
        
        emit(state.copyWith(
          status: ProgramsStatus.loaded,
          lastUpdated: DateTime.now(),
        ),);
      },
      emit,
      (error) => state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: 'Failed to create program: ${error.message}',
      ),
    );
  }

  Future<void> _onUpdateProgram(ProgramsUpdateRequested event, Emitter<ProgramsState> emit) async {
    await BlocUtils.executeWithErrorHandling(
      () async {
        emit(state.copyWith(
          status: ProgramsStatus.updating,
          programBeingModified: event.program,
        ),);
        
        if (_repo is FirebaseProgramRepository) {
          await (_repo as FirebaseProgramRepository).updateProgram(event.program);
        } else {
          throw Exception('Program update not supported with current repository');
        }
        
        emit(state.copyWith(
          status: ProgramsStatus.loaded,
          lastUpdated: DateTime.now(),
        ),);
      },
      emit,
      (error) => state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: 'Failed to update program: ${error.message}',
      ),
    );
  }

  Future<void> _onDeleteProgram(ProgramsDeleteRequested event, Emitter<ProgramsState> emit) async {
    await BlocUtils.executeWithErrorHandling(
      () async {
        emit(state.copyWith(
          status: ProgramsStatus.deleting,
        ),);
        
        if (_repo is FirebaseProgramRepository) {
          await (_repo as FirebaseProgramRepository).deleteProgram(event.programId);
        } else {
          throw Exception('Program deletion not supported with current repository');
        }
        
        emit(state.copyWith(
          status: ProgramsStatus.loaded,
          lastUpdated: DateTime.now(),
        ),);
      },
      emit,
      (error) => state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: 'Failed to delete program: ${error.message}',
      ),
    );
  }

  Future<void> _onSeedDefault(ProgramsSeedDefaultRequested event, Emitter<ProgramsState> emit) async {
    // Seeding disabled - no default programs will be created
    AppLogger.info('Default program seeding is disabled', tag: 'ProgramsBloc');
    emit(state.copyWith(
      status: ProgramsStatus.loaded,
      lastUpdated: DateTime.now(),
    ),);
  }

  Future<void> _onRefreshRequested(ProgramsRefreshRequested event, Emitter<ProgramsState> emit) async {
    await BlocUtils.executeWithErrorHandling(
      () async {
        emit(state.copyWith(
          status: ProgramsStatus.refreshing,
          isRefreshing: true,
        ),);
        
        try {
          // Cancel existing subscriptions and restart them with retry mechanism
          await _subPrograms?.cancel();
          await _subActive?.cancel();
          
          int retryCount = 0;
          const maxRetries = 3;
          
          while (retryCount < maxRetries) {
            try {
              // Seeding disabled - only load user-created programs
              AppLogger.info('Refreshing user-created programs...', tag: 'ProgramsBloc');
              
              // Set up new subscriptions
              _subPrograms = _repo.watchAll().listen(
                (programs) {
                  if (!isClosed) {
                    add(_ProgramsUpdated(programs));
                  }
                },
                onError: (Object error) {
                  if (!isClosed) {
                    add(_ProgramsErrorOccurred(error.toString()));
                  }
                },
                cancelOnError: false,
              );
              
              _subActive = _repo.watchActive().listen(
                (active) {
                  if (!isClosed) {
                    add(_ActiveUpdated(active));
                  }
                },
                onError: (Object error) {
                  if (!isClosed) {
                    add(_ProgramsErrorOccurred('Failed to load active program: $error'));
                  }
                },
                cancelOnError: false,
              );
              
              break; // Success, exit retry loop
            } catch (e) {
              retryCount++;
              if (retryCount >= maxRetries) {
                rethrow; // Re-throw after max retries
              }
              // Wait before retry with exponential backoff
              await Future.delayed(Duration(milliseconds: 500 * retryCount));
            }
          }
          
          emit(state.copyWith(
            status: ProgramsStatus.loaded,
            isRefreshing: false,
            lastUpdated: DateTime.now(),
          ),);
          
          AppLogger.success('Successfully refreshed programs', tag: 'ProgramsBloc');
        } catch (e) {
          rethrow;
        }
      },
      emit,
      (error) => state.copyWith(
        status: ProgramsStatus.error,
        errorMessage: 'Failed to refresh programs: ${error.message}',
        isRefreshing: false,
      ),
    );
  }

  Future<void> _onCategoryFilterChanged(ProgramsCategoryFilterChanged event, Emitter<ProgramsState> emit) async {
    emit(state.copyWith(
      selectedCategory: event.category,
      lastUpdated: DateTime.now(),
    ),);
  }

  Future<void> _onQueryChanged(ProgramsQueryChanged event, Emitter<ProgramsState> emit) async {
    emit(state.copyWith(
      searchQuery: event.query,
      lastUpdated: DateTime.now(),
    ),);
  }

  Future<void> _onRetryRequested(ProgramsRetryRequested event, Emitter<ProgramsState> emit) async {
    // Retry by restarting the programs loading
    add(const ProgramsStarted());
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
