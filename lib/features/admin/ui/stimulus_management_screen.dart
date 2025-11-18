import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:spark_app/features/admin/domain/custom_stimulus.dart';
import 'package:spark_app/features/admin/services/custom_stimulus_service.dart';
import 'package:spark_app/features/admin/ui/create_stimulus_screen.dart';

class StimulusManagementScreen extends StatefulWidget {
  const StimulusManagementScreen({super.key});

  @override
  State<StimulusManagementScreen> createState() => _StimulusManagementScreenState();
}

class _StimulusManagementScreenState extends State<StimulusManagementScreen> {
  final CustomStimulusService _stimulusService = CustomStimulusService();
  final TextEditingController _searchController = TextEditingController();
  
  List<CustomStimulus> _allStimuli = [];
  List<CustomStimulus> _filteredStimuli = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  // Stream subscription for real-time updates
  Stream<List<CustomStimulus>>? _stimuliStream;
  StreamSubscription<List<CustomStimulus>>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _loadStimuli();
    // Set up real-time listener for better synchronization
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStimuli() async {
    setState(() => _isLoading = true);
    try {
      final stimuli = await _stimulusService.getAllCustomStimuli();
      setState(() {
        _allStimuli = stimuli;
        _filteredStimuli = stimuli;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stimuli: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterStimuli(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredStimuli = _allStimuli;
      } else {
        _filteredStimuli = _allStimuli.where((stimulus) =>
          stimulus.name.toLowerCase().contains(query.toLowerCase()) ||
          stimulus.description.toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }

  void _setupRealtimeListener() {
    _stimuliStream = _stimulusService.getCustomStimuliStream();
    _streamSubscription = _stimuliStream?.listen((stimuli) {
      if (mounted) {
        setState(() {
          _allStimuli = stimuli;
          _isLoading = false;
          // Reapply current filter
          _filterStimuli(_searchQuery);
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stimuli: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: Text(
          'Stimulus Management',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.primary.withOpacity(0.9),
                colorScheme.secondary.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search and Add Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: _filterStimuli,
                  decoration: InputDecoration(
                    hintText: 'Search stimuli...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterStimuli('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Add New Stimulus Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showCreateStimulusDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Stimulus'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stimuli List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStimuli.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadStimuli,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _filteredStimuli.length,
                          itemBuilder: (context, index) {
                            final stimulus = _filteredStimuli[index];
                            return _buildStimulusCard(stimulus);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 80,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No Custom Stimuli' : 'No Results Found',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty 
                ? 'Create your first custom stimulus to get started'
                : 'Try adjusting your search terms',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showCreateStimulusDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add New Stimulus'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStimulusCard(CustomStimulus stimulus) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStimulusTypeColor(stimulus.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStimulusTypeIcon(stimulus.type),
                    color: _getStimulusTypeColor(stimulus.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stimulus.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${stimulus.type.name.toUpperCase()} • ${stimulus.items.length} items',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(value, stimulus),
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
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy),
                          SizedBox(width: 8),
                          Text('Duplicate'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            if (stimulus.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                stimulus.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Preview of stimulus items
            _buildStimulusPreview(stimulus),

            const SizedBox(height: 16),

            // Footer
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  'Created ${_formatDate(stimulus.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStimulusPreview(CustomStimulus stimulus) {
    final sortedItems = _stimulusService.getSortedItems(stimulus.items);
    final previewItems = sortedItems.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview (${sortedItems.length} items)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: previewItems.map((item) => _buildPreviewChip(item, stimulus.type)).toList(),
          ),
          if (sortedItems.length > 8) ...[
            const SizedBox(height: 8),
            Text(
              '+${sortedItems.length - 8} more items',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewChip(CustomStimulusItem item, CustomStimulusType type) {
    switch (type) {
      case CustomStimulusType.image:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: item.imageBase64 != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.memory(
                    Uri.parse(item.imageBase64!).data!.contentAsBytes(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 20),
                  ),
                )
              : const Icon(Icons.image, size: 20),
        );
      case CustomStimulusType.color:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.color ?? Colors.grey,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
        );
      case CustomStimulusType.text:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Text(
            item.textValue ?? '',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        );
      case CustomStimulusType.shape:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: const Icon(Icons.category, size: 20, color: Colors.purple),
        );
    }
  }

  Color _getStimulusTypeColor(CustomStimulusType type) {
    switch (type) {
      case CustomStimulusType.image:
        return Colors.green;
      case CustomStimulusType.text:
        return Colors.blue;
      case CustomStimulusType.color:
        return Colors.orange;
      case CustomStimulusType.shape:
        return Colors.purple;
    }
  }

  IconData _getStimulusTypeIcon(CustomStimulusType type) {
    switch (type) {
      case CustomStimulusType.image:
        return Icons.image;
      case CustomStimulusType.text:
        return Icons.text_fields;
      case CustomStimulusType.color:
        return Icons.palette;
      case CustomStimulusType.shape:
        return Icons.category;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleMenuAction(String action, CustomStimulus stimulus) {
    switch (action) {
      case 'edit':
        _showEditStimulusDialog(stimulus);
        break;
      case 'duplicate':
        _duplicateStimulus(stimulus);
        break;
      case 'delete':
        _showDeleteConfirmation(stimulus);
        break;
    }
  }

  void _showCreateStimulusDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateStimulusScreen(
          onStimulusCreated: () {
            // No need to manually reload - real-time stream will handle it
            // Just show success message if needed
          },
        ),
      ),
    );
  }

  void _showEditStimulusDialog(CustomStimulus stimulus) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditStimulusScreen(
          stimulus: stimulus,
          onStimulusUpdated: () {
            // No need to manually reload - real-time stream will handle it
            // Just show success message if needed
          },
        ),
      ),
    );
  }

  void _duplicateStimulus(CustomStimulus stimulus) async {
    try {
      await _stimulusService.createCustomStimulus(
        name: '${stimulus.name} (Copy)',
        description: stimulus.description,
        type: stimulus.type,
        items: stimulus.items,
        createdBy: stimulus.createdBy,
      );
      
      // No need to manually reload - real-time stream will handle it
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stimulus duplicated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error duplicating stimulus: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(CustomStimulus stimulus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Stimulus'),
        content: Text('Are you sure you want to delete "${stimulus.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteStimulus(stimulus);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStimulus(CustomStimulus stimulus) async {
    try {
      await _stimulusService.deleteCustomStimulus(stimulus.id);
      
      // No need to manually update local state - real-time stream will handle it
      // This ensures consistency with the database
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stimulus removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      // If there's an actual error, show error message
      // The real-time stream will handle state synchronization
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting stimulus: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Edit Stimulus Screen - Full implementation
class EditStimulusScreen extends StatefulWidget {
  final CustomStimulus stimulus;
  final VoidCallback onStimulusUpdated;
  
  const EditStimulusScreen({
    super.key,
    required this.stimulus,
    required this.onStimulusUpdated,
  });

  @override
  State<EditStimulusScreen> createState() => _EditStimulusScreenState();
}

class _EditStimulusScreenState extends State<EditStimulusScreen> {
  final CustomStimulusService _stimulusService = CustomStimulusService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  
  late List<CustomStimulusItem> _items;
  bool _isLoading = false;
  bool _isUpdating = false;
  static const int _maxImages = 8;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.stimulus.name);
    _descriptionController = TextEditingController(text: widget.stimulus.description);
    _items = List.from(widget.stimulus.items);
  }

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
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        title: Text(
          'Edit Stimulus',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isUpdating ? null : _updateStimulus,
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
                    _buildBasicInfoSection(),
                    const SizedBox(height: 24),
                    _buildImagesSection(),
                  ],
                ),
              ),
            ),
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
            'No images in this stimulus',
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
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isUpdating ? null : () => Navigator.of(context).pop(),
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
              onPressed: _isUpdating ? null : _updateStimulus,
              child: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Stimulus'),
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
          backgroundColor: Colors.orange,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editImageItem(int index) async {
    final nameController = TextEditingController(text: _items[index].name);
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: _buildImagePreview(_items[index]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Image Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final imageFile = await _stimulusService.pickImageFromGallery();
                        if (imageFile != null) {
                          final newItem = await _stimulusService.createImageStimulusItem(
                            name: nameController.text.trim(),
                            imageFile: imageFile,
                            order: _items[index].order,
                          );
                          Navigator.of(context).pop({
                            'item': newItem,
                          });
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error changing image: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Change Image'),
                  ),
                ),
              ],
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
              Navigator.of(context).pop({
                'name': nameController.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
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
    
    nameController.dispose();
  }

  void _duplicateImageItem(int index) {
    if (_items.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot duplicate - maximum $_maxImages images allowed'),
          backgroundColor: Colors.orange,
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
        backgroundColor: Colors.green,
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

  Future<void> _updateStimulus() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one stimulus item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isUpdating = true);

    try {
      final updatedStimulus = widget.stimulus.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        items: _items,
        updatedAt: DateTime.now(),
      );

      await _stimulusService.updateCustomStimulus(updatedStimulus);

      if (mounted) {
        // Call the callback but don't rely on it for UI updates
        // The real-time stream will handle the updates
        widget.onStimulusUpdated();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stimulus updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating stimulus: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }
}