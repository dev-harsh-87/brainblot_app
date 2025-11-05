import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spark_app/core/error/app_error.dart';

/// Utility functions for BLoC operations
class BlocUtils {
  /// Safe execution wrapper that handles exceptions and converts them to AppError
  static Future<T> safeExecute<T>(
    Future<T> Function() operation, {
    T? fallback,
  }) async {
    try {
      return await operation();
    } catch (e) {
      if (e is Exception) {
        throw e.toAppError();
      }
      throw UnknownError(e.toString());
    }
  }

  /// Execute operation with error handling for BLoC events
  static Future<void> executeWithErrorHandling<State>(
    Future<void> Function() operation,
    Emitter<State> emit,
    State Function(AppError error) errorStateBuilder,
  ) async {
    try {
      await operation();
    } catch (e) {
      final error = e is AppError ? e : UnknownError(e.toString());
      emit(errorStateBuilder(error));
    }
  }

  /// Debounce utility for search and input operations
  static void debounce<T>(
    T value,
    Duration delay,
    void Function(T) callback,
    Map<String, dynamic> debounceMap,
    String key,
  ) {
    if (debounceMap[key] != null) {
      (debounceMap[key] as Future).ignore();
    }
    
    debounceMap[key] = Future.delayed(delay, () {
      callback(value);
      debounceMap.remove(key);
    });
  }
}
