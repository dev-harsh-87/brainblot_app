import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brainblot_app/core/error/app_error.dart';

/// Global error handler for the application
class ErrorHandler {
  static void showError(BuildContext context, AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message),
        backgroundColor: _getErrorColor(error),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static Color _getErrorColor(AppError error) {
    switch (error.runtimeType) {
      case NetworkError:
        return Colors.orange;
      case AuthError:
        return Colors.red;
      case StorageError:
        return Colors.purple;
      case ValidationError:
        return Colors.amber;
      default:
        return Colors.red;
    }
  }

  static String getUserFriendlyMessage(AppError error) {
    switch (error.runtimeType) {
      case NetworkError:
        return 'Network connection issue. Please check your internet connection.';
      case AuthError:
        return 'Authentication failed. Please try logging in again.';
      case StorageError:
        return 'Data storage issue. Your changes may not be saved.';
      case ValidationError:
        return 'Please check your input and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

/// Mixin for BLoCs to handle errors consistently
mixin ErrorHandlerMixin<Event, State> on Bloc<Event, State> {
  void handleError(Exception exception, Emitter<State> emit) {
    final error = exception.toAppError();
    // Override this method in specific BLoCs to handle errors appropriately
    // For example, emit a state with error information
  }
}
