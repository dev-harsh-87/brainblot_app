import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DrillDetailScreen extends StatelessWidget {
  final Drill drill;
  const DrillDetailScreen({super.key, required this.drill});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(drill.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${drill.category.toUpperCase()} • ${drill.difficulty.name}'),
            const SizedBox(height: 8),
            Text('Duration: ${drill.durationSec}s   Reps: ${drill.reps}   Rest: ${drill.restSec}s'),
            const SizedBox(height: 8),
            Text('Stimuli: ${drill.stimulusTypes.map((e) => e.name).join(', ')}'),
            const Spacer(),
            FilledButton(
              onPressed: () => context.go('/drill-runner', extra: drill),
              child: const Text('Start Drill'),
            ),
          ],
        ),
      ),
    );
  }
}
