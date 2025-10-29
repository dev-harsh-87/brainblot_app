import 'package:firebase_core/firebase_core.dart';
import 'package:brainblot_app/core/services/database_initialization_service.dart';

/// Service to initialize the app with database setup
class AppInitializationService {
  static bool _isInitialized = false;

  /// Initialize the application
  /// Call this from main.dart after Firebase.initializeApp()
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🚀 Initializing application...');

      final initService = DatabaseInitializationService();

      // Check if database is already initialized
      final isInitialized = await initService.isDatabaseInitialized();

      if (!isInitialized) {
        print('📝 Database not initialized. Setting up...');
        await initService.initializeDatabase();
        
        final superAdminCreds = initService.getDefaultSuperAdminCredentials();
        final adminCreds = initService.getDefaultAdminCredentials();
        print('✅ Database initialized successfully!');
        print('');
        print('👑 Super Admin Account:');
        print('📧 Email: ${superAdminCreds['email']}');
        print('🔑 Password: ${superAdminCreds['password']}');
        print('');
        print('👤 Admin Account:');
        print('📧 Email: ${adminCreds['email']}');
        print('🔑 Password: ${adminCreds['password']}');
        print('');
        print('⚠️ Please change these passwords after first login!');
      } else {
        print('✅ Database already initialized');
      }

      _isInitialized = true;
    } catch (e) {
      print('❌ Application initialization failed: $e');
      rethrow;
    }
  }

  /// Reset database (use with caution!)
  static Future<void> resetDatabase() async {
    final initService = DatabaseInitializationService();
    await initService.resetDatabase();
  }

  /// Check if app is initialized
  static bool get isInitialized => _isInitialized;
}