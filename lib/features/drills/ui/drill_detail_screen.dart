import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DrillDetailScreen extends StatelessWidget {
  final Drill drill;
  const DrillDetailScreen({super.key, required this.drill});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                drill.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getDifficultyColor(drill.difficulty).withOpacity(0.8),
                      _getDifficultyColor(drill.difficulty).withOpacity(0.4),
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
                          _getCategoryIcon(drill.category),
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 100,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          drill.difficulty.name.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getDifficultyColor(drill.difficulty),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  // TODO: Toggle favorite
                },
                icon: Icon(
                  drill.favorite ? Icons.favorite : Icons.favorite_border,
                  color: drill.favorite ? colorScheme.error : null,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      context.go('/drill-builder', extra: drill);
                      break;
                    case 'duplicate':
                      // TODO: Duplicate drill
                      break;
                    case 'share':
                      // TODO: Share drill
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          drill.category.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (drill.isPreset)
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
                          '${drill.durationSec}s',
                          colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          Icons.repeat,
                          'Repetitions',
                          '${drill.reps}x',
                          colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          Icons.pause,
                          'Rest',
                          '${drill.restSec}s',
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
                    children: drill.stimulusTypes.map((type) => _buildStimulusChip(context, type)).toList(),
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
                    child: _buildZoneVisualization(drill.zones),
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
                          onPressed: () => context.go('/drill-runner', extra: drill),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Preview drill
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text('Preview'),
                          style: OutlinedButton.styleFrom(
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
          _buildConfigRow(context, 'Number of Stimuli', '${drill.numberOfStimuli}'),
          const Divider(),
          _buildConfigRow(context, 'Colors Used', '${drill.colors.length} colors'),
          const Divider(),
          _buildConfigRow(context, 'Total Duration', '${(drill.durationSec * drill.reps + drill.restSec * (drill.reps - 1))}s'),
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
