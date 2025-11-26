import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/services/preferences_service.dart';
import 'package:spark_app/core/auth/services/permission_service.dart';
import 'package:spark_app/core/auth/services/unified_user_service.dart';
import 'package:spark_app/core/services/module_access_fix_service.dart';
import 'package:spark_app/core/services/force_module_update_service.dart';
import 'package:spark_app/core/auth/services/device_session_service.dart';
import 'package:spark_app/features/subscription/services/subscription_sync_service.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'dart:async';

/// Centralized session management service
/// Handles user sessions, role-based access, and automatic cleanup
class SessionManagementService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final PermissionService? _permissionService;
  final SubscriptionSyncService _subscriptionSync;
  final DeviceSessionService _deviceSessionService;
  
  // Session state
  AppUser? _currentSession;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _logoutSubscription;
  
  // Session callbacks
  final List<Function(AppUser?)> _sessionListeners = [];
  
  SessionManagementService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    PermissionService? permissionService,
    SubscriptionSyncService? subscriptionSync,
    DeviceSessionService? deviceSessionService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _permissionService = permissionService,
        _subscriptionSync = subscriptionSync ?? SubscriptionSyncService(),
        _deviceSessionService = deviceSessionService ?? DeviceSessionService() {
    _initializeSessionMonitoring();
  }

  /// Initialize session monitoring
  void _initializeSessionMonitoring() {
    // Check if there's an existing Firebase Auth user on init
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      AppLogger.debug('Session init: Found existing Firebase user, establishing session');
      // Initialize subscription sync service when user is authenticated
      _subscriptionSync.initialize().catchError((e) {
        AppLogger.error('Failed to initialize subscription sync', error: e);
      });
      _establishSession(currentUser).catchError((e) {
        AppLogger.error('Failed to establish initial session', error: e);
      });
    }
    
    // Listen to Firebase Auth state changes
    _authSubscription = _auth.authStateChanges().listen(_handleAuthStateChange);
  }

  /// Handle authentication state changes
  Future<void> _handleAuthStateChange(User? firebaseUser) async {
    if (firebaseUser == null) {
      // User logged out - clear session
      await _clearSession();
      return;
    }

    // Initialize subscription sync service when user logs in
    if (!_subscriptionSync.isInitialized) {
      _subscriptionSync.initialize().catchError((e) {
        AppLogger.error('Failed to initialize subscription sync on login', error: e);
      });
    }

    // CRITICAL: User logged in - establish session WITHOUT device registration
    // Device registration will happen after conflict check in AuthBloc
    // This prevents premature session creation before conflict resolution
    await _establishSession(firebaseUser, skipDeviceRegistration: true);
  }

  /// Establish user session
  /// Set skipDeviceRegistration=true to defer device session creation (for conflict handling)
  Future<void> _establishSession(User firebaseUser, {bool skipDeviceRegistration = false}) async {
    try {
      // Cancel existing user subscription if any
      await _userSubscription?.cancel();
      await _logoutSubscription?.cancel();
      
      // Only register device session if not skipped (conflict check happens in AuthBloc first)
      if (!skipDeviceRegistration) {
        // Check if user is admin first
        final userRole = _determineUserRole(firebaseUser.email);
        final isAdmin = userRole == 'admin';
        
        AppLogger.debug('Registering device session');
        try {
          final existingSessions = await _deviceSessionService.registerDeviceSession(
            firebaseUser.uid,
            isAdmin: isAdmin,
          );
          
          // If there are existing sessions and user is not admin, log it
          if (existingSessions.isNotEmpty && !isAdmin) {
            AppLogger.warning('Found ${existingSessions.length} existing sessions for user');
          }
          
          AppLogger.info('Device session registered (Admin: $isAdmin)');
        } catch (e) {
          AppLogger.error('Device session registration failed', error: e);
          // Continue with session establishment - this is not critical
        }
      } else {
        AppLogger.debug('Skipping device registration - will be handled after conflict check');
      }
      
      // DISABLED: Logout notifications causing issues - will implement later
      // Listen for logout notifications from other devices
      // try {
      //   _logoutSubscription = _deviceSessionService.listenForLogoutNotifications().listen(
      //     (notification) async {
      //       // Only process logout if we still have an active session
      //       if (_currentSession != null && firebaseUser.uid == _currentSession!.id) {
      //         AppLogger.info('Received valid logout notification from another device');
      //         await _handleForceLogout();
      //       } else {
      //         AppLogger.debug('Ignoring stale logout notification');
      //       }
      //     },
      //     onError: (error) {
      //       // Silent fail - notification system is not critical
      //       AppLogger.error('Logout notification error', error: error);
      //     },
      //   );
      // } catch (e) {
      //   AppLogger.error('Failed to setup logout notifications', error: e);
      //   // Continue - this is not critical for session establishment
      // }
      
      // CRITICAL: First ensure user profile exists
      await _ensureUserProfileExists(firebaseUser);
      
      // Wait for profile to be fully created/updated
      await Future.delayed(const Duration(milliseconds: 200));
      
      // CRITICAL: Sync subscription BEFORE listening to snapshots
      // This ensures the user gets the correct moduleAccess from their plan
      AppLogger.debug('Syncing subscription before establishing session');
      try {
        await _subscriptionSync.syncUserOnLogin(firebaseUser.uid);
        AppLogger.info('Subscription synced successfully');
        
        // Force update user to new complete module access
        final forceUpdateService = ForceModuleUpdateService();
        await forceUpdateService.forceUpdateUser(firebaseUser.uid);
        
        // Fix module access naming issues (basic_drills -> drills, etc.)
        final moduleFixService = ModuleAccessFixService();
        await moduleFixService.fixUserModuleAccess(firebaseUser.uid);
        
        // Wait a bit more to ensure Firestore document is updated
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        AppLogger.error('Subscription sync failed', error: e);
        // Continue - user can still use the app with default permissions
      }
      
      // Listen to user document changes for real-time role/permission updates
      _userSubscription = _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data() != null) {
          try {
            _currentSession = AppUser.fromFirestore(doc);
            _notifySessionListeners(_currentSession);
// Sync user subscription on login
            _subscriptionSync.syncUserOnLogin(doc.id).catchError((e) {
              AppLogger.error('Failed to sync subscription', error: e);
            });
            
            // Only clear cache if role actually changed
            if (_permissionService != null) {
              _permissionService!.clearCache();
            }
            
            AppLogger.info('Session established for user: ${_currentSession!.email}, role: ${_currentSession!.role.value}');
          } catch (e) {
            AppLogger.error('Failed to parse user profile', error: e);
            AppLogger.debug('Recreating user profile with proper structure');
            _createUserProfile(firebaseUser);
          }
        } else {
          // User document doesn't exist, create it
          AppLogger.debug('User document not found, creating profile');
          _createUserProfile(firebaseUser);
        }
      }, onError: (error) {
        AppLogger.error('Session monitoring error', error: error);
        // Don't clear session completely - user might still be authenticated
        // Just log the error and continue
        AppLogger.warning('Auth check: Session failed to establish, clearing auth state');
        _currentSession = null;
        _notifySessionListeners(null);
      },);
    } catch (e) {
      AppLogger.error('Failed to establish session', error: e);
      AppLogger.warning('Auth check: Session failed to establish, clearing auth state');
      _currentSession = null;
      _notifySessionListeners(null);
    }
  }



  /// Clear user session (called automatically by auth state changes)
  Future<void> _clearSession() async {
    // Cancel subscriptions
    await _userSubscription?.cancel();
    await _logoutSubscription?.cancel();
    _userSubscription = null;
    _logoutSubscription = null;
    
    // Clear session data
    _currentSession = null;
    
    // Clear saved credentials
    try {
      final prefs = await PreferencesService.getInstance();
      await prefs.clearSavedCredentials();
    } catch (e) {
      AppLogger.error('Failed to clear saved credentials', error: e);
    }
    
    // Notify listeners
    _notifySessionListeners(null);
    
    AppLogger.info('Session cleared');
  }

  /// Get current session
  AppUser? getCurrentSession() => _currentSession;

  /// Check if user is logged in
  /// Returns true if either session is established OR Firebase user exists
  /// This allows for graceful session restoration
  bool isLoggedIn() {
    final hasSession = _currentSession != null;
    final hasFirebaseUser = _auth.currentUser != null;
    
    // If we have Firebase user but no session yet, session is being established
    if (hasFirebaseUser && !hasSession) {
      AppLogger.debug('isLoggedIn: Firebase user exists, session establishing');
    }
    
    return hasSession || hasFirebaseUser;
  }

  /// Check if current user is admin
  bool isAdmin() {
    if (_currentSession == null) return false;
    return _currentSession!.role.isAdmin();
  }

  /// Check if current user has specific role
  bool hasRole(String roleName) {
    if (_currentSession == null) return false;
    return _currentSession!.role.value == roleName;
  }

  /// Check if user has module access
  bool hasModuleAccess(String module) {
    if (_currentSession == null) return false;
    
    // Admin always has access
    if (_currentSession!.role.isAdmin()) return true;
    
    // Check subscription-based access
    return _currentSession!.hasModuleAccess(module);
  }

  /// Check if user can access admin content
  bool canAccessAdminContent() {
    if (_currentSession == null) return false;
    return _currentSession!.canAccessAdminContent();
  }

  /// Check if user can create programs
  bool canCreatePrograms() {
    if (_currentSession == null) return false;
    return _currentSession!.canCreatePrograms();
  }

  /// Check if user can manage users
  bool canManageUsers() {
    if (_currentSession == null) return false;
    return _currentSession!.canManageUsers();
  }

  /// Get current user's subscription plan
  String? getSubscriptionPlan() {
    if (_currentSession == null) return null;
    return _currentSession!.subscription.plan;
  }

  /// Check if subscription is active
  bool isSubscriptionActive() {
    if (_currentSession == null) return false;
    return _currentSession!.subscription.isActive();
  }

  /// Get user's module access list
  List<String> getModuleAccess() {
    if (_currentSession == null) return [];
    return _currentSession!.subscription.moduleAccess;
  }

  /// Add session listener
  void addSessionListener(Function(AppUser?) listener) {
    _sessionListeners.add(listener);
  }

  /// Remove session listener
  void removeSessionListener(Function(AppUser?) listener) {
    _sessionListeners.remove(listener);
  }

  /// Notify all session listeners
  void _notifySessionListeners(AppUser? session) {
    for (final listener in _sessionListeners) {
      try {
        listener(session);
      } catch (e) {
        AppLogger.error('Session listener error', error: e);
      }
    }
  }

  /// Sign out and clear session
  Future<void> signOut() async {
    try {
      // CRITICAL: Cleanup device session BEFORE signing out from Firebase Auth
      // This ensures we still have authentication when accessing Firestore
      if (_currentSession != null) {
        await _deviceSessionService.cleanupSession(_currentSession!.id);
      }
      
      // Cancel subscriptions
      await _userSubscription?.cancel();
      await _logoutSubscription?.cancel();
      _userSubscription = null;
      _logoutSubscription = null;
      
      // Clear saved credentials
      try {
        final prefs = await PreferencesService.getInstance();
        await prefs.clearSavedCredentials();
      } catch (e) {
        AppLogger.error('Failed to clear saved credentials', error: e);
      }
      
      // NOW sign out from Firebase Auth
      await _auth.signOut();
      
      // Clear session data
      _currentSession = null;
      
      // Notify listeners
      _notifySessionListeners(null);
      
      AppLogger.success('Sign out completed', tag: 'SessionManagement');
    } catch (e) {
      AppLogger.error('Sign out error', error: e, tag: 'SessionManagement');
      // Force clear session even on error
      _currentSession = null;
      _notifySessionListeners(null);
      rethrow;
    }
  }

  /// Force refresh session data
  Future<void> refreshSession() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _establishSession(user);
    }
  }

  /// Register device session without forcing logout (for initial login when no conflicts)
  Future<void> registerCurrentDeviceSession() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check if user is admin
      final userRole = _determineUserRole(user.email);
      final isAdmin = userRole == 'admin';

      // Register device session without forcing logout
      await _deviceSessionService.registerDeviceSession(
        user.uid,
        isAdmin: isAdmin,
        forceLogoutOthers: false,
      );

      AppLogger.info('Device session registered');
    } catch (e) {
      AppLogger.error('Failed to register device session', error: e);
      rethrow;
    }
  }

  /// Force logout from all other devices and continue with current login
  Future<void> forceLogoutOtherDevicesAndContinue() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check if user is admin
      final userRole = _determineUserRole(user.email);
      final isAdmin = userRole == 'admin';

      // Force logout from other devices
      await _deviceSessionService.registerDeviceSession(
        user.uid,
        isAdmin: isAdmin,
        forceLogoutOthers: true, // This will logout other devices
      );

      AppLogger.info('Forced logout from other devices completed');
    } catch (e) {
      AppLogger.error('Failed to force logout other devices', error: e);
      rethrow;
    }
  }

  /// Get session features summary
  Map<String, dynamic> getSessionFeatures() {
    if (_currentSession == null) {
      return {
        'isLoggedIn': false,
        'isAdmin': false,
        'plan': null,
        'moduleAccess': <String>[],
        'canAccessAdminContent': false,
        'canCreatePrograms': false,
        'canManageUsers': false,
      };
    }

    return {
      'isLoggedIn': true,
      'isAdmin': _currentSession!.role.isAdmin(),
      'plan': _currentSession!.subscription.plan,
      'moduleAccess': _currentSession!.subscription.moduleAccess,
      'canAccessAdminContent': _currentSession!.canAccessAdminContent(),
      'canCreatePrograms': _currentSession!.canCreatePrograms(),
      'canManageUsers': _currentSession!.canManageUsers(),
      'user': {
        'id': _currentSession!.id,
        'email': _currentSession!.email,
        'displayName': _currentSession!.displayName,
        'role': _currentSession!.role.value,
      },
    };
  }

  /// Stream session changes
  Stream<AppUser?> watchSession() async* {
    // Emit current session first
    yield _currentSession;
    
    // Then listen to auth state changes
    await for (final user in _auth.authStateChanges()) {
      if (user == null) {
        yield null;
      } else {
        // Wait for session to be established
        await Future.delayed(const Duration(milliseconds: 100));
        yield _currentSession;
      }
    }
  }

  /// Ensure user profile exists in Firestore
  Future<void> _ensureUserProfileExists(User firebaseUser) async {
    try {
      AppLogger.debug('Checking if user profile exists for: ${firebaseUser.uid}');
      final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      
      if (!userDoc.exists) {
        AppLogger.debug('Creating user profile for: ${firebaseUser.email}');
        await _createUserProfile(firebaseUser);
      } else {
        AppLogger.debug('User profile already exists');
        
        // Check if role needs to be updated for existing users
        final currentData = userDoc.data()!;
        final currentRole = currentData['role'] as String?;
        final expectedRole = _determineUserRole(firebaseUser.email);
        
        if (currentRole != expectedRole) {
          AppLogger.debug('Updating role from "$currentRole" to "$expectedRole" for: ${firebaseUser.email}');
          await _firestore.collection('users').doc(firebaseUser.uid).update({
            'role': expectedRole,
            'lastActiveAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          AppLogger.info('Role updated successfully');
        } else {
          // Just update lastActiveAt
          await _firestore.collection('users').doc(firebaseUser.uid).update({
            'lastActiveAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      AppLogger.error('Error ensuring user profile', error: e);
    }
  }

  /// Create user profile in Firestore using UnifiedUserService
  Future<void> _createUserProfile(User firebaseUser) async {
    try {
      final unifiedUserService = UnifiedUserService();
      await unifiedUserService.createUserProfile(firebaseUser);
      AppLogger.info('Created profile for: ${firebaseUser.email}');
    } catch (e) {
      AppLogger.error('Failed to create user profile', error: e);
      rethrow;
    }
  }

  /// Determine user role based on email address
  String _determineUserRole(String? email) {
    if (email == null) return 'user';
    
    const adminEmails = [
      'admin@spark.com',
      'admin@gmail.com',
      'harsh@gmail.com',  // Add your actual admin email
      'test@admin.com',   // For testing
    ];
    
    if (adminEmails.contains(email.toLowerCase())) {
      return 'admin';
    }
    
    return 'user';
  }

  /// Dispose and cleanup
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _userSubscription?.cancel();
    await _logoutSubscription?.cancel();
    await _subscriptionSync.dispose();
    _sessionListeners.clear();
  }
}