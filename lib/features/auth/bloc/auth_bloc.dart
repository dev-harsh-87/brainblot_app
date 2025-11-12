import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/auth/data/auth_repository.dart';
import 'package:spark_app/features/auth/data/firebase_user_repository.dart';
import 'package:spark_app/core/services/preferences_service.dart';
import 'package:spark_app/core/auth/services/session_management_service.dart';
import 'package:spark_app/features/auth/services/multi_device_session_service.dart';
import 'package:spark_app/core/di/injection.dart';
import 'dart:async';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  final FirebaseUserRepository? _userRepo;
  final SessionManagementService? _sessionService;
  final MultiDeviceSessionService _multiDeviceService;
  late final StreamSubscription<User?> _authSubscription;
  
  AuthBloc(
    this._repo, {
    FirebaseUserRepository? userRepo,
    SessionManagementService? sessionService,
    MultiDeviceSessionService? multiDeviceService,
  })  : _userRepo = userRepo,
        _sessionService = sessionService ?? getIt<SessionManagementService>(),
        _multiDeviceService = multiDeviceService ?? getIt<MultiDeviceSessionService>(),
        super(_getInitialState()) {
    on<AuthLoginSubmitted>(_onLogin);
    on<AuthRegisterSubmitted>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthUserChanged>(_onUserChanged);
    on<AuthCheckRequested>(_onAuthCheck);
    on<AuthForgotPasswordSubmitted>(_onForgotPassword);
    on<AuthDeviceConflictDetected>(_onDeviceConflictDetected);
    on<AuthContinueWithCurrentDevice>(_onContinueWithCurrentDevice);
    
    // Listen to auth state changes for automatic session management
    _authSubscription = _repo.authState().listen((user) {
      add(AuthUserChanged(user));
    });
  }

  /// Determines initial state based on current Firebase Auth state
  /// This helps with hot reload scenarios and app restarts
  static AuthState _getInitialState() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // User is logged in, start with authenticated state immediately
      // The session will be established asynchronously via SessionManagementService
      debugPrint('🔄 Initial state: User exists in Firebase Auth, starting as authenticated');
      return AuthState(status: AuthStatus.authenticated, user: currentUser);
    }
    return const AuthState.initial();
  }

  Future<void> _onLogin(AuthLoginSubmitted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final cred = await _repo.signInWithEmailPassword(email: event.email, password: event.password);
      
      // Check for existing sessions before completing login
      final existingSessions = await _multiDeviceService.getActiveSessions();
      final otherSessions = existingSessions.where((session) => !session.isCurrentDevice).toList();
      
      if (otherSessions.isNotEmpty) {
        // There are other active sessions, show device conflict
        emit(state.copyWith(
          status: AuthStatus.deviceConflict,
          user: cred.user,
          existingSessions: otherSessions.map((s) => s.toFirestore()).toList(),
        ),);
      } else {
        // No conflicts, proceed with normal authentication
        emit(state.copyWith(status: AuthStatus.authenticated, user: cred.user));
      }
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: e.message ?? 'Authentication failed'));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, error: e.toString()));
    }
  }

  Future<void> _onRegister(AuthRegisterSubmitted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
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
      
      print('✅ Logout successful - session and credentials cleared');
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
      // User exists in Firebase Auth, mark as authenticated immediately
      // Session establishment happens asynchronously via SessionManagementService
      print('🔍 Auth check: Found Firebase user, marking as authenticated');
      emit(state.copyWith(status: AuthStatus.authenticated, user: currentUser));
    } else {
      // No user found
      print('🔍 Auth check: No Firebase user found');
      emit(const AuthState.initial());
    }
  }

  Future<void> _onForgotPassword(AuthForgotPasswordSubmitted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _repo.sendPasswordResetEmail(email: event.email);
      emit(state.copyWith(
        status: AuthStatus.passwordResetSent,
        message: 'Password reset email sent to ${event.email}',
      ),);
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

  Future<void> _onDeviceConflictDetected(AuthDeviceConflictDetected event, Emitter<AuthState> emit) async {
    emit(state.copyWith(
      status: AuthStatus.deviceConflict,
      existingSessions: event.existingSessions,
    ),);
  }

  Future<void> _onContinueWithCurrentDevice(AuthContinueWithCurrentDevice event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      // Force logout from other devices and continue with current login
      await _sessionService!.forceLogoutOtherDevicesAndContinue();
      
      // Complete the authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        emit(state.copyWith(status: AuthStatus.authenticated, user: currentUser));
      } else {
        emit(state.copyWith(status: AuthStatus.failure, error: 'Authentication failed'));
      }
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
