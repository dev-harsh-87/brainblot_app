import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';
import 'package:brainblot_app/core/auth/models/app_user.dart';
import 'package:brainblot_app/core/auth/services/permission_service.dart';
import 'package:brainblot_app/core/auth/services/session_management_service.dart';
import 'package:brainblot_app/core/utils/create_super_admin.dart';

/// Helper class for testing and verifying role-based functionality
class RoleTestHelper {
  static const String _testUserEmail = 'user@test.com';
  static const String _testUserPassword = 'Test@123456';
  
  /// Test the complete role-based system
  static Future<Map<String, dynamic>> testRoleBasedSystem() async {
    final results = <String, dynamic>{};
    
    try {
      print('🧪 Starting Role-Based System Test...');
      
      // Test 1: Create admin user
      results['admin_creation'] = await _testAdminCreation();
      
      // Test 2: Create regular user
      results['user_creation'] = await _testUserCreation();
      
      // Test 3: Test permission service
      results['permission_service'] = await _testPermissionService();
      
      // Test 4: Test session management
      results['session_management'] = await _testSessionManagement();
      
      // Test 5: Test role switching
      results['role_switching'] = await _testRoleSwitching();
      
      print('✅ Role-Based System Test Complete');
      return results;
      
    } catch (e) {
      print('❌ Role-Based System Test Failed: $e');
      results['error'] = e.toString();
      return results;
    }
  }
  
  /// Test admin user creation
  static Future<bool> _testAdminCreation() async {
    try {
      print('📝 Testing admin creation...');
      
      // Create admin using existing utility
      await CreateAdmin.create();
      
      // Verify admin exists
      final firestore = FirebaseFirestore.instance;
      final adminQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: 'admin@brainblot.com')
          .get();
      
      if (adminQuery.docs.isEmpty) {
        print('❌ Admin user not found in database');
        return false;
      }
      
      final adminData = adminQuery.docs.first.data();
      final adminRole = UserRole.fromString(adminData['role'] as String? ?? 'user');
      
      if (!adminRole.isAdmin()) {
        print('❌ Admin user does not have admin role');
        return false;
      }
      
      print('✅ Admin creation test passed');
      return true;
      
    } catch (e) {
      print('❌ Admin creation test failed: $e');
      return false;
    }
  }
  
  /// Test regular user creation
  static Future<bool> _testUserCreation() async {
    try {
      print('📝 Testing user creation...');
      
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      
      // Check if test user already exists
      try {
        await auth.signInWithEmailAndPassword(
          email: _testUserEmail,
          password: _testUserPassword,
        );
        print('✅ Test user already exists');
        await auth.signOut();
        return true;
      } catch (e) {
        // User doesn't exist, create them
      }
      
      // Create test user
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: _testUserEmail,
        password: _testUserPassword,
      );
      
      final userId = userCredential.user!.uid;
      
      // Create user document
      final testUser = AppUser(
        id: userId,
        email: _testUserEmail,
        displayName: 'Test User',
        role: UserRole.user,
        subscription: UserSubscription.free(),
        preferences: const UserPreferences(),
        stats: const UserStats(),
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await firestore
          .collection('users')
          .doc(userId)
          .set(testUser.toFirestore());
      
      await auth.signOut();
      
      print('✅ User creation test passed');
      return true;
      
    } catch (e) {
      print('❌ User creation test failed: $e');
      return false;
    }
  }
  
  /// Test permission service functionality
  static Future<bool> _testPermissionService() async {
    try {
      print('📝 Testing permission service...');
      
      final auth = FirebaseAuth.instance;
      final permissionService = PermissionService();
      
      // Test with admin user
      await auth.signInWithEmailAndPassword(
        email: 'admin@brainblot.com',
        password: 'Admin@123456',
      );
      
      // Wait for session to establish
      await Future.delayed(const Duration(seconds: 2));
      
      final isAdmin = await permissionService.isAdmin();
      if (!isAdmin) {
        print('❌ Permission service admin check failed');
        return false;
      }
      
      final adminRole = await permissionService.getCurrentUserRole();
      if (!adminRole.isAdmin()) {
        print('❌ Permission service role check failed');
        return false;
      }
      
      await auth.signOut();
      
      // Test with regular user
      await auth.signInWithEmailAndPassword(
        email: _testUserEmail,
        password: _testUserPassword,
      );
      
      // Wait for session to establish
      await Future.delayed(const Duration(seconds: 2));
      
      final isUser = await permissionService.isAdmin();
      if (isUser) {
        print('❌ Permission service user check failed');
        return false;
      }
      
      final userRole = await permissionService.getCurrentUserRole();
      if (userRole.isAdmin()) {
        print('❌ Permission service user role check failed');
        return false;
      }
      
      await auth.signOut();
      
      print('✅ Permission service test passed');
      return true;
      
    } catch (e) {
      print('❌ Permission service test failed: $e');
      return false;
    }
  }
  
  /// Test session management functionality
  static Future<bool> _testSessionManagement() async {
    try {
      print('📝 Testing session management...');
      
      final auth = FirebaseAuth.instance;
      final sessionService = SessionManagementService();
      
      // Test with admin login
      await auth.signInWithEmailAndPassword(
        email: 'admin@brainblot.com',
        password: 'Admin@123456',
      );
      
      // Wait for session to establish
      await Future.delayed(const Duration(seconds: 2));
      
      if (!sessionService.isLoggedIn()) {
        print('❌ Session management login check failed');
        return false;
      }
      
      if (!sessionService.isAdmin()) {
        print('❌ Session management admin check failed');
        return false;
      }
      
      final sessionFeatures = sessionService.getSessionFeatures();
      if (!(sessionFeatures['isAdmin'] as bool? ?? false)) {
        print('❌ Session features admin check failed');
        return false;
      }
      
      await auth.signOut();
      
      // Wait for session to clear
      await Future.delayed(const Duration(seconds: 1));
      
      if (sessionService.isLoggedIn()) {
        print('❌ Session management logout check failed');
        return false;
      }
      
      print('✅ Session management test passed');
      return true;
      
    } catch (e) {
      print('❌ Session management test failed: $e');
      return false;
    }
  }
  
  /// Test role switching functionality
  static Future<bool> _testRoleSwitching() async {
    try {
      print('📝 Testing role switching...');
      
      final auth = FirebaseAuth.instance;
      final permissionService = PermissionService();
      
      // Sign in as admin to test role updates
      await auth.signInWithEmailAndPassword(
        email: 'admin@brainblot.com',
        password: 'Admin@123456',
      );
      
      // Wait for session to establish
      await Future.delayed(const Duration(seconds: 2));
      
      // Get test user ID
      final firestore = FirebaseFirestore.instance;
      final testUserQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: _testUserEmail)
          .get();
      
      if (testUserQuery.docs.isEmpty) {
        print('❌ Test user not found for role switching test');
        return false;
      }
      
      final testUserId = testUserQuery.docs.first.id;
      
      // Test updating user role (admin can update others)
      await permissionService.updateUserRole(testUserId, UserRole.user);
      
      // Verify the role was updated
      await Future.delayed(const Duration(seconds: 1));
      final updatedRole = await permissionService.getUserRole(testUserId);
      
      if (updatedRole != UserRole.user) {
        print('❌ Role update verification failed');
        return false;
      }
      
      await auth.signOut();
      
      print('✅ Role switching test passed');
      return true;
      
    } catch (e) {
      print('❌ Role switching test failed: $e');
      return false;
    }
  }
  
  /// Get system status
  static Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      
      // Count users by role
      final usersSnapshot = await firestore.collection('users').get();
      final users = usersSnapshot.docs;
      
      final adminCount = users.where((doc) {
        final data = doc.data();
        final role = UserRole.fromString(data['role'] as String? ?? 'user');
        return role.isAdmin();
      }).length;
      
      final userCount = users.length - adminCount;
      
      return {
        'total_users': users.length,
        'admin_users': adminCount,
        'regular_users': userCount,
        'current_user': auth.currentUser?.email,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
  
  /// Print comprehensive system report
  static Future<void> printSystemReport() async {
    print('=' * 60);
    print('🛡️ ROLE-BASED SYSTEM REPORT');
    print('=' * 60);
    
    final status = await getSystemStatus();
    print('📊 System Status:');
    status.forEach((key, value) {
      print('   $key: $value');
    });
    
    print('\n🧪 Running System Tests...');
    final testResults = await testRoleBasedSystem();
    
    print('\n📋 Test Results:');
    testResults.forEach((key, value) {
      final status = value == true ? '✅' : (value == false ? '❌' : '⚠️');
      print('   $status $key: $value');
    });
    
    print('\n' + '=' * 60);
    print('📝 Admin Credentials:');
    print('   Email: admin@brainblot.com');
    print('   Password: Admin@123456');
    print('=' * 60);
  }
}