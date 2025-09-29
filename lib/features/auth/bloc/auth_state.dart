part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, failure }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final String? error;
  const AuthState({required this.status, this.user, this.error});

  const AuthState.initial() : this(status: AuthStatus.initial);

  AuthState copyWith({AuthStatus? status, User? user, String? error}) => AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );

  @override
  List<Object?> get props => [status, user, error];
}
