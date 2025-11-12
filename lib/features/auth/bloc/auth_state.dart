part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, failure, passwordResetSent, deviceConflict }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final String? error;
  final String? message;
  final List<dynamic>? existingSessions;
  const AuthState({required this.status, this.user, this.error, this.message, this.existingSessions});

  const AuthState.initial() : this(status: AuthStatus.initial);

  AuthState copyWith({AuthStatus? status, User? user, String? error, String? message, List<dynamic>? existingSessions}) => AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
        message: message,
        existingSessions: existingSessions,
      );

  @override
  List<Object?> get props => [status, user, error, message, existingSessions];
}
