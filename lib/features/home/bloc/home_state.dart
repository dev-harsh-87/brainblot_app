part of 'home_bloc.dart';

enum HomeStatus { initial, loaded }

class HomeState extends Equatable {
  final HomeStatus status;
  final Drill? recommended;
  final List<SessionResult> recent;
  const HomeState({required this.status, required this.recommended, required this.recent});
  const HomeState.initial() : this(status: HomeStatus.initial, recommended: null, recent: const []);

  HomeState copyWith({HomeStatus? status, Drill? recommended, List<SessionResult>? recent}) => HomeState(
        status: status ?? this.status,
        recommended: recommended ?? this.recommended,
        recent: recent ?? this.recent,
      );

  @override
  List<Object?> get props => [status, recommended, recent];
}
