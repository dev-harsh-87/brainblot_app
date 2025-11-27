import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/auth/services/user_management_service.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/features/subscription/data/subscription_plan_repository.dart';
import 'package:spark_app/features/subscription/domain/subscription_plan.dart';

class UserFormScreen extends StatefulWidget {
  final String? userId;
  final Map<String, dynamic>? existingUserData;
  final bool isEdit;

  const UserFormScreen({
    super.key,
    this.userId,
    this.existingUserData,
    this.isEdit = false,
  });

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userManagementService = GetIt.instance<UserManagementService>();
  final _subscriptionPlanRepository = SubscriptionPlanRepository();
  
  // Form controllers
  late final TextEditingController _displayNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  
  // Form state
  UserRole _selectedRole = UserRole.user;
  String? _selectedPlanId;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  List<SubscriptionPlan> _availablePlans = [];
  bool _loadingPlans = true;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: (widget.existingUserData?['displayName'] as String?) ?? '',
    );
    _emailController = TextEditingController(
      text: (widget.existingUserData?['email'] as String?) ?? '',
    );
    _passwordController = TextEditingController();
    
    if (widget.isEdit && widget.existingUserData != null) {
      _selectedRole = UserRole.fromString(
        widget.existingUserData!['role'] as String? ?? 'user',
      );
      final subscription = widget.existingUserData!['subscription'] as Map<String, dynamic>?;
      if (subscription != null) {
        // Try to get planId first, then fall back to plan
        _selectedPlanId = subscription['planId'] as String? ?? subscription['plan'] as String?;
        
        // Debug logging
        print('🔍 UserFormScreen Init: Subscription data: $subscription');
        print('🔍 UserFormScreen Init: Selected plan ID: $_selectedPlanId');
      }
    }
    
    _loadSubscriptionPlans();
  }

  Future<void> _loadSubscriptionPlans() async {
    try {
      final plans = await _subscriptionPlanRepository.getActivePlans();
      setState(() {
        _availablePlans = plans;
        _loadingPlans = false;
        
        // For editing, validate that the selected plan exists in available plans
        if (widget.isEdit && _selectedPlanId != null) {
          final planExists = plans.any((plan) => plan.id == _selectedPlanId);
          if (!planExists) {
            // If the user's current plan is not in active plans, try to find it by name
            final subscription = widget.existingUserData!['subscription'] as Map<String, dynamic>?;
            final currentPlanName = subscription?['plan'] as String?;
            
            if (currentPlanName != null) {
              // Try to find a plan that matches the current plan name
              final matchingPlan = plans.where((plan) =>
                plan.name.toLowerCase() == currentPlanName.toLowerCase() ||
                plan.id.toLowerCase() == currentPlanName.toLowerCase()
              ).firstOrNull;
              
              if (matchingPlan != null) {
                _selectedPlanId = matchingPlan.id;
              } else if (plans.isNotEmpty) {
                // Fallback to first available plan
                _selectedPlanId = plans.first.id;
              }
            }
          }
        }
        
        // Set default plan if not editing and no plan selected
        if (!widget.isEdit && plans.isNotEmpty && _selectedPlanId == null) {
          _selectedPlanId = plans.first.id;
        }
        
        // Debug logging
        print('🔍 UserFormScreen: Loaded ${plans.length} plans');
        print('🔍 UserFormScreen: Selected plan ID: $_selectedPlanId');
        print('🔍 UserFormScreen: Available plan IDs: ${plans.map((p) => p.id).toList()}');
      });
    } catch (e) {
      setState(() {
        _loadingPlans = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load plans: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit User' : 'Add New User'),
        elevation: 0,
      ),
      body: _loadingPlans
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(theme),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(
            'Basic Information',
            Icons.person_outline,
            [
              _buildTextField(
                controller: _displayNameController,
                label: 'Display Name',
                icon: Icons.badge,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Display name is required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                enabled: !widget.isEdit,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Email is required';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value!)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              if (!widget.isEdit) ...[
                const SizedBox(height: 16),
                _buildPasswordField(),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Role & Permissions',
            Icons.admin_panel_settings_outlined,
            [_buildRoleSelector(theme)],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Subscription Plan',
            Icons.card_membership_outlined,
            [_buildSubscriptionPlanSelector(theme)],
          ),
          const SizedBox(height: 32),
          _buildActionButtons(theme),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.goldPrimary),
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
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: enabled ? context.colors.surface : context.colors.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      validator: (value) {
        if (value?.isEmpty ?? true) return 'Password is required';
        if (value!.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
          fillColor:  context.colors.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildRoleSelector(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: UserRole.values.map((role) {
          final isSelected = _selectedRole == role;
          final roleColor = AppTheme.getRoleColor(role.value);
          
          return InkWell(
            onTap: () => setState(() => _selectedRole = role),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? roleColor.withOpacity(0.1)
                    : Colors.transparent,
                border: Border(
                  bottom: role != UserRole.values.last
                      ? BorderSide(color: Colors.grey[200]!)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? roleColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? roleColor : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? roleColor : Colors.grey[600],
                          ),
                        ),
                        Text(
                          _getRoleDescription(role),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.admin_panel_settings,
                    color: roleColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubscriptionPlanSelector(ThemeData theme) {
    if (_availablePlans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.warningColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No subscription plans available. Please create plans first.',
                style: TextStyle(color: AppTheme.warningColor),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: _availablePlans.map((plan) {
          final isSelected = _selectedPlanId == plan.id;
          final planColor = AppTheme.getSubscriptionColor(plan.name.toLowerCase());
          
          return InkWell(
            onTap: () => setState(() => _selectedPlanId = plan.id),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? planColor.withOpacity(0.1)
                    : Colors.transparent,
                border: Border(
                  bottom: plan != _availablePlans.last
                      ? BorderSide(color: Colors.grey[200]!)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? planColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? planColor : context.colors.outline,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 16, color: AppTheme.whitePure)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plan.name.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? planColor : context.colors.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: planColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${plan.currency} ${plan.price.toStringAsFixed(0)}/${plan.billingPeriod}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: planColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (plan.features.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: plan.features.take(3).map((feature) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.colors.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.card_membership,
                    color: planColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.goldPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.whitePure),
                    ),
                  )
                : Text(
                    widget.isEdit ? 'Update User' : 'Create User',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.whitePure,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Full system access with user management';
      case UserRole.user:
        return 'Standard user with basic features';
      default:
        return 'Standard access';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a subscription plan'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedPlan = _availablePlans.firstWhere(
        (plan) => plan.id == _selectedPlanId,
      );

      if (widget.isEdit) {
        await _updateUser(selectedPlan);
      } else {
        await _createUser(selectedPlan);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEdit
                  ? 'User updated successfully'
                  : 'User created successfully',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createUser(SubscriptionPlan plan) async {
    print('🔄 Starting user creation process...');
    print('📧 Email: ${_emailController.text.trim()}');
    print('👤 Display Name: ${_displayNameController.text.trim()}');
    print('🔐 Role: ${_selectedRole.value}');
    print('📦 Plan: ${plan.name}');
    
    try {
      final user = await _userManagementService.createUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
        role: _selectedRole,
        subscriptionData: {
          'plan': plan.name.toLowerCase(),
          'planId': plan.id,
          'status': 'active',
          'moduleAccess': plan.moduleAccess,
          'expiresAt': null,
        },
      );
      print('✅ User creation completed successfully');
      print('🆔 Created user ID: ${user.id}');
    } catch (e) {
      print('❌ User creation failed: $e');
      rethrow;
    }
  }

  Future<void> _updateUser(SubscriptionPlan plan) async {
    if (widget.userId == null) return;

    print('🔄 Updating user subscription...');
    print('📦 New Plan: ${plan.name} (ID: ${plan.id})');
    print('🔧 Module Access: ${plan.moduleAccess}');

    // Create complete subscription object
    final subscriptionData = {
      'plan': plan.name.toLowerCase(),
      'planId': plan.id,
      'status': 'active', // Keep existing status or set to active
      'moduleAccess': plan.moduleAccess,
      'expiresAt': null, // Admin changes don't set expiration by default
    };

    // Update user role and display name first
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .update({
      'displayName': _displayNameController.text.trim(),
      'role': _selectedRole.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update subscription using the service method
    await _userManagementService.updateUserSubscription(
      widget.userId!,
      subscriptionData,
    );

    print('✅ User subscription updated successfully');
    print('📊 Updated subscription data: $subscriptionData');
  }
}