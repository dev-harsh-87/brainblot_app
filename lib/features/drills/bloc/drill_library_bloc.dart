import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/data/firebase_drill_repository.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/core/bloc/bloc_utils.dart';

part 'drill_library_event.dart';
part 'drill_library_state.dart';

class DrillLibraryBloc extends Bloc<DrillLibraryEvent, DrillLibraryState> {
  final DrillRepository _repo;
  StreamSubscription<List<Drill>>? _sub;

  DrillLibraryBloc(this._repo) : super(const DrillLibraryState.initial()) {
    on<DrillLibraryStarted>(_onStarted);
    on<DrillLibraryQueryChanged>(_onQueryChanged);
    on<DrillLibraryFilterChanged>(_onFilterChanged);
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
          errorMessage: null,
        ));
        
        // Ensure default drills are seeded (only for Firebase repository)
        try {
          if (_repo is FirebaseDrillRepository) {
            await (_repo as FirebaseDrillRepository).seedDefaultDrills();
          }
        } catch (e) {
          print('⚠️ Warning: Could not seed default drills: $e');
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
    ));
    
    // Apply filters with debouncing effect
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!isClosed) {
      final filtered = _applyFilters(state.all, query: event.query);
      emit(state.copyWith(
        status: DrillLibraryStatus.loaded,
        items: filtered,
        lastUpdated: DateTime.now(),
      ));
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
    ));
  }

  Future<void> _onViewChanged(DrillLibraryViewChanged event, Emitter<DrillLibraryState> emit) async {
    emit(state.copyWith(
      status: DrillLibraryStatus.filtering,
      currentView: event.view,
    ));
    
    final filtered = _applyFilters(state.all, view: event.view);
    emit(state.copyWith(
      status: DrillLibraryStatus.loaded,
      items: filtered,
      lastUpdated: DateTime.now(),
    ));
  }

  Future<void> _onRefreshRequested(DrillLibraryRefreshRequested event, Emitter<DrillLibraryState> emit) async {
    await BlocUtils.executeWithErrorHandling(
      () async {
        emit(state.copyWith(
          status: DrillLibraryStatus.refreshing,
          isRefreshing: true,
          errorMessage: null,
        ));
        
        try {
          // Force refresh from repository with retry mechanism
          List<Drill> items = [];
          int retryCount = 0;
          const maxRetries = 3;
          
          while (retryCount < maxRetries) {
            try {
              items = await _repo.fetchAll();
              break; // Success, exit retry loop
            } catch (e) {
              retryCount++;
              if (retryCount >= maxRetries) {
                throw e; // Re-throw after max retries
              }
              // Wait before retry with exponential backoff
              await Future.delayed(Duration(milliseconds: 500 * retryCount));
            }
          }
          
          final filtered = _applyFilters(items);
          
          emit(state.copyWith(
            status: DrillLibraryStatus.loaded,
            items: filtered,
            all: items,
            isRefreshing: false,
            lastUpdated: DateTime.now(),
          ));
          
          print('✅ Successfully refreshed ${items.length} drills');
        } catch (e) {

          throw e;
        }
      },
      emit,
      (error) => state.copyWith(
        status: DrillLibraryStatus.error,
        errorMessage: 'Failed to refresh data: ${error.message}',
        isRefreshing: false,
      ),
    );
  }

  Future<void> _onFiltersCleared(DrillLibraryFiltersCleared event, Emitter<DrillLibraryState> emit) async {
    emit(state.copyWith(
      query: null,
      category: null,
      difficulty: null,
      items: state.all,
      lastUpdated: DateTime.now(),
    ));
  }

  void _onItemsUpdated(_DrillLibraryItemsUpdated event, Emitter<DrillLibraryState> emit) {
    final filtered = _applyFilters(event.items);
    emit(state.copyWith(
      status: DrillLibraryStatus.loaded,
      items: filtered,
      all: event.items,
      errorMessage: null,
      lastUpdated: DateTime.now(),
    ));
  }

  void _onErrorOccurred(_DrillLibraryErrorOccurred event, Emitter<DrillLibraryState> emit) {
    emit(state.copyWith(
      status: DrillLibraryStatus.error,
      errorMessage: event.error,
      isRefreshing: false,
    ));
  }

  List<Drill> _applyFilters(List<Drill> items, {String? query, String? category, Difficulty? difficulty, DrillLibraryView? view}) {
    // Use provided parameters or fall back to state
    final searchQuery = query ?? state.query;
    final filterCategory = category ?? state.category;
    final filterDifficulty = difficulty ?? state.difficulty;
    final currentView = view ?? state.currentView;
    
    Iterable<Drill> out = items;
    
    // Apply view filter first
    switch (currentView) {
      case DrillLibraryView.favorites:
        out = out.where((d) => d.favorite);
        break;
      case DrillLibraryView.custom:
        out = out.where((d) => !d.isPreset);
        break;
      case DrillLibraryView.all:
        // No additional filtering needed
        break;
    }
    
    // Apply other filters
    if ((searchQuery ?? '').isNotEmpty) {
      out = out.where((d) => d.name.toLowerCase().contains(searchQuery!.toLowerCase()));
    }
    if ((filterCategory ?? '').isNotEmpty) {
      out = out.where((d) => d.category.toLowerCase() == filterCategory!.toLowerCase());
    }
    if (filterDifficulty != null) {
      out = out.where((d) => d.difficulty == filterDifficulty);
    }
    return out.toList(growable: false);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
