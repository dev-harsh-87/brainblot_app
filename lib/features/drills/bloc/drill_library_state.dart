part of 'drill_library_bloc.dart';

enum DrillLibraryStatus { initial, loading, loaded }

class DrillLibraryState extends Equatable {
  final DrillLibraryStatus status;
  final List<Drill> items; // filtered
  final List<Drill> all; // raw stream
  final String? query;
  final String? category;
  final Difficulty? difficulty;

  const DrillLibraryState({
    required this.status,
    required this.items,
    required this.all,
    this.query,
    this.category,
    this.difficulty,
  });

  const DrillLibraryState.initial()
      : this(status: DrillLibraryStatus.initial, items: const [], all: const []);

  DrillLibraryState copyWith({
    DrillLibraryStatus? status,
    List<Drill>? items,
    List<Drill>? all,
    String? query,
    String? category,
    Difficulty? difficulty,
  }) {
    return DrillLibraryState(
      status: status ?? this.status,
      items: items ?? this.items,
      all: all ?? this.all,
      query: query ?? this.query,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  @override
  List<Object?> get props => [status, items, all, query, category, difficulty];
}
