import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/features/drills/data/drill_repository.dart';
import 'package:spark_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:spark_app/features/sharing/ui/sharing_screen.dart';
import 'package:spark_app/features/sharing/ui/privacy_control_widget.dart';
import 'package:spark_app/features/sharing/services/sharing_service.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/core/widgets/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:convert';
import 'package:spark_app/core/widgets/profile_avatar.dart';
import 'package:spark_app/features/profile/services/profile_service.dart';
import 'package:spark_app/features/sharing/domain/user_profile.dart';

class DrillDetailScreen extends StatefulWidget {
  final Drill drill;
  const DrillDetailScreen({super.key, required this.drill});

  @override
  State<DrillDetailScreen> createState() => _DrillDetailScreenState();
}

class _DrillDetailScreenState extends State<DrillDetailScreen> with WidgetsBindingObserver {
  late DrillRepository _drillRepository;
  late SharingService _sharingService;
  late ProfileService _profileService;
  late Drill _currentDrill;
  UserProfile? _userProfile;
  bool _isLoading = false;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drillRepository = getIt<DrillRepository>();
    _sharingService = getIt<SharingService>();
    _profileService = getIt<ProfileService>();
    _currentDrill = widget.drill;
    _loadOwnershipInfo();
    _loadUserProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh drill data when app is resumed
      try {
        final drillLibraryBloc = getIt<DrillLibraryBloc>();
        drillLibraryBloc.add(const DrillLibraryRefreshRequested());
      } catch (e) {
        // Bloc might not be available
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _profileService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
    }
  }

  Future<void> _loadOwnershipInfo() async {
    try {
      final isOwner = await _sharingService.isOwner('drill', _currentDrill.id);
      if (mounted) {
        setState(() => _isOwner = isOwner);
      }
    } catch (e) {
      if (!_currentDrill.isPreset && mounted) {
        setState(() => _isOwner = true);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh the drill library bloc when returning to this screen
    try {
      final drillLibraryBloc = getIt<DrillLibraryBloc>();
      drillLibraryBloc.add(const DrillLibraryRefreshRequested());
    } catch (e) {
      // Bloc might not be available
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasMedia = _currentDrill.videoUrl != null || _currentDrill.stepImageUrl != null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: colorScheme.primary,
          ),
        ),
        title: Text(
          _currentDrill.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            iconColor: colorScheme.onPrimary,
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
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media Section (Full Width)
                if (hasMedia) _buildFullWidthMediaSection(),
                
                // Content Section
                Padding(
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
                      const SizedBox(height: 24),
                      
                      // Tags Section
                      if (_currentDrill.tags.isNotEmpty) ...[
                        Text(
                          'Tags',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _currentDrill.tags.map((tag) => _buildTagChip(context, tag)).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Sharing Information
                      if (_currentDrill.sharedWith.isNotEmpty) ...[
                        Text(
                          'Sharing Information',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSharingInfoCard(context),
                        const SizedBox(height: 24),
                      ],
                      
                      // Creation Details
                      Text(
                        'Creation Details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCreationDetailsCard(context),
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
              ],
            ),
          ),
          // Loading overlay
          if (_isLoading)
            Container(
              color: colorScheme.surface.withOpacity(0.8),
              child: Center(
                child: Card(
                  color: colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: colorScheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Processing...',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
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

  Widget _buildFullWidthMediaSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final hasVideo = _currentDrill.videoUrl != null;
    final hasImage = _currentDrill.stepImageUrl != null;
    
    if (!hasVideo && !hasImage) {
      return const SizedBox.shrink();
    }

    // If only one media type exists, show it directly
    if (hasVideo && !hasImage) {
      return SizedBox(
        height: 300,
        width: double.infinity,
        child: _buildVideoPlayer(),
      );
    }
    
    if (!hasVideo && hasImage) {
      return SizedBox(
        height: 300,
        width: double.infinity,
        child: _buildImageDisplay(),
      );
    }

    // If both exist, show tabbed interface
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab selector
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_outline, size: 18),
                      SizedBox(width: 6),
                      Text('Video'),
                    ],
                  ),
                ),
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Image'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          SizedBox(
            height: 300,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TabBarView(
                children: [
                  _buildVideoPlayer(),
                  _buildImageDisplay(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final videoId = YoutubePlayer.convertUrlToId(_currentDrill.videoUrl ?? '');
    
    if (videoId == null) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Invalid YouTube URL',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
      ),
    );

    return YoutubePlayer(
      controller: controller,
      showVideoProgressIndicator: true,
      progressIndicatorColor: colorScheme.primary,
      progressColors: ProgressBarColors(
        playedColor: colorScheme.primary,
        handleColor: colorScheme.primaryContainer,
        bufferedColor: colorScheme.primaryContainer.withOpacity(0.3),
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
      bottomActions: [
        CurrentPosition(),
        ProgressBar(isExpanded: true),
        RemainingDuration(),
        const PlaybackSpeedButton(),
      ],
    );
  }

  Widget _buildImageDisplay() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = _currentDrill.stepImageUrl;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No image available',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildImageFromBase64(imageUrl);
  }

  Widget _buildImageFromBase64(String base64String) {
    try {
      String cleanBase64 = base64String;
      if (base64String.contains('base64,')) {
        cleanBase64 = base64String.split('base64,')[1];
      }
      
      final imageBytes = base64Decode(cleanBase64);
      
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load image',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to decode image',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      );
    }
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
          _buildConfigRow(context, 'Drill Mode', _currentDrill.drillMode.name.toUpperCase()),
          const Divider(),
          _buildConfigRow(context, 'Presentation Mode', _currentDrill.presentationMode.name.toUpperCase()),
          const Divider(),
          _buildConfigRow(context, 'Number of Sets', '${_currentDrill.sets}'),
          const Divider(),
          _buildConfigRow(context, 'Number of Stimuli', '${_currentDrill.numberOfStimuli}'),
          const Divider(),
          _buildConfigRow(context, 'Stimulus Length', '${_currentDrill.stimulusLengthMs}ms'),
          const Divider(),
          _buildConfigRow(context, 'Delay Between Stimuli', '${_currentDrill.delayBetweenStimuliMs}ms'),
          const Divider(),
          _buildConfigRow(context, 'Colors Used', '${_currentDrill.colors.length} colors'),
          const Divider(),
          _buildConfigRow(context, 'Arrow Directions', '${_currentDrill.arrows.length} directions'),
          const Divider(),
          _buildConfigRow(context, 'Shape Types', '${_currentDrill.shapes.length} shapes'),
          const Divider(),
          _buildConfigRow(context, 'Number Range', _currentDrill.numberRange.name.toUpperCase()),
          const Divider(),
          _buildConfigRow(context, 'Drill Type', _currentDrill.type.toUpperCase()),
          const Divider(),
          _buildConfigRow(context, 'Visibility', _currentDrill.visibility.toUpperCase()),
          const Divider(),
          _buildConfigRow(context, 'Status', _currentDrill.status.toUpperCase()),
          const Divider(),
          _buildConfigRow(context, 'Created By Role', _currentDrill.createdByRole.toUpperCase()),
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

  Future<void> _editDrill() async {
    HapticFeedback.lightImpact();
    
    final editedDrill = await context.push<Drill>('/drill-builder', extra: _currentDrill);
    
    if (editedDrill != null && mounted) {
      try {
        await _drillRepository.upsert(editedDrill);
        
        setState(() {
          _currentDrill = editedDrill;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Drill updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
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
        return AppTheme.successColor;
      case Difficulty.intermediate:
        return AppTheme.warningColor;
      case Difficulty.advanced:
        return AppTheme.errorColor;
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
      case StimulusType.custom:
        return Icons.extension;
    }
  }

  Widget _buildTagChip(BuildContext context, String tag) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.infoColor.withOpacity(0.3),
        ),
      ),
      child: Text(
        tag.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppTheme.infoColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSharingInfoCard(BuildContext context) {
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
          _buildConfigRow(context, 'Shared With', '${_currentDrill.sharedWith.length} users'),
          const Divider(),
          _buildConfigRow(context, 'Visibility', _currentDrill.visibility.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildCreationDetailsCard(BuildContext context) {
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
          _buildConfigRow(context, 'Created By', _currentDrill.createdBy ?? 'Unknown'),
          const Divider(),
          _buildConfigRow(context, 'Creator Role', _currentDrill.createdByRole.toUpperCase()),
          const Divider(),
          _buildConfigRow(context, 'Created At', _formatDate(_currentDrill.createdAt)),
          const Divider(),
          _buildConfigRow(context, 'Status', _currentDrill.status.toUpperCase()),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ZoneVisualizationPainter extends CustomPainter {
  final List<ReactionZone> zones;

  _ZoneVisualizationPainter(this.zones);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.infoColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppTheme.infoColor
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
