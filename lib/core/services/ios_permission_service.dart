import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Enhanced iOS permission service that handles the complex iOS permission flow
class IOSPermissionService {
  static const String _tag = '🍎 iOS Permission Service';

  /// Check if we're running on iOS
  static bool get isIOS => Platform.isIOS;

  /// Check if all required permissions are granted
  static Future<bool> arePermissionsGranted() async {
    if (!isIOS) return true;

    try {
      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;

      debugPrint('$_tag Permission status check:');
      debugPrint('$_tag   Bluetooth: $bluetoothStatus');
      debugPrint('$_tag   Location: $locationStatus');

      return bluetoothStatus.isGranted && locationStatus.isGranted;
    } catch (e) {
      debugPrint('$_tag ❌ Error checking permissions: $e');
      return false;
    }
  }

  /// Request permissions with proper iOS handling
  static Future<PermissionRequestResult> requestPermissions() async {
    if (!isIOS) {
      return PermissionRequestResult(
        success: true,
        message: 'Not iOS - permissions handled by system',
        needsSettings: false,
      );
    }

    try {
      debugPrint('$_tag Starting iOS permission request...');

      // Check current status
      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;

      debugPrint('$_tag Initial status:');
      debugPrint('$_tag   Bluetooth: $bluetoothStatus');
      debugPrint('$_tag   Location: $locationStatus');

      // If already granted, return success
      if (bluetoothStatus.isGranted && locationStatus.isGranted) {
        return PermissionRequestResult(
          success: true,
          message: 'All permissions already granted',
          needsSettings: false,
        );
      }

      // If permanently denied, direct to settings
      if (bluetoothStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied) {
        return PermissionRequestResult(
          success: false,
          message: 'Permissions permanently denied - please enable in iOS Settings',
          needsSettings: true,
        );
      }

      // If denied (but not permanently), they likely need Settings on iOS
      if (bluetoothStatus.isDenied || locationStatus.isDenied) {
        return PermissionRequestResult(
          success: false,
          message: 'Permissions denied - please enable in iOS Settings',
          needsSettings: true,
        );
      }

      // Try to request permissions that are not determined
      bool bluetoothGranted = bluetoothStatus.isGranted;
      bool locationGranted = locationStatus.isGranted;
      bool showedDialog = false;

      if (!bluetoothGranted && !bluetoothStatus.isDenied && !bluetoothStatus.isPermanentlyDenied) {
        debugPrint('$_tag Requesting Bluetooth permission...');
        try {
          final result = await Permission.bluetooth.request();
          bluetoothGranted = result.isGranted;
          showedDialog = true;
          debugPrint('$_tag Bluetooth request result: $result');
          
          // Wait for iOS to process the permission
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('$_tag Error requesting Bluetooth: $e');
        }
      }

      if (!locationGranted && !locationStatus.isDenied && !locationStatus.isPermanentlyDenied) {
        debugPrint('$_tag Requesting Location permission...');
        try {
          final result = await Permission.locationWhenInUse.request();
          locationGranted = result.isGranted;
          showedDialog = true;
          debugPrint('$_tag Location request result: $result');
          
          // Wait for iOS to process the permission
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('$_tag Error requesting Location: $e');
        }
      }

      // Check final status
      final finalBluetoothStatus = await Permission.bluetooth.status;
      final finalLocationStatus = await Permission.locationWhenInUse.status;

      debugPrint('$_tag Final status:');
      debugPrint('$_tag   Bluetooth: $finalBluetoothStatus');
      debugPrint('$_tag   Location: $finalLocationStatus');

      final allGranted = finalBluetoothStatus.isGranted && finalLocationStatus.isGranted;

      if (allGranted) {
        return PermissionRequestResult(
          success: true,
          message: 'All permissions granted successfully',
          needsSettings: false,
        );
      } else {
        // If we showed dialogs but permissions are still not granted,
        // or if permissions are in denied state, direct to Settings
        final needsSettings = showedDialog || 
                             finalBluetoothStatus.isDenied || 
                             finalLocationStatus.isDenied ||
                             finalBluetoothStatus.isPermanentlyDenied ||
                             finalLocationStatus.isPermanentlyDenied;

        return PermissionRequestResult(
          success: false,
          message: needsSettings 
              ? 'Please enable Bluetooth and Location permissions in iOS Settings'
              : 'Some permissions were not granted',
          needsSettings: needsSettings,
        );
      }

    } catch (e) {
      debugPrint('$_tag ❌ Error requesting permissions: $e');
      return PermissionRequestResult(
        success: false,
        message: 'Permission request failed - please enable in iOS Settings',
        needsSettings: true,
      );
    }
  }

  /// Get detailed permission status for debugging
  static Future<Map<String, dynamic>> getDetailedStatus() async {
    if (!isIOS) return {'platform': 'not_ios'};

    try {
      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;

      return {
        'platform': 'ios',
        'bluetooth': {
          'status': bluetoothStatus.toString(),
          'isGranted': bluetoothStatus.isGranted,
          'isDenied': bluetoothStatus.isDenied,
          'isPermanentlyDenied': bluetoothStatus.isPermanentlyDenied,
          'isUndetermined': !bluetoothStatus.isGranted && !bluetoothStatus.isDenied && !bluetoothStatus.isPermanentlyDenied,
        },
        'location': {
          'status': locationStatus.toString(),
          'isGranted': locationStatus.isGranted,
          'isDenied': locationStatus.isDenied,
          'isPermanentlyDenied': locationStatus.isPermanentlyDenied,
          'isUndetermined': !locationStatus.isGranted && !locationStatus.isDenied && !locationStatus.isPermanentlyDenied,
        },
        'allGranted': bluetoothStatus.isGranted && locationStatus.isGranted,
        'needsSettings': bluetoothStatus.isDenied || 
                        locationStatus.isDenied ||
                        bluetoothStatus.isPermanentlyDenied ||
                        locationStatus.isPermanentlyDenied,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Open iOS Settings
  static Future<bool> openSettings() async {
    try {
      debugPrint('$_tag Opening iOS Settings...');
      return await openAppSettings();
    } catch (e) {
      debugPrint('$_tag ❌ Failed to open Settings: $e');
      return false;
    }
  }

  /// Get user-friendly instructions for enabling permissions
  static String getSettingsInstructions() {
    return '''To enable permissions in iOS Settings:

1. Tap "Open Settings" below
2. Look for "Spark" in the app list
3. If you see it, enable any permissions shown

If Spark is not in the app list:
• Go to Settings > Privacy & Security
• Tap "Bluetooth" → Enable for Spark
• Go back, tap "Location Services"
• Enable Location for Spark
• Return to Spark and try again''';
  }
}

/// Result of iOS permission request
class PermissionRequestResult {
  final bool success;
  final String message;
  final bool needsSettings;

  const PermissionRequestResult({
    required this.success,
    required this.message,
    required this.needsSettings,
  });

  @override
  String toString() {
    return 'PermissionRequestResult(success: $success, needsSettings: $needsSettings, message: $message)';
  }
}