import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brainblot_app/features/subscription/domain/subscription_plan.dart';
import 'package:brainblot_app/features/subscription/data/subscription_plan_repository.dart';

class SubscriptionPlanFormScreen extends StatefulWidget {
  final SubscriptionPlan? plan;

  const SubscriptionPlanFormScreen({
    super.key,
    this.plan,
  });

  @override
  State<SubscriptionPlanFormScreen> createState() =>
      _SubscriptionPlanFormScreenState();
}

class _SubscriptionPlanFormScreenState
    extends State<SubscriptionPlanFormScreen> {
  late final SubscriptionPlanRepository _planRepository;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _billingPeriodController;
  late final TextEditingController _priorityController;
  late final TextEditingController _maxDrillsController;
  late final TextEditingController _maxProgramsController;

  final List<TextEditingController> _featureControllers = [];
  late bool _isActive;
  late Set<String> _selectedModules;

  // Available modules that can be granted access
  static const List<ModulePermission> availableModules = [
    ModulePermission(
      id: 'drills',
      name: 'Drills',
      description: 'Access to drill management',
      icon: Icons.sports_basketball,
    ),
    ModulePermission(
      id: 'profile',
      name: 'Profile',
      description: 'User profile management',
      icon: Icons.person,
    ),
    ModulePermission(
      id: 'stats',
      name: 'Statistics',
      description: 'View personal statistics',
      icon: Icons.bar_chart,
    ),
    ModulePermission(
      id: 'analysis',
      name: 'Analysis',
      description: 'Performance analysis tools',
      icon: Icons.analytics,
    ),
    ModulePermission(
      id: 'admin_drills',
      name: 'Admin Drills',
      description: 'Access to admin-created drills',
      icon: Icons.admin_panel_settings,
    ),
    ModulePermission(
      id: 'admin_programs',
      name: 'Admin Programs',
      description: 'Access to admin-created programs',
      icon: Icons.app_settings_alt,
    ),
    ModulePermission(
      id: 'programs',
      name: 'Programs',
      description: 'Create and manage training programs',
      icon: Icons.calendar_today,
    ),
    ModulePermission(
      id: 'multiplayer',
      name: 'Multiplayer',
      description: 'Multiplayer features and competitions',
      icon: Icons.groups,
    ),
    ModulePermission(
      id: 'user_management',
      name: 'User Management',
      description: 'Create and manage users (Institute only)',
      icon: Icons.people,
    ),
    ModulePermission(
      id: 'team_management',
      name: 'Team Management',
      description: 'Manage teams and groups',
      icon: Icons.group_work,
    ),
    ModulePermission(
      id: 'bulk_operations',
      name: 'Bulk Operations',
      description: 'Perform operations in bulk',
      icon: Icons.layers,
    ),
  ];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _planRepository = SubscriptionPlanRepository();

    // Initialize controllers with existing plan data or defaults
    _nameController = TextEditingController(text: widget.plan?.name ?? '');
    _descController =
        TextEditingController(text: widget.plan?.description ?? '');
    _priceController =
        TextEditingController(text: widget.plan?.price.toString() ?? '0');
    _billingPeriodController =
        TextEditingController(text: widget.plan?.billingPeriod ?? 'monthly');
    _priorityController =
        TextEditingController(text: widget.plan?.priority.toString() ?? '0');
    _maxDrillsController =
        TextEditingController(text: widget.plan?.maxDrills.toString() ?? '-1');
    _maxProgramsController = TextEditingController(
        text: widget.plan?.maxPrograms.toString() ?? '-1');

    _isActive = widget.plan?.isActive ?? true;
    _selectedModules = Set<String>.from(widget.plan?.moduleAccess ?? []);

    // Initialize feature controllers
    if (widget.plan != null && widget.plan!.features.isNotEmpty) {
      for (var feature in widget.plan!.features) {
        _featureControllers.add(TextEditingController(text: feature));
      }
    } else {
      _featureControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _billingPeriodController.dispose();
    _priorityController.dispose();
    _maxDrillsController.dispose();
    _maxProgramsController.dispose();
    for (var controller in _featureControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.plan == null ? 'Create Plan' : 'Edit Plan'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Basic Information Section
              _buildSection(
                title: 'Basic Information',
                icon: Icons.info_outline,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Plan Name',
                    icon: Icons.title,
                    required: true,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Plan name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _descController,
                    label: 'Description',
                    icon: Icons.description,
                    required: true,
                    maxLines: 3,
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Description is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _priceController,
                          label: 'Price',
                          icon: Icons.attach_money,
                          required: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Price is required';
                            }
                            if (double.tryParse(value!) == null) {
                              return 'Invalid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _billingPeriodController,
                          label: 'Billing Period',
                          icon: Icons.calendar_today,
                          required: true,
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Billing period is required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _priorityController,
                          label: 'Priority',
                          icon: Icons.priority_high,
                          required: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Priority is required';
                            }
                            if (int.tryParse(value!) == null) {
                              return 'Invalid priority';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('Active'),
                          value: _isActive,
                          onChanged: (value) =>
                              setState(() => _isActive = value),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Limits Section
              _buildSection(
                title: 'Limits',
                icon: Icons.speed,
                children: [
                  _buildTextField(
                    controller: _maxDrillsController,
                    label: 'Max Drills (-1 for unlimited)',
                    icon: Icons.sports_basketball,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d+')),
                    ],
                    helperText: 'Use -1 for unlimited drills',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _maxProgramsController,
                    label: 'Max Programs (-1 for unlimited)',
                    icon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d+')),
                    ],
                    helperText: 'Use -1 for unlimited programs',
                  ),
                ],
              ),

              // Module Access Section
              _buildSection(
                title: 'Module Access',
                icon: Icons.apps,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Select which modules users with this plan can access',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  ...availableModules.map((module) => _buildModuleCard(module)),
                ],
              ),

              // Features Section
              _buildSection(
                title: 'Features',
                icon: Icons.star_outline,
                children: [
                  ..._featureControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controller = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: controller,
                              label: 'Feature ${index + 1}',
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_featureControllers.length > 1)
                            IconButton(
                              onPressed: () => _removeFeature(index),
                              icon: const Icon(Icons.remove_circle_outline),
                              color: Colors.red,
                              tooltip: 'Remove feature',
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addFeature,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Feature'),
                  ),
                ],
              ),

              // Save Button
              Container(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _savePlan,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving
                          ? 'Saving...'
                          : (widget.plan == null ? 'Create Plan' : 'Save Changes'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        helperText: helperText,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
    );
  }

  Widget _buildModuleCard(ModulePermission module) {
    final isSelected = _selectedModules.contains(module.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleModule(module.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  module.icon,
                  color: isSelected ? Colors.blue : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.blue : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      module.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleModule(module.id),
                activeColor: Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleModule(String moduleId) {
    setState(() {
      if (_selectedModules.contains(moduleId)) {
        _selectedModules.remove(moduleId);
      } else {
        _selectedModules.add(moduleId);
      }
    });
  }

  void _addFeature() {
    setState(() {
      _featureControllers.add(TextEditingController());
    });
  }

  void _removeFeature(int index) {
    setState(() {
      _featureControllers[index].dispose();
      _featureControllers.removeAt(index);
    });
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate at least one module is selected
    if (_selectedModules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one module'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Collect features
      final features = _featureControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (features.isEmpty) {
        throw Exception('Please add at least one feature');
      }

      final plan = SubscriptionPlan(
        id: widget.plan?.id ?? _nameController.text.toLowerCase().replaceAll(' ', '_'),
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        price: double.parse(_priceController.text),
        billingPeriod: _billingPeriodController.text.trim(),
        features: features,
        moduleAccess: _selectedModules.toList(),
        maxDrills: int.parse(_maxDrillsController.text),
        maxPrograms: int.parse(_maxProgramsController.text),
        isActive: _isActive,
        priority: int.parse(_priorityController.text),
        createdAt: widget.plan?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.plan == null) {
        await _planRepository.createPlan(plan);
      } else {
        await _planRepository.updatePlan(plan);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.plan == null
                  ? 'Plan created successfully'
                  : 'Plan updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class ModulePermission {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  const ModulePermission({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}