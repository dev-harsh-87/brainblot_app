import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyControlWidget extends StatelessWidget {
  final bool isPublic;
  final bool isOwner;
  final String itemType; // 'drill' or 'program'
  final String itemName;
  final VoidCallback? onTogglePrivacy;
  final bool isLoading;

  const PrivacyControlWidget({
    super.key,
    required this.isPublic,
    required this.isOwner,
    required this.itemType,
    required this.itemName,
    this.onTogglePrivacy,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!isOwner) {
      // Show read-only status for non-owners
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPublic 
              ? Colors.green.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPublic 
                ? Colors.green.withOpacity(0.3)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPublic ? Icons.public : Icons.lock,
              size: 16,
              color: isPublic ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              isPublic ? 'Public' : 'Private',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isPublic ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Interactive control for owners
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Privacy Settings',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPublic ? 'Public $itemType' : 'Private $itemType',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPublic 
                          ? 'Visible to all users in the community'
                          : 'Only visible to you and people you share with',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: isPublic,
                  onChanged: onTogglePrivacy != null ? (_) {
                    HapticFeedback.lightImpact();
                    onTogglePrivacy!();
                  } : null,
                  activeThumbColor: colorScheme.primary,
                ),
            ],
          ),
          
          if (isPublic) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This $itemType is now discoverable by all users',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PrivacyToggleButton extends StatelessWidget {
  final bool isPublic;
  final bool isOwner;
  final VoidCallback? onToggle;
  final bool isLoading;

  const PrivacyToggleButton({
    super.key,
    required this.isPublic,
    required this.isOwner,
    this.onToggle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Always show the privacy indicator, even for non-owners
    return GestureDetector(
      onTap: isOwner && !isLoading ? () {
        HapticFeedback.lightImpact();
        onToggle?.call();
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

        decoration: BoxDecoration(
          color: isPublic 
              ? Colors.green.withOpacity(0.15)
              : Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPublic 
                ? Colors.green.withOpacity(0.4)
                : Colors.grey.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            else
              Icon(
                isPublic ? Icons.public : Icons.lock,
                size: 10,
                color: isPublic ? Colors.green.shade700 : Colors.grey.shade700,
              ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                isPublic ? 'PUBLIC' : 'PRIVATE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isPublic ? Colors.green.shade700 : Colors.grey.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isOwner && !isLoading) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.edit,
                size: 10,
                color: isPublic ? Colors.green.shade600 : Colors.grey.shade600,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Large privacy toggle button for main screens
class PrivacyToggleIconButton extends StatelessWidget {
  final bool isPublic;
  final bool isOwner;
  final VoidCallback? onToggle;
  final bool isLoading;

  const PrivacyToggleIconButton({
    super.key,
    required this.isPublic,
    required this.isOwner,
    this.onToggle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOwner) {
      // Show read-only indicator for non-owners
      return IconButton(
        onPressed: null,
        icon: Icon(
          isPublic ? Icons.public : Icons.lock,
          color: isPublic ? Colors.green : Colors.grey,
        ),
        tooltip: isPublic ? 'Public Content' : 'Private Content',
      );
    }

    return IconButton(
      onPressed: isLoading ? null : onToggle,
      icon: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : Icon(
              isPublic ? Icons.public : Icons.lock,
              color: isPublic ? Colors.green : Colors.grey.shade600,
            ),
      tooltip: isPublic 
          ? 'Make Private (tap to change)' 
          : 'Make Public (tap to change)',
    );
  }
}
