import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/auth/data/auth_repository.dart';
import 'package:spark_app/features/auth/data/firebase_user_repository.dart';
import 'package:spark_app/core/services/preferences_service.dart';
import 'package:spark_app/core/auth/services/session_management_service.dart';
import 'package:spark_app/core/auth/services/device_session_service.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'dart:async';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  final FirebaseUserRepository? _userRepo;
  final SessionManagementService? _sessionService;
  final DeviceSessionService _deviceSessionService;
  late final StreamSubscription<User?> _authSubscription;
  
  AuthBloc(
    this._repo, {
    FirebaseUserRepository? userRepo,
    SessionManagementService? sessionService,
    DeviceSessionService? deviceSessionService,
  })  : _userRepo = userRepo,
        _sessionService = sessionService ?? getIt<SessionManagementService>(),
        _deviceSessionService = deviceSessionService ?? DeviceSessionService(),
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
      
      // CRITICAL: Ensure user is set before checking sessions
      if (cred.user == null) {
        throw Exception('Authentication failed - no user returned');
      }
      
      // CRITICAL: Wait for auth state to fully settle before checking sessions
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check for existing sessions using simplified service
      try {
        final existingSessions = await _deviceSessionService.registerDeviceSession(cred.user!.uid);
        AppLogger.debug('Found ${existingSessions.length} conflicting sessions', tag: 'Auth');
        
        if (existingSessions.isNotEmpty) {
          // Show device conflict dialog
          AppLogger.warning('Device conflict detected: ${existingSessions.length} other sessions found', tag: 'Auth');
          emit(state.copyWith(
            status: AuthStatus.deviceConflict,
            user: cred.user,
            existingSessions: existingSessions,
          ));
          return; // Stop here to show conflict dialog
        }
        
        // No conflicts, register current session
        // Session is already registered in registerDeviceSession call above
        AppLogger.info('Device session registered successfully', tag: 'Auth');
      } catch (e) {
        AppLogger.error('Session management error', error: e, tag: 'Auth');
        // Continue with login even if session management fails
        try {
          await _sessionService!.registerCurrentDeviceSession();
        } catch (fallbackError) {
          AppLogger.warning('Fallback session registration also failed', tag: 'Auth');
        }
      }
      
      // No conflicts found, complete authentication
      emit(state.copyWith(status: AuthStatus.authenticated, user: cred.user));
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Login failed', error: e, tag: 'Auth');
      emit(state.copyWith(status: AuthStatus.failure, error: e.message ?? 'Authentication failed'));
    } catch (e) {
      AppLogger.error('Login error', error: e, tag: 'Auth');
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
      // Use simplified session service for cleanup
      await _deviceSessionService.cleanupSession(state.user!.uid);
      
      // Then use main session service for complete logout
      await _sessionService!.signOut();
      
      // Wait for auth state to settle
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Clear state completely - this ensures clean logout
      emit(const AuthState.initial());
      
      AppLogger.success('Logout successful - session and credentials cleared', tag: 'Auth');
    } catch (e) {
      AppLogger.error('Logout failed', error: e, tag: 'Auth');
      // Even if logout fails, clear local state
      emit(const AuthState.initial());
    }
  }
  
  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    // CRITICAL: Don't override deviceConflict state
    // This prevents race condition where auth listener overrides conflict dialog
    if (state.status == AuthStatus.deviceConflict) {
      AppLogger.debug('Skipping user changed - device conflict in progress', tag: 'Auth');
      return;
    }
    
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
      AppLogger.debug('Auth check: Found Firebase user, marking as authenticated', tag: 'Auth');
      emit(state.copyWith(status: AuthStatus.authenticated, user: currentUser));
    } else {
      // No user found
      AppLogger.debug('Auth check: No Firebase user found', tag: 'Auth');
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
      // Use simplified session service to logout other devices
      // Get device info and logout other sessions
      final deviceInfo = await _deviceSessionService.getDeviceInfo();
      final currentDeviceId = deviceInfo['deviceId'] as String;
      // Note: _logoutExistingSessions is private, so we'll use registerDeviceSession with forceLogoutOthers
      
      // Register current device session
      await _deviceSessionService.registerDeviceSession(state.user!.uid, forceLogoutOthers: true);
      
      // Complete the authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        emit(state.copyWith(status: AuthStatus.authenticated, user: currentUser));
        AppLogger.success('Successfully continued with current device after logout', tag: 'Auth');
      } else {
        emit(state.copyWith(status: AuthStatus.failure, error: 'Authentication failed'));
      }
    } catch (e) {
      AppLogger.error('Failed to continue with current device', error: e, tag: 'Auth');
      emit(state.copyWith(status: AuthStatus.failure, error: e.toString()));
    }
  }
  
  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }
}
