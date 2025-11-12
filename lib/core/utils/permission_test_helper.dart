import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spark_app/features/multiplayer/services/professional_permission_manager.dart';

/// Helper class for testing permission functionality
class PermissionTestHelper {
  static const String _tag = '🧪 PermissionTest';

  /// Test all multiplayer permissions
  static Future<void> testMultiplayerPermissions() async {
    debugPrint('$_tag Starting multiplayer permission test...');
    
    try {
      // Test 1: Check current permission status
      debugPrint('$_tag Test 1: Checking current permission status...');
      final currentStatus = await ProfessionalPermissionManager.getPermissionStatus();
      debugPrint('$_tag Current status: $currentStatus');
      
      // Test 2: Check if all permissions are granted
      debugPrint('$_tag Test 2: Checking if all permissions are granted...');
      final allGranted = await ProfessionalPermissionManager.areAllPermissionsGranted();
      debugPrint('$_tag All permissions granted: $allGranted');
      
      // Test 3: List required permissions
      debugPrint('$_tag Test 3: Required permissions:');
      for (final permission in ProfessionalPermissionManager.requiredPermissions) {
        final status = await permission.status;
        final displayName = ProfessionalPermissionManager.getPermissionDisplayName(permission);
        final description = ProfessionalPermissionManager.getPermissionDescription(permission);
        debugPrint('$_tag   $displayName: $status');
        debugPrint('$_tag     Description: $description');
      }
      
      // Test 4: Check platform-specific permissions
      debugPrint('$_tag Test 4: Platform-specific permissions check...');
      if (defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('$_tag Android platform detected');
        try {
          final nearbyWifiStatus = await Permission.nearbyWifiDevices.status;
          debugPrint('$_tag   Nearby WiFi Devices: $nearbyWifiStatus');
        } catch (e) {
          debugPrint('$_tag   Nearby WiFi Devices permission not available: $e');
        }
      } else {
        debugPrint('$_tag iOS platform detected');
      }
      
      debugPrint('$_tag ✅ Permission test completed successfully');
      
    } catch (e) {
      debugPrint('$_tag ❌ Permission test failed: $e');
    }
  }

  /// Test permission request flow
  static Future<void> testPermissionRequest() async {
    debugPrint('$_tag Starting permission request test...');
    
    try {
      final result = await ProfessionalPermissionManager.requestPermissions(
        showRationale: false, // Don't show dialogs during test
      );
      
      debugPrint('$_tag Permission request result:');
      debugPrint('$_tag   Success: ${result.success}');
      debugPrint('$_tag   Message: ${result.message}');
      debugPrint('$_tag   Needs Settings: ${result.needsSettings}');
      debugPrint('$_tag   Permanently Denied: ${result.permanentlyDenied.length}');
      
      if (result.permanentlyDenied.isNotEmpty) {
        debugPrint('$_tag   Permanently denied permissions:');
        for (final permission in result.permanentlyDenied) {
          final displayName = ProfessionalPermissionManager.getPermissionDisplayName(permission);
          debugPrint('$_tag     - $displayName');
        }
      }
      
      debugPrint('$_tag ✅ Permission request test completed');
      
    } catch (e) {
      debugPrint('$_tag ❌ Permission request test failed: $e');
    }
  }

  /// Print detailed permission report
  static Future<void> printPermissionReport() async {
    debugPrint('$_tag 📋 DETAILED PERMISSION REPORT');
    debugPrint('$_tag ================================');
    
    try {
      final report = await ProfessionalPermissionManager.getPermissionStatus();
      
      debugPrint('$_tag Overall Status:');
      debugPrint('$_tag   All Required Granted: ${report.allRequiredGranted}');
      debugPrint('$_tag   Has Permission Issues: ${report.hasPermissionIssues}');
      debugPrint('$_tag   Error: ${report.error ?? 'None'}');
      
      debugPrint('$_tag');
      debugPrint('$_tag Granted Permissions (${report.grantedPermissions.length}):');
      for (final permission in report.grantedPermissions) {
        final displayName = ProfessionalPermissionManager.getPermissionDisplayName(permission);
        debugPrint('$_tag   ✅ $displayName');
      }
      
      debugPrint('$_tag');
      debugPrint('$_tag Denied Permissions (${report.deniedPermissions.length}):');
      for (final permission in report.deniedPermissions) {
        final displayName = ProfessionalPermissionManager.getPermissionDisplayName(permission);
        debugPrint('$_tag   ❌ $displayName');
      }
      
      debugPrint('$_tag');
      debugPrint('$_tag Permanently Denied Permissions (${report.permanentlyDeniedPermissions.length}):');
      for (final permission in report.permanentlyDeniedPermissions) {
        final displayName = ProfessionalPermissionManager.getPermissionDisplayName(permission);
        debugPrint('$_tag   🚫 $displayName');
      }
      
      debugPrint('$_tag ================================');
      
    } catch (e) {
      debugPrint('$_tag ❌ Failed to generate permission report: $e');
    }
  }

  /// Quick permission check for debugging
  static Future<bool> quickPermissionCheck() async {
    try {
      final allGranted = await ProfessionalPermissionManager.areAllPermissionsGranted();
      debugPrint('$_tag Quick check - All permissions granted: $allGranted');
      
      if (!allGranted) {
        debugPrint('$_tag Missing permissions detected - run printPermissionReport() for details');
      }
      
      return allGranted;
    } catch (e) {
      debugPrint('$_tag Quick permission check failed: $e');
      return false;
    }
  }
}