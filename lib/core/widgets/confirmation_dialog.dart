import 'package:flutter/material.dart';

/// A reusable confirmation dialog for important actions
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final IconData? icon;
  final Color? iconColor;
  final Color? confirmButtonColor;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.icon,
    this.iconColor,
    this.confirmButtonColor,
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? colorScheme.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor ?? colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
            onCancel?.call();
          },
          child: Text(
            cancelText,
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(true);
            onConfirm?.call();
          },
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive 
                ? colorScheme.error 
                : (confirmButtonColor ?? colorScheme.primary),
            foregroundColor: isDestructive 
                ? colorScheme.onError 
                : colorScheme.onPrimary,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }

  /// Show a privacy change confirmation dialog
  static Future<bool?> showPrivacyConfirmation(
    BuildContext context, {
    required bool isCurrentlyPublic,
    required String itemType, // 'drill' or 'program'
    required String itemName,
  }) {
    final newState = isCurrentlyPublic ? 'private' : 'public';
    final icon = isCurrentlyPublic ? Icons.lock : Icons.public;
    final iconColor = isCurrentlyPublic ? Colors.orange : Colors.green;
    
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Change ${itemType.substring(0, 1).toUpperCase()}${itemType.substring(1)} Privacy',
        message: 'Are you sure you want to make "$itemName" $newState?\n\n'
            '${isCurrentlyPublic 
                ? '• Only you will be able to see and use this $itemType\n'
                  '• It will be removed from public browsing'
                : '• Everyone will be able to see and use this $itemType\n'
                  '• It will appear in public browsing'}',
        confirmText: 'Make ${newState.substring(0, 1).toUpperCase()}${newState.substring(1)}',
        cancelText: 'Keep ${isCurrentlyPublic ? 'Public' : 'Private'}',
        icon: icon,
        iconColor: iconColor,
        confirmButtonColor: iconColor,
      ),
    );
  }

  /// Show a program activation confirmation dialog
  static Future<bool?> showProgramActivationConfirmation(
    BuildContext context, {
    required String programName,
    required int durationDays,
    required String category,
    required String level,
    bool hasCurrentProgram = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Activate Training Program',
        message: 'Are you sure you want to activate "$programName"?\n\n'
            '• Duration: $durationDays days\n'
            '• Category: $category\n'
            '• Level: $level\n\n'
            '${hasCurrentProgram 
                ? 'This will replace your current active program and reset your progress.'
                : 'This will start your training journey with this program.'}',
        confirmText: 'Activate Program',
        icon: Icons.play_circle_filled,
        iconColor: Colors.green,
        confirmButtonColor: Colors.green,
      ),
    );
  }

  /// Show a generic confirmation dialog
  static Future<bool?> showGenericConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    IconData? icon,
    Color? iconColor,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        iconColor: iconColor,
        isDestructive: isDestructive,
      ),
    );
  }
}
