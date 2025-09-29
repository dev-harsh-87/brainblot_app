import 'package:brainblot_app/features/settings/bloc/settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _sportCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sportCtrl.dispose();
    _goalsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state.status == SettingsStatus.loading || state.settings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = state.settings!;
          _nameCtrl.text = s.name;
          _sportCtrl.text = s.sport;
          _goalsCtrl.text = s.goals;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person)),
                onChanged: (_) => _onProfileChanged(context),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sportCtrl,
                decoration: const InputDecoration(labelText: 'Sport focus', prefixIcon: Icon(Icons.sports_soccer)),
                onChanged: (_) => _onProfileChanged(context),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _goalsCtrl,
                decoration: const InputDecoration(labelText: 'Goals', prefixIcon: Icon(Icons.flag)),
                onChanged: (_) => _onProfileChanged(context),
              ),
              const SizedBox(height: 16),
              const Text('Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SwitchListTile(
                value: s.sound,
                onChanged: (v) => context.read<SettingsBloc>().add(SettingsToggled(sound: v)),
                title: const Text('Sound on stimuli'),
                secondary: const Icon(Icons.volume_up),
              ),
              SwitchListTile(
                value: s.vibration,
                onChanged: (v) => context.read<SettingsBloc>().add(SettingsToggled(vibration: v)),
                title: const Text('Vibration'),
                secondary: const Icon(Icons.vibration),
              ),
              SwitchListTile(
                value: s.highBrightness,
                onChanged: (v) => context.read<SettingsBloc>().add(SettingsToggled(highBrightness: v)),
                title: const Text('High brightness during training'),
                secondary: const Icon(Icons.brightness_high),
              ),
              SwitchListTile(
                value: s.darkMode,
                onChanged: (v) => context.read<SettingsBloc>().add(SettingsToggled(darkMode: v)),
                title: const Text('Dark mode'),
                secondary: const Icon(Icons.dark_mode),
              ),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Colorblind mode'),
                trailing: DropdownButton<String>(
                  value: s.colorblindMode,
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None')),
                    DropdownMenuItem(value: 'protanopia', child: Text('Protanopia')),
                    DropdownMenuItem(value: 'deuteranopia', child: Text('Deuteranopia')),
                    DropdownMenuItem(value: 'tritanopia', child: Text('Tritanopia')),
                  ],
                  onChanged: (v) {
                    if (v != null) context.read<SettingsBloc>().add(SettingsColorblindChanged(v));
                  },
                ),
              ),
              SwitchListTile(
                value: s.notifications,
                onChanged: (v) => context.read<SettingsBloc>().add(SettingsToggled(notifications: v)),
                title: const Text('Push notifications'),
                secondary: const Icon(Icons.notifications),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onProfileChanged(BuildContext context) {
    context.read<SettingsBloc>().add(SettingsProfileChanged(
          name: _nameCtrl.text.trim(),
          sport: _sportCtrl.text.trim(),
          goals: _goalsCtrl.text.trim(),
        ));
  }
}
