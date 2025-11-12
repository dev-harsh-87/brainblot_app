import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// iOS-specific permission helper to handle the unique iOS permission flow
class IOSPermissionHelper {
  static const String _tag = '🍎 iOS Permissions';

  /// Check if we're running on iOS
  static bool get isIOS => Platform.isIOS;

  /// Handle iOS-specific permission request flow
  static Future<bool> requestIOSPermissions() async {
    if (!isIOS) return true;

    try {
      debugPrint('$_tag Starting iOS permission request flow...');

      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;

      debugPrint('$_tag Current status - Bluetooth: $bluetoothStatus, Location: $locationStatus');

      // If permissions are already granted, we're good
      if (bluetoothStatus.isGranted && locationStatus.isGranted) {
        debugPrint('$_tag ✅ All permissions already granted');
        return true;
      }

      // If any permissions are permanently denied, we can't request them
      if (bluetoothStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied) {
        debugPrint('$_tag ⚠️ Some permissions are permanently denied - user must enable in Settings');
        return false;
      }

      // On iOS, if permissions are denied, they often need Settings access
      // especially after the first denial
      if (bluetoothStatus.isDenied || locationStatus.isDenied) {
        debugPrint('$_tag ⚠️ Permissions are denied - likely need Settings access on iOS');
        return false;
      }

      // Request permissions that are not determined yet
      bool allGranted = true;
      bool requestedAny = false;

      if (!bluetoothStatus.isGranted && bluetoothStatus != PermissionStatus.denied) {
        debugPrint('$_tag 🔄 Requesting Bluetooth permission...');
        try {
          final result = await Permission.bluetooth.request();
          requestedAny = true;
          debugPrint('$_tag Bluetooth result: $result');
          if (!result.isGranted) {
            allGranted = false;
            debugPrint('$_tag ⚠️ Bluetooth permission not granted: $result');
          }
          // Add delay after permission request
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('$_tag ❌ Error requesting Bluetooth: $e');
          allGranted = false;
        }
      }

      if (!locationStatus.isGranted && locationStatus != PermissionStatus.denied) {
        debugPrint('$_tag 🔄 Requesting Location permission...');
        try {
          final result = await Permission.locationWhenInUse.request();
          requestedAny = true;
          debugPrint('$_tag Location result: $result');
          if (!result.isGranted) {
            allGranted = false;
            debugPrint('$_tag ⚠️ Location permission not granted: $result');
          }
          // Add delay after permission request
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('$_tag ❌ Error requesting Location: $e');
          allGranted = false;
        }
      }

      // If we didn't request any permissions and they're not granted,
      // they likely need Settings access
      if (!requestedAny && (!bluetoothStatus.isGranted || !locationStatus.isGranted)) {
        debugPrint('$_tag ⚠️ No permissions requested but some not granted - likely need Settings');
        return false;
      }

      debugPrint('$_tag Final result - All granted: $allGranted');
      return allGranted;

    } catch (e) {
      debugPrint('$_tag ❌ Error requesting iOS permissions: $e');
      return false;
    }
  }

  /// Check if permissions need to be requested through Settings
  static Future<bool> needsSettingsForPermissions() async {
    if (!isIOS) return false;

    try {
      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;

      // On iOS, if permissions are denied and we've already tried to request them,
      // they are effectively permanently denied
      final bluetoothPermanent = bluetoothStatus.isPermanentlyDenied ||
          (bluetoothStatus.isDenied && await _hasBeenRequestedBefore(Permission.bluetooth));
      final locationPermanent = locationStatus.isPermanentlyDenied ||
          (locationStatus.isDenied && await _hasBeenRequestedBefore(Permission.locationWhenInUse));

      debugPrint('$_tag Bluetooth permanent: $bluetoothPermanent, Location permanent: $locationPermanent');
      
      return bluetoothPermanent || locationPermanent;
    } catch (e) {
      debugPrint('$_tag ❌ Error checking permission status: $e');
      return false;
    }
  }

  /// Check if a permission has been requested before (iOS specific)
  static Future<bool> _hasBeenRequestedBefore(Permission permission) async {
    try {
      // On iOS, if a permission is denied but not permanently denied,
      // and we try to request it again, it will immediately become permanently denied
      // This is a heuristic to detect if we've already requested it
      final status = await permission.status;
      
      // If it's denied but not permanently denied, we assume it might have been requested
      // This is because iOS typically shows permanently denied after the first denial
      return status.isDenied && !status.isPermanentlyDenied;
    } catch (e) {
      debugPrint('$_tag Error checking if permission was requested before: $e');
      return false;
    }
  }

  /// Get user-friendly permission status message
  static Future<String> getPermissionStatusMessage() async {
    if (!isIOS) return 'Permissions ready';

    try {
      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;

      if (bluetoothStatus.isGranted && locationStatus.isGranted) {
        return 'All permissions granted ✅';
      }

      if (bluetoothStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied) {
        return 'Permissions denied - please enable in iOS Settings';
      }

      if (bluetoothStatus.isDenied || locationStatus.isDenied) {
        return 'Permissions required for multiplayer features';
      }

      return 'Checking permissions...';
    } catch (e) {
      return 'Permission check failed';
    }
  }
}