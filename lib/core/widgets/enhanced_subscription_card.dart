import 'package:flutter/material.dart';
import 'package:brainblot_app/core/theme/app_theme.dart';
import 'package:brainblot_app/features/subscription/domain/subscription_plan.dart';

/// Enhanced subscription status card for home screen
class EnhancedSubscriptionCard extends StatelessWidget {
  final SubscriptionPlan currentPlan;
  final Map<String, dynamic> usage;
  final VoidCallback? onTap;
  final VoidCallback? onUpgrade;

  const EnhancedSubscriptionCard({
    super.key,
    required this.currentPlan,
    required this.usage,
    this.onTap,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planColor = AppTheme.getSubscriptionColor(currentPlan.id);
    final isFreePlan = currentPlan.id == 'free';
    
    return Card(
      elevation: 8,
      shadowColor: planColor.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            gradient: _getPlanGradient(planColor),
            border: Border.all(
              color: planColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with plan name and badge
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: planColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: planColor.withOpacity(0.4),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Text(
                                '${currentPlan.name} Plan',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getTextColor(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacing4),
                          Text(
                            currentPlan.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _getSecondaryTextColor(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Plan badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: planColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        boxShadow: [
                          BoxShadow(
                            color: planColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'ACTIVE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacing20),
                
                // Price section
                Row(
                  children: [
                    if (currentPlan.price > 0) ...[
                      Text(
                        '\$${currentPlan.price.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: _getTextColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '/${currentPlan.billingPeriod}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _getSecondaryTextColor(),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Free Forever',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: _getTextColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (isFreePlan && onUpgrade != null)
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onUpgrade,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing16,
                                vertical: AppTheme.spacing8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.upgrade,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: AppTheme.spacing4),
                                  Text(
                                    'Upgrade',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacing20),
                
                // Features preview (show first 3)
                Column(
                  children: currentPlan.features.take(3).map((feature) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppTheme.successColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing12),
                          Expanded(
                            child: Text(
                              feature,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _getTextColor(),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ),
                
                // Show more features indicator
                if (currentPlan.features.length > 3) ...[
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    children: [
                      const SizedBox(width: 32), // Align with features
                      Text(
                        '+${currentPlan.features.length - 3} more features',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getSecondaryTextColor(),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: AppTheme.spacing16),
                
                // Module access count
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: _getTextColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(
                      color: _getTextColor().withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.apps,
                        color: planColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(
                        '${currentPlan.moduleAccess.length} Modules Unlocked',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _getTextColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: _getSecondaryTextColor(),
                        size: 16,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppTheme.spacing12),
                
                // Tap to view details
                Center(
                  child: Text(
                    'Tap to view all features and plans',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _getSecondaryTextColor(),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _getPlanGradient(Color planColor) {
    switch (currentPlan.id) {
      case 'institute':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            planColor.withOpacity(0.15),
            planColor.withOpacity(0.05),
            Colors.white.withOpacity(0.8),
          ],
        );
      case 'player':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            planColor.withOpacity(0.1),
            planColor.withOpacity(0.03),
            Colors.white,
          ],
        );
      default: // free
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.withOpacity(0.05),
            Colors.white,
          ],
        );
    }
  }

  Color _getTextColor() {
    switch (currentPlan.id) {
      case 'institute':
        return AppTheme.neutral800;
      default:
        return AppTheme.neutral900;
    }
  }

  Color _getSecondaryTextColor() {
    switch (currentPlan.id) {
      case 'institute':
        return AppTheme.neutral600;
      default:
        return AppTheme.neutral600;
    }
  }
}

/// Compact subscription status widget for smaller spaces
class CompactSubscriptionStatus extends StatelessWidget {
  final SubscriptionPlan currentPlan;
  final VoidCallback? onTap;

  const CompactSubscriptionStatus({
    super.key,
    required this.currentPlan,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planColor = AppTheme.getSubscriptionColor(currentPlan.id);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing12,
          vertical: AppTheme.spacing8,
        ),
        decoration: BoxDecoration(
          color: planColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: planColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: planColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            Text(
              currentPlan.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: planColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppTheme.spacing4),
            Icon(
              Icons.arrow_drop_down,
              color: planColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}