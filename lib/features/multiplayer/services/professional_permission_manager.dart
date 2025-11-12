import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import 'package:spark_app/core/utils/ios_permission_helper.dart';
import 'package:spark_app/core/services/enhanced_ios_permission_service.dart';

/// Professional permission management system for multiplayer features
/// Handles both iOS and Android permissions with platform-specific optimizations
class ProfessionalPermissionManager {
  static const String _tag = '🔐 PermissionManager';
  
  /// Required permissions for multiplayer functionality
  static final List<permission_handler.Permission> requiredPermissions = [
    permission_handler.Permission.bluetooth,
    permission_handler.Permission.locationWhenInUse,
    // Android 12+ specific Bluetooth permissions
    permission_handler.Permission.bluetoothScan,
    permission_handler.Permission.bluetoothConnect,
    permission_handler.Permission.bluetoothAdvertise,
    // Android 13+ nearby WiFi devices permission
    permission_handler.Permission.nearbyWifiDevices,
  ];

  /// Additional permissions for enhanced functionality
  static final List<permission_handler.Permission> optionalPermissions = [
    permission_handler.Permission.microphone, // For future voice features
  ];

  /// Private getter for backward compatibility
  static List<permission_handler.Permission> get _requiredPermissions => requiredPermissions;
  static List<permission_handler.Permission> get _optionalPermissions => optionalPermissions;

  /// Check if all required permissions are granted
  static Future<bool> areAllPermissionsGranted() async {
    try {
      debugPrint('$_tag Checking all required permissions...');
      
      final platformPermissions = _getPlatformSpecificPermissions();
      
      for (final permission in platformPermissions) {
        try {
          final status = await permission.status;
          debugPrint('$_tag ${permission.toString()}: $status');
          
          if (!status.isGranted) {
            debugPrint('$_tag Permission ${permission.toString()} not granted');
            return false;
          }
        } catch (e) {
          // Some permissions might not be available on certain Android versions
          debugPrint('$_tag Warning: Could not check ${permission.toString()}: $e');
          // For Android 12+ permissions, if they're not available, we assume they're not needed
          if (!_isAndroid12Permission(permission)) {
            return false;
          }
        }
      }
      
      debugPrint('$_tag ✅ All required permissions are granted');
      return true;
    } catch (e) {
      debugPrint('$_tag ❌ Error checking permissions: $e');
      return false;
    }
  }

  /// Get detailed permission status
  static Future<PermissionStatusReport> getPermissionStatus() async {
    final report = PermissionStatusReport();
    
    try {
      debugPrint('$_tag Generating detailed permission report...');
      
      // Check platform-specific required permissions
      final platformPermissions = _getPlatformSpecificPermissions();
      for (final permission in platformPermissions) {
        final status = await permission.status;
        report.permissions[permission] = status;
        
        debugPrint('$_tag   ${permission.toString()}: $status (isGranted: ${status.isGranted}, isDenied: ${status.isDenied}, isPermanentlyDenied: ${status.isPermanentlyDenied})');
        
        if (status.isGranted) {
          report.grantedPermissions.add(permission);
        } else if (status.isPermanentlyDenied) {
          report.permanentlyDeniedPermissions.add(permission);
        } else if (status.isDenied) {
          // On iOS, check if this permission was previously requested and denied
          // If so, it should be treated as permanently denied
          if (IOSPermissionHelper.isIOS) {
            // For iOS, if a permission is denied, we need to check if it can still be requested
            // If not, it's effectively permanently denied
            try {
              // On iOS, denied permissions often need Settings access
              // especially for Bluetooth and Location after first denial
              if (permission == permission_handler.Permission.bluetooth ||
                  permission == permission_handler.Permission.locationWhenInUse) {
                debugPrint('$_tag   iOS: Critical permission $permission is denied - likely needs Settings');
                // Treat critical denied permissions as effectively permanently denied on iOS
                report.permanentlyDeniedPermissions.add(permission);
              } else {
                report.deniedPermissions.add(permission);
              }
            } catch (e) {
              debugPrint('$_tag   Error checking iOS permission status: $e');
              report.deniedPermissions.add(permission);
            }
          } else {
            report.deniedPermissions.add(permission);
          }
        } else {
          // Handle other statuses (like restricted, limited, etc.)
          debugPrint('$_tag   Unhandled permission status: $status for $permission');
          report.deniedPermissions.add(permission);
        }
      }
      
      // Check optional permissions
      for (final permission in _optionalPermissions) {
        try {
          final status = await permission.status;
          report.permissions[permission] = status;
          
          if (status.isGranted) {
            report.grantedPermissions.add(permission);
          }
        } catch (e) {
          debugPrint('$_tag Optional permission ${permission.toString()} not available: $e');
        }
      }
      
      final requiredPlatformPermissions = _getPlatformSpecificPermissions();
      report.allRequiredGranted = requiredPlatformPermissions.every((p) => report.grantedPermissions.contains(p));
      report.hasPermissionIssues = report.permanentlyDeniedPermissions.isNotEmpty;
      
      debugPrint('$_tag Permission Report:');
      debugPrint('$_tag   Granted: ${report.grantedPermissions.length}');
      debugPrint('$_tag   Denied: ${report.deniedPermissions.length}');
      debugPrint('$_tag   Permanently Denied: ${report.permanentlyDeniedPermissions.length}');
      debugPrint('$_tag   All Required Granted: ${report.allRequiredGranted}');
      
      return report;
    } catch (e) {
      debugPrint('$_tag ❌ Error generating permission report: $e');
      report.error = e.toString();
      return report;
    }
  }

  /// Request permissions with professional flow
  static Future<PermissionRequestResult> requestPermissions({
    bool showRationale = true,
  }) async {
    try {
      debugPrint('$_tag Starting professional permission request flow...');
      
      // Use enhanced iOS permission service for iOS devices
      if (EnhancedIOSPermissionService.isIOS) {
        debugPrint('$_tag Using enhanced iOS permission service...');
        
        // Initialize the enhanced service first
        await EnhancedIOSPermissionService.initialize();
        
        final result = await EnhancedIOSPermissionService.requestPermissions(
          forceNativeDialog: showRationale,
          showRationale: showRationale,
        );
        
        final updatedStatus = await getPermissionStatus();
        
        // Create permanently denied list for iOS
        final permanentlyDenied = <permission_handler.Permission>[];
        if (result.needsSettings) {
          for (final permission in _requiredPermissions) {
            final status = await permission.status;
            if (!status.isGranted) {
              permanentlyDenied.add(permission);
            }
          }
        }
        
        return PermissionRequestResult(
          success: result.success,
          message: result.message,
          permissionStatus: updatedStatus,
          needsSettings: result.needsSettings,
          permanentlyDenied: permanentlyDenied,
        );
      }
      
      // Original flow for non-iOS devices
      // Add a small delay to ensure the app is fully loaded
      await Future.delayed(const Duration(milliseconds: 500));
      
      // First, get current status
      final currentStatus = await getPermissionStatus();
      
      // If all permissions are already granted, return success
      if (currentStatus.allRequiredGranted) {
        debugPrint('$_tag ✅ All permissions already granted');
        return PermissionRequestResult(
          success: true,
          message: 'All permissions are already granted',
          permissionStatus: currentStatus,
        );
      }
      
      // Check for permanently denied permissions BEFORE making the request
      if (currentStatus.permanentlyDeniedPermissions.isNotEmpty) {
        debugPrint('$_tag ⚠️ Found permanently denied permissions: ${currentStatus.permanentlyDeniedPermissions}');
        
        return PermissionRequestResult(
          success: false,
          message: 'Some permissions are permanently denied. Please enable them in Settings.',
          permissionStatus: currentStatus,
          needsSettings: true,
          permanentlyDenied: currentStatus.permanentlyDeniedPermissions,
        );
      }
      
      // Request permissions that are not granted (platform-specific)
      final platformPermissions = _getPlatformSpecificPermissions();
      final permissionsToRequest = platformPermissions
          .where((p) => !currentStatus.grantedPermissions.contains(p))
          .toList();
      
      if (permissionsToRequest.isEmpty) {
        debugPrint('$_tag ✅ No permissions need to be requested');
        return PermissionRequestResult(
          success: true,
          message: 'All required permissions are available',
          permissionStatus: currentStatus,
        );
      }
      
      debugPrint('$_tag 🔄 Requesting permissions: $permissionsToRequest');
      
      // Request permissions one by one to ensure proper dialog display
      final results = <permission_handler.Permission, permission_handler.PermissionStatus>{};
      
      for (final permission in permissionsToRequest) {
        try {
          debugPrint('$_tag 🔄 Requesting permission: $permission');
          final status = await permission.request();
          results[permission] = status;
          debugPrint('$_tag   Result for ${permission.toString()}: $status');
          
          // Add a small delay between requests to ensure proper dialog handling
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          debugPrint('$_tag ❌ Error requesting permission $permission: $e');
          results[permission] = permission_handler.PermissionStatus.denied;
        }
      }
      
      debugPrint('$_tag Permission request results:');
      results.forEach((permission, status) {
        debugPrint('$_tag   ${permission.toString()}: $status');
      });
      
      // Get updated status
      final updatedStatus = await getPermissionStatus();
      
      if (updatedStatus.allRequiredGranted) {
        debugPrint('$_tag ✅ All required permissions granted successfully');
        return PermissionRequestResult(
          success: true,
          message: 'All permissions granted successfully!',
          permissionStatus: updatedStatus,
        );
      } else {
        final deniedPermissions = updatedStatus.deniedPermissions
            .where((p) => _requiredPermissions.contains(p))
            .toList();
        
        final permanentlyDeniedPermissions = updatedStatus.permanentlyDeniedPermissions
            .where((p) => _requiredPermissions.contains(p))
            .toList();
        
        // Also check the raw request results for permanently denied permissions
        // This handles cases where the status check might not catch them
        final rawPermanentlyDenied = results.entries
            .where((entry) => entry.value == permission_handler.PermissionStatus.permanentlyDenied)
            .map((entry) => entry.key)
            .where((p) => _requiredPermissions.contains(p))
            .toList();
        
        // Combine both lists and remove duplicates
        final allPermanentlyDenied = <permission_handler.Permission>{
          ...permanentlyDeniedPermissions,
          ...rawPermanentlyDenied,
        }.toList();
        
        String message = 'Some required permissions were not granted:\n';
        
        for (final permission in deniedPermissions) {
          if (!allPermanentlyDenied.contains(permission)) {
            message += '• ${_getPermissionDisplayName(permission)}: Required for multiplayer features\n';
          }
        }
        
        for (final permission in allPermanentlyDenied) {
          message += '• ${_getPermissionDisplayName(permission)}: Required for multiplayer features\n';
        }
        
        debugPrint('$_tag ❌ Permission request incomplete: $message');
        
        final needsSettings = allPermanentlyDenied.isNotEmpty;
        debugPrint('$_tag needsSettings: $needsSettings (permanently denied: ${allPermanentlyDenied.length})');
        
        return PermissionRequestResult(
          success: false,
          message: message.trim(),
          permissionStatus: updatedStatus,
          needsSettings: needsSettings,
          permanentlyDenied: allPermanentlyDenied,
        );
      }
      
    } catch (e) {
      debugPrint('$_tag ❌ Error during permission request: $e');
      return PermissionRequestResult(
        success: false,
        message: 'Error requesting permissions: $e',
        permissionStatus: await getPermissionStatus(),
        error: e.toString(),
      );
    }
  }

  /// Open app settings
  static Future<bool> openAppSettings() async {
    try {
      debugPrint('$_tag Opening app settings...');
      final result = await permission_handler.openAppSettings();
      debugPrint('$_tag App settings opened: $result');
      return result;
    } catch (e) {
      debugPrint('$_tag ❌ Failed to open app settings: $e');
      return false;
    }
  }

  /// Reset permissions (for development/testing)
  static Future<void> resetPermissions() async {
    if (kDebugMode) {
      debugPrint('$_tag 🔄 Resetting permissions (debug mode only)...');
      // This is mainly for development - in production, users need to manually reset in Settings
      try {
        await openAppSettings();
      } catch (e) {
        debugPrint('$_tag ❌ Error resetting permissions: $e');
      }
    }
  }

  /// Get user-friendly permission name
  static String getPermissionDisplayName(permission_handler.Permission permission) {
    switch (permission) {
      case permission_handler.Permission.bluetooth:
        return 'Bluetooth';
      case permission_handler.Permission.locationWhenInUse:
        return 'Location';
      case permission_handler.Permission.microphone:
        return 'Microphone';
      case permission_handler.Permission.bluetoothScan:
        return 'Bluetooth Scan';
      case permission_handler.Permission.bluetoothConnect:
        return 'Bluetooth Connect';
      case permission_handler.Permission.bluetoothAdvertise:
        return 'Bluetooth Advertise';
      case permission_handler.Permission.nearbyWifiDevices:
        return 'Nearby WiFi Devices';
      default:
        return permission.toString().split('.').last;
    }
  }

  /// Private getter for backward compatibility
  static String _getPermissionDisplayName(permission_handler.Permission permission) => getPermissionDisplayName(permission);

  /// Get permission description for user
  static String getPermissionDescription(permission_handler.Permission permission) {
    switch (permission) {
      case permission_handler.Permission.bluetooth:
        return 'Required to connect with other devices for multiplayer training sessions';
      case permission_handler.Permission.locationWhenInUse:
        return 'Required to discover nearby devices (your location is not stored or shared)';
      case permission_handler.Permission.microphone:
        return 'Optional: For voice commands and communication features';
      case permission_handler.Permission.bluetoothScan:
        return 'Required to scan for nearby Bluetooth devices';
      case permission_handler.Permission.bluetoothConnect:
        return 'Required to connect to nearby Bluetooth devices';
      case permission_handler.Permission.bluetoothAdvertise:
        return 'Required to advertise your device to others';
      case permission_handler.Permission.nearbyWifiDevices:
        return 'Required to discover and connect to nearby devices for multiplayer sessions';
      default:
        return 'Required for app functionality';
    }
  }

  /// Check if permission is critical (required for core functionality)
  static bool isPermissionCritical(permission_handler.Permission permission) {
    return _requiredPermissions.contains(permission);
  }

  /// Get platform-specific permissions
  static List<permission_handler.Permission> _getPlatformSpecificPermissions() {
    if (IOSPermissionHelper.isIOS) {
      // iOS only needs Bluetooth and Location
      return [
        permission_handler.Permission.bluetooth,
        permission_handler.Permission.locationWhenInUse,
      ];
    } else {
      // Android needs all Bluetooth permissions and nearby WiFi devices
      return [
        permission_handler.Permission.bluetooth,
        permission_handler.Permission.locationWhenInUse,
        permission_handler.Permission.bluetoothScan,
        permission_handler.Permission.bluetoothConnect,
        permission_handler.Permission.bluetoothAdvertise,
        permission_handler.Permission.nearbyWifiDevices,
      ];
    }
  }

  /// Check if permission is Android 12+ specific
  static bool _isAndroid12Permission(permission_handler.Permission permission) {
    return [
      permission_handler.Permission.bluetoothScan,
      permission_handler.Permission.bluetoothConnect,
      permission_handler.Permission.bluetoothAdvertise,
      permission_handler.Permission.nearbyWifiDevices,
    ].contains(permission);
  }
}

/// Detailed permission status report
class PermissionStatusReport {
  final Map<permission_handler.Permission, permission_handler.PermissionStatus> permissions = {};
  final List<permission_handler.Permission> grantedPermissions = [];
  final List<permission_handler.Permission> deniedPermissions = [];
  final List<permission_handler.Permission> permanentlyDeniedPermissions = [];
  
  bool allRequiredGranted = false;
  bool hasPermissionIssues = false;
  String? error;

  @override
  String toString() {
    return 'PermissionStatusReport(granted: ${grantedPermissions.length}, denied: ${deniedPermissions.length}, permanentlyDenied: ${permanentlyDeniedPermissions.length}, allRequiredGranted: $allRequiredGranted)';
  }
}

/// Result of permission request operation
class PermissionRequestResult {
  final bool success;
  final String message;
  final PermissionStatusReport permissionStatus;
  final bool needsSettings;
  final List<permission_handler.Permission> permanentlyDenied;
  final String? error;

  const PermissionRequestResult({
    required this.success,
    required this.message,
    required this.permissionStatus,
    this.needsSettings = false,
    this.permanentlyDenied = const [],
    this.error,
  });

  @override
  String toString() {
    return 'PermissionRequestResult(success: $success, message: $message, needsSettings: $needsSettings)';
  }
}