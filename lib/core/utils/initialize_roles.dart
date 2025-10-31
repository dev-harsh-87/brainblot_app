import 'package:brainblot_app/core/utils/role_test_helper.dart';
import 'package:brainblot_app/core/utils/create_super_admin.dart';

/// Initialize and test the role-based system
class InitializeRoles {
  /// Setup the complete role-based system
  static Future<void> setupRoleBasedSystem() async {
    print('🚀 Initializing Role-Based System...');
    
    try {
      // Step 1: Create admin user
      print('\n📝 Step 1: Creating admin user...');
      await CreateAdmin.create();
      
      // Step 2: Print system report
      print('\n📊 Step 2: Generating system report...');
      await RoleTestHelper.printSystemReport();
      
      print('\n✅ Role-Based System Initialization Complete!');
      print('\n🎯 Next Steps:');
      print('   1. Login with admin credentials');
      print('   2. Navigate to /admin to access admin panel');
      print('   3. Create regular users and test role-based features');
      
    } catch (e) {
      print('\n❌ Role-Based System Initialization Failed: $e');
      rethrow;
    }
  }
  
  /// Quick test of role functionality
  static Future<bool> quickRoleTest() async {
    try {
      final results = await RoleTestHelper.testRoleBasedSystem();
      
      // Check if all tests passed
      bool allPassed = true;
      for (final result in results.values) {
        if (result != true) {
          allPassed = false;
          break;
        }
      }
      
      if (allPassed) {
        print('✅ All role-based tests passed!');
      } else {
        print('⚠️ Some role-based tests failed. Check the output above.');
      }
      
      return allPassed;
    } catch (e) {
      print('❌ Role test failed: $e');
      return false;
    }
  }
}