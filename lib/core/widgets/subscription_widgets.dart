import 'package:flutter/material.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/features/subscription/domain/subscription_plan.dart';

/// Widget to display subscription plan information with upgrade prompts
class SubscriptionPlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrentPlan;
  final bool isUpgrade;
  final VoidCallback? onSelectPlan;
  final VoidCallback? onUpgrade;

  const SubscriptionPlanCard({
    super.key,
    required this.plan,
    this.isCurrentPlan = false,
    this.isUpgrade = false,
    this.onSelectPlan,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: isCurrentPlan ? AppTheme.elevationHigh : AppTheme.elevationMedium,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          color: AppTheme.neutral800,
          border: isCurrentPlan ? Border.all(
            color: AppTheme.primaryColor,
            width: 2,
          ) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Plan header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: _getTextColor(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing4),
                        Text(
                          plan.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _getSecondaryTextColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrentPlan)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing12,
                        vertical: AppTheme.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        'CURRENT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacing20),
              
              // Price
              if (plan.price > 0) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${plan.price.toStringAsFixed(2)}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: _getTextColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      '/${plan.billingPeriod}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _getSecondaryTextColor(),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Free',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: _getTextColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              
              const SizedBox(height: AppTheme.spacing24),
              
              // Features list
              ...plan.features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        feature,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _getTextColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),),
              
              const SizedBox(height: AppTheme.spacing24),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: _buildActionButton(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient? _getPlanGradient() {
    if (plan.id == 'institute') {
      return null;
    }
    return null;
  }

  Color _getTextColor() {
    if (plan.id == 'institute') {
      return Colors.white;
    }
    return AppTheme.neutral900;
  }

  Color _getSecondaryTextColor() {
    if (plan.id == 'institute') {
      return Colors.white70;
    }
    return AppTheme.neutral600;
  }

  Widget _buildActionButton(BuildContext context) {
    if (isCurrentPlan) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _getTextColor().withOpacity(0.3)),
        ),
        child: Text(
          'Current Plan',
          style: TextStyle(color: _getTextColor()),
        ),
      );
    }
    
    if (isUpgrade) {
      return ElevatedButton(
        onPressed: onUpgrade,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successColor,
        ),
        child: const Text('Upgrade Now'),
      );
    }
    
    return ElevatedButton(
      onPressed: onSelectPlan,
      child: const Text('Select Plan'),
    );
  }
}

/// Widget to show subscription status and limits
class SubscriptionStatusWidget extends StatelessWidget {
  final SubscriptionPlan currentPlan;
  final Map<String, dynamic> usage;
  final VoidCallback? onUpgrade;

  const SubscriptionStatusWidget({
    super.key,
    required this.currentPlan,
    required this.usage,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.getSubscriptionColor(currentPlan.id),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  '${currentPlan.name} Plan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (currentPlan.id != 'institute' && onUpgrade != null)
                  TextButton(
                    onPressed: onUpgrade,
                    child: const Text('Upgrade'),
                  ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacing12),
            
            // Usage indicators
            if (currentPlan.maxDrills > 0) ...[
              _buildUsageIndicator(
                context,
                'Drills',
                (usage['drills'] as int?) ?? 0,
                currentPlan.maxDrills,
                Icons.fitness_center,
              ),
              const SizedBox(height: AppTheme.spacing8),
            ],
            
            if (currentPlan.maxPrograms > 0) ...[
              _buildUsageIndicator(
                context,
                'Programs',
                (usage['programs'] as int?) ?? 0,
                currentPlan.maxPrograms,
                Icons.schedule,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsageIndicator(
    BuildContext context,
    String label,
    int used,
    int limit,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final percentage = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final isNearLimit = percentage >= 0.8;
    
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.neutral600,
        ),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '$used / $limit',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isNearLimit ? AppTheme.warningColor : null,
                      fontWeight: isNearLimit ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing4),
              LinearProgressIndicator(
                value: percentage,
                backgroundColor: AppTheme.neutral200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isNearLimit ? AppTheme.warningColor : AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget to show feature access with upgrade prompts
class FeatureAccessWidget extends StatelessWidget {
  final String featureName;
  final String description;
  final bool hasAccess;
  final IconData icon;
  final VoidCallback? onUpgrade;
  final VoidCallback? onTap;

  const FeatureAccessWidget({
    super.key,
    required this.featureName,
    required this.description,
    required this.hasAccess,
    required this.icon,
    this.onUpgrade,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: InkWell(
        onTap: hasAccess ? onTap : onUpgrade,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: hasAccess ? AppTheme.primaryColor : AppTheme.neutral300,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: AppTheme.spacing16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      featureName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: hasAccess ? null : AppTheme.neutral400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: hasAccess ? AppTheme.neutral600 : AppTheme.neutral400,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (!hasAccess) ...[
                const SizedBox(width: AppTheme.spacing8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing8,
                    vertical: AppTheme.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    'UPGRADE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: AppTheme.spacing8),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.neutral400,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget to show admin-only features
class AdminFeatureWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const AdminFeatureWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? AppTheme.adminColor;
    
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            gradient: LinearGradient(
              colors: [
                effectiveColor.withOpacity(0.1),
                effectiveColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: AppTheme.spacing16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: effectiveColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutral600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: AppTheme.spacing8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: AppTheme.spacing4,
                ),
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  'ADMIN',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}