import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/auth/data/auth_repository.dart';
import 'package:spark_app/core/services/preferences_service.dart';
import 'package:spark_app/core/auth/services/session_management_service.dart';
import 'package:spark_app/core/auth/services/device_session_service.dart';
import 'package:spark_app/core/auth/services/permission_initialization_service.dart';
import 'package:spark_app/core/auth/services/permission_manager.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'dart:async';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  final SessionManagementService? _sessionService;
  final DeviceSessionService _deviceSessionService;
  final PermissionInitializationService _permissionService;
  late final StreamSubscription<User?> _authSubscription;
  
  AuthBloc(
    this._repo, {
    SessionManagementService? sessionService,
    DeviceSessionService? deviceSessionService,
    PermissionInitializationService? permissionService,
  })  : _sessionService = sessionService ?? getIt<SessionManagementService>(),
        _deviceSessionService = deviceSessionService ?? DeviceSessionService(),
        _permissionService = permissionService ?? PermissionInitializationService(),
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
    
    // If we start with an authenticated user (app restart), initialize permissions
    if (state.status == AuthStatus.loading && state.user != null) {
      AppLogger.info('App restarted with authenticated user, initializing permissions', tag: 'Auth');
      // Add a small delay to ensure Firebase is fully ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!isClosed) {
          add(AuthCheckRequested());
        }
      });
    }
  }

  /// Determines initial state based on current Firebase Auth state
  /// This helps with hot reload scenarios and app restarts
  static AuthState _getInitialState() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // User is logged in, start with loading state to initialize permissions
      // This ensures permissions are loaded on app restart
      debugPrint('🔄 Initial state: User exists in Firebase Auth, starting with loading to initialize permissions');
      return AuthState(status: AuthStatus.loading, user: currentUser);
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
      
      // Initialize permissions immediately after successful authentication
      AppLogger.info('Initializing user permissions', tag: 'Auth');
      final permissions = await _permissionService.initializePermissions();
      AppLogger.success('Permissions loaded: ${permissions.toString()}', tag: 'Auth');
      
      // Also initialize the PermissionManager for real-time updates
      try {
        await PermissionManager.instance.initializePermissions();
        AppLogger.success('PermissionManager initialized', tag: 'Auth');
      } catch (e) {
        AppLogger.warning('PermissionManager initialization failed: $e', tag: 'Auth');
        // Don't fail login if PermissionManager fails
      }
      
      // No conflicts found, complete authentication with permissions
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: cred.user,
        permissions: permissions,
      ));
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
      
      // Wait for profile creation to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Initialize permissions for new user
      AppLogger.info('Initializing permissions for new user', tag: 'Auth');
      final permissions = await _permissionService.initializePermissions();
      AppLogger.success('Permissions loaded: ${permissions.toString()}', tag: 'Auth');
      
      // Also initialize the PermissionManager for real-time updates
      try {
        await PermissionManager.instance.initializePermissions();
        AppLogger.success('PermissionManager initialized for new user', tag: 'Auth');
      } catch (e) {
        AppLogger.warning('PermissionManager initialization failed for new user: $e', tag: 'Auth');
        // Don't fail registration if PermissionManager fails
      }
      
      // Profile creation is now handled by SessionManagementService
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: cred.user,
        permissions: permissions,
      ));
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
      
      // Clear permission cache
      _permissionService.clearCache();
      
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
  
  Future<void> _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) async {
    // CRITICAL: Don't override deviceConflict state
    // This prevents race condition where auth listener overrides conflict dialog
    if (state.status == AuthStatus.deviceConflict) {
      AppLogger.debug('Skipping user changed - device conflict in progress', tag: 'Auth');
      return;
    }
    
    if (event.user != null) {
      AppLogger.info('User changed to: ${event.user!.uid}', tag: 'Auth');
      
      // Load permissions when user changes
      UserPermissions? permissions;
      bool permissionLoadSuccess = false;
      
      try {
        AppLogger.info('User changed - initializing permissions', tag: 'Auth');
        
        // Try to load permissions with retry logic
        int retryCount = 0;
        const maxRetries = 2;
        
        while (retryCount < maxRetries && !permissionLoadSuccess) {
          try {
            permissions = await _permissionService.initializePermissions();
            permissionLoadSuccess = true;
            AppLogger.success('Permissions loaded on user change (attempt ${retryCount + 1}): ${permissions.toString()}', tag: 'Auth');
          } catch (e) {
            retryCount++;
            AppLogger.warning('Permission load attempt $retryCount failed on user change: $e', tag: 'Auth');
            if (retryCount < maxRetries) {
              await Future.delayed(const Duration(milliseconds: 300));
            }
          }
        }
        
        // Also initialize the PermissionManager for real-time updates
        try {
          await PermissionManager.instance.initializePermissions();
          AppLogger.success('PermissionManager initialized on user change', tag: 'Auth');
        } catch (e) {
          AppLogger.warning('PermissionManager initialization failed on user change: $e', tag: 'Auth');
          // Retry PermissionManager initialization in background
          Future.delayed(const Duration(milliseconds: 500), () async {
            try {
              await PermissionManager.instance.initializePermissions();
              AppLogger.success('PermissionManager initialized on retry (user change)', tag: 'Auth');
            } catch (retryError) {
              AppLogger.error('PermissionManager retry failed on user change: $retryError', tag: 'Auth');
            }
          });
        }
      } catch (e) {
        AppLogger.error('Failed to load permissions on user change', error: e, tag: 'Auth');
      }
      
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: event.user,
        permissions: permissions,
      ));
      
      // If permission loading failed, try again in background
      if (!permissionLoadSuccess) {
        AppLogger.info('Attempting background permission load after user change...', tag: 'Auth');
        Future.delayed(const Duration(seconds: 1), () async {
          try {
            final backgroundPermissions = await _permissionService.initializePermissions();
            await PermissionManager.instance.initializePermissions();
            AppLogger.success('Background permission load successful after user change', tag: 'Auth');
            
            // Update state if still authenticated and same user
            if (!isClosed &&
                state.status == AuthStatus.authenticated &&
                state.user?.uid == event.user!.uid) {
              emit(state.copyWith(permissions: backgroundPermissions));
            }
          } catch (e) {
            AppLogger.error('Background permission load failed after user change', error: e, tag: 'Auth');
          }
        });
      }
      
    } else {
      AppLogger.info('User changed to null - logging out', tag: 'Auth');
      // Clear permissions cache on logout
      _permissionService.clearCache();
      
      // Also clear PermissionManager
      try {
        PermissionManager.instance.clearCache();
      } catch (e) {
        AppLogger.warning('Failed to clear PermissionManager cache: $e', tag: 'Auth');
      }
      
      emit(const AuthState.initial());
    }
  }
  
  Future<void> _onAuthCheck(AuthCheckRequested event, Emitter<AuthState> emit) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        AppLogger.info('Auth check: Found Firebase user ${currentUser.uid}', tag: 'Auth');
        
        // Emit loading state first to show progress
        emit(state.copyWith(status: AuthStatus.loading, user: currentUser));
        
        // Load permissions on auth check (important for app restart)
        UserPermissions? permissions;
        bool permissionInitSuccess = false;
        
        try {
          AppLogger.info('Auth check - initializing permissions for user ${currentUser.uid}', tag: 'Auth');
          
          // Try multiple times if needed for robustness
          int retryCount = 0;
          const maxRetries = 3;
          
          while (retryCount < maxRetries && !permissionInitSuccess) {
            try {
              permissions = await _permissionService.initializePermissions();
              permissionInitSuccess = true;
              AppLogger.success('Permissions loaded on auth check (attempt ${retryCount + 1}): ${permissions.toString()}', tag: 'Auth');
            } catch (e) {
              retryCount++;
              AppLogger.warning('Permission initialization attempt $retryCount failed: $e', tag: 'Auth');
              if (retryCount < maxRetries) {
                await Future.delayed(Duration(milliseconds: 500 * retryCount));
              }
            }
          }
          
          // Also initialize the PermissionManager for real-time updates
          try {
            await PermissionManager.instance.initializePermissions();
            AppLogger.success('PermissionManager initialized on auth check', tag: 'Auth');
          } catch (e) {
            AppLogger.warning('PermissionManager initialization failed on auth check: $e', tag: 'Auth');
            // Try to initialize it again after a delay
            Future.delayed(const Duration(seconds: 1), () async {
              try {
                await PermissionManager.instance.initializePermissions();
                AppLogger.success('PermissionManager initialized on retry', tag: 'Auth');
              } catch (retryError) {
                AppLogger.error('PermissionManager retry also failed: $retryError', tag: 'Auth');
              }
            });
          }
          
        } catch (e) {
          AppLogger.error('Failed to load permissions on auth check after all retries', error: e, tag: 'Auth');
          // Continue with authentication even if permissions fail
          // The user can still use the app, just with limited functionality
        }
        
        AppLogger.success('Auth check: User authenticated successfully', tag: 'Auth');
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: currentUser,
          permissions: permissions,
        ));
        
        // If permissions failed, try to reload them in the background
        if (!permissionInitSuccess) {
          AppLogger.info('Attempting background permission reload...', tag: 'Auth');
          Future.delayed(const Duration(seconds: 2), () async {
            try {
              final backgroundPermissions = await _permissionService.initializePermissions();
              await PermissionManager.instance.initializePermissions();
              AppLogger.success('Background permission reload successful', tag: 'Auth');
              
              // Update state with loaded permissions if still authenticated
              if (!isClosed && state.status == AuthStatus.authenticated) {
                emit(state.copyWith(permissions: backgroundPermissions));
              }
            } catch (e) {
              AppLogger.error('Background permission reload failed', error: e, tag: 'Auth');
            }
          });
        }
        
      } else {
        // No user found
        AppLogger.debug('Auth check: No Firebase user found', tag: 'Auth');
        emit(const AuthState.initial());
      }
    } catch (e) {
      AppLogger.error('Auth check failed completely', error: e, tag: 'Auth');
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
      
      // Initialize permissions after device session is registered
      UserPermissions? permissions;
      try {
        AppLogger.info('Initializing permissions after device conflict resolution', tag: 'Auth');
        permissions = await _permissionService.initializePermissions();
        AppLogger.success('Permissions loaded: ${permissions.toString()}', tag: 'Auth');
      } catch (e) {
        AppLogger.error('Failed to load permissions after device conflict', error: e, tag: 'Auth');
      }
      
      // Complete the authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: currentUser,
          permissions: permissions,
        ));
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
