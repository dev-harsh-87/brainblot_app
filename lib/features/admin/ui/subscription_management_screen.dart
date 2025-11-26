import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/features/subscription/domain/subscription_plan.dart';
import 'package:spark_app/features/subscription/data/subscription_plan_repository.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/features/admin/ui/screens/plan_form_screen.dart';
import 'package:get_it/get_it.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  final _planRepository = GetIt.instance<SubscriptionPlanRepository>();
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Management'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubscriptionStats(),
            const SizedBox(height: 24),
            _buildPlansList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePlanDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Plan'),
        backgroundColor: context.colors.primary,
      ),
    );
  }

  Widget _buildSubscriptionStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        final freeUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sub = data['subscription'] as Map<String, dynamic>?;
          return sub?['plan'] == 'free';
        }).length;

        final playerUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sub = data['subscription'] as Map<String, dynamic>?;
          return sub?['plan'] == 'player';
        }).length;

        final instituteUsers = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sub = data['subscription'] as Map<String, dynamic>?;
          return sub?['plan'] == 'institute';
        }).length;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscription Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Free', freeUsers, AppTheme.freeColor),
                    _buildStatColumn(
                        'Player', playerUsers, AppTheme.playerColor,),
                    _buildStatColumn(
                        'Institute', instituteUsers, AppTheme.instituteColor,),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPlansList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subscription Plans',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<SubscriptionPlan>>(
          stream: _planRepository.watchAllPlans(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 64, color: context.colors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading plans',
                      style: TextStyle(fontSize: 18, color: context.colors.error),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(fontSize: 14, color: context.colors.onSurface.withOpacity(0.6)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final plans = snapshot.data ?? [];
            if (plans.isEmpty) {
              return Center(
                child: Column(
                  children: [
                    Icon(Icons.card_membership,
                        size: 64, color: context.colors.onSurface.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    Text(
                      'No subscription plans found',
                      style: TextStyle(fontSize: 18, color: context.colors.onSurface.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first plan to get started',
                      style: TextStyle(fontSize: 14, color: context.colors.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                return _buildPlanCard(plans[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final planColor = AppTheme.getSubscriptionColor(plan.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: planColor.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        onTap: () => _showPlanDetailsDialog(plan),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: planColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.card_membership,
                        color: planColor, size: 28,),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Plan name
                            Text(
                              plan.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Badges row
                            Row(
                              children: [
                                // System Plan Badge
                                if (_isPredefinedPlan(plan.id)) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4,),
                                    decoration: BoxDecoration(
                                      color: AppTheme.infoColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.infoColor.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified_outlined,
                                          size: 12,
                                          color: AppTheme.infoColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'SYSTEM',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.infoColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Active/Inactive Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4,),
                                  decoration: BoxDecoration(
                                    color: plan.isActive
                                        ? AppTheme.successColor.withOpacity(0.1)
                                        : context.colors.onSurface.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: plan.isActive
                                          ? AppTheme.successColor
                                          : context.colors.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    plan.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: plan.isActive
                                          ? AppTheme.successColor
                                          : context.colors.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colors.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handlePlanAction(value, plan),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                                plan.isActive
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,),
                            const SizedBox(width: 8),
                            Text(plan.isActive ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                      // Only show delete option for non-predefined plans
                      if (!_isPredefinedPlan(plan.id)) ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: AppTheme.errorColor)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      'Price',
                      '\$${plan.price.toStringAsFixed(2)}/month',
                      Icons.attach_money,
                      planColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(
                      'Features',
                      '${plan.features.length} items',
                      Icons.list,
                      planColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(
                      'Modules',
                      '${plan.moduleAccess.length} modules',
                      Icons.apps,
                      planColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      String label, String value, IconData icon, Color color,) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: context.colors.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Check if a plan is predefined and should not be deleted
  bool _isPredefinedPlan(String planId) {
    const predefinedPlans = ['free', 'player', 'premium', 'institute'];
    return predefinedPlans.contains(planId.toLowerCase());
  }

  void _handlePlanAction(String action, SubscriptionPlan plan) {
    switch (action) {
      case 'edit':
        _showEditPlanDialog(plan);
        break;
      case 'toggle':
        _togglePlanStatus(plan);
        break;
      case 'delete':
        _showDeleteConfirmation(plan);
        break;
    }
  }

  void _showPlanDetailsDialog(SubscriptionPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(plan.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Description', plan.description),
              _buildDetailRow(
                  'Price', '\$${plan.price.toStringAsFixed(2)}',),
              _buildDetailRow('Billing Cycle', 'month'),
              _buildDetailRow(
                  'Status', plan.isActive ? 'Active' : 'Inactive',),
              const SizedBox(height: 16),
              const Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...plan.features.map((f) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 16, color: AppTheme.successColor),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f)),
                      ],
                    ),
                  ),),
              const SizedBox(height: 16),
              const Text(
                'Module Access:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: plan.moduleAccess
                    .map((m) => Chip(
                          label: Text(m),
                          backgroundColor:
                              AppTheme.getSubscriptionColor(plan.id)
                                  .withOpacity(0.1),
                        ),)
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showCreatePlanDialog() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PlanFormScreen(),
      ),
    );

    // No need for setState() - StreamBuilder will automatically update
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan created successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  void _showEditPlanDialog(SubscriptionPlan plan) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PlanFormScreen(
          planId: plan.id,
          existingPlan: plan,
          isEdit: true,
        ),
      ),
    );

    // No need for setState() - StreamBuilder will automatically update
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan updated successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _togglePlanStatus(SubscriptionPlan plan) async {
    try {
      await _planRepository.togglePlanStatus(plan.id, !plan.isActive);
      // No need for setState() - StreamBuilder will automatically update
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Plan ${plan.isActive ? "deactivated" : "activated"} successfully",),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle plan: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(SubscriptionPlan plan) {
    // Check if this is a predefined plan
    if (_isPredefinedPlan(plan.id)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.warningColor),
              const SizedBox(width: 8),
              const Text('Cannot Delete Plan'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The "${plan.name}" plan is a predefined system plan and cannot be deleted.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.infoColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppTheme.infoColor, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You can edit this plan to modify its features, pricing, and settings, but it cannot be removed from the system.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showEditPlanDialog(plan);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Plan'),
            ),
          ],
        ),
      );
      return;
    }

    // Show normal delete confirmation for custom plans
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${plan.name}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_outlined, color: AppTheme.errorColor, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action cannot be undone. Users with this plan will need to be reassigned to a different plan.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePlan(plan.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlan(String planId) async {
    try {
      await _planRepository.deletePlan(planId);
      // No need for setState() - StreamBuilder will automatically update
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan deleted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete plan: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}