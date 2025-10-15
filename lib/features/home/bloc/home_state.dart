part of 'home_bloc.dart';

enum HomeStatus { 
  initial, 
  loading, 
  loaded, 
  refreshing,
  error,
}

class HomeState extends Equatable {
  final HomeStatus status;
  final Drill? recommended;
  final List<SessionResult> recent;
  final String? errorMessage;
  final bool isRefreshing;
  final DateTime? lastUpdated;

  const HomeState({
    required this.status, 
    required this.recommended, 
    required this.recent,
    this.errorMessage,
    this.isRefreshing = false,
    this.lastUpdated,
  });

  const HomeState.initial() : this(
    status: HomeStatus.initial, 
    recommended: null, 
    recent: const [],
    isRefreshing: false,
  );

  HomeState copyWith({
    HomeStatus? status, 
    Drill? recommended, 
    List<SessionResult>? recent,
    String? errorMessage,
    bool? isRefreshing,
    DateTime? lastUpdated,
  }) => HomeState(
        status: status ?? this.status,
        recommended: recommended ?? this.recommended,
        recent: recent ?? this.recent,
        errorMessage: errorMessage,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  // Helper methods for better state checking
  bool get hasError => errorMessage != null;
  bool get isLoading => status == HomeStatus.loading;
  bool get isSuccess => status == HomeStatus.loaded && !hasError;
  bool get isEmpty => recommended == null && recent.isEmpty && status == HomeStatus.loaded;
  bool get hasRecommendedDrill => recommended != null;
  bool get hasRecentSessions => recent.isNotEmpty;

  @override
  List<Object?> get props => [
    status, 
    recommended, 
    recent, 
    errorMessage, 
    isRefreshing, 
    lastUpdated,
  ];
}
