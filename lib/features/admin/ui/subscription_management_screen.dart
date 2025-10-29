import 'package:flutter/material.dart';
import 'package:brainblot_app/core/auth/services/permission_service.dart';
import 'package:brainblot_app/core/auth/guards/admin_guard.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';
import 'package:brainblot_app/features/subscription/domain/subscription_plan.dart';
import 'package:brainblot_app/features/subscription/data/subscription_plan_repository.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  final PermissionService permissionService;

  const SubscriptionManagementScreen({
    super.key,
    required this.permissionService,
  });

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  late final SubscriptionPlanRepository _planRepository;

  @override
  void initState() {
    super.initState();
    _planRepository = SubscriptionPlanRepository();
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      permissionService: widget.permissionService,
      requiredRole: UserRole.superAdmin,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Subscription Management'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreatePlanDialog(context),
            ),
          ],
        ),
        body: StreamBuilder<List<SubscriptionPlan>>(
          stream: _planRepository.watchActivePlans(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final plans = snapshot.data ?? [];

            if (plans.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.card_membership, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No subscription plans available'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _initializeDefaultPlans(),
                      child: const Text('Initialize Default Plans'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              itemBuilder: (context, index) => _buildPlanCard(context, plans[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, SubscriptionPlan plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${plan.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                    ),
                    Text(
                      '/${plan.billingPeriod}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plan.features.map((feature) => Chip(
                label: Text(feature),
                backgroundColor: Colors.blue.withOpacity(0.1),
              )).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  onPressed: () => _showEditPlanDialog(context, plan),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: Icon(plan.isActive ? Icons.toggle_on : Icons.toggle_off),
                  label: Text(plan.isActive ? 'Active' : 'Inactive'),
                  onPressed: () => _togglePlanStatus(plan),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeDefaultPlans() async {
    try {
      await _planRepository.initializeDefaultPlans();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default plans initialized')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _togglePlanStatus(SubscriptionPlan plan) async {
    try {
      await _planRepository.togglePlanStatus(plan.id, !plan.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan ${plan.isActive ? 'deactivated' : 'activated'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCreatePlanDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final featuresController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Subscription Plan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Plan Name'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: featuresController,
                decoration: const InputDecoration(
                  labelText: 'Features (comma-separated)',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final plan = SubscriptionPlan(
                  id: nameController.text.toLowerCase().replaceAll(' ', '_'),
                  name: nameController.text,
                  description: descController.text,
                  price: double.parse(priceController.text),
                  features: featuresController.text.split(',').map((e) => e.trim()).toList(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await _planRepository.createPlan(plan);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Plan created successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditPlanDialog(BuildContext context, SubscriptionPlan plan) {
    final nameController = TextEditingController(text: plan.name);
    final descController = TextEditingController(text: plan.description);
    final priceController = TextEditingController(text: plan.price.toString());
    final featuresController = TextEditingController(text: plan.features.join(', '));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Subscription Plan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Plan Name'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: featuresController,
                decoration: const InputDecoration(
                  labelText: 'Features (comma-separated)',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final updatedPlan = plan.copyWith(
                  name: nameController.text,
                  description: descController.text,
                  price: double.parse(priceController.text),
                  features: featuresController.text.split(',').map((e) => e.trim()).toList(),
                  updatedAt: DateTime.now(),
                );

                await _planRepository.updatePlan(updatedPlan);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Plan updated successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}