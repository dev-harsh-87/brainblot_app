import 'package:equatable/equatable.dart';

/// Base class for all application errors
abstract class AppError extends Equatable {
  const AppError(this.message, [this.code]);
  
  final String message;
  final String? code;
  
  @override
  List<Object?> get props => [message, code];
}

/// Network-related errors
class NetworkError extends AppError {
  const NetworkError(super.message, [super.code]);
}

/// Authentication-related errors
class AuthError extends AppError {
  const AuthError(super.message, [super.code]);
}

/// Data persistence errors
class StorageError extends AppError {
  const StorageError(super.message, [super.code]);
}

/// Validation errors
class ValidationError extends AppError {
  const ValidationError(super.message, [super.code]);
}

/// Unknown/unexpected errors
class UnknownError extends AppError {
  const UnknownError(super.message, [super.code]);
}

/// Extension to convert exceptions to AppError
extension ExceptionToAppError on Exception {
  AppError toAppError() {
    if (this is AppError) return this as AppError;
    
    final message = toString();
    
    // Firebase Auth errors
    if (message.contains('firebase_auth')) {
      return AuthError(message, 'firebase_auth');
    }
    
    // Network errors
    if (message.contains('network') || 
        message.contains('connection') || 
        message.contains('timeout')) {
      return NetworkError(message, 'network');
    }
    
    // Storage errors
    if (message.contains('storage') || 
        message.contains('hive') || 
        message.contains('preferences')) {
      return StorageError(message, 'storage');
    }
    
    return UnknownError(message, 'unknown');
  }
}
