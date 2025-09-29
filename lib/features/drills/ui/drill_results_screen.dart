import 'package:brainblot_app/features/drills/domain/session_result.dart';
import 'package:flutter/material.dart';

class DrillResultsScreen extends StatelessWidget {
  final SessionResult result;
  const DrillResultsScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final drill = result.drill;
    return Scaffold(
      appBar: AppBar(title: const Text('Session Summary')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(drill.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Duration: ${(result.durationMs / 1000).toStringAsFixed(2)}s'),
            const SizedBox(height: 8),
            Text('Stimuli: ${result.totalStimuli}'),
            const SizedBox(height: 8),
            Text('Hits: ${result.hits}  •  Misses: ${result.misses}  •  Acc: ${(result.accuracy * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            Text('Avg RT: ${result.avgReactionMs.toStringAsFixed(0)} ms'),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
