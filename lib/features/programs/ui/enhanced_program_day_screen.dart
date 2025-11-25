import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/features/programs/domain/program.dart';
import 'package:spark_app/features/programs/services/program_progress_service.dart';
import 'package:spark_app/features/programs/services/drill_assignment_service.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/core/theme/app_theme.dart';

class EnhancedProgramDayScreen extends StatefulWidget {
  final Program program;
  final int dayNumber;
  final ProgramProgress? progress;
  final ActiveProgram? activeProgram;

  const EnhancedProgramDayScreen({
    super.key,
    required this.program,
    required this.dayNumber,
    this.progress,
    this.activeProgram,
  });

  @override
  State<EnhancedProgramDayScreen> createState() => _EnhancedProgramDayScreenState();
}

class _EnhancedProgramDayScreenState extends State<EnhancedProgramDayScreen> {
  late final ProgramProgressService _progressService;
  late final DrillAssignmentService _drillService;
  
  List<Drill> _assignedDrills = [];
  bool _isLoading = true;
  bool _isCompleting = false;
  ProgramProgress? _progress;
  ActiveProgram? _activeProgram;
  Timer? _countdownTimer;
  Duration? _timeUntilUnlock;
  bool _isDayAccessible = false;
  List<bool> _drillCompletionStatus = [];

  @override
  void initState() {
    super.initState();
    _progressService = getIt<ProgramProgressService>();
    _drillService = getIt<DrillAssignmentService>();
    _progress = widget.progress;
    _activeProgram = widget.activeProgram;
    _loadDayData();
    _checkDayAccessibility();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _checkDayAccessibility() {
    if (_activeProgram != null) {
      _isDayAccessible = _activeProgram!.isDayAccessible(widget.dayNumber);
      _timeUntilUnlock = _activeProgram!.getTimeUntilDayUnlock(widget.dayNumber);
    } else {
      // If no active program, assume day 1 is accessible
      _isDayAccessible = widget.dayNumber == 1;
    }
  }

  void _startCountdownTimer() {
    if (!_isDayAccessible && _timeUntilUnlock != null && _timeUntilUnlock!.inSeconds > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _timeUntilUnlock = _activeProgram?.getTimeUntilDayUnlock(widget.dayNumber);
          if (_timeUntilUnlock == null || _timeUntilUnlock!.inSeconds <= 0) {
            _isDayAccessible = true;
            timer.cancel();
          }
        });
      });
    }
  }

  Future<void> _loadDayData() async {
    setState(() => _isLoading = true);

    try {
      // Load drills for this day from dayWiseDrillIds
      if (widget.program.dayWiseDrillIds.isNotEmpty) {
        print('🔍 DEBUG: Program ${widget.program.name} dayWiseDrillIds: ${widget.program.dayWiseDrillIds}');
        print('🔍 DEBUG: Looking for day ${widget.dayNumber} drills');
        
        final drillIds = widget.program.dayWiseDrillIds[widget.dayNumber];
        print('🔍 DEBUG: Found drill IDs for day ${widget.dayNumber}: $drillIds');

        if (drillIds != null && drillIds.isNotEmpty) {
          // Load all assigned drills for this day
          final drills = <Drill>[];
          for (final drillId in drillIds) {
            final drill = await _drillService.getDrillById(drillId);
            if (drill != null) {
              drills.add(drill);
            }
          }
          _assignedDrills = drills;
          _drillCompletionStatus = List.filled(drills.length, false);
          
          print('✅ Loaded ${drills.length} drills for day ${widget.dayNumber}');
        } else {
          print('ℹ️ No drills assigned to day ${widget.dayNumber}');
        }
      }
      
      // If no drills found, try to get recommended drills as fallback
      if (_assignedDrills.isEmpty) {
        print('ℹ️ Info: No drills assigned to day ${widget.dayNumber}, getting recommendations');
        final recommendedDrills = await _drillService.getRecommendedDrills(
          widget.program.category, 
          widget.program.level,
          limit: 3, // Get up to 3 recommended drills
        );
        if (recommendedDrills.isNotEmpty) {
          _assignedDrills = recommendedDrills;
          _drillCompletionStatus = List.filled(recommendedDrills.length, false);
          print('✅ Auto-assigned ${recommendedDrills.length} recommended drills');
        }
      }

      // Load latest progress if not provided
      _progress ??= await _progressService.getProgramProgress(widget.program.id);
    } catch (e) {
      print('❌ Error loading day data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeDrill(int drillIndex) async {
    if (drillIndex >= _drillCompletionStatus.length) return;
    
    setState(() {
      _drillCompletionStatus[drillIndex] = true;
    });

    // Check if all drills are completed
    if (_drillCompletionStatus.every((completed) => completed)) {
      await _completeProgramDay();
    }
  }

  Future<void> _completeProgramDay() async {
    if (_isCompleting) return;

    setState(() => _isCompleting = true);

    try {
      await _progressService.completeProgramDay(widget.program.id, widget.dayNumber);
      
      // Refresh progress
      _progress = await _progressService.getProgramProgress(widget.program.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Day ${widget.dayNumber} completed! 🎉'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );

        // Check if program is fully completed
        if (_progress?.isCompleted == true) {
          _showProgramCompletionDialog();
        } else {
          // Navigate back
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing day: $e'),
            backgroundColor: AppTheme.errorColor,
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
            Text(
              'You\'ve successfully finished all ${widget.program.durationDays} days of training!',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop(); // Go back to programs screen
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  String _formatCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Widget _buildCountdownWidget() {
    if (_timeUntilUnlock == null || _timeUntilUnlock!.inSeconds <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.schedule,
            size: 48,
            color: AppTheme.warningColor,
          ),
          const SizedBox(height: 12),
          Text(
            'Day ${widget.dayNumber} Unlocks In:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.warningColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCountdown(_timeUntilUnlock!),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.warningColor,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Complete the previous day and wait until midnight to unlock this day.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.warningColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDrillCard(Drill drill, int index) {
    final isCompleted = index < _drillCompletionStatus.length && _drillCompletionStatus[index];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.successColor : AppTheme.infoColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
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
                        drill.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (drill.description?.isNotEmpty == true)
                        Text(
                          drill.description!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (isCompleted)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Chip(
                  label: Text(drill.category),
                  backgroundColor: AppTheme.infoColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: AppTheme.infoColor),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(drill.difficulty.name.toUpperCase()),
                  backgroundColor: AppTheme.successColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: AppTheme.successColor),
                ),
                const Spacer(),
                if (!isCompleted)
                  ElevatedButton(
                    onPressed: () async {
                      // Navigate to drill runner
                      final result = await context.push('/drill-runner', extra: drill);
                      if (result == true) {
                        await _completeDrill(index);
                      }
                    },
                    child: const Text('Start Drill'),
                  )
                else
                  const Text(
                    'Completed ✓',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Day ${widget.dayNumber}'),
            Text(
              widget.program.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isDayAccessible
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCountdownWidget(),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'This day is locked. Complete the previous day and wait until midnight to unlock.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Day header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.infoColor.withOpacity(0.8), AppTheme.infoColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day ${widget.dayNumber}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_assignedDrills.length} drill${_assignedDrills.length != 1 ? 's' : ''} assigned',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                          if (_drillCompletionStatus.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _drillCompletionStatus.where((c) => c).length / _drillCompletionStatus.length,
                              backgroundColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_drillCompletionStatus.where((c) => c).length}/${_drillCompletionStatus.length} completed',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Drills list
                    Expanded(
                      child: _assignedDrills.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.fitness_center,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No drills assigned for this day',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Contact your trainer to add drills to this day.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _assignedDrills.length,
                              itemBuilder: (context, index) {
                                return _buildDrillCard(_assignedDrills[index], index);
                              },
                            ),
                    ),
                    
                    // Complete day button
                    if (_assignedDrills.isNotEmpty && _drillCompletionStatus.every((completed) => completed))
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton(
                          onPressed: _isCompleting ? null : _completeProgramDay,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isCompleting
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Completing Day...'),
                                  ],
                                )
                              : Text(
                                  'Complete Day ${widget.dayNumber} 🎉',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
    );
  }
}