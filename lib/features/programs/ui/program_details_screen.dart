import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:spark_app/core/ui/edge_to_edge.dart';
import 'package:spark_app/features/programs/services/drill_assignment_service.dart';
import 'package:spark_app/core/di/injection.dart';

import 'package:spark_app/features/programs/domain/program.dart';

class ProgramDetailsScreen extends StatefulWidget {
  final Program program;

  const ProgramDetailsScreen({
    super.key,
    required this.program,
  });

  @override
  State<ProgramDetailsScreen> createState() => _ProgramDetailsScreenState();
}

class _ProgramDetailsScreenState extends State<ProgramDetailsScreen> {
  final Map<String, String> _drillNames = {};
  bool _isLoadingDrills = false;

  @override
  void initState() {
    super.initState();
    _loadDrillNames();
  }

  Future<void> _loadDrillNames() async {
    setState(() => _isLoadingDrills = true);

    try {
      final drillService = getIt<DrillAssignmentService>();

      // Get unique drill IDs from both program days and dayWiseDrillIds
      final Set<String> drillIds = {};

      // From program days (old format)
      for (final day in widget.program.days) {
        if (day.drillId != null && day.drillId!.isNotEmpty) {
          drillIds.add(day.drillId!);
        }
      }

      // From dayWiseDrillIds (new enhanced format)
      for (final drillIdsList in widget.program.dayWiseDrillIds.values) {
        drillIds.addAll(drillIdsList);
      }

      // Load drill names
      for (final drillId in drillIds) {
        try {
          final drill = await drillService.getDrillById(drillId);
          if (drill != null && mounted) {
            setState(() {
              _drillNames[drillId] = drill.name;
            });
          }
        } catch (e) {
          // Skip if drill not found
          print('Error loading drill $drillId: $e');
        }
      }
    } catch (e) {
      print('Error loading drill names: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingDrills = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Set system UI for primary colored app bar
    EdgeToEdge.setPrimarySystemUI(context);
    return EdgeToEdgeScaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text(widget.program.name),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Program header
            Text(
              widget.program.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Program info chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(widget.program.category),
                  backgroundColor: colorScheme.primaryContainer,
                ),
                Chip(
                  label: Text(widget.program.level),
                  backgroundColor: colorScheme.secondaryContainer,
                ),
                Chip(
                  label: Text('${widget.program.durationDays} days'),
                  backgroundColor: colorScheme.tertiaryContainer,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Program schedule section
            Text(
              'Program Schedule',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Program days list
            if (widget.program.days.isEmpty &&
                widget.program.dayWiseDrillIds.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No days scheduled for this program',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              widget.program.days.isNotEmpty
                  ? _buildOldFormatDaysList(theme, colorScheme)
                  : _buildEnhancedFormatDaysList(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildOldFormatDaysList(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: widget.program.days.map((day) {
        final hasDrill = day.drillId != null && day.drillId!.isNotEmpty;
        final drillName = hasDrill ? _drillNames[day.drillId] : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: _buildDayListTile(
            theme,
            colorScheme,
            dayNumber: day.dayNumber,
            title: day.title,
            description: day.description,
            drillId: day.drillId,
            drillName: drillName,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEnhancedFormatDaysList(
      ThemeData theme, ColorScheme colorScheme,) {
    // Build list from dayWiseDrillIds
    final sortedDays = widget.program.dayWiseDrillIds.keys.toList()..sort();

    return Column(
      children: sortedDays.map((dayNumber) {
        final drillIds = widget.program.dayWiseDrillIds[dayNumber] ?? [];
        final hasDrill = drillIds.isNotEmpty;
        final drillId = hasDrill ? drillIds.first : null;
        final drillName = drillId != null ? _drillNames[drillId] : null;
        final drillCount = drillIds.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: _buildDayListTile(
            theme,
            colorScheme,
            dayNumber: dayNumber,
            title: 'Day $dayNumber',
            description: drillCount > 1
                ? '$drillCount drills assigned'
                : (hasDrill ? 'Training day' : 'Rest day'),
            drillId: drillId,
            drillName: drillName,
            drillCount: drillCount,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayListTile(
    ThemeData theme,
    ColorScheme colorScheme, {
    required int dayNumber,
    required String title,
    required String description,
    String? drillId,
    String? drillName,
    int drillCount = 1,
  }) {
    final hasDrill = drillId != null && drillId.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: hasDrill
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        child: Text(
          '$dayNumber',
          style: TextStyle(
            color: hasDrill ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (hasDrill) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 14,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    drillName ??
                        (_isLoadingDrills
                            ? 'Loading drill...'
                            : 'Drill assigned'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (drillCount > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2,),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+${drillCount - 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      trailing: hasDrill
          ? Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: colorScheme.primary,
            )
          : Icon(
              Icons.info_outline,
              size: 16,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
      onTap: hasDrill
          ? () {
              // Navigate to drill or day details
              // TODO: Implement navigation to specific drill/day
            }
          : null,
    );
  }
}

