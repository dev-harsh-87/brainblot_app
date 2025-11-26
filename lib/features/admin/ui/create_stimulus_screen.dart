import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:spark_app/features/admin/domain/custom_stimulus.dart';
import 'package:spark_app/features/admin/services/custom_stimulus_service.dart';
import 'package:spark_app/core/theme/app_theme.dart';

class CreateStimulusScreen extends StatefulWidget {
  final VoidCallback onStimulusCreated;
  
  const CreateStimulusScreen({super.key, required this.onStimulusCreated});

  @override
  State<CreateStimulusScreen> createState() => _CreateStimulusScreenState();
}

class _CreateStimulusScreenState extends State<CreateStimulusScreen> {
  final CustomStimulusService _stimulusService = CustomStimulusService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final CustomStimulusType _selectedType = CustomStimulusType.image; // Fixed to image only
  List<CustomStimulusItem> _items = [];
  bool _isLoading = false;
  bool _isCreating = false;
  static const int _maxImages = 8; // Maximum number of images allowed

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
                iconTheme: IconThemeData(
          color: colorScheme.onPrimary,
        ),
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: Text(
          'Create Custom Stimulus',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createStimulus,
            child: Text(
              'Save',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    _buildBasicInfoSection(),
                    const SizedBox(height: 24),
                    
                    // Images Section (removed type selection since only images are supported)
                    _buildImagesSection(),
                  ],
                ),
              ),
            ),
            
            // Bottom Actions
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Name Field
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Stimulus Name',
              hintText: 'Enter a descriptive name',
              prefixIcon: const Icon(Icons.psychology),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a stimulus name';
              }
              if (value.trim().length < 3) {
                return 'Name must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Description Field
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Describe what this stimulus is for',
              prefixIcon: const Icon(Icons.description),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Images (${_items.length}/$_maxImages)',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _items.length >= _maxImages ? null : _addImageItem,
                icon: const Icon(Icons.add_photo_alternate, size: 18),
                label: const Text('Add Image'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_items.isEmpty)
            _buildEmptyImagesState()
          else
            _buildImagesList(),
        ],
      ),
    );
  }

  Widget _buildEmptyImagesState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 48,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No images added yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add up to $_maxImages images that will be displayed as visual stimuli',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addImageItem,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add First Image'),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesList() {
    return Column(
      children: _items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _buildItemCard(item, index);
      }).toList(),
    );
  }

  Widget _buildItemCard(CustomStimulusItem item, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Image Preview
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
              ),
              child: _buildImagePreview(item),
            ),
            const SizedBox(width: 16),
            
            // Item Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Item ${index + 1}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _editImageItem(index),
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Edit Image',
                ),
                IconButton(
                  onPressed: () => _duplicateImageItem(index),
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Duplicate Image',
                ),
                IconButton(
                  onPressed: () => _removeImageItem(index),
                  icon: Icon(Icons.delete, size: 20, color: context.colors.error),
                  tooltip: 'Delete Image',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(CustomStimulusItem item) {
    if (item.imageBase64 != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.memory(
          Uri.parse(item.imageBase64!).data!.contentAsBytes(),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 24),
        ),
      );
    }
    return const Icon(Icons.image, size: 24);
  }

  Widget _buildBottomActions() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: context.colors.onSurface.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _isCreating || _items.isEmpty ? null : _createStimulus,
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Stimulus'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addImageItem() async {
    if (_items.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $_maxImages images allowed'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }
    try {
      final imageFile = await _stimulusService.pickImageFromGallery();
      if (imageFile != null) {
        final item = await _stimulusService.createImageStimulusItem(
          name: 'Image ${_items.length + 1}',
          imageFile: imageFile,
          order: _items.length,
        );
        setState(() {
          _items.add(item);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding image: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  void _editImageItem(int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditImageDialog(
        item: _items[index],
        onImageChanged: (imageFile) async {
          if (imageFile != null) {
            return await _stimulusService.createImageStimulusItem(
              name: _items[index].name,
              imageFile: imageFile,
              order: _items[index].order,
            );
          }
          return null;
        },
      ),
    );

    if (result != null) {
      setState(() {
        if (result['name'] != null) {
          _items[index] = _items[index].copyWith(name: result['name'] as String);
        }
        if (result['item'] != null) {
          _items[index] = result['item'] as CustomStimulusItem;
        }
      });
    }
  }

  void _duplicateImageItem(int index) {
    if (_items.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot duplicate - maximum $_maxImages images allowed'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final originalItem = _items[index];
    final duplicatedItem = originalItem.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${originalItem.name} (Copy)',
      order: _items.length,
    );

    setState(() {
      _items.add(duplicatedItem);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image duplicated successfully'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _removeImageItem(int index) {
    setState(() {
      _items.removeAt(index);
      // Update order for remaining items
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(order: i);
      }
    });
  }

  Future<void> _createStimulus() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add at least one stimulus item'),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      await _stimulusService.createCustomStimulus(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        items: _items,
        createdBy: 'admin', // This should come from auth service
      );

      if (mounted) {
        // Call the callback but don't rely on it for UI updates
        // The real-time stream will handle the updates
        widget.onStimulusCreated();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom stimulus created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating stimulus: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}

// Dialog for editing image items
class _EditImageDialog extends StatefulWidget {
  final CustomStimulusItem item;
  final Future<CustomStimulusItem?> Function(File?) onImageChanged;

  const _EditImageDialog({
    required this.item,
    required this.onImageChanged,
  });

  @override
  State<_EditImageDialog> createState() => _EditImageDialogState();
}

class _EditImageDialogState extends State<_EditImageDialog> {
  late final TextEditingController _nameController;
  final CustomStimulusService _stimulusService = CustomStimulusService();
  bool _isLoading = false;
  CustomStimulusItem? _updatedItem;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Edit Image'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current Image Preview
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: (_updatedItem?.imageBase64 ?? widget.item.imageBase64) != null
                  ? Image.memory(
                      Uri.parse(_updatedItem?.imageBase64 ?? widget.item.imageBase64!).data!.contentAsBytes(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, size: 48),
                    )
                  : const Icon(Icons.image, size: 48),
            ),
          ),
          const SizedBox(height: 16),
          
          // Change Image Button
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _changeImage,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library),
            label: const Text('Change Image'),
          ),
          const SizedBox(height: 16),
          
          // Name Field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Image Name',
              hintText: 'Enter a descriptive name',
              prefixIcon: Icon(Icons.label),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final result = <String, dynamic>{};
            if (_nameController.text.trim() != widget.item.name) {
              result['name'] = _nameController.text.trim();
            }
            if (_updatedItem != null) {
              result['item'] = _updatedItem;
            }
            Navigator.of(context).pop(result.isNotEmpty ? result : null);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _changeImage() async {
    setState(() => _isLoading = true);
    
    try {
      final imageFile = await _stimulusService.pickImageFromGallery();
      if (imageFile != null) {
        final newItem = await widget.onImageChanged(imageFile);
        if (newItem != null) {
          setState(() {
            _updatedItem = newItem.copyWith(
              id: widget.item.id,
              name: _nameController.text.trim(),
              order: widget.item.order,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing image: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}