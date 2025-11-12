import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/features/subscription/data/subscription_plan_repository.dart';

/// Service for initializing database with default data
class DatabaseInitializationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SubscriptionPlanRepository _planRepository;

  static const String _defaultAdminEmail = 'admin@brianblot.com';
  static const String _defaultAdminPassword = 'Admin@123456';

  DatabaseInitializationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SubscriptionPlanRepository? planRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _planRepository = planRepository ?? SubscriptionPlanRepository();

  /// Clear all database collections (use with caution!)
  Future<void> clearDatabase() async {
    try {
      print('🗑️ Starting database cleanup...');

      // List of collections to clear
      final collections = [
        'users',
        'drills',
        'programs',
        'sessions',
        'subscription_plans',
      ];

      for (final collection in collections) {
        final snapshot = await _firestore.collection(collection).get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
        print('✅ Cleared collection: $collection (${snapshot.docs.length} documents)');
      }

      print('✅ Database cleanup completed');
    } catch (e) {
      print('❌ Database cleanup failed: $e');
      rethrow;
    }
  }

  /// Initialize database with default data
  Future<void> initializeDatabase() async {
    try {
      print('🚀 Starting database initialization...');

      // Initialize subscription plans
      await _initializeSubscriptionPlans();

      // Create default admin user
      await _createDefaultAdmin();

      // Create default admin user
      await _createDefaultAdmin();

      print('✅ Database initialization completed');
    } catch (e) {
      print('❌ Database initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize subscription plans
  Future<void> _initializeSubscriptionPlans() async {
    try {
      print('📋 Initializing subscription plans...');
      await _planRepository.initializeDefaultPlans();
      print('✅ Subscription plans initialized');
    } catch (e) {
      print('❌ Failed to initialize subscription plans: $e');
      rethrow;
    }
  }

  /// Create default admin user
  Future<void> _createDefaultAdmin() async {
    try {
      print('👤 Creating default admin user...');

      // Check if admin already exists
      final existingUsers = await _firestore
          .collection('users')
          .where('email', isEqualTo: _defaultAdminEmail)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        print('ℹ️ Default admin user already exists');
        return;
      }

      // Create admin auth user
      UserCredential userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: _defaultAdminEmail,
          password: _defaultAdminPassword,
        );
      } catch (e) {
        // If user exists in auth but not in Firestore, sign in
        userCredential = await _auth.signInWithEmailAndPassword(
          email: _defaultAdminEmail,
          password: _defaultAdminPassword,
        );
      }

      final userId = userCredential.user!.uid;

      // Create admin user document
      final admin = AppUser(
        id: userId,
        email: _defaultAdminEmail,
        displayName: 'Administrator',
        role: UserRole.admin,
        subscription: const UserSubscription(
          plan: 'free',
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
        ), // Admin gets full access (note: plan ID should be from DB, but using "free" with full modules for admin)
        preferences: const UserPreferences(),
        stats: const UserStats(),
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .set(admin.toFirestore());

      print('✅ Default admin user created');
      print('📧 Email: $_defaultAdminEmail');
      print('🔑 Password: $_defaultAdminPassword');
    } catch (e) {
      print('❌ Failed to create default admin: $e');
      rethrow;
    }
  }


  /// Reset database and reinitialize with fresh data
  Future<void> resetDatabase() async {
    try {
      print('🔄 Starting database reset...');
      
      await clearDatabase();
      await initializeDatabase();
      
      print('✅ Database reset completed successfully');
    } catch (e) {
      print('❌ Database reset failed: $e');
      rethrow;
    }
  }

  /// Check if database is initialized
  Future<bool> isDatabaseInitialized() async {
    try {
      // Check if subscription plans exist
      final plans = await _planRepository.getAllPlans();
      if (plans.isEmpty) return false;

      // Check if admin user exists
      final adminUsers = await _firestore
          .collection('users')
          .where('email', isEqualTo: _defaultAdminEmail)
          .get();
      if (adminUsers.docs.isEmpty) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get default admin credentials
  Map<String, String> getDefaultAdminCredentials() {
    return {
      'email': _defaultAdminEmail,
      'password': _defaultAdminPassword,
    };
  }

  /// Create an admin user
  Future<void> createAdmin({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      print('👤 Creating admin user...');

      // Create admin auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;

      // Create admin user document
      final admin = AppUser(
        id: userId,
        email: email,
        displayName: displayName,
        role: UserRole.admin,
        subscription: const UserSubscription(
          plan: 'free',
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
        ), // Admin gets full access
        preferences: const UserPreferences(),
        stats: const UserStats(),
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .set(admin.toFirestore());

      print('✅ Admin user created');
    } catch (e) {
      print('❌ Failed to create admin: $e');
      rethrow;
    }
  }

  /// Create a default admin user with custom credentials
  Future<void> createDefaultAdmin({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      print('👤 Creating admin user...');

      // Create admin auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;

      // Create admin user document
      final adminUser = AppUser(
        id: userId,
        email: email,
        displayName: displayName,
        subscription: const UserSubscription(
          plan: 'free',
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
        ), // Gets full access
        preferences: const UserPreferences(),
        stats: const UserStats(),
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .set(adminUser.toFirestore());

      print('✅ Admin user created');
    } catch (e) {
      print('❌ Failed to create admin: $e');
      rethrow;
    }
  }
}