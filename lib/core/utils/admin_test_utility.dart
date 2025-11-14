import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/core/services/admin_account_service.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Utility class for testing and manually creating admin accounts
class AdminTestUtility {
  static const String _tag = 'AdminTestUtility';
  
  /// Test admin account creation and login
  static Future<void> testAdminAccount() async {
    try {
      AppLogger.info('🧪 Starting admin account test...', tag: _tag);
      
      // Step 1: Create admin account
      final adminService = AdminAccountService();
      final createResult = await adminService.createAdminAccountIfNeeded();
      
      if (!createResult.success) {
        AppLogger.error('❌ Admin account creation failed: ${createResult.message}', tag: _tag);
        return;
      }
      
      AppLogger.success('✅ Admin account creation test passed', tag: _tag);
      
      // Step 2: Test login
      AppLogger.info('🔐 Testing admin login...', tag: _tag);
      
      final auth = FirebaseAuth.instance;
      UserCredential? loginResult;
      
      try {
        loginResult = await auth.signInWithEmailAndPassword(
          email: 'admin@gmail.com',
          password: 'Admin@1234',
        );
        AppLogger.success('✅ Admin login test passed', tag: _tag);
      } catch (e) {
        AppLogger.error('❌ Admin login test failed', error: e, tag: _tag);
        return;
      }
      
      // Step 3: Verify Firestore data
      AppLogger.info('📄 Testing Firestore data...', tag: _tag);
      
      final userId = loginResult.user!.uid;
      final firestore = FirebaseFirestore.instance;
      
      try {
        final userDoc = await firestore.collection('users').doc(userId).get();
        
        if (!userDoc.exists) {
          AppLogger.error('❌ Admin user document not found in Firestore', tag: _tag);
          return;
        }
        
        final userData = userDoc.data()!;
        
        // Verify required fields
        final requiredFields = {
          'email': 'admin@gmail.com',
          'role': 'admin',
          'displayName': 'Administrator',
        };
        
        for (final entry in requiredFields.entries) {
          if (userData[entry.key] != entry.value) {
            AppLogger.error('❌ Field ${entry.key} mismatch. Expected: ${entry.value}, Got: ${userData[entry.key]}', tag: _tag);
            return;
          }
        }
        
        // Verify subscription
        final subscription = userData['subscription'] as Map<String, dynamic>?;
        if (subscription == null || subscription['status'] != 'active') {
          AppLogger.error('❌ Admin subscription not active', tag: _tag);
          return;
        }
        
        // Verify module access
        final moduleAccess = subscription['moduleAccess'] as List<dynamic>?;
        if (moduleAccess == null || !moduleAccess.contains('admin_drills')) {
          AppLogger.error('❌ Admin module access not configured properly', tag: _tag);
          return;
        }
        
        AppLogger.success('✅ Firestore data test passed', tag: _tag);
        
      } catch (e) {
        AppLogger.error('❌ Firestore data test failed', error: e, tag: _tag);
        return;
      }
      
      // Step 4: Sign out
      await auth.signOut();
      AppLogger.info('🔓 Signed out admin user', tag: _tag);
      
      AppLogger.success('🎉 All admin account tests passed!', tag: _tag);
      
    } catch (e) {
      AppLogger.error('❌ Admin account test failed', error: e, tag: _tag);
    }
  }
  
  /// Manually create admin account (for debugging)
  static Future<void> manuallyCreateAdminAccount() async {
    try {
      AppLogger.info('🔧 Manually creating admin account...', tag: _tag);
      
      final adminService = AdminAccountService();
      final result = await adminService.createAdminAccountIfNeeded();
      
      if (result.success) {
        AppLogger.success('✅ Manual admin account creation successful', tag: _tag);
        print('🎉 ADMIN ACCOUNT READY!');
        print('📧 Email: admin@gmail.com');
        print('🔑 Password: Admin@1234');
        print('🆔 User ID: ${result.userId}');
        
        // Verify account
        final isVerified = await adminService.verifyAdminAccount();
        if (isVerified) {
          print('✅ Account verified and ready for use');
        } else {
          print('⚠️ Account created but verification failed');
        }
        
      } else {
        AppLogger.error('❌ Manual admin account creation failed: ${result.message}', tag: _tag);
        print('❌ Failed to create admin account: ${result.message}');
      }
      
    } catch (e) {
      AppLogger.error('❌ Manual admin account creation error', error: e, tag: _tag);
      print('❌ Error: $e');
    }
  }
  
  /// Get admin account status
  static Future<void> getAdminAccountStatus() async {
    try {
      AppLogger.info('📊 Checking admin account status...', tag: _tag);
      
      final adminService = AdminAccountService();
      final details = await adminService.getAdminAccountDetails();
      
      if (details != null) {
        AppLogger.success('✅ Admin account found', tag: _tag);
        print('📊 ADMIN ACCOUNT STATUS:');
        print('🆔 ID: ${details['id']}');
        print('📧 Email: ${details['email']}');
        print('👤 Name: ${details['displayName']}');
        print('🎭 Role: ${details['role']}');
        print('📦 Subscription: ${details['subscription']?['plan']} (${details['subscription']?['status']})');
        print('📅 Created: ${details['createdAt']}');
        print('🕐 Last Active: ${details['lastActiveAt']}');
        
        final moduleAccess = details['subscription']?['moduleAccess'] as List<dynamic>?;
        if (moduleAccess != null) {
          print('🔑 Module Access: ${moduleAccess.join(', ')}');
        }
        
      } else {
        AppLogger.warning('⚠️ Admin account not found', tag: _tag);
        print('⚠️ Admin account not found in database');
      }
      
    } catch (e) {
      AppLogger.error('❌ Error checking admin account status', error: e, tag: _tag);
      print('❌ Error: $e');
    }
  }
  
  /// Reset admin account (delete and recreate)
  static Future<void> resetAdminAccount() async {
    try {
      AppLogger.info('🔄 Resetting admin account...', tag: _tag);
      
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      
      // Step 1: Find and delete existing admin account
      final adminQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: 'admin@gmail.com')
          .get();
      
      for (final doc in adminQuery.docs) {
        await doc.reference.delete();
        AppLogger.info('🗑️ Deleted admin document: ${doc.id}', tag: _tag);
      }
      
      // Step 2: Try to delete from Firebase Auth (if signed in)
      try {
        final loginResult = await auth.signInWithEmailAndPassword(
          email: 'admin@gmail.com',
          password: 'Admin@1234',
        );
        await loginResult.user!.delete();
        AppLogger.info('🗑️ Deleted admin from Firebase Auth', tag: _tag);
      } catch (e) {
        AppLogger.info('ℹ️ Could not delete from Firebase Auth (may not exist): $e', tag: _tag);
      }
      
      // Step 3: Create new admin account
      await manuallyCreateAdminAccount();
      
    } catch (e) {
      AppLogger.error('❌ Error resetting admin account', error: e, tag: _tag);
      print('❌ Error: $e');
    }
  }
}