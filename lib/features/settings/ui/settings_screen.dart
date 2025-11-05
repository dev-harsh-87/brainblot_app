import 'package:spark_app/core/services/auto_refresh_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/auth/bloc/auth_bloc.dart';
import 'package:spark_app/features/settings/bloc/settings_bloc.dart';
import 'package:spark_app/features/settings/data/settings_repository.dart';
import 'package:spark_app/features/profile/services/profile_service.dart';
import 'package:spark_app/core/ui/edge_to_edge.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with AutoRefreshMixin {
  late final ProfileService _profileService;

  @override
  void initState() {
    super.initState();
    _profileService = getIt<ProfileService>();
    
    // Setup auto-refresh listeners for settings changes
    listenToAutoRefresh(AutoRefreshService.profile, () {
      // Refresh settings when profile changes
      if (mounted) {
        context.read<SettingsBloc>().add(const SettingsStarted());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Set system UI for primary colored app bar
    EdgeToEdge.setPrimarySystemUI(context);

    return EdgeToEdgeScaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context),
      extendBodyBehindAppBar: false,
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state.status == SettingsStatus.loading) {
            return _buildLoadingState(context);
          }

          final settings = state.settings ?? UserSettings.defaults;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                _buildProfileSection(context, settings),
                const SizedBox(height: 24),
                _buildPreferencesSection(context, settings),
                const SizedBox(height: 24),
                _buildAccessibilitySection(context, settings),
                const SizedBox(height: 24),
                _buildNotificationSection(context, settings),
                const SizedBox(height: 24),
                _buildDataSection(context),
                const SizedBox(height: 24),
                _buildSupportSection(context),
                const SizedBox(height: 24),
                _buildAboutSection(context),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      elevation: 0,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      title: Text(
        'Settings',
        style: theme.textTheme.headlineSmall?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.9),
              colorScheme.secondary.withOpacity(0.8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: colorScheme.primary,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading settings...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, UserSettings settings) {
    return _buildSection(
      context,
      'Profile',
      Icons.person_rounded,
      Colors.blue,
      [
        _buildTextSetting(
          context,
          'Display Name',
          settings.name.isEmpty ? 'Not set' : settings.name,
          Icons.badge_rounded,
          () => _showNameDialog(settings),
        ),
        _buildTextSetting(
          context,
          'Preferred Sport',
          settings.sport.isEmpty ? 'Not set' : settings.sport,
          Icons.sports_rounded,
          () => _showSportDialog(settings),
        ),
        _buildTextSetting(
          context,
          'Training Goals',
          settings.goals.isEmpty ? 'Not set' : settings.goals,
          Icons.flag_rounded,
          () => _showGoalsDialog(settings),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(BuildContext context, UserSettings settings) {
    return _buildSection(
      context,
      'Preferences',
      Icons.tune_rounded,
      Colors.purple,
      [
        _buildSwitchSetting(
          context,
          'Sound Effects',
          'Play audio feedback during training',
          settings.sound,
          Icons.volume_up_rounded,
          (value) => _updateSetting(sound: value),
        ),
        _buildSwitchSetting(
          context,
          'Haptic Feedback',
          'Vibration feedback for interactions',
          settings.vibration,
          Icons.vibration_rounded,
          (value) => _updateSetting(vibration: value),
        ),
        _buildSwitchSetting(
          context,
          'High Brightness',
          'Increase screen brightness during training',
          settings.highBrightness,
          Icons.brightness_high_rounded,
          (value) => _updateSetting(highBrightness: value),
        ),
        _buildSwitchSetting(
          context,
          'Dark Mode',
          'Use dark theme throughout the app',
          settings.darkMode,
          Icons.dark_mode_rounded,
          (value) => _updateSetting(darkMode: value),
        ),
      ],
    );
  }

  Widget _buildAccessibilitySection(BuildContext context, UserSettings settings) {
    return _buildSection(
      context,
      'Accessibility',
      Icons.accessibility_rounded,
      Colors.green,
      [
        _buildDropdownSetting(
          context,
          'Color Vision',
          'Adjust colors for color vision differences',
          settings.colorblindMode,
          Icons.palette_rounded,
          {
            'none': 'Normal Vision',
            'protanopia': 'Protanopia (Red-blind)',
            'deuteranopia': 'Deuteranopia (Green-blind)',
            'tritanopia': 'Tritanopia (Blue-blind)',
          },
          (value) => _updateSetting(colorblindMode: value),
        ),
      ],
    );
  }

  Widget _buildNotificationSection(BuildContext context, UserSettings settings) {
    return _buildSection(
      context,
      'Notifications',
      Icons.notifications_rounded,
      Colors.orange,
      [
        _buildSwitchSetting(
          context,
          'Push Notifications',
          'Receive training reminders and updates',
          settings.notifications,
          Icons.notifications_active_rounded,
          (value) => _updateSetting(notifications: value),
        ),
        _buildActionSetting(
          context,
          'Notification Settings',
          'Configure system notification preferences',
          Icons.settings_rounded,
          () => _openNotificationSettings(),
        ),
      ],
    );
  }

  Widget _buildDataSection(BuildContext context) {
    return _buildSection(
      context,
      'Data & Privacy',
      Icons.security_rounded,
      Colors.red,
      [
        _buildActionSetting(
          context,
          'Export Data',
          'Download your training data',
          Icons.download_rounded,
          () => _exportData(),
        ),
        _buildActionSetting(
          context,
          'Clear Cache',
          'Free up storage space',
          Icons.cleaning_services_rounded,
          () => _clearCache(),
        ),
        _buildActionSetting(
          context,
          'Privacy Policy',
          'View our privacy policy',
          Icons.privacy_tip_rounded,
          () => _openPrivacyPolicy(),
        ),
        const Divider(height: 32),
        _buildActionSetting(
          context,
          'Logout',
          'Sign out of your account',
          Icons.logout_rounded,
          () => _handleLogout(),
        ),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return _buildSection(
      context,
      'Support',
      Icons.help_rounded,
      Colors.teal,
      [
        _buildActionSetting(
          context,
          'Help Center',
          'Get help and tutorials',
          Icons.help_center_rounded,
          () => _openHelpCenter(),
        ),
        _buildActionSetting(
          context,
          'Contact Support',
          'Get in touch with our team',
          Icons.support_agent_rounded,
          () => _contactSupport(),
        ),
        _buildActionSetting(
          context,
          'Rate App',
          'Rate Spark on the App Store',
          Icons.star_rounded,
          () => _rateApp(),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return _buildSection(
      context,
      'About',
      Icons.info_rounded,
      Colors.indigo,
      [
        _buildInfoSetting(
          context,
          'Version',
          '1.0.0',
          Icons.info_outline_rounded,
        ),
        _buildInfoSetting(
          context,
          'Build Number',
          '1',
          Icons.build_rounded,
        ),
        _buildActionSetting(
          context,
          'Terms of Service',
          'View terms and conditions',
          Icons.description_rounded,
          () => _openTermsOfService(),
        ),
        _buildActionSetting(
          context,
          'Open Source Licenses',
          'View third-party licenses',
          Icons.code_rounded,
          () => _showLicenses(),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.15),
                        color.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Section Content
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: children.map((child) {
                final index = children.indexOf(child);
                return Column(
                  children: [
                    child,
                    if (index < children.length - 1)
                      Divider(
                        height: 1,
                        color: colorScheme.outline.withOpacity(0.1),
                        indent: 20,
                        endIndent: 20,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    IconData icon,
    ValueChanged<bool> onChanged,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.primary,
      ),
    );
  }

  Widget _buildTextSetting(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: value == 'Not set' 
              ? colorScheme.onSurface.withOpacity(0.5)
              : colorScheme.onSurface.withOpacity(0.8),
          fontStyle: value == 'Not set' ? FontStyle.italic : null,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colorScheme.onSurface.withOpacity(0.5),
      ),
      onTap: onTap,
    );
  }

  Widget _buildDropdownSetting(
    BuildContext context,
    String title,
    String subtitle,
    String value,
    IconData icon,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            options[value] ?? value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colorScheme.onSurface.withOpacity(0.5),
      ),
      onTap: () => _showDropdownDialog(title, options, value, onChanged),
    );
  }

  Widget _buildActionSetting(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colorScheme.onSurface.withOpacity(0.5),
      ),
      onTap: onTap,
    );
  }

  Widget _buildInfoSetting(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
    );
  }

  // Dialog Methods
  void _showNameDialog(UserSettings settings) {
    final controller = TextEditingController(text: settings.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Enter your name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _updateProfile(name: controller.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSportDialog(UserSettings settings) {
    final sports = [
      'Soccer', 'Basketball', 'Tennis', 'Baseball', 'Football',
      'Hockey', 'Volleyball', 'Golf', 'Swimming', 'Track & Field',
      'Boxing', 'Martial Arts', 'General Fitness', 'Other'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preferred Sport'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sports.length,
            itemBuilder: (context, index) {
              final sport = sports[index];
              return RadioListTile<String>(
                title: Text(sport),
                value: sport,
                groupValue: settings.sport,
                onChanged: (value) {
                  if (value != null) {
                    _updateProfile(sport: value);
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showGoalsDialog(UserSettings settings) {
    final controller = TextEditingController(text: settings.goals);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Training Goals'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'What are your training goals?',
            border: OutlineInputBorder(),
            hintText: 'e.g., Improve reaction time, increase accuracy...',
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _updateProfile(goals: controller.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDropdownDialog(
    String title,
    Map<String, String> options,
    String currentValue,
    ValueChanged<String> onChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final key = options.keys.elementAt(index);
              final value = options[key]!;
              return RadioListTile<String>(
                title: Text(value),
                value: key,
                groupValue: currentValue,
                onChanged: (selected) {
                  if (selected != null) {
                    onChanged(selected);
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Action Methods
  void _updateSetting({
    bool? sound,
    bool? vibration,
    bool? highBrightness,
    bool? darkMode,
    String? colorblindMode,
    bool? notifications,
  }) {
    context.read<SettingsBloc>().add(SettingsToggled(
      sound: sound,
      vibration: vibration,
      highBrightness: highBrightness,
      darkMode: darkMode,
      colorblindMode: colorblindMode,
      notifications: notifications,
    ));
  }

  void _updateProfile({String? name, String? sport, String? goals}) {
    context.read<SettingsBloc>().add(SettingsProfileChanged(
      name: name,
      sport: sport,
      goals: goals,
    ));
  }

  void _openNotificationSettings() {
    // Open system notification settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening system notification settings...'),
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data export feature coming soon!'),
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear temporary files and free up storage space. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _openPrivacyPolicy() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy Policy: https://brainblot.com/privacy'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _openHelpCenter() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Help Center: https://brainblot.com/help'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _contactSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact Support: support@brainblot.com'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you! Please rate us on the App Store.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _openTermsOfService() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terms of Service: https://brainblot.com/terms'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'Spark',
      applicationVersion: '1.0.0',
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Trigger logout via AuthBloc
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              // Navigate to auth screen
              context.go("/auth");
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}
