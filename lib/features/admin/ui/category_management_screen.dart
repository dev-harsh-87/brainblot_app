import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:spark_app/features/drills/domain/drill_category.dart';
import 'package:spark_app/features/drills/data/drill_category_repository.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final DrillCategoryRepository _repository = DrillCategoryRepository();
  final _uuid = const Uuid();

  Future<void> _showCategoryBottomSheet({DrillCategory? category, List<DrillCategory>? existingCategories}) async {
    final displayNameController = TextEditingController(text: category?.displayName ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                category == null ? 'Add Category' : 'Edit Category',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Form
              Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (category == null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Category ID will be auto-generated',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (category == null) const SizedBox(height: 20),
                    
                    TextFormField(
                      controller: displayNameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'e.g., Soccer, Basketball',
                        helperText: 'Enter the display name for the category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a category name';
                        }
                        // Check for duplicate display names
                        if (category == null && existingCategories != null) {
                          final isDuplicate = existingCategories.any(
                            (cat) => cat.displayName.toLowerCase() == value.toLowerCase(),
                          );
                          if (isDuplicate) {
                            return 'A category with this name already exists';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
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
                    child: FilledButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(context, true);
                        }
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(category == null ? 'Add Category' : 'Update Category'),
                    ),
                  ),
                ],
              ),
              
              // Add some bottom padding for better spacing
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (category == null) {
          // Create new category with auto-generated ID
          final categoryId = _uuid.v4(); // Use UUID for guaranteed uniqueness
          final categoryName = displayNameController.text
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '_'); // Convert to safe format
          
          final newCategory = DrillCategory(
            id: categoryId,
            name: categoryName,
            displayName: displayNameController.text.trim(),
            order: existingCategories?.length ?? 0,
            createdBy: currentUser?.uid,
          );
          await _repository.createCategory(newCategory);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Category created successfully')),
            );
          }
        } else {
          // Update existing category
          final updatedCategory = category.copyWith(
            displayName: displayNameController.text.trim(),
          );
          await _repository.updateCategory(updatedCategory);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Category updated successfully')),
            );
          }
        }
        // No need to call _loadCategories() - StreamBuilder will automatically update
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleCategoryStatus(DrillCategory category) async {
    try {
      await _repository.toggleCategoryStatus(category.id, !category.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              category.isActive
                  ? 'Category deactivated'
                  : 'Category activated',
            ),
          ),
        );
      }
      // No need to call _loadCategories() - StreamBuilder will automatically update
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteCategory(DrillCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.displayName}"?\n\n'
          'This will soft-delete the category (mark as inactive). '
          'Existing drills will keep their category reference.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteCategory(category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted successfully')),
          );
        }
        // No need to call _loadCategories() - StreamBuilder will automatically update
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Management'),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: StreamBuilder<List<DrillCategory>>(
        stream: _repository.watchAllCategories(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading categories',
                    style: TextStyle(fontSize: 18, color: colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.6)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No categories yet',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first category to get started',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) async {
              // Create a mutable copy for reordering
              final reorderedCategories = List<DrillCategory>.from(categories);
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              final category = reorderedCategories.removeAt(oldIndex);
              reorderedCategories.insert(newIndex, category);
              
              try {
                await _repository.reorderCategories(reorderedCategories);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error reordering: $e')),
                  );
                }
              }
            },
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                key: ValueKey(category.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.drag_handle,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                  title: Text(
                    category.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: category.isActive
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  subtitle: Text(
                    category.name,
                    style: TextStyle(
                      color: category.isActive
                          ? colorScheme.onSurface.withOpacity(0.7)
                          : colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!category.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'INACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _showCategoryBottomSheet(category: category, existingCategories: categories);
                              break;
                            case 'toggle':
                              _toggleCategoryStatus(category);
                              break;
                            case 'delete':
                              _deleteCategory(category);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(category.isActive
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                const SizedBox(width: 8),
                                Text(category.isActive
                                    ? 'Deactivate'
                                    : 'Activate'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: AppTheme.errorColor),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: AppTheme.errorColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<List<DrillCategory>>(
        stream: _repository.watchAllCategories(),
        builder: (context, snapshot) {
          final categories = snapshot.data ?? [];
          return FloatingActionButton.extended(
            onPressed: () => _showCategoryBottomSheet(existingCategories: categories),
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
          );
        },
      ),
    );
  }
}