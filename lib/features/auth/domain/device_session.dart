import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a device session for multi-device management
class DeviceSession extends Equatable {
  final String userId;
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final String platform;
  final String appVersion;
  final String? fcmToken;
  final DateTime loginTime;
  final DateTime lastActiveTime;
  final bool isActive;
  final bool isCurrentDevice;

  const DeviceSession({
    required this.userId,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.platform,
    required this.appVersion,
    this.fcmToken,
    required this.loginTime,
    required this.lastActiveTime,
    required this.isActive,
    this.isCurrentDevice = false,
  });

  /// Create DeviceSession from Firestore document
  factory DeviceSession.fromFirestore(DocumentSnapshot doc, {bool isCurrentDevice = false}) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DeviceSession(
      userId: (data['userId'] as String?) ?? '',
      deviceId: (data['deviceId'] as String?) ?? '',
      deviceName: (data['deviceName'] as String?) ?? 'Unknown Device',
      deviceType: (data['deviceType'] as String?) ?? 'Unknown',
      platform: (data['platform'] as String?) ?? 'Unknown',
      appVersion: (data['appVersion'] as String?) ?? '1.0.0',
      fcmToken: data['fcmToken'] as String?,
      loginTime: (data['loginTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveTime: (data['lastActiveTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: (data['isActive'] as bool?) ?? false,
      isCurrentDevice: isCurrentDevice,
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'platform': platform,
      'appVersion': appVersion,
      'fcmToken': fcmToken,
      'loginTime': Timestamp.fromDate(loginTime),
      'lastActiveTime': Timestamp.fromDate(lastActiveTime),
      'isActive': isActive,
    };
  }

  /// Get device icon based on platform
  String get deviceIcon {
    switch (platform.toLowerCase()) {
      case 'android':
        return '📱';
      case 'ios':
        return '📱';
      case 'web':
        return '💻';
      case 'windows':
        return '🖥️';
      case 'macos':
        return '🖥️';
      case 'linux':
        return '🖥️';
      default:
        return '📱';
    }
  }

  /// Get formatted last active time
  String get formattedLastActive {
    final now = DateTime.now();
    final difference = now.difference(lastActiveTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Get formatted login time
  String get formattedLoginTime {
    final now = DateTime.now();
    final difference = now.difference(loginTime);

    if (difference.inDays == 0) {
      return 'Today at ${loginTime.hour.toString().padLeft(2, '0')}:${loginTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${loginTime.hour.toString().padLeft(2, '0')}:${loginTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${loginTime.day}/${loginTime.month}/${loginTime.year}';
    }
  }

  /// Check if device is online (active within last 5 minutes)
  bool get isOnline {
    final now = DateTime.now();
    final difference = now.difference(lastActiveTime);
    return difference.inMinutes < 5 && isActive;
  }

  /// Copy with method
  DeviceSession copyWith({
    String? userId,
    String? deviceId,
    String? deviceName,
    String? deviceType,
    String? platform,
    String? appVersion,
    String? fcmToken,
    DateTime? loginTime,
    DateTime? lastActiveTime,
    bool? isActive,
    bool? isCurrentDevice,
  }) {
    return DeviceSession(
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      platform: platform ?? this.platform,
      appVersion: appVersion ?? this.appVersion,
      fcmToken: fcmToken ?? this.fcmToken,
      loginTime: loginTime ?? this.loginTime,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      isActive: isActive ?? this.isActive,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        deviceId,
        deviceName,
        deviceType,
        platform,
        appVersion,
        fcmToken,
        loginTime,
        lastActiveTime,
        isActive,
        isCurrentDevice,
      ];
}