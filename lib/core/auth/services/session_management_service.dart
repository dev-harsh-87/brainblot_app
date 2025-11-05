import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/services/preferences_service.dart';
import 'package:spark_app/core/auth/services/permission_service.dart';
import 'package:spark_app/features/subscription/services/subscription_sync_service.dart';
import 'dart:async';

/// Centralized session management service
/// Handles user sessions, role-based access, and automatic cleanup
class SessionManagementService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final PermissionService? _permissionService;
  final SubscriptionSyncService _subscriptionSync;
  
  // Session state
  AppUser? _currentSession;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  
  // Session callbacks
  final List<Function(AppUser?)> _sessionListeners = [];
  
  SessionManagementService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    PermissionService? permissionService,
    SubscriptionSyncService? subscriptionSync,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _permissionService = permissionService,
        _subscriptionSync = subscriptionSync ?? SubscriptionSyncService() {
    _initializeSessionMonitoring();
  }

  /// Initialize session monitoring
  void _initializeSessionMonitoring() {
    // Initialize subscription sync service
    _subscriptionSync.initialize().catchError((e) {
      print("⚠️ Failed to initialize subscription sync: $e");
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
      
      // First ensure user profile exists
// CRITICAL: Sync subscription BEFORE listening to snapshots
      // This ensures the user gets the correct moduleAccess from their plan
      print("🔄 Syncing subscription before establishing session...");
      await _subscriptionSync.syncUserOnLogin(firebaseUser.uid);
      print("✅ Subscription synced");
      await _ensureUserProfileExists(firebaseUser);
      
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
        _currentSession = null;
        _notifySessionListeners(null);
      });
    } catch (e) {
      print('❌ Failed to establish session: $e');
      _currentSession = null;
      _notifySessionListeners(null);
    }
  }

  /// Clear user session
  Future<void> _clearSession() async {
    // Cancel subscriptions
    await _userSubscription?.cancel();
    _userSubscription = null;
    
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
                status: 'active',
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
                status: 'active',
                moduleAccess: ['drills', 'profile', 'stats', 'analysis'],
              ),
        preferences: const UserPreferences(
          theme: 'system',
          notifications: true,
          soundEnabled: true,
          language: 'en',
          timezone: 'UTC',
        ),
        stats: const UserStats(
          totalSessions: 0,
          totalDrillsCompleted: 0,
          totalProgramsCompleted: 0,
          averageAccuracy: 0.0,
          averageReactionTime: 0.0,
          streakDays: 0,
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
    await _subscriptionSync.dispose();
    _sessionListeners.clear();
  }
}