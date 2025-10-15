import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:brainblot_app/features/sharing/ui/sharing_screen.dart';
import 'package:brainblot_app/features/sharing/ui/privacy_control_widget.dart';
import 'package:brainblot_app/features/sharing/services/sharing_service.dart';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/core/widgets/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class DrillDetailScreen extends StatefulWidget {
  final Drill drill;
  const DrillDetailScreen({super.key, required this.drill});

  @override
  State<DrillDetailScreen> createState() => _DrillDetailScreenState();
}

class _DrillDetailScreenState extends State<DrillDetailScreen> {
  late DrillRepository _drillRepository;
  late SharingService _sharingService;
  late Drill _currentDrill;
  bool _isLoading = false;
  bool _isOwner = false;
  bool _privacyLoading = false;

  @override
  void initState() {
    super.initState();
    _drillRepository = getIt<DrillRepository>();
    _sharingService = getIt<SharingService>();
    _currentDrill = widget.drill;
    _loadOwnershipInfo();
  }

  Future<void> _loadOwnershipInfo() async {
    try {
      print('🔍 Checking ownership for drill: ${_currentDrill.id}');
      final isOwner = await _sharingService.isOwner('drill', _currentDrill.id);
      print('👤 Ownership result: $isOwner');
      if (mounted) {
        setState(() => _isOwner = isOwner);
      }
    } catch (e) {
      // Ownership check failure shouldn't block the UI
      print('❌ Failed to check ownership: $e');
      // For custom drills, assume ownership if check fails
      if (!_currentDrill.isPreset && mounted) {
        setState(() => _isOwner = true);
      }
    }
  }

  Future<void> _togglePrivacy() async {
    if (!_isOwner) return;

    // Show confirmation dialog
    final confirmed = await ConfirmationDialog.showPrivacyConfirmation(
      context,
      isCurrentlyPublic: _currentDrill.isPublic,
      itemType: 'drill',
      itemName: _currentDrill.name,
    );

    if (confirmed != true) return;

    setState(() => _privacyLoading = true);
    
    try {
      await _sharingService.togglePrivacy('drill', _currentDrill.id, !_currentDrill.isPublic);
      
      if (mounted) {
        setState(() {
          _currentDrill = _currentDrill.copyWith(isPublic: !_currentDrill.isPublic);
          _privacyLoading = false;
        });
        
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _currentDrill.isPublic ? Icons.public : Icons.lock,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(_currentDrill.isPublic 
                    ? 'Drill is now public! 🌍'
                    : 'Drill is now private 🔒'),
              ],
            ),
            backgroundColor: _currentDrill.isPublic ? Colors.green : Colors.grey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _privacyLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update privacy: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _currentDrill.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getDifficultyColor(_currentDrill.difficulty).withOpacity(0.8),
                      _getDifficultyColor(_currentDrill.difficulty).withOpacity(0.4),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getCategoryIcon(_currentDrill.category),
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: _isLoading ? null : _toggleFavorite,
                icon: Icon(
                  _currentDrill.favorite ? Icons.favorite : Icons.favorite_border,
                  color: _currentDrill.favorite ? colorScheme.error : null,
                ),
              ),
              PrivacyToggleIconButton(
                isPublic: _currentDrill.isPublic,
                isOwner: _isOwner,
                onToggle: _isOwner && !_privacyLoading ? _togglePrivacy : null,
                isLoading: _privacyLoading,
              ),
              PopupMenuButton<String>(
                onSelected: _isLoading ? null : (value) {
                  switch (value) {
                    case 'edit':
                      _editDrill();
                      break;
                    case 'duplicate':
                      _duplicateDrill();
                      break;
                    case 'share':
                      _shareDrill();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (!_currentDrill.isPreset)
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
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 8),
                        Text('Share'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category and Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _currentDrill.category.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(_currentDrill.difficulty).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _getDifficultyColor(_currentDrill.difficulty).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _currentDrill.difficulty.name.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getDifficultyColor(_currentDrill.difficulty),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_currentDrill.isPreset)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'PRESET',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Quick Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          Icons.timer,
                          'Duration',
                          '${_currentDrill.durationSec}s',
                          colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          Icons.repeat,
                          'Repetitions',
                          '${_currentDrill.reps}x',
                          colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          Icons.pause,
                          'Rest',
                          '${_currentDrill.restSec}s',
                          colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Stimulus Types Section
                  Text(
                    'Stimulus Types',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _currentDrill.stimulusTypes.map((type) => _buildStimulusChip(context, type)).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  // Reaction Zones Section
                  Text(
                    'Reaction Zones',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                    ),
                    child: _buildZoneVisualization(_currentDrill.zones),
                  ),
                  const SizedBox(height: 24),
                  
                  // Configuration Details
                  Text(
                    'Configuration',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildConfigurationCard(context),
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () => context.push('/drill-runner', extra: _currentDrill),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Drill'),
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, IconData icon, String label, String value, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStimulusChip(BuildContext context, StimulusType type) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStimulusIcon(type), size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            type.name.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneVisualization(List<ReactionZone> zones) {
    return Stack(
      children: [
        // Background grid
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: CustomPaint(
            size: const Size(double.infinity, 200),
            painter: _ZoneVisualizationPainter(zones),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildConfigRow(context, 'Number of Stimuli', '${_currentDrill.numberOfStimuli}'),
          const Divider(),
          _buildConfigRow(context, 'Colors Used', '${_currentDrill.colors.length} colors'),
          const Divider(),
          _buildConfigRow(context, 'Total Duration', '${(_currentDrill.durationSec * _currentDrill.reps + _currentDrill.restSec * (_currentDrill.reps - 1))}s'),
        ],
      ),
    );
  }

  Widget _buildConfigRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Functionality Methods
  Future<void> _toggleFavorite() async {
    if (_isLoading) return;
    
    print('🔄 Toggling favorite for drill: ${_currentDrill.id}, current: ${_currentDrill.favorite}');
    setState(() => _isLoading = true);
    
    try {
      await _drillRepository.toggleFavorite(_currentDrill.id);
      setState(() {
        _currentDrill = _currentDrill.copyWith(favorite: !_currentDrill.favorite);
      });
      print('✅ Favorite toggled successfully, new state: ${_currentDrill.favorite}');
      
      // Refresh the drill library to update the UI
      try {
        final drillLibraryBloc = getIt<DrillLibraryBloc>();
        drillLibraryBloc.add(const DrillLibraryRefreshRequested());
      } catch (e) {
        // DrillLibraryBloc might not be available, that's okay
        print('DrillLibraryBloc not available for refresh: $e');
      }
      
      // Show feedback
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _currentDrill.favorite 
                ? 'Added to favorites' 
                : 'Removed from favorites',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editDrill() async {
    print('✏️ Editing drill: ${_currentDrill.id}, isPreset: ${_currentDrill.isPreset}, isOwner: $_isOwner');
    HapticFeedback.lightImpact();
    
    final editedDrill = await context.push<Drill>('/drill-builder', extra: _currentDrill);
    print('📝 Edit result: ${editedDrill != null ? "Success" : "Cancelled"}');
    
    if (editedDrill != null && mounted) {
      // Update the drill in the repository
      try {
        await _drillRepository.upsert(editedDrill);
        
        // Update the current drill state
        setState(() {
          _currentDrill = editedDrill;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drill updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update drill: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _duplicateDrill() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      HapticFeedback.lightImpact();
      
      // Create a copy with new ID and modified name
      final duplicatedDrill = _currentDrill.copyWith(
        id: const Uuid().v4(),
        name: '${_currentDrill.name} (Copy)',
        favorite: false,
        isPreset: false,
      );
      
      await _drillRepository.upsert(duplicatedDrill);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Drill duplicated successfully'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                context.pushReplacement('/drill-detail', extra: duplicatedDrill);
              },
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate drill: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareDrill() async {
    try {
      HapticFeedback.lightImpact();
      
      // Navigate to sharing screen
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SharingScreen(
            itemType: 'drill',
            itemId: _currentDrill.id,
            itemName: _currentDrill.name,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share drill: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getDifficultyColor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return Colors.green;
      case Difficulty.intermediate:
        return Colors.orange;
      case Difficulty.advanced:
        return Colors.red;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'soccer':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      case 'tennis':
        return Icons.sports_tennis;
      case 'fitness':
        return Icons.fitness_center;
      case 'hockey':
        return Icons.sports_hockey;
      case 'volleyball':
        return Icons.sports_volleyball;
      case 'football':
        return Icons.sports_football;
      default:
        return Icons.psychology;
    }
  }

  IconData _getStimulusIcon(StimulusType type) {
    switch (type) {
      case StimulusType.color:
        return Icons.palette;
      case StimulusType.shape:
        return Icons.category;
      case StimulusType.arrow:
        return Icons.arrow_forward;
      case StimulusType.number:
        return Icons.numbers;
      case StimulusType.audio:
        return Icons.volume_up;
    }
  }
}

class _ZoneVisualizationPainter extends CustomPainter {
  final List<ReactionZone> zones;

  _ZoneVisualizationPainter(this.zones);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final zone in zones) {
      switch (zone) {
        case ReactionZone.center:
          final rect = Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.3,
            height: size.height * 0.3,
          );
          canvas.drawOval(rect, paint);
          canvas.drawOval(rect, borderPaint);
          break;
        case ReactionZone.top:
          final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.25);
          canvas.drawRect(rect, paint);
          canvas.drawRect(rect, borderPaint);
          break;
        case ReactionZone.bottom:
          final rect = Rect.fromLTWH(0, size.height * 0.75, size.width, size.height * 0.25);
          canvas.drawRect(rect, paint);
          canvas.drawRect(rect, borderPaint);
          break;
        case ReactionZone.left:
          final rect = Rect.fromLTWH(0, 0, size.width * 0.25, size.height);
          canvas.drawRect(rect, paint);
          canvas.drawRect(rect, borderPaint);
          break;
        case ReactionZone.right:
          final rect = Rect.fromLTWH(size.width * 0.75, 0, size.width * 0.25, size.height);
          canvas.drawRect(rect, paint);
          canvas.drawRect(rect, borderPaint);
          break;
        case ReactionZone.quadrants:
          // Draw four quadrants
          final quadrants = [
            Rect.fromLTWH(0, 0, size.width / 2, size.height / 2),
            Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height / 2),
            Rect.fromLTWH(0, size.height / 2, size.width / 2, size.height / 2),
            Rect.fromLTWH(size.width / 2, size.height / 2, size.width / 2, size.height / 2),
          ];
          for (final quad in quadrants) {
            canvas.drawRect(quad, paint);
            canvas.drawRect(quad, borderPaint);
          }
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
