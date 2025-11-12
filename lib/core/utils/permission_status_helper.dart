import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper to provide user-friendly permission status messages
class PermissionStatusHelper {
  static const String _tag = '📋 Permission Status';

  /// Get user-friendly explanation of current permission status
  static Future<String> getStatusExplanation() async {
    try {
      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;

      debugPrint('$_tag Bluetooth: $bluetoothStatus, Location: $locationStatus');

      if (bluetoothStatus.isGranted && locationStatus.isGranted) {
        return '✅ All permissions granted! Multiplayer features are ready to use.';
      }

      if (bluetoothStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied) {
        return '''❌ Permissions Required

Multiplayer features need Bluetooth and Location permissions.

On iOS, once permissions are denied, they must be enabled manually:

1. Open iOS Settings
2. Find "Spark" in the app list
3. Enable Bluetooth and Location permissions
4. Return to Spark and try again

If Spark is not in Settings:
• Go to Settings > Privacy & Security
• Tap "Bluetooth" → Enable for Spark
• Go back, tap "Location Services" → Enable for Spark''';
      }

      if (bluetoothStatus.isDenied || locationStatus.isDenied) {
        return '''🔐 Permissions Needed

Multiplayer features require:
• Bluetooth: To connect with other devices
• Location: Required by iOS for Bluetooth discovery

Tap "Request Permissions" to continue.''';
      }

      return 'Checking permissions...';
    } catch (e) {
      debugPrint('$_tag Error getting status explanation: $e');
      return 'Unable to check permission status. Please try again.';
    }
  }

  /// Check if user should be directed to Settings
  static Future<bool> shouldOpenSettings() async {
    try {
      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;
      
      return bluetoothStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied;
    } catch (e) {
      debugPrint('$_tag Error checking if should open settings: $e');
      return false;
    }
  }

  /// Get simple status for UI display
  static Future<String> getSimpleStatus() async {
    try {
      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;

      if (bluetoothStatus.isGranted && locationStatus.isGranted) {
        return 'Ready ✅';
      }

      if (bluetoothStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied) {
        return 'Settings Required ⚙️';
      }

      return 'Permissions Needed 🔐';
    } catch (e) {
      return 'Unknown Status ❓';
    }
  }

  /// Get detailed status breakdown
  static Future<Map<String, String>> getDetailedStatus() async {
    final result = <String, String>{};
    
    try {
      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;

      result['bluetooth'] = _getStatusEmoji(bluetoothStatus);
      result['location'] = _getStatusEmoji(locationStatus);
      result['overall'] = await getSimpleStatus();
      
      return result;
    } catch (e) {
      result['error'] = e.toString();
      return result;
    }
  }

  static String _getStatusEmoji(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '✅ Granted';
      case PermissionStatus.denied:
        return '❌ Denied';
      case PermissionStatus.permanentlyDenied:
        return '⚙️ Settings Required';
      case PermissionStatus.restricted:
        return '🚫 Restricted';
      case PermissionStatus.limited:
        return '⚠️ Limited';
      case PermissionStatus.provisional:
        return '🔶 Provisional';
      default:
        return '❓ Unknown';
    }
  }
}