part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, failure, passwordResetSent }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final String? error;
  final String? message;
  const AuthState({required this.status, this.user, this.error, this.message});

  const AuthState.initial() : this(status: AuthStatus.initial);

  AuthState copyWith({AuthStatus? status, User? user, String? error, String? message}) => AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
        message: message,
      );

  @override
  List<Object?> get props => [status, user, error, message];
}
