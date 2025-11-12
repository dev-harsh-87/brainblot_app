import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Workaround for iOS permission issues
/// This handles the case where iOS permissions are immediately denied
class IOSPermissionWorkaround {
  static const String _tag = '🔧 iOS Permission Fix';

  /// Check if we're on iOS
  static bool get isIOS => Platform.isIOS;

  /// Handle iOS permission request with proper fallback
  static Future<Map<String, dynamic>> handlePermissionRequest() async {
    if (!isIOS) {
      return {'success': true, 'needsSettings': false, 'message': 'Not iOS'};
    }

    try {
      debugPrint('$_tag Starting iOS permission workaround...');

      // Check current status
      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;

      debugPrint('$_tag Initial - Bluetooth: $bluetoothStatus, Location: $locationStatus');

      // If already granted, return success
      if (bluetoothStatus.isGranted && locationStatus.isGranted) {
        return {
          'success': true,
          'needsSettings': false,
          'message': 'All permissions already granted'
        };
      }

      // If permanently denied, direct to settings
      if (bluetoothStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied) {
        return {
          'success': false,
          'needsSettings': true,
          'message': 'Permissions permanently denied - please enable in iOS Settings'
        };
      }

      // Try to request permissions with proper iOS handling
      bool bluetoothGranted = bluetoothStatus.isGranted;
      bool locationGranted = locationStatus.isGranted;
      bool showedPermissionDialog = false;

      if (!bluetoothGranted) {
        debugPrint('$_tag Requesting Bluetooth...');
        try {
          final result = await Permission.bluetooth.request();
          bluetoothGranted = result.isGranted;
          showedPermissionDialog = true;
          debugPrint('$_tag Bluetooth result: $result');
          
          // Add delay to ensure iOS processes the permission properly
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('$_tag Error requesting Bluetooth permission: $e');
        }
      }

      if (!locationGranted) {
        debugPrint('$_tag Requesting Location...');
        try {
          final result = await Permission.locationWhenInUse.request();
          locationGranted = result.isGranted;
          showedPermissionDialog = true;
          debugPrint('$_tag Location result: $result');
          
          // Add delay to ensure iOS processes the permission properly
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('$_tag Error requesting Location permission: $e');
        }
      }

      // Check final status after a brief delay
      await Future.delayed(const Duration(milliseconds: 300));
      final finalBluetoothStatus = await Permission.bluetooth.status;
      final finalLocationStatus = await Permission.locationWhenInUse.status;

      debugPrint('$_tag Final - Bluetooth: $finalBluetoothStatus, Location: $finalLocationStatus');

      final allGranted = finalBluetoothStatus.isGranted && finalLocationStatus.isGranted;
      final anyPermanentlyDenied = finalBluetoothStatus.isPermanentlyDenied || finalLocationStatus.isPermanentlyDenied;

      if (allGranted) {
        return {
          'success': true,
          'needsSettings': false,
          'message': 'All permissions granted successfully'
        };
      } else if (anyPermanentlyDenied) {
        return {
          'success': false,
          'needsSettings': true,
          'message': 'Permissions permanently denied - please enable in iOS Settings'
        };
      } else if (showedPermissionDialog && (!allGranted && (finalBluetoothStatus.isDenied || finalLocationStatus.isDenied))) {
        // On iOS, if we showed a permission dialog and permissions are still denied,
        // they likely need to be enabled in Settings
        return {
          'success': false,
          'needsSettings': true,
          'message': '''Multiplayer features require Bluetooth and Location permissions.

To enable them:
1. Open iOS Settings
2. Scroll down and find "Spark"
3. Enable Bluetooth and Location permissions
4. Return to Spark and try again

If Spark is not in the app list:
• Go to Settings > Privacy & Security > Bluetooth
• Enable for Spark
• Go to Settings > Privacy & Security > Location Services
• Enable for Spark'''
        };
      } else if (!showedPermissionDialog) {
        // If no permission dialog was shown, permissions might already be in a denied state
        // that requires Settings access
        return {
          'success': false,
          'needsSettings': true,
          'message': 'Permissions need to be enabled in iOS Settings'
        };
      } else {
        return {
          'success': false,
          'needsSettings': false,
          'message': 'Some permissions were not granted'
        };
      }

    } catch (e) {
      debugPrint('$_tag ❌ Error in permission workaround: $e');
      return {
        'success': false,
        'needsSettings': true,
        'message': 'Permission request failed. Please enable permissions in iOS Settings.'
      };
    }
  }
}