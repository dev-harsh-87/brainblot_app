import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class DrillBuilderScreen extends StatefulWidget {
  final Drill? initial;
  const DrillBuilderScreen({super.key, this.initial});

  @override
  State<DrillBuilderScreen> createState() => _DrillBuilderScreenState();
}

class _DrillBuilderScreenState extends State<DrillBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late TextEditingController _name;
  String _category = 'fitness';
  Difficulty _difficulty = Difficulty.beginner;
  int _duration = 60;
  int _rest = 30;
  int _reps = 3;
  int _numberOfStimuli = 30;
  final Set<StimulusType> _stimuli = {StimulusType.color};
  final Set<ReactionZone> _zones = {ReactionZone.center};

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _name = TextEditingController(text: d?.name ?? 'Custom Drill');
    if (d != null) {
      _category = d.category;
      _difficulty = d.difficulty;
      _duration = d.durationSec;
      _rest = d.restSec;
      _reps = d.reps;
      _numberOfStimuli = d.numberOfStimuli;
      _stimuli
        ..clear()
        ..addAll(d.stimulusTypes);
      _zones
        ..clear()
        ..addAll(d.zones);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Drill _build() {
    return Drill(
      id: widget.initial?.id ?? _uuid.v4(),
      name: _name.text.trim(),
      category: _category,
      difficulty: _difficulty,
      durationSec: _duration,
      restSec: _rest,
      reps: _reps,
      stimulusTypes: _stimuli.toList(),
      numberOfStimuli: _numberOfStimuli,
      zones: _zones.toList(),
      colors: const [Colors.red, Colors.green, Colors.blue, Colors.yellow],
      isPreset: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'Create Drill' : 'Edit Drill')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              items: const [
                DropdownMenuItem(value: 'fitness', child: Text('Fitness')),
                DropdownMenuItem(value: 'soccer', child: Text('Soccer')),
                DropdownMenuItem(value: 'basketball', child: Text('Basketball')),
                DropdownMenuItem(value: 'hockey', child: Text('Hockey')),
                DropdownMenuItem(value: 'tennis', child: Text('Tennis')),
                DropdownMenuItem(value: 'volleyball', child: Text('Volleyball')),
                DropdownMenuItem(value: 'football', child: Text('Football')),
                DropdownMenuItem(value: 'lacrosse', child: Text('Lacrosse')),
                DropdownMenuItem(value: 'physiotherapy', child: Text('Physiotherapy')),
                DropdownMenuItem(value: 'agility', child: Text('Agility')),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'fitness'),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Difficulty>(
              value: _difficulty,
              items: Difficulty.values
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                  .toList(),
              onChanged: (v) => setState(() => _difficulty = v ?? Difficulty.beginner),
              decoration: const InputDecoration(labelText: 'Difficulty'),
            ),
            const SizedBox(height: 12),
            _NumField(label: 'Duration (sec)', value: _duration, onChanged: (v) => setState(() => _duration = v)),
            _NumField(label: 'Rest (sec)', value: _rest, onChanged: (v) => setState(() => _rest = v)),
            _NumField(label: 'Reps', value: _reps, onChanged: (v) => setState(() => _reps = v)),
            _NumField(label: 'Number of Stimuli', value: _numberOfStimuli, onChanged: (v) => setState(() => _numberOfStimuli = v)),
            const SizedBox(height: 12),
            const Text('Stimulus Types', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: StimulusType.values
                  .map((s) => FilterChip(
                        label: Text(s.name),
                        selected: _stimuli.contains(s),
                        onSelected: (sel) => setState(() => sel ? _stimuli.add(s) : _stimuli.remove(s)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Text('Reaction Zones', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: ReactionZone.values
                  .map((z) => FilterChip(
                        label: Text(z.name),
                        selected: _zones.contains(z),
                        onSelected: (sel) => setState(() => sel ? _zones.add(z) : _zones.remove(z)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(_build());
                }
              },
              child: Text(widget.initial == null ? 'Save' : 'Update'),
            )
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _NumField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter a number' : null,
      onChanged: (v) {
        final n = int.tryParse(v); if (n != null) onChanged(n);
      },
    );
  }
}
