import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:brainblot_app/features/settings/bloc/settings_bloc.dart';
import 'package:brainblot_app/features/settings/data/settings_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state.status == SettingsStatus.loading || state.settings == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading settings...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          final settings = state.settings!;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // App Preferences Section
              _buildSectionHeader(
                context,
                'App Preferences',
                Icons.tune_rounded,
                'Customize your training experience',
              ),
              const SizedBox(height: 16),
              _buildPreferencesCard(context, settings),
              const SizedBox(height: 32),

              // Accessibility Section
              _buildSectionHeader(
                context,
                'Accessibility',
                Icons.accessibility_new_rounded,
                'Visual and interaction settings',
              ),
              const SizedBox(height: 16),
              _buildAccessibilityCard(context, settings),
              const SizedBox(height: 32),

              // Notifications Section
              _buildSectionHeader(
                context,
                'Notifications',
                Icons.notifications_rounded,
                'Manage your alerts and reminders',
              ),
              const SizedBox(height: 16),
              _buildNotificationsCard(context, settings),
              const SizedBox(height: 32),

              // About Section
              _buildSectionHeader(
                context,
                'About',
                Icons.info_outline_rounded,
                'App information and support',
              ),
              const SizedBox(height: 16),
              _buildAboutCard(context),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    String description,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreferencesCard(BuildContext context, UserSettings settings) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            context,
            icon: Icons.volume_up_rounded,
            title: 'Sound Effects',
            subtitle: 'Audio feedback during training sessions',
            trailing: Switch.adaptive(
              value: settings.sound,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                context.read<SettingsBloc>().add(SettingsToggled(sound: value));
              },
            ),
          ),
          _buildDivider(colorScheme),
          _buildSettingsTile(
            context,
            icon: Icons.vibration_rounded,
            title: 'Haptic Feedback',
            subtitle: 'Vibration on taps and interactions',
            trailing: Switch.adaptive(
              value: settings.vibration,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                context.read<SettingsBloc>().add(SettingsToggled(vibration: value));
              },
            ),
          ),
          _buildDivider(colorScheme),
          _buildSettingsTile(
            context,
            icon: Icons.brightness_high_rounded,
            title: 'High Brightness',
            subtitle: 'Maximize screen brightness during drills',
            trailing: Switch.adaptive(
              value: settings.highBrightness,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                context.read<SettingsBloc>().add(SettingsToggled(highBrightness: value));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityCard(BuildContext context, UserSettings settings) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            context,
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            subtitle: 'Use dark theme throughout the app',
            trailing: Switch.adaptive(
              value: settings.darkMode,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                context.read<SettingsBloc>().add(SettingsToggled(darkMode: value));
              },
            ),
          ),
          _buildDivider(colorScheme),
          _buildSettingsTile(
            context,
            icon: Icons.visibility_rounded,
            title: 'Colorblind Support',
            subtitle: 'Adjust colors for better visibility',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: settings.colorblindMode,
                underline: const SizedBox(),
                isDense: true,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
                dropdownColor: colorScheme.surface,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('None')),
                  DropdownMenuItem(value: 'protanopia', child: Text('Protanopia')),
                  DropdownMenuItem(value: 'deuteranopia', child: Text('Deuteranopia')),
                  DropdownMenuItem(value: 'tritanopia', child: Text('Tritanopia')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    HapticFeedback.lightImpact();
                    context.read<SettingsBloc>().add(SettingsColorblindChanged(value));
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard(BuildContext context, UserSettings settings) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: _buildSettingsTile(
        context,
        icon: Icons.notifications_rounded,
        title: 'Push Notifications',
        subtitle: 'Receive training reminders and updates',
        trailing: Switch.adaptive(
          value: settings.notifications,
          onChanged: (value) {
            HapticFeedback.lightImpact();
            context.read<SettingsBloc>().add(SettingsToggled(notifications: value));
          },
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          _buildActionTile(
            context,
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            onTap: () {
              HapticFeedback.lightImpact();
              _showHelpDialog(context);
            },
          ),
          _buildDivider(colorScheme),
          _buildActionTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Learn how we protect your data',
            onTap: () {
              HapticFeedback.lightImpact();
              _showPrivacyDialog(context);
            },
          ),
          _buildDivider(colorScheme),
          _buildActionTile(
            context,
            icon: Icons.info_outline_rounded,
            title: 'About BrainBlot',
            subtitle: 'Version 1.0.0 • Made with ❤️',
            onTap: () {
              HapticFeedback.lightImpact();
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Divider(
      height: 1,
      thickness: 1,
      color: colorScheme.outline.withOpacity(0.1),
      indent: 56,
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'Need help with BrainBlot?\n\n'
          '• Check our FAQ section\n'
          '• Contact support: support@brainblot.com\n'
          '• Join our community forum\n\n'
          'We\'re here to help you improve your reaction time!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text(
          'Your privacy is important to us.\n\n'
          '• We only collect necessary training data\n'
          '• Your personal information is encrypted\n'
          '• Data is stored locally and securely\n'
          '• We never share your data with third parties\n\n'
          'For full details, visit our website.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'BrainBlot',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.psychology_rounded,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 32,
        ),
      ),
      children: [
        const Text(
          'BrainBlot helps athletes and fitness enthusiasts improve their reaction time, '
          'cognitive processing speed, and decision-making abilities through scientifically '
          'designed training drills.\n\n'
          'Train smarter, react faster, perform better.',
        ),
      ],
    );
  }
}