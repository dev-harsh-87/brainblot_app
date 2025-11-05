import 'package:flutter/material.dart';
import 'package:spark_app/core/error/app_error.dart';

/// Reusable error widget for consistent error display
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.showDetails = false,
  });

  final AppError error;
  final VoidCallback? onRetry;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getErrorIcon(error),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _getErrorTitle(error),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getUserFriendlyMessage(error),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              Text(
                error.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon(AppError error) {
    switch (error.runtimeType) {
      case NetworkError:
        return Icons.wifi_off;
      case AuthError:
        return Icons.lock_outline;
      case StorageError:
        return Icons.storage;
      case ValidationError:
        return Icons.warning_outlined;
      default:
        return Icons.error_outline;
    }
  }

  String _getErrorTitle(AppError error) {
    switch (error.runtimeType) {
      case NetworkError:
        return 'Connection Issue';
      case AuthError:
        return 'Authentication Error';
      case StorageError:
        return 'Storage Error';
      case ValidationError:
        return 'Invalid Input';
      default:
        return 'Something Went Wrong';
    }
  }

  String _getUserFriendlyMessage(AppError error) {
    switch (error.runtimeType) {
      case NetworkError:
        return 'Please check your internet connection and try again.';
      case AuthError:
        return 'Please sign in again to continue.';
      case StorageError:
        return 'There was an issue saving your data.';
      case ValidationError:
        return 'Please check your input and try again.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

/// Compact error widget for inline display
class CompactErrorWidget extends StatelessWidget {
  const CompactErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  final AppError error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.message,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              iconSize: 20,
              color: Colors.red[700],
            ),
          ],
        ],
      ),
    );
  }
}
