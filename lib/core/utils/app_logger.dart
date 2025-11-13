import 'package:flutter/foundation.dart';

/// Professional logging utility for the application
/// Only logs in debug mode, silent in production
class AppLogger {
  static const String _prefix = '🔷 Spark';
  
  /// Log info messages (general information)
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final tagPrefix = tag != null ? '[$tag]' : '';
      print('$_prefix ℹ️ $tagPrefix $message');
    }
  }
  
  /// Log success messages
  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      final tagPrefix = tag != null ? '[$tag]' : '';
      print('$_prefix ✅ $tagPrefix $message');
    }
  }
  
  /// Log warning messages
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      final tagPrefix = tag != null ? '[$tag]' : '';
      print('$_prefix ⚠️ $tagPrefix $message');
    }
  }
  
  /// Log error messages (always logged, even in production)
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final tagPrefix = tag != null ? '[$tag]' : '';
    print('$_prefix ❌ $tagPrefix $message');
    if (error != null) {
      print('Error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      print('Stack trace: $stackTrace');
    }
  }
  
  /// Log debug messages (only in debug mode, for detailed debugging)
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      final tagPrefix = tag != null ? '[$tag]' : '';
      print('$_prefix 🔍 $tagPrefix $message');
    }
  }
}