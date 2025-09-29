import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';

part 'drill_library_event.dart';
part 'drill_library_state.dart';

class DrillLibraryBloc extends Bloc<DrillLibraryEvent, DrillLibraryState> {
  final DrillRepository _repo;
  StreamSubscription<List<Drill>>? _sub;

  DrillLibraryBloc(this._repo) : super(const DrillLibraryState.initial()) {
    on<DrillLibraryStarted>(_onStarted);
    on<DrillLibraryQueryChanged>(_onQueryChanged);
    on<DrillLibraryFilterChanged>(_onFilterChanged);
    on<_DrillLibraryItemsUpdated>(_onItemsUpdated);
  }

  Future<void> _onStarted(DrillLibraryStarted event, Emitter<DrillLibraryState> emit) async {
    emit(state.copyWith(status: DrillLibraryStatus.loading));
    _sub?.cancel();
    _sub = _repo.watchAll().listen((items) => add(_DrillLibraryItemsUpdated(items)));
  }

  Future<void> _onQueryChanged(DrillLibraryQueryChanged event, Emitter<DrillLibraryState> emit) async {
    emit(state.copyWith(query: event.query));
  }

  Future<void> _onFilterChanged(DrillLibraryFilterChanged event, Emitter<DrillLibraryState> emit) async {
    emit(state.copyWith(category: event.category, difficulty: event.difficulty));
  }

  void _onItemsUpdated(_DrillLibraryItemsUpdated event, Emitter<DrillLibraryState> emit) {
    final filtered = _applyFilters(event.items);
    emit(state.copyWith(status: DrillLibraryStatus.loaded, items: filtered, all: event.items));
  }

  List<Drill> _applyFilters(List<Drill> items) {
    Iterable<Drill> out = items;
    if ((state.query ?? '').isNotEmpty) {
      out = out.where((d) => d.name.toLowerCase().contains(state.query!.toLowerCase()));
    }
    if ((state.category ?? '').isNotEmpty) {
      out = out.where((d) => d.category == state.category);
    }
    if (state.difficulty != null) {
      out = out.where((d) => d.difficulty == state.difficulty);
    }
    return out.toList(growable: false);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
