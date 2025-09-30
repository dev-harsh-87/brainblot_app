import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:brainblot_app/features/programs/domain/program.dart';
import 'package:brainblot_app/features/programs/services/program_progress_service.dart';
import 'package:brainblot_app/features/programs/services/drill_assignment_service.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:brainblot_app/core/di/injection.dart';

class ProgramDayScreen extends StatefulWidget {
  final Program program;
  final int dayNumber;
  final ProgramProgress? progress;

  const ProgramDayScreen({
    super.key,
    required this.program,
    required this.dayNumber,
    this.progress,
  });

  @override
  State<ProgramDayScreen> createState() => _ProgramDayScreenState();
}

class _ProgramDayScreenState extends State<ProgramDayScreen> {
  late final ProgramProgressService _progressService;
  late final DrillAssignmentService _drillService;
  
  ProgramDay? _currentDay;
  Drill? _assignedDrill;
  bool _isLoading = true;
  bool _isCompleting = false;
  ProgramProgress? _progress;

  @override
  void initState() {
    super.initState();
    _progressService = getIt<ProgramProgressService>();
    _drillService = getIt<DrillAssignmentService>();
    _progress = widget.progress;
    _loadDayData();
  }

  Future<void> _loadDayData() async {
    setState(() => _isLoading = true);

    try {
      // Find the current day
      _currentDay = widget.program.days.firstWhere(
        (day) => day.dayNumber == widget.dayNumber,
      );

      // Load assigned drill if available
      if (_currentDay?.drillId != null) {
        _assignedDrill = await _drillService.getDrillById(_currentDay!.drillId!);
      }

      // Load latest progress if not provided
      if (_progress == null) {
        _progress = await _progressService.getProgramProgress(widget.program.id);
      }
    } catch (e) {
      print('❌ Error loading day data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeProgramDay() async {
    if (_isCompleting || _currentDay == null) return;

    setState(() => _isCompleting = true);

    try {
      await _progressService.completeProgramDay(widget.program.id, widget.dayNumber);
      
      // Refresh progress
      _progress = await _progressService.getProgramProgress(widget.program.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Day ${widget.dayNumber} completed! 🎉'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Check if program is fully completed
        if (_progress?.isCompleted == true) {
          _showProgramCompletionDialog();
        } else {
          // Navigate back or to next day
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing day: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isCompleting = false);
    }
  }

  void _showProgramCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 32),
            SizedBox(width: 12),
            Text('Program Completed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Congratulations! You\'ve completed the entire "${widget.program.name}" program.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Program Stats:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('• Total Days: ${widget.program.totalDays}'),
                  Text('• Category: ${widget.program.category}'),
                  Text('• Level: ${widget.program.level}'),
                  if (_progress != null)
                    Text('• Time Active: ${_formatDuration(_progress!.timeActive)}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/programs');
            },
            child: const Text('View Programs'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/programs');
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _navigateToDrill() {
    if (_assignedDrill == null) return;
    
    // Navigate to drill screen with the assigned drill
    context.push('/drills/practice', extra: {
      'drill': _assignedDrill,
      'fromProgram': true,
      'programId': widget.program.id,
      'dayNumber': widget.dayNumber,
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} days';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours';
    } else {
      return '${duration.inMinutes} minutes';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Day ${widget.dayNumber}'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentDay == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Day ${widget.dayNumber}'),
        ),
        body: const Center(
          child: Text('Day not found'),
        ),
      );
    }

    final isCompleted = _progress?.isDayCompleted(widget.dayNumber) ?? false;
    final canComplete = !isCompleted;
    final isCurrentDay = _progress?.currentDay == widget.dayNumber;

    return Scaffold(
      appBar: AppBar(
        title: Text('Day ${widget.dayNumber}'),
        actions: [
          if (isCompleted)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Program info header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.program.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.program.category.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_progress != null) ...[
                      LinearProgressIndicator(
                        value: _progress!.progressPercentage / 100,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Progress: ${_progress!.completedDays.length}/${_progress!.totalDays} days (${_progress!.progressPercentage.toStringAsFixed(1)}%)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Day details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCompleted 
                                ? Colors.green 
                                : isCurrentDay 
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check, color: Colors.white)
                                : Text(
                                    '${widget.dayNumber}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentDay!.title,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isCompleted)
                                Text(
                                  'Completed ✓',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else if (isCurrentDay)
                                Text(
                                  'Current Day',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentDay!.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Assigned drill section
            if (_assignedDrill != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.fitness_center,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Assigned Drill',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _assignedDrill!.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getDifficultyColor(_assignedDrill!.difficulty).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _assignedDrill!.difficulty.name.toUpperCase(),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: _getDifficultyColor(_assignedDrill!.difficulty),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Duration: ${_assignedDrill!.durationSec}s • Reps: ${_assignedDrill!.reps} • Difficulty: ${_assignedDrill!.difficulty.name}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _navigateToDrill,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Start Drill'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Completion section
            if (canComplete) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete This Day',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mark this day as completed to track your progress and unlock the next day.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isCompleting ? null : _completeProgramDay,
                          icon: _isCompleting 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle),
                          label: Text(_isCompleting ? 'Completing...' : 'Complete Day'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (isCompleted) ...[
              Card(
                color: Colors.green.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Day Completed!',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              'Great job! You\'ve completed this day.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
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
}
