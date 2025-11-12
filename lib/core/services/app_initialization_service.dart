import 'package:spark_app/core/services/database_initialization_service.dart';
import 'package:spark_app/core/services/enhanced_ios_permission_service.dart';
import 'package:spark_app/core/services/fcm_token_service.dart';
import 'package:spark_app/core/services/category_initialization_service.dart';

/// Service to initialize the app with database setup
class AppInitializationService {
  static bool _isInitialized = false;

  /// Initialize the application
  /// Call this from main.dart after Firebase.initializeApp()
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🚀 Initializing application...');

      // Initialize iOS permission service first (if on iOS)
      if (EnhancedIOSPermissionService.isIOS) {
        print('🍎 Initializing iOS permission service...');
        await EnhancedIOSPermissionService.initialize();
        print('✅ iOS permission service initialized');
      }

      // Initialize FCM token service
      print('🔔 Initializing FCM token service...');
      await FCMTokenService.instance.initialize();
      print('✅ FCM token service initialized');

      final initService = DatabaseInitializationService();

      // Check if database is already initialized
      final isInitialized = await initService.isDatabaseInitialized();

      if (!isInitialized) {
        print('📝 Database not initialized. Setting up...');
        await initService.initializeDatabase();
        
        final adminCreds = initService.getDefaultAdminCredentials();
        print('✅ Database initialized successfully!');
        print('');
        print('👑 Admin Account:');
        print('📧 Email: ${adminCreds['email']}');
        print('🔑 Password: ${adminCreds['password']}');
        print('');
        print('⚠️ Please change the admin password after first login!');
      } else {
        print('✅ Database already initialized');
      }

      // Initialize default categories if needed
      final categoryService = CategoryInitializationService();
      final needsCategoryInit = await categoryService.needsInitialization();
      if (needsCategoryInit) {
        print('🏷️ Initializing default drill categories...');
        await categoryService.initializeDefaultCategories();
      } else {
        print('✅ Drill categories already initialized');
      }

      // Log permission status for debugging
      if (EnhancedIOSPermissionService.isIOS) {
        final permissionStatus = await EnhancedIOSPermissionService.getDetailedStatus();
        print('🔐 iOS Permission Status: $permissionStatus');
      }

      _isInitialized = true;
      print('🎉 Application initialization completed successfully!');
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