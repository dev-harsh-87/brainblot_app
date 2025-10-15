part of 'drill_library_bloc.dart';

enum DrillLibraryStatus { 
  initial, 
  loading, 
  loaded, 
  filtering, 
  error,
  refreshing,
}

class DrillLibraryState extends Equatable {
  final DrillLibraryStatus status;
  final List<Drill> items; // filtered
  final List<Drill> all; // raw stream
  final String? query;
  final String? category;
  final Difficulty? difficulty;
  final DrillLibraryView currentView;
  final String? errorMessage;
  final bool isRefreshing;
  final DateTime? lastUpdated;

  const DrillLibraryState({
    required this.status,
    required this.items,
    required this.all,
    this.query,
    this.category,
    this.difficulty,
    this.currentView = DrillLibraryView.all,
    this.errorMessage,
    this.isRefreshing = false,
    this.lastUpdated,
  });

  const DrillLibraryState.initial()
      : this(
          status: DrillLibraryStatus.initial, 
          items: const [], 
          all: const [],
          isRefreshing: false,
        );

  DrillLibraryState copyWith({
    DrillLibraryStatus? status,
    List<Drill>? items,
    List<Drill>? all,
    String? query,
    String? category,
    Difficulty? difficulty,
    DrillLibraryView? currentView,
    String? errorMessage,
    bool? isRefreshing,
    DateTime? lastUpdated,
  }) {
    return DrillLibraryState(
      status: status ?? this.status,
      items: items ?? this.items,
      all: all ?? this.all,
      query: query ?? this.query,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      currentView: currentView ?? this.currentView,
      errorMessage: errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Helper methods for better state checking
  bool get hasError => errorMessage != null;
  bool get isLoading => status == DrillLibraryStatus.loading;
  bool get isSuccess => status == DrillLibraryStatus.loaded && !hasError;
  bool get isEmpty => items.isEmpty && status == DrillLibraryStatus.loaded;
  bool get hasFilters => (query?.isNotEmpty ?? false) || 
                        (category?.isNotEmpty ?? false) || 
                        difficulty != null;

  @override
  List<Object?> get props => [
    status, 
    items, 
    all, 
    query, 
    category, 
    difficulty, 
    currentView,
    errorMessage, 
    isRefreshing, 
    lastUpdated,
  ];
}
