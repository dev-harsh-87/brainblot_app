import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Simple test script to verify permission handling
/// Run this with: dart run test_permissions.dart
void main() async {
  print('🧪 Testing Permission Handling...\n');
  
  if (Platform.isIOS) {
    await testIOSPermissions();
  } else if (Platform.isAndroid) {
    await testAndroidPermissions();
  } else {
    print('❌ Unsupported platform: ${Platform.operatingSystem}');
  }
}

Future<void> testIOSPermissions() async {
  print('🍎 Testing iOS Permissions...');
  
  try {
    // Test Bluetooth permission
    final bluetoothStatus = await Permission.bluetooth.status;
    print('📶 Bluetooth: $bluetoothStatus');
    
    // Test Location permission
    final locationStatus = await Permission.locationWhenInUse.status;
    print('📍 Location: $locationStatus');
    
    // Check if we can request permissions
    if (!bluetoothStatus.isGranted) {
      print('🔄 Requesting Bluetooth permission...');
      final result = await Permission.bluetooth.request();
      print('📶 Bluetooth result: $result');
    }
    
    if (!locationStatus.isGranted) {
      print('🔄 Requesting Location permission...');
      final result = await Permission.locationWhenInUse.request();
      print('📍 Location result: $result');
    }
    
    // Final status check
    final finalBluetooth = await Permission.bluetooth.status;
    final finalLocation = await Permission.locationWhenInUse.status;
    
    final allGranted = finalBluetooth.isGranted && finalLocation.isGranted;
    
    print('\n📊 Final iOS Status:');
    print('📶 Bluetooth: $finalBluetooth');
    print('📍 Location: $finalLocation');
    print('✅ All granted: $allGranted');
    
    if (!allGranted) {
      print('\n💡 To fix:');
      print('1. Go to Settings > Privacy & Security');
      print('2. Enable Bluetooth and Location for this app');
    }
    
  } catch (e) {
    print('❌ iOS Permission test failed: $e');
  }
}

Future<void> testAndroidPermissions() async {
  print('🤖 Testing Android Permissions...');
  
  final permissions = [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.locationWhenInUse,
  ];
  
  // Add nearbyWifiDevices if available
  try {
    permissions.add(Permission.nearbyWifiDevices);
    print('📱 Added nearbyWifiDevices permission');
  } catch (e) {
    print('📱 nearbyWifiDevices not available: $e');
  }
  
  try {
    print('\n🔍 Checking current status...');
    final statuses = <Permission, PermissionStatus>{};
    
    for (final permission in permissions) {
      try {
        final status = await permission.status;
        statuses[permission] = status;
        print('${_getPermissionIcon(permission)} ${_getPermissionName(permission)}: $status');
      } catch (e) {
        print('❌ Error checking ${_getPermissionName(permission)}: $e');
        statuses[permission] = PermissionStatus.denied;
      }
    }
    
    // Check for permanently denied
    final permanentlyDenied = statuses.entries
        .where((e) => e.value == PermissionStatus.permanentlyDenied)
        .map((e) => e.key)
        .toList();
    
    if (permanentlyDenied.isNotEmpty) {
      print('\n⚠️  Permanently denied permissions:');
      for (final p in permanentlyDenied) {
        print('  - ${_getPermissionName(p)}');
      }
      print('💡 Enable these in Settings > Apps > Permissions');
      return;
    }
    
    // Request missing permissions
    final toRequest = statuses.entries
        .where((e) => e.value != PermissionStatus.granted)
        .map((e) => e.key)
        .toList();
    
    if (toRequest.isNotEmpty) {
      print('\n🔄 Requesting ${toRequest.length} permissions...');
      try {
        final results = await toRequest.request();
        
        print('\n📊 Request Results:');
        results.forEach((permission, status) {
          statuses[permission] = status;
          print('${_getPermissionIcon(permission)} ${_getPermissionName(permission)}: $status');
        });
      } catch (e) {
        print('❌ Error requesting permissions: $e');
      }
    }
    
    // Final status
    final allGranted = statuses.values.every((s) => s == PermissionStatus.granted);
    
    print('\n📊 Final Android Status:');
    statuses.forEach((permission, status) {
      print('${_getPermissionIcon(permission)} ${_getPermissionName(permission)}: $status');
    });
    print('✅ All granted: $allGranted');
    
    if (!allGranted) {
      final denied = statuses.entries
          .where((e) => e.value != PermissionStatus.granted)
          .map((e) => _getPermissionName(e.key))
          .toList();
      
      print('\n💡 Missing permissions: ${denied.join(', ')}');
      print('Enable these in Settings > Apps > Permissions');
    }
    
  } catch (e) {
    print('❌ Android Permission test failed: $e');
  }
}

String _getPermissionIcon(Permission permission) {
  switch (permission) {
    case Permission.bluetooth:
      return '📶';
    case Permission.bluetoothScan:
      return '🔍';
    case Permission.bluetoothConnect:
      return '🔗';
    case Permission.bluetoothAdvertise:
      return '📡';
    case Permission.locationWhenInUse:
      return '📍';
    case Permission.nearbyWifiDevices:
      return '📱';
    default:
      return '❓';
  }
}

String _getPermissionName(Permission permission) {
  switch (permission) {
    case Permission.bluetooth:
      return 'Bluetooth';
    case Permission.bluetoothScan:
      return 'Bluetooth Scan';
    case Permission.bluetoothConnect:
      return 'Bluetooth Connect';
    case Permission.bluetoothAdvertise:
      return 'Bluetooth Advertise';
    case Permission.locationWhenInUse:
      return 'Location';
    case Permission.nearbyWifiDevices:
      return 'Nearby WiFi Devices';
    default:
      return permission.toString().split('.').last;
  }
}