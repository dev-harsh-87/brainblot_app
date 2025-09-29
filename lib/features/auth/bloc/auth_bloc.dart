import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/features/auth/data/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  AuthBloc(this._repo) : super(const AuthState.initial()) {
    on<AuthLoginSubmitted>(_onLogin);
    on<AuthRegisterSubmitted>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onLogin(AuthLoginSubmitted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, error: null));
    try {
      final cred = await _repo.signInWithEmailPassword(email: event.email, password: event.password);
      emit(state.copyWith(status: AuthStatus.authenticated, user: cred.user));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: e.message ?? 'Authentication failed'));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRegister(AuthRegisterSubmitted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, error: null));
    try {
      final cred = await _repo.registerWithEmailPassword(email: event.email, password: event.password);
      emit(state.copyWith(status: AuthStatus.authenticated, user: cred.user));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: e.message ?? 'Registration failed'));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _repo.signOut();
    emit(const AuthState.initial());
  }
}
