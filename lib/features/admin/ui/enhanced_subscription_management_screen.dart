import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:brainblot_app/core/auth/services/permission_service.dart';
import 'package:brainblot_app/core/auth/guards/admin_guard.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';
import 'package:brainblot_app/features/subscription/domain/subscription_plan.dart';
import 'package:brainblot_app/features/subscription/data/subscription_plan_repository.dart';
import 'package:brainblot_app/features/admin/ui/subscription_plan_form_screen.dart';

class EnhancedSubscriptionManagementScreen extends StatefulWidget {
  final PermissionService permissionService;

  const EnhancedSubscriptionManagementScreen({
    super.key,
    required this.permissionService,
  });

  @override
  State<EnhancedSubscriptionManagementScreen> createState() =>
      _EnhancedSubscriptionManagementScreenState();
}

class _EnhancedSubscriptionManagementScreenState
    extends State<EnhancedSubscriptionManagementScreen>
    with SingleTickerProviderStateMixin {
  late final SubscriptionPlanRepository _planRepository;
  late TabController _tabController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _planRepository = SubscriptionPlanRepository();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      permissionService: widget.permissionService,
      requiredRole: UserRole.admin,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildStatsBar(),
            Expanded(child: _buildPlansList()),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _navigateToCreatePlan(),
          icon: const Icon(Icons.add),
          label: const Text('Create Plan'),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Subscription Management'),
      elevation: 0,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Active Plans'),
          Tab(text: 'All Plans'),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter Plans',
          onSelected: (value) => setState(() => _selectedFilter = value),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'all', child: Text('All Plans')),
            const PopupMenuItem(value: 'active', child: Text('Active Only')),
            const PopupMenuItem(value: 'inactive', child: Text('Inactive Only')),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    return FutureBuilder<List<SubscriptionPlan>>(
      future: _planRepository.getAllPlans(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final plans = snapshot.data!;
        final totalPlans = plans.length;
        final activePlans = plans.where((p) => p.isActive).length;
        final totalRevenue = plans.where((p) => p.isActive).fold<double>(
              0,
              (sum, plan) => sum + plan.price,
            );

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive stats layout
              if (constraints.maxWidth < 600) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Total Plans',
                            totalPlans.toString(),
                            Icons.card_membership,
                            Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Active',
                            activePlans.toString(),
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStatItem(
                      'Revenue',
                      '\$${totalRevenue.toStringAsFixed(0)}',
                      Icons.attach_money,
                      Colors.purple,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Total Plans',
                    totalPlans.toString(),
                    Icons.card_membership,
                    Colors.blue,
                  ),
                  _buildStatItem(
                    'Active',
                    activePlans.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatItem(
                    'Revenue',
                    '\$${totalRevenue.toStringAsFixed(0)}',
                    Icons.attach_money,
                    Colors.purple,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPlansList() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildPlansListView(activeOnly: true),
        _buildPlansListView(activeOnly: false),
      ],
    );
  }

  Widget _buildPlansListView({required bool activeOnly}) {
    return StreamBuilder<List<SubscriptionPlan>>(
      stream: activeOnly
          ? _planRepository.watchActivePlans()
          : Stream.value([]),
      builder: (context, snapshot) {
        if (!activeOnly) {
          return FutureBuilder<List<SubscriptionPlan>>(
            future: _planRepository.getAllPlans(),
            builder: (context, futureSnapshot) {
              return _buildPlanContent(futureSnapshot);
            },
          );
        }
        return _buildPlanContent(snapshot);
      },
    );
  }

  Widget _buildPlanContent(AsyncSnapshot<List<SubscriptionPlan>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error: ${snapshot.error}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final plans = snapshot.data ?? [];

    if (plans.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_membership, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No subscription plans available',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first plan to get started',
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _initializeDefaultPlans(),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Initialize Default Plans'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive list layout
        return ListView.builder(
          padding: EdgeInsets.all(constraints.maxWidth < 600 ? 12 : 16),
          itemCount: plans.length,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(
              bottom: constraints.maxWidth < 600 ? 12 : 16,
            ),
            child: _buildPlanCard(plans[index], constraints.maxWidth),
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, double screenWidth) {
    final isPopular = plan.id == 'player';
    final isCompact = screenWidth < 600;

    return Card(
      elevation: isPopular ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPopular
            ? const BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(isCompact ? 16 : 20),
            child: isCompact
                ? _buildCompactCardContent(plan)
                : _buildFullCardContent(plan),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCardContent(SubscriptionPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getPlanColor(plan.id).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getPlanIcon(plan.id),
                color: _getPlanColor(plan.id),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: plan.isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      plan.isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: plan.isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Price on the right for compact view
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${plan.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _getPlanColor(plan.id),
                  ),
                ),
                Text(
                  '/${plan.billingPeriod}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Description
        Text(
          plan.description,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),

        // Features count
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
              const SizedBox(width: 6),
              Text(
                '${plan.features.length} Features',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showPlanDetailsDialog(plan),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToEditPlan(plan),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFullCardContent(SubscriptionPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plan Icon and Name
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getPlanColor(plan.id).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getPlanIcon(plan.id),
                color: _getPlanColor(plan.id),
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: plan.isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      plan.isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: plan.isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Price
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${plan.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _getPlanColor(plan.id),
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '/${plan.billingPeriod}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Description
        Text(
          plan.description,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),

        // Features count and Actions Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 6),
                  Text(
                    '${plan.features.length} Features',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _showPlanDetailsDialog(plan),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _navigateToEditPlan(plan),
              icon: const Icon(Icons.edit),
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getPlanIcon(String planId) {
    switch (planId) {
      case 'free':
        return Icons.emoji_events_outlined;
      case 'player':
        return Icons.sports_basketball;
      case 'institute':
        return Icons.school;
      default:
        return Icons.card_membership;
    }
  }

  Color _getPlanColor(String planId) {
    switch (planId) {
      case 'free':
        return Colors.grey;
      case 'player':
        return Colors.blue;
      case 'institute':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _showPlanDetailsDialog(SubscriptionPlan plan) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _getPlanColor(plan.id).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getPlanColor(plan.id),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getPlanIcon(plan.id),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${plan.price.toStringAsFixed(2)}/${plan.billingPeriod}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      _buildDetailSection(
                        'Description',
                        Icons.description,
                        [Text(plan.description)],
                      ),
                      const SizedBox(height: 24),

                      // Features
                      _buildDetailSection(
                        'Features',
                        Icons.check_circle_outline,
                        plan.features
                            .map((feature) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check, size: 20, color: Colors.green[700]),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(feature)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 24),

                      // Details
                      _buildDetailSection(
                        'Plan Details',
                        Icons.info_outline,
                        [
                          _buildInfoRow('Plan ID', plan.id),
                          _buildInfoRow('Priority', plan.priority.toString()),
                          _buildInfoRow('Billing Period', plan.billingPeriod),
                          _buildInfoRow('Status', plan.isActive ? 'Active' : 'Inactive'),
                          _buildInfoRow(
                            'Created',
                            plan.createdAt != null
                                ? DateFormat('MMM d, yyyy').format(plan.createdAt!)
                                : 'N/A',
                          ),
                          _buildInfoRow(
                            'Updated',
                            plan.updatedAt != null
                                ? DateFormat('MMM d, yyyy').format(plan.updatedAt!)
                                : 'N/A',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _togglePlanStatus(plan);
                        },
                        icon: Icon(plan.isActive ? Icons.toggle_off : Icons.toggle_on),
                        label: Text(plan.isActive ? 'Deactivate' : 'Activate'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToEditPlan(plan);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Plan'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

Future<void> _navigateToCreatePlan() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionPlanFormScreen(),
      ),
    );

    if (result == true) {
      setState(() {}); // Refresh the list
    }
  }

  Future<void> _navigateToEditPlan(SubscriptionPlan plan) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionPlanFormScreen(plan: plan),
      ),
    );

    if (result == true) {
      setState(() {}); // Refresh the list
    }
  }
  void _showCreatePlanDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final billingPeriodController = TextEditingController(text: 'month');
    final priorityController = TextEditingController(text: '1');
    final List<TextEditingController> featureControllers = [
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Create Subscription Plan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Plan Name *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: descController,
                            decoration: const InputDecoration(
                              labelText: 'Description *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                            ),
                            maxLines: 3,
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: priceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Price *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d+\.?\d{0,2}')),
                                  ],
                                  validator: (value) =>
                                      value?.isEmpty ?? true ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: billingPeriodController,
                                  decoration: const InputDecoration(
                                    labelText: 'Billing Period *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  validator: (value) =>
                                      value?.isEmpty ?? true ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: priorityController,
                            decoration: const InputDecoration(
                              labelText: 'Priority (1-10) *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.priority_high),
                              helperText: 'Lower number = higher priority',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value?.isEmpty ?? true) return 'Required';
                              final num = int.tryParse(value!);
                              if (num == null || num < 1 || num > 10) {
                                return 'Must be between 1-10';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Features',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    featureControllers.add(TextEditingController());
                                  });
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Feature'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...featureControllers.asMap().entries.map((entry) {
                            final index = entry.key;
                            final controller = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: controller,
                                      decoration: InputDecoration(
                                        labelText: 'Feature ${index + 1}',
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(Icons.check_circle_outline),
                                      ),
                                      validator: (value) =>
                                          value?.isEmpty ?? true ? 'Required' : null,
                                    ),
                                  ),
                                  if (featureControllers.length > 1)
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          featureControllers.removeAt(index);
                                        });
                                      },
                                      icon: const Icon(Icons.remove_circle_outline),
                                      color: Colors.red,
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              try {
                                final features = featureControllers
                                    .map((c) => c.text.trim())
                                    .where((text) => text.isNotEmpty)
                                    .toList();

                                final plan = SubscriptionPlan(
                                  id: nameController.text
                                      .toLowerCase()
                                      .replaceAll(' ', '_'),
                                  name: nameController.text,
                                  description: descController.text,
                                  price: double.parse(priceController.text),
                                  billingPeriod: billingPeriodController.text,
                                  priority: int.parse(priorityController.text),
                                  features: features,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );

                                await _planRepository.createPlan(plan);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Plan created successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            }
                          },
                          child: const Text('Create Plan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPlanDialog(SubscriptionPlan plan) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: plan.name);
    final descController = TextEditingController(text: plan.description);
    final priceController = TextEditingController(text: plan.price.toString());
    final billingPeriodController = TextEditingController(text: plan.billingPeriod);
    final priorityController = TextEditingController(text: plan.priority.toString());
    final List<TextEditingController> featureControllers = plan.features
        .map((feature) => TextEditingController(text: feature))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _getPlanColor(plan.id).withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getPlanColor(plan.id),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getPlanIcon(plan.id),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Edit ${plan.name}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Form (similar to create, but with existing values)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Plan Name *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: descController,
                            decoration: const InputDecoration(
                              labelText: 'Description *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                            ),
                            maxLines: 3,
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: priceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Price *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) =>
                                      value?.isEmpty ?? true ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: billingPeriodController,
                                  decoration: const InputDecoration(
                                    labelText: 'Billing Period *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  validator: (value) =>
                                      value?.isEmpty ?? true ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: priorityController,
                            decoration: const InputDecoration(
                              labelText: 'Priority (1-10) *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.priority_high),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value?.isEmpty ?? true) return 'Required';
                              final num = int.tryParse(value!);
                              if (num == null || num < 1 || num > 10) {
                                return 'Must be between 1-10';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Features',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    featureControllers.add(TextEditingController());
                                  });
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Feature'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...featureControllers.asMap().entries.map((entry) {
                            final index = entry.key;
                            final controller = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: controller,
                                      decoration: InputDecoration(
                                        labelText: 'Feature ${index + 1}',
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(Icons.check_circle_outline),
                                      ),
                                      validator: (value) =>
                                          value?.isEmpty ?? true ? 'Required' : null,
                                    ),
                                  ),
                                  if (featureControllers.length > 1)
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          featureControllers.removeAt(index);
                                        });
                                      },
                                      icon: const Icon(Icons.remove_circle_outline),
                                      color: Colors.red,
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              try {
                                final features = featureControllers
                                    .map((c) => c.text.trim())
                                    .where((text) => text.isNotEmpty)
                                    .toList();

                                final updatedPlan = plan.copyWith(
                                  name: nameController.text,
                                  description: descController.text,
                                  price: double.parse(priceController.text),
                                  billingPeriod: billingPeriodController.text,
                                  priority: int.parse(priorityController.text),
                                  features: features,
                                  updatedAt: DateTime.now(),
                                );

                                await _planRepository.updatePlan(updatedPlan);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Plan updated successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            }
                          },
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _initializeDefaultPlans() async {
    try {
      await _planRepository.initializeDefaultPlans();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default plans initialized successfully'),
            backgroundColor: Colors.green,
          ),
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
          SnackBar(
            content: Text(
              'Plan ${plan.isActive ? 'deactivated' : 'activated'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
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
}