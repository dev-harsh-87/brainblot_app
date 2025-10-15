part of 'drill_library_bloc.dart';

abstract class DrillLibraryEvent extends Equatable {
  const DrillLibraryEvent();
  @override
  List<Object?> get props => [];
}

class DrillLibraryStarted extends DrillLibraryEvent {
  const DrillLibraryStarted();
}

class DrillLibraryQueryChanged extends DrillLibraryEvent {
  final String query;
  const DrillLibraryQueryChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class DrillLibraryFilterChanged extends DrillLibraryEvent {
  final String? category;
  final Difficulty? difficulty;
  const DrillLibraryFilterChanged({this.category, this.difficulty});
  @override
  List<Object?> get props => [category, difficulty];
}

class DrillLibraryRefreshRequested extends DrillLibraryEvent {
  const DrillLibraryRefreshRequested();
}

class DrillLibraryFiltersCleared extends DrillLibraryEvent {
  const DrillLibraryFiltersCleared();
}

class DrillLibraryViewChanged extends DrillLibraryEvent {
  final DrillLibraryView view;
  const DrillLibraryViewChanged(this.view);
  @override
  List<Object?> get props => [view];
}

enum DrillLibraryView { all, favorites, custom }

class _DrillLibraryItemsUpdated extends DrillLibraryEvent {
  final List<Drill> items;
  const _DrillLibraryItemsUpdated(this.items);
  @override
  List<Object?> get props => [items];
}

class _DrillLibraryErrorOccurred extends DrillLibraryEvent {
  final String error;
  const _DrillLibraryErrorOccurred(this.error);
  @override
  List<Object?> get props => [error];
}
