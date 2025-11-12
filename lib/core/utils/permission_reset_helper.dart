import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Helper to provide instructions for resetting iOS permissions
class PermissionResetHelper {
  static const String _tag = '🔄 Permission Reset';

  /// Get instructions for resetting iOS permissions
  static String getIOSPermissionResetInstructions() {
    return '''
🔧 iOS Permission Reset Instructions

If permissions are not working, follow these steps:

METHOD 1 - Reset App Permissions:
1. Delete the Spark app from your device
2. Restart your iPhone/iPad
3. Reinstall Spark from the App Store
4. When prompted, allow Bluetooth and Location permissions

METHOD 2 - Manual Settings:
1. Open iOS Settings
2. Go to Privacy & Security
3. Tap "Bluetooth" → Find Spark → Enable
4. Go back to Privacy & Security
5. Tap "Location Services" → Find Spark → Enable "While Using App"

METHOD 3 - App-Specific Settings:
1. Open iOS Settings
2. Scroll down and find "Spark" in the app list
3. Enable all permissions shown
4. Return to Spark and try again

If Spark doesn't appear in Settings, it means the app hasn't requested permissions yet. Try using the multiplayer feature first.
''';
  }

  /// Check if we should show reset instructions
  static bool shouldShowResetInstructions() {
    return Platform.isIOS;
  }

  /// Copy reset instructions to clipboard
  static Future<void> copyInstructionsToClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: getIOSPermissionResetInstructions()));
      debugPrint('$_tag Instructions copied to clipboard');
    } catch (e) {
      debugPrint('$_tag Failed to copy to clipboard: $e');
    }
  }

  /// Get quick fix message
  static String getQuickFixMessage() {
    if (Platform.isIOS) {
      return '''
🚀 Quick Fix for iOS:

The fastest way to fix permission issues:
1. Delete and reinstall the Spark app
2. Allow permissions when prompted
3. Multiplayer features will work immediately

This resets all permission states and ensures proper dialog display.
''';
    }
    return 'Permission issues detected. Please check app settings.';
  }
}