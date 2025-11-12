import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Service to handle FCM token management and debugging
class FCMTokenService {
  static const String _tag = '🔔 FCM Token';
  static FCMTokenService? _instance;
  static FCMTokenService get instance => _instance ??= FCMTokenService._();
  
  FCMTokenService._();
  
  String? _currentToken;
  final StreamController<String?> _tokenController = StreamController<String?>.broadcast();
  
  /// Stream of FCM token changes
  Stream<String?> get tokenStream => _tokenController.stream;
  
  /// Get current FCM token
  String? get currentToken => _currentToken;
  
  /// Initialize FCM token service
  Future<void> initialize() async {
    try {
      debugPrint('$_tag Initializing FCM token service...');
      
      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        debugPrint('$_tag ✅ Token refreshed: ${token.substring(0, 20)}...');
        _currentToken = token;
        _tokenController.add(token);
      });
      
      // Get initial token with retry mechanism
      await _getInitialTokenWithRetry();
      
      debugPrint('$_tag FCM token service initialized');
    } catch (e) {
      debugPrint('$_tag ❌ Failed to initialize FCM token service: $e');
    }
  }
  
  /// Get initial FCM token with retry mechanism
  Future<void> _getInitialTokenWithRetry() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('$_tag Requesting initial FCM token (attempt $attempt/$maxRetries)...');
        
        final success = await _getInitialToken();
        if (success) {
          debugPrint('$_tag ✅ FCM token obtained successfully on attempt $attempt');
          return;
        }
        
        if (attempt < maxRetries) {
          debugPrint('$_tag ⏳ Retrying in ${retryDelay.inSeconds} seconds...');
          await Future.delayed(retryDelay);
        }
      } catch (e) {
        debugPrint('$_tag ❌ Attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }
    }
    
    debugPrint('$_tag ❌ Failed to get FCM token after $maxRetries attempts');
  }
  
  /// Get initial FCM token
  Future<bool> _getInitialToken() async {
    try {
      debugPrint('$_tag Requesting initial FCM token...');
      
      // Request permission first (for iOS)
      final settings = await FirebaseMessaging.instance.requestPermission(
        badge: true,
      );
      
      debugPrint('$_tag Notification permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // For iOS, wait a bit for APNS token to be available
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          debugPrint('$_tag iOS detected - waiting for APNS token...');
          await Future.delayed(const Duration(milliseconds: 1500));
          
          // Check if APNS token is available
          try {
            final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
            if (apnsToken != null) {
              debugPrint('$_tag ✅ APNS token is available: ${apnsToken.substring(0, 20)}...');
            } else {
              debugPrint('$_tag ⚠️ APNS token is not yet available - FCM token might fail');
            }
          } catch (e) {
            debugPrint('$_tag ⚠️ Error checking APNS token: $e');
          }
        }
        
        // Get the FCM token
        final token = await FirebaseMessaging.instance.getToken();
        
        if (token != null) {
          debugPrint('$_tag ✅ FCM token obtained: ${token.substring(0, 20)}...');
          _currentToken = token;
          _tokenController.add(token);
          return true;
        } else {
          debugPrint('$_tag ❌ FCM token is null');
          
          // For iOS, try additional strategies
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            return await _handleIOSTokenFailure();
          }
          
          return false;
        }
      } else {
        debugPrint('$_tag ❌ Notification permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('$_tag ❌ Error getting initial FCM token: $e');
      return false;
    }
  }
  
  /// Handle iOS-specific token failure scenarios
  Future<bool> _handleIOSTokenFailure() async {
    try {
      debugPrint('$_tag Handling iOS FCM token failure...');
      
      // Strategy 1: Wait longer for APNS token
      debugPrint('$_tag Strategy 1: Waiting longer for APNS token...');
      await Future.delayed(const Duration(seconds: 3));
      
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null) {
        debugPrint('$_tag ✅ APNS token now available: ${apnsToken.substring(0, 20)}...');
        
        // Try FCM token again
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          debugPrint('$_tag ✅ FCM token obtained after APNS wait: ${token.substring(0, 20)}...');
          _currentToken = token;
          _tokenController.add(token);
          return true;
        }
      }
      
      // Strategy 2: Delete and recreate token
      debugPrint('$_tag Strategy 2: Deleting and recreating FCM token...');
      try {
        await FirebaseMessaging.instance.deleteToken();
        await Future.delayed(const Duration(milliseconds: 1000));
        
        final newToken = await FirebaseMessaging.instance.getToken();
        if (newToken != null) {
          debugPrint('$_tag ✅ FCM token recreated: ${newToken.substring(0, 20)}...');
          _currentToken = newToken;
          _tokenController.add(newToken);
          return true;
        }
      } catch (e) {
        debugPrint('$_tag ❌ Token recreation failed: $e');
      }
      
      // Strategy 3: Check if this is a simulator issue
      debugPrint('$_tag Strategy 3: Checking for simulator/development issues...');
      debugPrint('$_tag ⚠️ FCM tokens may not work in iOS Simulator');
      debugPrint('$_tag ⚠️ Ensure you are testing on a physical iOS device');
      debugPrint('$_tag ⚠️ Ensure APNS certificates are properly configured');
      
      return false;
    } catch (e) {
      debugPrint('$_tag ❌ Error in iOS token failure handling: $e');
      return false;
    }
  }
  
  /// Manually refresh FCM token
  Future<String?> refreshToken() async {
    try {
      debugPrint('$_tag Manually refreshing FCM token...');
      await FirebaseMessaging.instance.deleteToken();
      await Future.delayed(const Duration(milliseconds: 500));
      final token = await FirebaseMessaging.instance.getToken();
      
      if (token != null) {
        debugPrint('$_tag ✅ Token refreshed: ${token.substring(0, 20)}...');
        _currentToken = token;
        _tokenController.add(token);
      } else {
        debugPrint('$_tag ❌ Failed to refresh token');
      }
      
      return token;
    } catch (e) {
      debugPrint('$_tag ❌ Error refreshing token: $e');
      return null;
    }
  }
  
  /// Get debug information about FCM/APNS status
  Future<Map<String, dynamic>> getDebugInfo() async {
    final info = <String, dynamic>{
      'platform': defaultTargetPlatform.toString(),
      'fcmToken': _currentToken,
      'fcmTokenLength': _currentToken?.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        info['apnsToken'] = apnsToken != null ? '${apnsToken.substring(0, 20)}...' : null;
        info['apnsTokenAvailable'] = apnsToken != null;
      } catch (e) {
        info['apnsError'] = e.toString();
      }
    }
    
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      info['notificationPermission'] = settings.authorizationStatus.toString();
    } catch (e) {
      info['permissionError'] = e.toString();
    }
    
    return info;
  }
  
  /// Dispose resources
  void dispose() {
    _tokenController.close();
  }
}