import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/auth/data/auth_repository.dart';
import 'package:spark_app/features/auth/data/firebase_user_repository.dart';
import 'package:spark_app/core/services/preferences_service.dart';
import 'package:spark_app/core/auth/services/session_management_service.dart';
import 'package:spark_app/core/di/injection.dart';
import 'dart:async';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  final FirebaseUserRepository? _userRepo;
  final SessionManagementService? _sessionService;
  late final StreamSubscription<User?> _authSubscription;
  
  AuthBloc(
    this._repo, {
    FirebaseUserRepository? userRepo,
    SessionManagementService? sessionService,
  })  : _userRepo = userRepo,
        _sessionService = sessionService ?? getIt<SessionManagementService>(),
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
      
      // Profile creation is now handled by SessionManagementService
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
      
      // Profile creation is now handled by SessionManagementService
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
      // Always use session service for logout (handles cleanup automatically)
      await _sessionService!.signOut();
      
      // Clear state completely
      emit(const AuthState.initial());
      
      print("✅ Logout successful - session and credentials cleared");
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
    // Emit loading state while checking authentication
    emit(state.copyWith(status: AuthStatus.loading));
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // User exists in Firebase Auth, wait for session to be established
      try {
        // Wait a moment for SessionManagementService to establish session
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Check if session service has established the session
        final sessionEstablished = _sessionService?.isLoggedIn() ?? false;
        
        if (sessionEstablished) {
          emit(state.copyWith(status: AuthStatus.authenticated, user: currentUser));
          print("✅ Auth check: User authenticated and session established");
        } else {
          // Session not yet established, wait a bit more and try again
          await Future.delayed(const Duration(milliseconds: 1000));
          final sessionRecheck = _sessionService?.isLoggedIn() ?? false;
          
          if (sessionRecheck) {
            emit(state.copyWith(status: AuthStatus.authenticated, user: currentUser));
            print("✅ Auth check: User authenticated after session restoration");
          } else {
            // Session failed to establish, sign out to clear inconsistent state
            print("⚠️ Auth check: Session failed to establish, clearing auth state");
            await FirebaseAuth.instance.signOut();
            emit(const AuthState.initial());
          }
        }
      } catch (e) {
        print("❌ Auth check error: $e");
        emit(const AuthState.initial());
      }
    } else {
      emit(const AuthState.initial());
      print("ℹ️ Auth check: No user found in Firebase Auth");
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
