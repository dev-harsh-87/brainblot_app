import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:brainblot_app/firebase_options.dart';
import 'package:brainblot_app/core/services/database_initialization_service.dart';

/// Script to initialize database with default data
/// Run this script once to set up the database
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 Database Initialization Script');
  print('=' * 50);
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');

    // Create initialization service
    final initService = DatabaseInitializationService();

    // Check if database is already initialized
    final isInitialized = await initService.isDatabaseInitialized();
    
    if (isInitialized) {
      print('⚠️ Database is already initialized');
      print('Do you want to reset the database? (y/n)');
      // In production, you would get user input here
      // For now, we'll skip if already initialized
      print('Skipping initialization...');
      return;
    }

    // Clear existing data
    print('\n🗑️ Clearing existing database...');
    await initService.clearDatabase();

    // Initialize database with default data
    print('\n📝 Initializing database...');
    await initService.initializeDatabase();

    // Get default admin credentials
    final credentials = initService.getDefaultAdminCredentials();
    
    print('\n' + '=' * 50);
    print('✅ Database initialization completed successfully!');
    print('=' * 50);
    print('\n📧 Default Admin Credentials:');
    print('   Email: ${credentials['email']}');
    print('   Password: ${credentials['password']}');
    print('\n⚠️ Please change the admin password after first login!');
    print('=' * 50);
  } catch (e, stackTrace) {
    print('\n❌ Database initialization failed!');
    print('Error: $e');
    print('Stack trace: $stackTrace');
  }
}