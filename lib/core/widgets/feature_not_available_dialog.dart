import 'package:flutter/material.dart';

/// Dialog to show when a feature is not available to the user
class FeatureNotAvailableDialog extends StatelessWidget {
  final String featureName;
  final String? description;
  final VoidCallback? onUpgradePressed;

  const FeatureNotAvailableDialog({
    super.key,
    required this.featureName,
    this.description,
    this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.lock_outline,
              color: Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Feature Not Available',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The "$featureName" feature is not available with your current subscription.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upgrade your subscription to access this feature',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        FilledButton(
          onPressed: onUpgradePressed ?? () {
            Navigator.of(context).pop();
            // Navigate to subscription screen
            Navigator.of(context).pushNamed('/subscription');
          },
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: const Text('Upgrade'),
        ),
      ],
    );
  }

  /// Show the dialog
  static Future<void> show(
    BuildContext context, {
    required String featureName,
    String? description,
    VoidCallback? onUpgradePressed,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => FeatureNotAvailableDialog(
        featureName: featureName,
        description: description,
        onUpgradePressed: onUpgradePressed,
      ),
    );
  }
}