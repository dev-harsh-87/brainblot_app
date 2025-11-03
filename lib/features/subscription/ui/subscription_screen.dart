import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/features/subscription/domain/subscription_plan.dart';
import 'package:brainblot_app/core/auth/models/app_user.dart';
import 'package:brainblot_app/features/subscription/services/subscription_request_service.dart';
import 'package:brainblot_app/features/subscription/domain/subscription_request.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  AppUser? _currentUser;
  List<SubscriptionPlan> _plans = [];
  List<SubscriptionRequest> _userRequests = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Load user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) throw Exception('User document not found');

      _currentUser = AppUser.fromFirestore(userDoc);

      // Load subscription plans
      final plansSnapshot = await FirebaseFirestore.instance
          .collection('subscription_plans')
          .orderBy('price')
          .get();

      _plans = plansSnapshot.docs
          .map((doc) => SubscriptionPlan.fromFirestore(doc))
          .toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Subscription Data',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error occurred',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;
    
    // Calculate responsive padding
    final horizontalPadding = isSmallScreen ? 16.0 : (isTablet ? 24.0 : 32.0);
    final maxContentWidth = isSmallScreen ? double.infinity : 1200.0;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                
                // Current Plan Card
                _buildCurrentPlanCard(isSmallScreen),
                
                const SizedBox(height: 32),
                
                // User Requests Section
                StreamBuilder<List<SubscriptionRequest>>(
                  stream: SubscriptionRequestService().getUserRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Your Subscription Requests',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track the status of your upgrade requests',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...snapshot.data!.map((request) =>
                            _buildRequestCard(request, isSmallScreen)
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                
                // Section Header
                Text(
                  'Available Plans',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Choose the plan that best fits your needs',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Plan Cards
                ..._plans.map((plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildPlanCard(plan, isSmallScreen),
                )),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(bool isSmallScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentPlanId = _currentUser?.subscription.plan ?? 'free';
    final currentStatus = _currentUser?.subscription.status ?? 'unknown';

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: colorScheme.primary,
                  size: isSmallScreen ? 24 : 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your Current Plan',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 18 : 20,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          Text(
            currentPlanId.toUpperCase(),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 28 : 32,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            _getPlanDescription(currentPlanId),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer.withOpacity(0.85),
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Status Badge
          _buildStatusBadge(currentStatus, theme),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, ThemeData theme) {
    final isActive = status == 'active';
    final color = isActive ? Colors.green : Colors.orange;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: color[700],
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: color[700],
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, bool isSmallScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCurrentPlan = _currentUser?.subscription.plan == plan.id;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isCurrentPlan
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.3),
          width: isCurrentPlan ? 2.5 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: isCurrentPlan 
                ? colorScheme.primary.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: isCurrentPlan ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan Header
          _buildPlanHeader(plan, isCurrentPlan, isSmallScreen),
          
          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outline.withOpacity(0.2),
          ),
          
          // Plan Content
          _buildPlanContent(plan, isCurrentPlan, isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildPlanHeader(SubscriptionPlan plan, bool isCurrentPlan, bool isSmallScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
      decoration: BoxDecoration(
        gradient: isCurrentPlan
            ? LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isCurrentPlan ? null : colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan Name and Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 22 : 26,
                        color: isCurrentPlan
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: isSmallScreen ? 13 : 15,
                        color: isCurrentPlan
                            ? colorScheme.onPrimaryContainer.withOpacity(0.8)
                            : colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${plan.price.toStringAsFixed(0)}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 32 : 36,
                      color: isCurrentPlan
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.primary,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '/ ${plan.billingPeriod}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCurrentPlan
                          ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                          : colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Current Plan Badge
          if (isCurrentPlan) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green[700],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CURRENT PLAN',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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

  Widget _buildPlanContent(SubscriptionPlan plan, bool isCurrentPlan, bool isSmallScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Features Header
          Row(
            children: [
              Icon(
                Icons.stars_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'What\'s Included',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 15 : 17,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Features List
          ...plan.features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.check,
                    color: colorScheme.primary,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: isSmallScreen ? 13 : 15,
                      height: 1.5,
                      color: colorScheme.onSurface.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          )),
          
          const SizedBox(height: 20),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: isCurrentPlan
                ? OutlinedButton.icon(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: colorScheme.outline.withOpacity(0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledForegroundColor: colorScheme.onSurface.withOpacity(0.5),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Current Plan'),
                  )
                : FilledButton.icon(
                    onPressed: () => _showRequestUpgradeDialog(plan),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.send, size: 20),
                    label: Text(
                      "Request ${plan.name}",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _getPlanDescription(String planId) {
    switch (planId.toLowerCase()) {
      case 'free':
        return 'Basic features for getting started';
      case 'player':
        return 'Advanced features for serious players';
      case 'institute':
        return 'Complete solution for organizations';
      default:
        return 'Subscription plan';
    }
  }

  String _getActionButtonText(SubscriptionPlan plan) {
    final currentPlan = _currentUser?.subscription.plan ?? 'free';
    final planOrder = {'free': 0, 'player': 1, 'institute': 2};
    
    final currentOrder = planOrder[currentPlan.toLowerCase()] ?? 0;
    final targetOrder = planOrder[plan.id.toLowerCase()] ?? 0;

    if (targetOrder > currentOrder) {
      return 'Upgrade to ${plan.name}';
    } else if (targetOrder < currentOrder) {
      return 'Downgrade to ${plan.name}';
    } else {
      return 'Switch to ${plan.name}';
    }
  }

  void _showRequestUpgradeDialog(SubscriptionPlan plan) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Request ${plan.name} Plan"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request upgrade to ${plan.name} plan for \$${plan.price.toStringAsFixed(0)}/${plan.billingPeriod}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: "Reason for upgrade",
                  hintText: "Why do you need this plan?",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please provide a reason";
                  }
                  if (value.trim().length < 10) {
                    return "Please provide more details (at least 10 characters)";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Your request will be reviewed by an admin',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              reasonController.dispose();
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final reason = reasonController.text.trim();
                reasonController.dispose();
                Navigator.pop(context);
                await _submitUpgradeRequest(plan, reason);
              }
            },
            child: const Text("Submit Request"),
          ),
        ],
      ),
    );
  }

  Future<void> _submitUpgradeRequest(SubscriptionPlan plan, String reason) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final service = SubscriptionRequestService();
      await service.createUpgradeRequest(
        requestedPlan: plan.id,
        reason: reason,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text("Upgrade request submitted for ${plan.name} plan!"),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to submit request: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showUpgradeDialog(SubscriptionPlan plan) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade to ${plan.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price: \$${plan.price.toStringAsFixed(2)} / ${plan.billingPeriod}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Payment integration coming soon!',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This is a demonstration of the subscription system. In production, this would integrate with a payment provider like Stripe or PayPal.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showDemoUpgradeSuccess(plan);
            },
            child: const Text('Demo Upgrade'),
          ),
        ],
      ),
    );
  }

  void _showDemoUpgradeSuccess(SubscriptionPlan plan) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Demo: Successfully upgraded to ${plan.name} plan'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildRequestCard(SubscriptionRequest request, bool isSmallScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Determine status color and icon
    MaterialColor statusColor;
    Color statusDark;
    IconData statusIcon;
    String statusText;
    
    if (request.isPending) {
      statusColor = Colors.orange;
      statusDark = Colors.orange.shade700;
      statusIcon = Icons.pending;
      statusText = 'PENDING';
    } else if (request.isApproved) {
      statusColor = Colors.green;
      statusDark = Colors.green.shade700;
      statusIcon = Icons.check_circle;
      statusText = 'APPROVED';
    } else {
      statusColor = Colors.red;
      statusDark = Colors.red.shade700;
      statusIcon = Icons.cancel;
      statusText = 'REJECTED';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHigh,
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to ${request.requestedPlan.toUpperCase()}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 15 : 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From ${request.currentPlan} plan',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: statusDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusDark,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Reason
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            // Rejection reason if rejected
            if (request.isRejected && request.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.red[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rejection Reason:',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.rejectionReason!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Admin info if processed
            if (request.adminName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Processed by ${request.adminName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            // Date
            const SizedBox(height: 8),
            Text(
              'Requested on ${_formatDate(request.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}