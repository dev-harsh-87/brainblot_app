import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spark_app/features/drills/data/drill_repository.dart';
import 'package:spark_app/features/drills/data/firebase_drill_repository.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'package:spark_app/core/bloc/bloc_utils.dart';

part 'drill_library_event.dart';
part 'drill_library_state.dart';

class DrillLibraryBloc extends Bloc<DrillLibraryEvent, DrillLibraryState> {
  final DrillRepository _repo;
  StreamSubscription<List<Drill>>? _sub;

  DrillLibraryBloc(this._repo) : super(const DrillLibraryState.initial()) {
    on<DrillLibraryStarted>(_onStarted);
    on<DrillLibraryQueryChanged>(_onQueryChanged);
    on<DrillLibraryFilterChanged>(_onFilterChanged);
    on<DrillLibraryFiltersChanged>(_onFiltersChanged);
    on<DrillLibraryViewChanged>(_onViewChanged);
    on<DrillLibraryRefreshRequested>(_onRefreshRequested);
    on<DrillLibraryFiltersCleared>(_onFiltersCleared);
    on<_DrillLibraryItemsUpdated>(_onItemsUpdated);
    on<_DrillLibraryErrorOccurred>(_onErrorOccurred);
    
    // Auto-start loading drills
    add(const DrillLibraryStarted());
  }

  Future<void> _onStarted(DrillLibraryStarted event, Emitter<DrillLibraryState> emit) async {
    await BlocUtils.executeWithErrorHandling(
      () async {
        emit(state.copyWith(
          status: DrillLibraryStatus.loading,
        ),);
        
        // Ensure default drills are seeded (only for Firebase repository)
        try {
          if (_repo is FirebaseDrillRepository) {
            await (_repo as FirebaseDrillRepository).seedDefaultDrills();
          }
        } catch (e) {
          AppLogger.warning('Could not seed default drills', tag: 'DrillLibraryBloc');
          // Continue even if seeding fails
        }
        
        await _sub?.cancel();
        _sub = _repo.watchAll().listen(
          (items) => add(_DrillLibraryItemsUpdated(items)),
          onError: (Object error) => add(_DrillLibraryErrorOccurred(error.toString())),
        );
      },
      emit,
      (error) => state.copyWith(
        status: DrillLibraryStatus.error,
        errorMessage: error.message,
      ),
    );
  }

  Future<void> _onQueryChanged(DrillLibraryQueryChanged event, Emitter<DrillLibraryState> emit) async {
    emit(state.copyWith(
      status: DrillLibraryStatus.filtering,
      query: event.query,
    ),);
    
    // Apply filters with debouncing effect
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!isClosed) {
      final filtered = _applyFilters(state.all, query: event.query);
      emit(state.copyWith(
        status: DrillLibraryStatus.loaded,
        items: filtered,
        lastUpdated: DateTime.now(),
      ),);
    }
  }

  Future<void> _onFilterChanged(DrillLibraryFilterChanged event, Emitter<DrillLibraryState> emit) async {
    // Update the state with new filters
    final newState = state.copyWith(
      status: DrillLibraryStatus.filtering,
      category: event.category,
      difficulty: event.difficulty,
    );
    emit(newState);
    
    // Apply filters with the updated state
    final filtered = _applyFilters(newState.all, 
      query: newState.query,
      category: newState.category,
      difficulty: newState.difficulty,
    );
    
    emit(newState.copyWith(
      status: DrillLibraryStatus.loaded,
      items: filtered,
      lastUpdated: DateTime.now(),
    ),);
  }

  Future<void> _onFiltersChanged(DrillLibraryFiltersChanged event, Emitter<DrillLibraryState> emit) async {
    // Update the state with new filters and search query
    final newState = state.copyWith(
      status: DrillLibraryStatus.filtering,
      category: event.category,
      difficulty: event.difficulty,
      query: event.searchQuery,
    );
    emit(newState);
    
    // Apply filters with the updated state
    final filtered = _applyFilters(newState.all,
      query: newState.query,
      category: newState.category,
      difficulty: newState.difficulty,
    );
    
    emit(newState.copyWith(
      status: DrillLibraryStatus.loaded,
      items: filtered,
      lastUpdated: DateTime.now(),
    ),);
  }

  Future<void> _onViewChanged(DrillLibraryViewChanged event, Emitter<DrillLibraryState> emit) async {
    emit(state.copyWith(
      status: DrillLibraryStatus.loading,
      currentView: event.view,
    ),);
    
    await _sub?.cancel();
    
    try {
      // Use appropriate data source based on view with proper error handling
      switch (event.view) {
        case DrillLibraryView.favorites:
          _sub = _repo.watchFavorites().listen(
            (drills) {
              if (!isClosed) {
                add(_DrillLibraryItemsUpdated(drills as List<Drill>));
              }
            },
            onError: (error) {
              if (!isClosed) {
                AppLogger.error('Error in favorites stream', error: error);
                add(_DrillLibraryErrorOccurred('Failed to load favorite drills: $error'));
              }
            },
          );
          break;
        case DrillLibraryView.all:
          // For admin drills view, use a more reliable approach
          if (_repo is FirebaseDrillRepository) {
            try {
              // Add retry logic for admin drills
              List<Drill> adminDrills = [];
              int retryCount = 0;
              const maxRetries = 3;
              
              while (retryCount < maxRetries) {
                try {
                  adminDrills = await (_repo as FirebaseDrillRepository).fetchAdminDrills();
                  break; // Success, exit retry loop
                } catch (e) {
                  retryCount++;
                  if (retryCount >= maxRetries) {
                    rethrow; // Re-throw after max retries
                  }
                  // Wait before retry with exponential backoff
                  await Future.delayed(Duration(milliseconds: 500 * retryCount));
                  AppLogger.warning('Retrying admin drills fetch (attempt $retryCount)', tag: 'DrillLibraryBloc');
                }
              }
              
              if (!isClosed) {
                add(_DrillLibraryItemsUpdated(adminDrills));
              }
            } catch (e) {
              if (!isClosed) {
                AppLogger.error('Failed to load admin drills after retries', error: e);
                add(_DrillLibraryErrorOccurred('Failed to load admin drills: $e'));
              }
            }
          } else {
            _sub = _repo.watchAll().listen(
              (drills) {
                if (!isClosed) {
                  add(_DrillLibraryItemsUpdated(drills as List<Drill>));
                }
              },
              onError: (error) {
                if (!isClosed) {
                  AppLogger.error('Error in all drills stream', error: error);
                  add(_DrillLibraryErrorOccurred('Failed to load drills: $error'));
                }
              },
            );
          }
          break;
        case DrillLibraryView.custom:
          // For custom/my drills view
          _sub = _repo.watchAll().listen(
            (drills) {
              if (!isClosed) {
                add(_DrillLibraryItemsUpdated(drills as List<Drill>));
              }
            },
            onError: (error) {
              if (!isClosed) {
                AppLogger.error('Error in custom drills stream', error: error);
                add(_DrillLibraryErrorOccurred('Failed to load your drills: $error'));
              }
            },
          );
          break;
      }
    } catch (e) {
      if (!isClosed) {
        AppLogger.error('Error in view change', error: e);
        emit(state.copyWith(
          status: DrillLibraryStatus.error,
          errorMessage: 'Failed to switch view: $e',
        ));
      }
    }
  }

  Future<void> _onRefreshRequested(DrillLibraryRefreshRequested event, Emitter<DrillLibraryState> emit) async {
    await BlocUtils.executeWithErrorHandling(
      () async {
        emit(state.copyWith(
          status: DrillLibraryStatus.refreshing,
          isRefreshing: true,
        ),);
        
        try {
          // Force refresh from repository with enhanced retry mechanism
          List<Drill> items = [];
          int retryCount = 0;
          const maxRetries = 3;
          
          while (retryCount < maxRetries) {
            try {
              AppLogger.info('🔄 Refresh attempt ${retryCount + 1}/$maxRetries', tag: 'DrillLibraryBloc');
              
              // Use view-specific fetch method for better reliability
              switch (state.currentView) {
                case DrillLibraryView.favorites:
                  items = await _repo.fetchFavoriteDrills();
                  break;
                case DrillLibraryView.all:
                  if (_repo is FirebaseDrillRepository) {
                    items = await (_repo as FirebaseDrillRepository).fetchAdminDrills();
                  } else {
                    items = await _repo.fetchAll();
                  }
                  break;
                case DrillLibraryView.custom:
                  items = await _repo.fetchAll();
                  break;
              }
              
              AppLogger.success('✅ Refresh successful: ${items.length} items loaded', tag: 'DrillLibraryBloc');
              break; // Success, exit retry loop
            } catch (e) {
              retryCount++;
              AppLogger.warning('❌ Refresh attempt ${retryCount} failed: $e', tag: 'DrillLibraryBloc');
              
              if (retryCount >= maxRetries) {
                rethrow; // Re-throw after max retries
              }
              
              // Wait before retry with exponential backoff
              final delayMs = 500 * retryCount;
              AppLogger.info('⏳ Waiting ${delayMs}ms before retry...', tag: 'DrillLibraryBloc');
              await Future.delayed(Duration(milliseconds: delayMs));
            }
          }
          
          final filtered = _applyFilters(items);
          
          emit(state.copyWith(
            status: DrillLibraryStatus.loaded,
            items: filtered,
            all: items,
            isRefreshing: false,
            lastUpdated: DateTime.now(),
            errorMessage: null, // Clear any previous error
          ),);
          
          AppLogger.success('Successfully refreshed ${items.length} drills (${filtered.length} after filters)', tag: 'DrillLibraryBloc');
        } catch (e) {
          AppLogger.error('Failed to refresh after all retries', error: e, tag: 'DrillLibraryBloc');
          rethrow;
        }
      },
      emit,
      (error) => state.copyWith(
        status: DrillLibraryStatus.error,
        errorMessage: _getErrorMessage(error),
        isRefreshing: false,
      ),
    );
  }
  
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    } else if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorStr.contains('permission') || errorStr.contains('unauthorized')) {
      return 'Access denied. Please check your permissions.';
    } else if (errorStr.contains('not found')) {
      return 'Data not found. Please refresh and try again.';
    } else {
      return 'Failed to load data. Please try again.';
    }
  }

  Future<void> _onFiltersCleared(DrillLibraryFiltersCleared event, Emitter<DrillLibraryState> emit) async {
    emit(state.copyWith(
      category: null,
      items: state.all,
      lastUpdated: DateTime.now(),
    ),);
  }

  void _onItemsUpdated(_DrillLibraryItemsUpdated event, Emitter<DrillLibraryState> emit) {
    final filtered = _applyFilters(event.items);
    emit(state.copyWith(
      status: DrillLibraryStatus.loaded,
      items: filtered,
      all: event.items,
      lastUpdated: DateTime.now(),
    ),);
  }

  void _onErrorOccurred(_DrillLibraryErrorOccurred event, Emitter<DrillLibraryState> emit) {
    emit(state.copyWith(
      status: DrillLibraryStatus.error,
      errorMessage: event.error,
      isRefreshing: false,
    ),);
  }

  List<Drill> _applyFilters(List<Drill> items, {String? query, String? category, Difficulty? difficulty, DrillLibraryView? view}) {
    // Use provided parameters or fall back to state
    final searchQuery = (query ?? state.query ?? '').trim();
    final filterCategory = (category ?? state.category ?? '').trim();
    final filterDifficulty = difficulty ?? state.difficulty;
    final currentView = view ?? state.currentView;
    
    Iterable<Drill> out = items;
    
    // Apply view filter first
    switch (currentView) {
      case DrillLibraryView.favorites:
        // No filtering needed - the stream already provides only favorites
        break;
      case DrillLibraryView.custom:
        // Filter to show only user-created drills (not preset/admin drills)
        out = out.where((d) => !d.isPreset && d.createdByRole != 'admin');
        break;
      case DrillLibraryView.all:
        // For admin drills view, show only admin-created drills
        // The data should already be filtered by the repository, but ensure consistency
        out = out.where((d) => d.createdByRole == 'admin');
        break;
    }
    
    // Apply search query filter
    if (searchQuery.isNotEmpty) {
      final queryLower = searchQuery.toLowerCase();
      out = out.where((d) {
        final name = d.name.toLowerCase();
        final description = d.description.toLowerCase();
        final category = d.category.toLowerCase();
        final tags = d.tags.map((tag) => tag.toLowerCase()).toList();
        
        return name.contains(queryLower) ||
               description.contains(queryLower) ||
               category.contains(queryLower) ||
               tags.any((tag) => tag.contains(queryLower));
      });
    }
    
    // Apply category filter
    if (filterCategory.isNotEmpty) {
      out = out.where((d) => d.category.toLowerCase() == filterCategory.toLowerCase());
    }
    
    // Apply difficulty filter
    if (filterDifficulty != null) {
      out = out.where((d) => d.difficulty == filterDifficulty);
    }
    
    final result = out.toList(growable: false);
    print('🔍 Applied filters - Query: "$searchQuery", Category: "$filterCategory", Difficulty: $filterDifficulty, View: $currentView');
    print('🔍 Filtered ${items.length} items down to ${result.length} items');
    
    return result;
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
