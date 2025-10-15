import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:go_router/go_router.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  double? _prevBrightness;
  bool _highBrightness = true;
  Drill? _recommended;

  @override
  void initState() {
    super.initState();
    _enableHighVisibility();
    _loadRecommended();
  }

  Future<void> _enableHighVisibility() async {
    try {
      await WakelockPlus.enable();
      _prevBrightness = await ScreenBrightness().current;
      if (_highBrightness) {
        await ScreenBrightness().setScreenBrightness(1.0);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    if (_prevBrightness != null) {
      ScreenBrightness().setScreenBrightness(_prevBrightness!);
    }
    super.dispose();
  }

  Future<void> _loadRecommended() async {
    final repo = getIt<DrillRepository>();
    final list = await repo.fetchAll();
    setState(() {
      _recommended = list.isNotEmpty ? list.first : null;
    });
  }

  Future<void> _toggleBrightness(bool value) async {
    setState(() => _highBrightness = value);
    if (value) {
      await ScreenBrightness().setScreenBrightness(1.0);
    } else if (_prevBrightness != null) {
      await ScreenBrightness().setScreenBrightness(_prevBrightness!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Training')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.brightness_high, color: Colors.white70),
                const SizedBox(width: 8),
                const Text('High Brightness', style: TextStyle(color: Colors.white70)),
                const Spacer(),
                Switch(
                  value: _highBrightness,
                  onChanged: _toggleBrightness,
                )
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white10,
              child: ListTile(
                title: const Text('Quick Start', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  _recommended != null ? _recommended!.name : 'No drills available',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: FilledButton(
                  onPressed: _recommended == null ? null : () => context.go('/drill-runner', extra: _recommended),
                  child: const Text('Start'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/drills'),
              icon: const Icon(Icons.library_books),
              label: const Text('Browse Drill Library'),
            ),
            const Spacer(),
            const Text('Tip: Use Programs to follow structured training plans.', style: TextStyle(color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}
