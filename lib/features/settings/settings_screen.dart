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
  final _formKey = GlobalKey<FormState>();

  bool _hasInitialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sportCtrl.dispose();
    _goalsCtrl.dispose();
    super.dispose();
  }

  void _initializeControllers(SettingsState state) {
    if (!_hasInitialized && state.settings != null) {
      _nameCtrl.text = state.settings!.name;
      _sportCtrl.text = state.settings!.sport;
      _goalsCtrl.text = state.settings!.goals;
      _hasInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state.status == SettingsStatus.loading || state.settings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          _initializeControllers(state);
          final settings = state.settings!;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Profile', Icons.person_outline),
                const SizedBox(height: 16),
                _buildProfileCard(context, settings),
                const SizedBox(height: 24),

                _buildSectionHeader('Training Preferences', Icons.fitness_center),
                const SizedBox(height: 16),
                _buildPreferencesCard(context, settings),
                const SizedBox(height: 24),

                _buildSectionHeader('Accessibility', Icons.accessibility_new),
                const SizedBox(height: 16),
                _buildAccessibilityCard(context, settings),
                const SizedBox(height: 24),

                _buildSectionHeader('Notifications', Icons.notifications_outlined),
                const SizedBox(height: 16),
                _buildNotificationsCard(context, settings),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context, dynamic settings) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'Enter your name',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
            onChanged: (_) => _onProfileChanged(context),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sportCtrl,
            decoration: InputDecoration(
              labelText: 'Sport Focus',
              hintText: 'e.g., Soccer, Basketball',
              prefixIcon: const Icon(Icons.sports_soccer),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (_) => _onProfileChanged(context),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _goalsCtrl,
            decoration: InputDecoration(
              labelText: 'Training Goals',
              hintText: 'What do you want to achieve?',
              prefixIcon: const Icon(Icons.flag),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 2,
            onChanged: (_) => _onProfileChanged(context),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard(BuildContext context, dynamic settings) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            context,
            value: settings.sound as bool,
            onChanged: (v) => context.read<SettingsBloc>().add(SettingsToggled(sound: v)),
            title: 'Sound Effects',
            subtitle: 'Play sounds during stimuli',
            icon: Icons.volume_up,
          ),
          const Divider(height: 1),
          _buildSwitchTile(
            context,
            value: settings.vibration as bool,
            onChanged: (v) => context.read<SettingsBloc>().add(SettingsToggled(vibration: v)),
            title: 'Haptic Feedback',
            subtitle: 'Vibrate on interactions',
            icon: Icons.vibration,
          ),
          const Divider(height: 1),
          _buildSwitchTile(
            context,
            value: settings.highBrightness as bool,
            onChanged: (v) => context.read<SettingsBloc>().add(SettingsToggled(highBrightness: v)),
            title: 'High Brightness',
            subtitle: 'Maximize screen brightness during training',
            icon: Icons.brightness_high,
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityCard(BuildContext context, dynamic settings) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            context,
            value: settings.darkMode as bool,
            onChanged: (v) => context.read<SettingsBloc>().add(SettingsToggled(darkMode: v)),
            title: 'Dark Mode',
            subtitle: 'Use dark theme throughout the app',
            icon: Icons.dark_mode,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('Colorblind Mode'),
            subtitle: const Text('Adjust colors for better visibility'),
            trailing: DropdownButton<String>(
              value: settings.colorblindMode as String,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'protanopia', child: Text('Protanopia')),
                DropdownMenuItem(value: 'deuteranopia', child: Text('Deuteranopia')),
                DropdownMenuItem(value: 'tritanopia', child: Text('Tritanopia')),
              ],
              onChanged: (v) {
                if (v != null) {
                  context.read<SettingsBloc>().add(SettingsColorblindChanged(v));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard(BuildContext context, dynamic settings) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: _buildSwitchTile(
        context,
        value: settings.notifications as bool,
        onChanged: (v) => context.read<SettingsBloc>().add(SettingsToggled(notifications: v)),
        title: 'Push Notifications',
        subtitle: 'Receive reminders and updates',
        icon: Icons.notifications,
      ),
    );
  }

  Widget _buildSwitchTile(
      BuildContext context, {
        required bool value,
        required ValueChanged<bool> onChanged,
        required String title,
        required String subtitle,
        required IconData icon,
      }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      secondary: Icon(icon),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _onProfileChanged(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<SettingsBloc>().add(SettingsProfileChanged(
        name: _nameCtrl.text.trim(),
        sport: _sportCtrl.text.trim(),
        goals: _goalsCtrl.text.trim(),
      ));
    }
  }
}