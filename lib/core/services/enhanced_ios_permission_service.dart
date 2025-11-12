import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Enhanced iOS permission service that handles native permission dialogs properly
/// and provides comprehensive fallback strategies for iOS permission management
class EnhancedIOSPermissionService {
  static const String _tag = '🍎 Enhanced iOS Permissions';
  static const MethodChannel _channel = MethodChannel('spark_app/permissions');

  /// Check if we're running on iOS
  static bool get isIOS => Platform.isIOS;

  /// Initialize the permission service
  static Future<void> initialize() async {
    if (!isIOS) return;
    
    try {
      debugPrint('$_tag Initializing enhanced iOS permission service...');
      
      // Set up method channel for native iOS permission handling
      _channel.setMethodCallHandler(_handleMethodCall);
      
      debugPrint('$_tag Enhanced iOS permission service initialized');
    } catch (e) {
      debugPrint('$_tag ❌ Failed to initialize: $e');
    }
  }

  /// Handle method calls from native iOS
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'permissionStatusChanged':
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('$_tag Permission status changed: $data');
        return null;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }

  /// Request permissions with enhanced iOS handling
  static Future<IOSPermissionResult> requestPermissions({
    bool forceNativeDialog = false,
    bool showRationale = true,
  }) async {
    if (!isIOS) {
      return IOSPermissionResult(
        success: true,
        message: 'Not iOS - permissions handled by system',
        needsSettings: false,
        permissionsGranted: {},
        permissionsDenied: {},
      );
    }

    try {
      debugPrint('$_tag Starting enhanced iOS permission request...');
      debugPrint('$_tag Force native dialog: $forceNativeDialog');
      debugPrint('$_tag Show rationale: $showRationale');

      // Step 1: Check current permission status
      final currentStatus = await _getCurrentPermissionStatus();
      debugPrint('$_tag Current status: $currentStatus');

      // Step 2: If all permissions are granted, return success
      if (currentStatus['allGranted'] == true) {
        return IOSPermissionResult(
          success: true,
          message: 'All permissions already granted',
          needsSettings: false,
          permissionsGranted: Map<String, bool>.from((currentStatus['granted'] as Map?) ?? {}),
          permissionsDenied: {},
        );
      }

      // Step 3: Check if we need to go to Settings
      final needsSettings = await _checkIfNeedsSettings(currentStatus);
      if (needsSettings && !forceNativeDialog) {
        return IOSPermissionResult(
          success: false,
          message: _getSettingsMessage(),
          needsSettings: true,
          permissionsGranted: Map<String, bool>.from((currentStatus['granted'] as Map?) ?? {}),
          permissionsDenied: Map<String, bool>.from((currentStatus['denied'] as Map?) ?? {}),
        );
      }

      // Step 4: Try to request permissions with multiple strategies
      final requestResult = await _requestPermissionsWithStrategies(
        currentStatus,
        forceNativeDialog: forceNativeDialog,
      );

      // Step 5: Get final status after request
      final finalStatus = await _getCurrentPermissionStatus();
      debugPrint('$_tag Final status: $finalStatus');

      // Step 6: Determine result
      if (finalStatus['allGranted'] == true) {
        return IOSPermissionResult(
          success: true,
          message: 'All permissions granted successfully!',
          needsSettings: false,
          permissionsGranted: Map<String, bool>.from((finalStatus['granted'] as Map?) ?? {}),
          permissionsDenied: {},
        );
      } else {
        final stillNeedsSettings = await _checkIfNeedsSettings(finalStatus);
        return IOSPermissionResult(
          success: false,
          message: stillNeedsSettings ? _getSettingsMessage() : 'Some permissions were not granted',
          needsSettings: stillNeedsSettings,
          permissionsGranted: Map<String, bool>.from((finalStatus['granted'] as Map?) ?? {}),
          permissionsDenied: Map<String, bool>.from((finalStatus['denied'] as Map?) ?? {}),
        );
      }

    } catch (e) {
      debugPrint('$_tag ❌ Error requesting permissions: $e');
      return IOSPermissionResult(
        success: false,
        message: 'Permission request failed. Please enable permissions in iOS Settings.',
        needsSettings: true,
        permissionsGranted: {},
        permissionsDenied: {},
        error: e.toString(),
      );
    }
  }

  /// Get current permission status for all required permissions
  static Future<Map<String, dynamic>> _getCurrentPermissionStatus() async {
    final permissions = [
      Permission.bluetooth,
      Permission.locationWhenInUse,
    ];

    final granted = <String, bool>{};
    final denied = <String, bool>{};
    final permanentlyDenied = <String, bool>{};

    for (final permission in permissions) {
      try {
        final status = await permission.status;
        final permissionName = _getPermissionName(permission);
        
        if (status.isGranted) {
          granted[permissionName] = true;
        } else if (status.isPermanentlyDenied) {
          permanentlyDenied[permissionName] = true;
        } else if (status.isDenied) {
          denied[permissionName] = true;
        }
        
        debugPrint('$_tag $permissionName: $status');
      } catch (e) {
        debugPrint('$_tag Error checking ${_getPermissionName(permission)}: $e');
        denied[_getPermissionName(permission)] = true;
      }
    }

    final allGranted = granted.length == permissions.length;
    
    return {
      'allGranted': allGranted,
      'granted': granted,
      'denied': denied,
      'permanentlyDenied': permanentlyDenied,
    };
  }

  /// Check if we need to direct user to Settings
  static Future<bool> _checkIfNeedsSettings(Map<String, dynamic> status) async {
    final permanentlyDenied = Map<String, bool>.from((status['permanentlyDenied'] as Map?) ?? {});
    final denied = Map<String, bool>.from((status['denied'] as Map?) ?? {});
    
    // On iOS, if any critical permissions are permanently denied or denied after first request,
    // we typically need Settings access
    return permanentlyDenied.isNotEmpty || denied.isNotEmpty;
  }

  /// Request permissions using multiple strategies
  static Future<Map<String, dynamic>> _requestPermissionsWithStrategies(
    Map<String, dynamic> currentStatus, {
    required bool forceNativeDialog,
  }) async {
    final results = <String, dynamic>{};
    
    try {
      // Strategy 1: Try standard permission request
      debugPrint('$_tag Strategy 1: Standard permission request');
      final standardResult = await _requestPermissionsStandard();
      results['standard'] = standardResult;
      
      // Wait a bit for iOS to process
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Strategy 2: If standard failed and we're forcing native dialog, try alternative approach
      if (forceNativeDialog && !(standardResult['success'] as bool? ?? false)) {
        debugPrint('$_tag Strategy 2: Alternative permission request');
        final alternativeResult = await _requestPermissionsAlternative();
        results['alternative'] = alternativeResult;
      }
      
      // Strategy 3: Try one-by-one request if batch failed
      if (!(standardResult['success'] as bool? ?? false)) {
        debugPrint('$_tag Strategy 3: One-by-one permission request');
        final oneByOneResult = await _requestPermissionsOneByOne();
        results['oneByOne'] = oneByOneResult;
      }
      
    } catch (e) {
      debugPrint('$_tag ❌ Error in permission request strategies: $e');
      results['error'] = e.toString();
    }
    
    return results;
  }

  /// Standard permission request approach
  static Future<Map<String, dynamic>> _requestPermissionsStandard() async {
    try {
      final permissions = [Permission.bluetooth, Permission.locationWhenInUse];
      final results = <Permission, PermissionStatus>{};
      
      for (final permission in permissions) {
        final status = await permission.status;
        if (!status.isGranted && !status.isPermanentlyDenied) {
          debugPrint('$_tag Requesting ${_getPermissionName(permission)}...');
          final result = await permission.request();
          results[permission] = result;
          debugPrint('$_tag ${_getPermissionName(permission)} result: $result');
          
          // Add delay between requests
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
      
      return {'success': results.values.any((status) => status.isGranted), 'results': results};
    } catch (e) {
      debugPrint('$_tag ❌ Standard request failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Alternative permission request approach
  static Future<Map<String, dynamic>> _requestPermissionsAlternative() async {
    try {
      // Try requesting permissions with a different timing approach
      debugPrint('$_tag Trying alternative permission request timing...');
      
      final bluetoothStatus = await Permission.bluetooth.status;
      final locationStatus = await Permission.locationWhenInUse.status;
      
      final results = <String, PermissionStatus>{};
      
      if (!bluetoothStatus.isGranted && !bluetoothStatus.isPermanentlyDenied) {
        await Future.delayed(const Duration(milliseconds: 100));
        final result = await Permission.bluetooth.request();
        results['bluetooth'] = result;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (!locationStatus.isGranted && !locationStatus.isPermanentlyDenied) {
        await Future.delayed(const Duration(milliseconds: 100));
        final result = await Permission.locationWhenInUse.request();
        results['location'] = result;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      return {'success': results.values.any((status) => status.isGranted), 'results': results};
    } catch (e) {
      debugPrint('$_tag ❌ Alternative request failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// One-by-one permission request approach
  static Future<Map<String, dynamic>> _requestPermissionsOneByOne() async {
    try {
      debugPrint('$_tag Requesting permissions one by one with delays...');
      
      final results = <String, PermissionStatus>{};
      
      // Request Bluetooth first
      final bluetoothStatus = await Permission.bluetooth.status;
      if (!bluetoothStatus.isGranted && !bluetoothStatus.isPermanentlyDenied) {
        debugPrint('$_tag One-by-one: Requesting Bluetooth...');
        await Future.delayed(const Duration(milliseconds: 200));
        final result = await Permission.bluetooth.request();
        results['bluetooth'] = result;
        debugPrint('$_tag One-by-one: Bluetooth result: $result');
        await Future.delayed(const Duration(milliseconds: 1000)); // Longer delay
      }
      
      // Request Location second
      final locationStatus = await Permission.locationWhenInUse.status;
      if (!locationStatus.isGranted && !locationStatus.isPermanentlyDenied) {
        debugPrint('$_tag One-by-one: Requesting Location...');
        await Future.delayed(const Duration(milliseconds: 200));
        final result = await Permission.locationWhenInUse.request();
        results['location'] = result;
        debugPrint('$_tag One-by-one: Location result: $result');
        await Future.delayed(const Duration(milliseconds: 1000)); // Longer delay
      }
      
      return {'success': results.values.any((status) => status.isGranted), 'results': results};
    } catch (e) {
      debugPrint('$_tag ❌ One-by-one request failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get user-friendly permission name
  static String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.bluetooth:
        return 'Bluetooth';
      case Permission.locationWhenInUse:
        return 'Location';
      default:
        return permission.toString().split('.').last;
    }
  }

  /// Get Settings message with detailed instructions
  static String _getSettingsMessage() {
    return '''To enable permissions for multiplayer features:

📱 Method 1 - Direct Settings:
1. Tap "Open Settings" below
2. Look for "Spark" in the app list
3. Enable Bluetooth and Location permissions

🔧 Method 2 - If Spark is not in app list:
1. Go to Settings > Privacy & Security
2. Tap "Bluetooth" → Enable for Spark
3. Go back, tap "Location Services"
4. Enable Location Services (if off)
5. Find and enable "Spark"

🔄 Then return to Spark and try again

Note: iOS requires Location permission for Bluetooth device discovery. Your location is never stored or shared.''';
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

  /// Get detailed permission status for debugging
  static Future<Map<String, dynamic>> getDetailedStatus() async {
    if (!isIOS) return {'platform': 'not_ios'};

    try {
      final status = await _getCurrentPermissionStatus();
      
      // Add additional iOS-specific information
      status['platform'] = 'ios';
      status['iosVersion'] = Platform.operatingSystemVersion;
      status['timestamp'] = DateTime.now().toIso8601String();
      
      return status;
    } catch (e) {
      return {'error': e.toString(), 'platform': 'ios'};
    }
  }

  /// Check if all required permissions are granted
  static Future<bool> areAllPermissionsGranted() async {
    if (!isIOS) return true;
    
    try {
      final status = await _getCurrentPermissionStatus();
      return status['allGranted'] == true;
    } catch (e) {
      debugPrint('$_tag ❌ Error checking permissions: $e');
      return false;
    }
  }
}

/// Result of iOS permission request
class IOSPermissionResult {
  final bool success;
  final String message;
  final bool needsSettings;
  final Map<String, bool> permissionsGranted;
  final Map<String, bool> permissionsDenied;
  final String? error;

  const IOSPermissionResult({
    required this.success,
    required this.message,
    required this.needsSettings,
    required this.permissionsGranted,
    required this.permissionsDenied,
    this.error,
  });

  @override
  String toString() {
    return 'IOSPermissionResult(success: $success, needsSettings: $needsSettings, granted: ${permissionsGranted.length}, denied: ${permissionsDenied.length})';
  }
}