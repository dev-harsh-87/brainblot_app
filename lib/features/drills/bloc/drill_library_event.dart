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

class _DrillLibraryItemsUpdated extends DrillLibraryEvent {
  final List<Drill> items;
  const _DrillLibraryItemsUpdated(this.items);
  @override
  List<Object?> get props => [items];
}
