import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/features/auth/data/auth_repository.dart';
import 'package:brainblot_app/features/auth/data/firebase_user_repository.dart';
import 'package:brainblot_app/core/services/preferences_service.dart';
import 'dart:async';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  final FirebaseUserRepository? _userRepo;
  late final StreamSubscription<User?> _authSubscription;
  
  AuthBloc(this._repo, {FirebaseUserRepository? userRepo}) 
      : _userRepo = userRepo,
        super(const AuthState.initial()) {
    on<AuthLoginSubmitted>(_onLogin);
    on<AuthRegisterSubmitted>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthUserChanged>(_onUserChanged);
    on<AuthCheckRequested>(_onAuthCheck);
    on<AuthForgotPasswordSubmitted>(_onForgotPassword);
    
    // Listen to auth state changes for automatic session management
    _authSubscription = _repo.authState().listen((user) {
      add(AuthUserChanged(user));
    });
  }

  Future<void> _onLogin(AuthLoginSubmitted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, error: null));
    try {
      final cred = await _repo.signInWithEmailPassword(email: event.email, password: event.password);
      
      // Ensure user profile exists and update last active
      if (_userRepo != null && cred.user != null) {
        try {
          await _userRepo!.createOrUpdateUserProfile(
            userId: cred.user!.uid,
            email: event.email,
            displayName: cred.user!.displayName ?? event.email.split('@').first,
            profileImageUrl: cred.user!.photoURL,
          );
        } catch (profileError) {
          // Profile update failure shouldn't block login
          print('Failed to update user profile: $profileError');
        }
      }
      
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
      
      // Create user profile in Firestore for sharing functionality
      if (_userRepo != null && cred.user != null) {
        try {
          await _userRepo!.createOrUpdateUserProfile(
            userId: cred.user!.uid,
            email: event.email,
            displayName: cred.user!.displayName ?? event.email.split('@').first,
            profileImageUrl: cred.user!.photoURL,
          );
        } catch (profileError) {
          // Profile creation failure shouldn't block registration
          print('Failed to create user profile: $profileError');
        }
      }
      
      emit(state.copyWith(status: AuthStatus.authenticated, user: cred.user));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: e.message ?? 'Registration failed'));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _repo.signOut();
      
      // Clear saved credentials on logout
      final prefs = await PreferencesService.getInstance();
      await prefs.clearSavedCredentials();
      
      emit(const AuthState.initial());
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: 'Logout failed: ${e.toString()}'));
    }
  }
  
  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(state.copyWith(status: AuthStatus.authenticated, user: event.user));
    } else {
      emit(const AuthState.initial());
    }
  }
  
  Future<void> _onAuthCheck(AuthCheckRequested event, Emitter<AuthState> emit) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      emit(state.copyWith(status: AuthStatus.authenticated, user: currentUser));
    } else {
      emit(const AuthState.initial());
    }
  }

  Future<void> _onForgotPassword(AuthForgotPasswordSubmitted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, error: null));
    try {
      await _repo.sendPasswordResetEmail(email: event.email);
      emit(state.copyWith(
        status: AuthStatus.passwordResetSent,
        error: null,
        message: 'Password reset email sent to ${event.email}',
      ));
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email address.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        default:
          errorMessage = e.message ?? 'Failed to send password reset email';
      }
      emit(state.copyWith(status: AuthStatus.failure, error: errorMessage));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: e.toString()));
    }
  }
  
  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }
}
