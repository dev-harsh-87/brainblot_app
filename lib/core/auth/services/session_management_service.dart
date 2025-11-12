import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/services/preferences_service.dart';
import 'package:spark_app/core/auth/services/permission_service.dart';
import 'package:spark_app/core/auth/services/device_session_service.dart';
import 'package:spark_app/features/subscription/services/subscription_sync_service.dart';
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
    // Initialize subscription sync service
    _subscriptionSync.initialize().catchError((e) {
      print('⚠️ Failed to initialize subscription sync: $e');
    });
    
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

    // User logged in - establish session
    await _establishSession(firebaseUser);
  }

  /// Establish user session
  Future<void> _establishSession(User firebaseUser) async {
    try {
      // Cancel existing user subscription if any
      await _userSubscription?.cancel();
      await _logoutSubscription?.cancel();
      
      // Register device session (handles single device login)
      // Check if user is admin first
      final userRole = _determineUserRole(firebaseUser.email);
      final isAdmin = userRole == 'admin';
      
      print('🔄 Registering device session...');
      try {
        final existingSessions = await _deviceSessionService.registerDeviceSession(
          firebaseUser.uid,
          isAdmin: isAdmin,
        );
        
        // If there are existing sessions and user is not admin, we should handle this
        // For now, we'll just log it - the UI will handle showing the conflict dialog
        if (existingSessions.isNotEmpty && !isAdmin) {
          print('⚠️ Found ${existingSessions.length} existing sessions for user');
          // You could emit an event here to show device conflict dialog
        }
        
        print('✅ Device session registered (Admin: $isAdmin)');
      } catch (e) {
        print('⚠️ Device session registration failed: $e');
        // Continue with session establishment - this is not critical
      }
      
      // Listen for logout notifications from other devices
      try {
        _logoutSubscription = _deviceSessionService.listenForLogoutNotifications().listen(
          (notification) async {
            print('📱 Received logout notification from another device');
            await _handleForceLogout();
          },
          onError: (error) {
            // Silent fail - notification system is not critical
            print('⚠️ Logout notification error: $error');
          },
        );
      } catch (e) {
        print('⚠️ Failed to setup logout notifications: $e');
        // Continue - this is not critical for session establishment
      }
      
      // First ensure user profile exists
      await _ensureUserProfileExists(firebaseUser);
      
      // CRITICAL: Sync subscription BEFORE listening to snapshots
      // This ensures the user gets the correct moduleAccess from their plan
      print('🔄 Syncing subscription before establishing session...');
      try {
        await _subscriptionSync.syncUserOnLogin(firebaseUser.uid);
        print('✅ Subscription synced');
      } catch (e) {
        print('⚠️ Subscription sync failed: $e');
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
              print('⚠️ Failed to sync subscription: $e');
            });
            
            // Only clear cache if role actually changed
            if (_permissionService != null) {
              _permissionService!.clearCache();
            }
            
            print('✅ Session established for user: ${_currentSession!.email}, role: ${_currentSession!.role.value}');
          } catch (e) {
            print('❌ Failed to parse user profile: $e');
            print('📝 Recreating user profile with proper structure...');
            _createUserProfile(firebaseUser);
          }
        } else {
          // User document doesn't exist, create it
          print('📝 User document not found, creating profile...');
          _createUserProfile(firebaseUser);
        }
      }, onError: (error) {
        print('❌ Session monitoring error: $error');
        // Don't clear session completely - user might still be authenticated
        // Just log the error and continue
        print('⚠️ Auth check: Session failed to establish, clearing auth state');
        _currentSession = null;
        _notifySessionListeners(null);
      },);
    } catch (e) {
      print('❌ Failed to establish session: $e');
      print('⚠️ Auth check: Session failed to establish, clearing auth state');
      _currentSession = null;
      _notifySessionListeners(null);
    }
  }

  /// Handle force logout from another device
  Future<void> _handleForceLogout() async {
    print('🚪 Force logout initiated - another device logged in');
    
    // Sign out from Firebase Auth
    await _auth.signOut();
    
    // Show user notification (you can customize this)
    print('📱 You have been logged out because your account was accessed from another device');
  }

  /// Clear user session
  Future<void> _clearSession() async {
    // Cancel subscriptions
    await _userSubscription?.cancel();
    await _logoutSubscription?.cancel();
    _userSubscription = null;
    _logoutSubscription = null;
    
    // Cleanup device session
    if (_currentSession != null) {
      await _deviceSessionService.cleanupSession(_currentSession!.id);
    }
    
    // Clear session data
    _currentSession = null;
    
    // Clear saved credentials
    try {
      final prefs = await PreferencesService.getInstance();
      await prefs.clearSavedCredentials();
    } catch (e) {
      print('⚠️ Failed to clear saved credentials: $e');
    }
    
    // Notify listeners
    _notifySessionListeners(null);
    
    print('✅ Session cleared');
  }

  /// Update user's last active timestamp
  Future<void> _updateLastActive(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silent fail - not critical
      print('⚠️ Failed to update last active: $e');
    }
  }

  /// Get current session
  AppUser? getCurrentSession() => _currentSession;

  /// Check if user is logged in
  bool isLoggedIn() => _currentSession != null && _auth.currentUser != null;

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
        print('⚠️ Session listener error: $e');
      }
    }
  }

  /// Sign out and clear session
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      // _clearSession will be called automatically via auth state changes
    } catch (e) {
      print('❌ Sign out error: $e');
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

      print('✅ Forced logout from other devices completed');
    } catch (e) {
      print('❌ Failed to force logout other devices: $e');
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
      print('🔍 Checking if user profile exists for: ${firebaseUser.uid}');
      final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      
      if (!userDoc.exists) {
        print('📝 Creating user profile for: ${firebaseUser.email}');
        await _createUserProfile(firebaseUser);
      } else {
        print('✅ User profile already exists');
        
        // Check if role needs to be updated for existing users
        final currentData = userDoc.data()!;
        final currentRole = currentData['role'] as String?;
        final expectedRole = _determineUserRole(firebaseUser.email);
        
        if (currentRole != expectedRole) {
          print('🔄 Updating role from "$currentRole" to "$expectedRole" for: ${firebaseUser.email}');
          await _firestore.collection('users').doc(firebaseUser.uid).update({
            'role': expectedRole,
            'lastActiveAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('✅ Role updated successfully');
        } else {
          // Just update lastActiveAt
          await _firestore.collection('users').doc(firebaseUser.uid).update({
            'lastActiveAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('❌ Error ensuring user profile: $e');
    }
  }

  /// Create user profile in Firestore
  Future<void> _createUserProfile(User firebaseUser) async {
    try {
      final userRole = _determineUserRole(firebaseUser.email);
      final isAdmin = userRole == 'admin';
      print('🔑 Assigning $userRole role to: ${firebaseUser.email}');
      
      // Create proper AppUser object and convert to Firestore format
      final appUser = AppUser(
        id: firebaseUser.uid,
        email: firebaseUser.email?.toLowerCase() ?? '',
        displayName: firebaseUser.displayName ?? (isAdmin ? 'Admin' : firebaseUser.email?.split('@').first ?? 'User'),
        profileImageUrl: firebaseUser.photoURL,
        role: UserRole.fromString(userRole),
        subscription: isAdmin
            ? const UserSubscription(
                plan: 'institute',
                moduleAccess: [
                  'drills',
                  'profile',
                  'stats',
                  'analysis',
                  'admin_drills',
                  'admin_programs',
                  'programs',
                  'multiplayer',
                  'user_management',
                  'team_management',
                  'bulk_operations',
                ],
              )
            : const UserSubscription(
                plan: 'free',
                moduleAccess: ['drills', 'profile', 'stats', 'analysis'],
              ),
        preferences: const UserPreferences(
          notifications: true,
        ),
        stats: const UserStats(
          totalDrillsCompleted: 0,
        ),
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(firebaseUser.uid).set(appUser.toFirestore());
      print('✅ Created profile for: ${firebaseUser.email} with role: $userRole');
    } catch (e) {
      print('❌ Failed to create user profile: $e');
      rethrow;
    }
  }

  /// Determine user role based on email address
  String _determineUserRole(String? email) {
    if (email == null) return 'user';
    
    const adminEmails = [
      'admin@spark.com',
      'admin@brianblot.com',  // Fixed spelling - user's actual admin email
      
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