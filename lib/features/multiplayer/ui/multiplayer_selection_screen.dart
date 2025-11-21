import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Screen for selecting between hosting or joining a multiplayer session
class MultiplayerSelectionScreen extends StatefulWidget {
  const MultiplayerSelectionScreen({super.key});

  @override
  State<MultiplayerSelectionScreen> createState() => _MultiplayerSelectionScreenState();
}

class _MultiplayerSelectionScreenState extends State<MultiplayerSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ),);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ),);

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Multiplayer Training',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 18 : 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildContent(context),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final padding = isSmallScreen ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          _buildHeader(context),
          SizedBox(height: isSmallScreen ? 24 : 40),

          // Selection Cards
          _buildSelectionCards(context),
          SizedBox(height: isSmallScreen ? 24 : 32),

          // Condensed Info Section with button to expand
          _buildCondensedInfoSection(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.3),
            colorScheme.secondaryContainer.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.people_rounded,
                  color: colorScheme.primary,
                  size: isSmallScreen ? 24 : 28,
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Train Together',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 20 : null,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect with friends and train simultaneously',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: isSmallScreen ? 13 : null,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCards(BuildContext context) {
    return Column(
      children: [
        _buildSelectionCard(
          context,
          title: 'Host Session',
          subtitle: 'Create a new training session and invite others',
          icon: Icons.wifi_tethering_rounded,
          color: Colors.blue,
          onTap: () => _navigateToHostScreen(context),
          features: [
            'Generate session code',
            'Control drill timing',
            'Manage participants',
            'Start/stop drills for everyone',
          ],
        ),
        const SizedBox(height: 20),
        _buildSelectionCard(
          context,
          title: 'Join Session',
          subtitle: 'Enter a session code to join an existing session',
          icon: Icons.login_rounded,
          color: Colors.green,
          onTap: () => _navigateToJoinScreen(context),
          features: [
            'Enter session code',
            'Follow host\'s drill timing',
            'Train simultaneously',
            'Chat with participants',
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required List<String> features,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isSmallScreen ? 28 : 32,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 18 : null,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: isSmallScreen ? 12 : null,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color,
                  size: isSmallScreen ? 16 : 20,
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 20),
            
            // Features
            ...features.map((feature) => Padding(
              padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 5 : 6,
                    height: isSmallScreen ? 5 : 6,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 10 : 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: isSmallScreen ? 13 : null,
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),),
          ],
        ),
      ),
    );
  }

  Widget _buildCondensedInfoSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return GestureDetector(
      onTap: () => _showInfoBottomSheet(context),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer.withOpacity(0.2),
              colorScheme.secondaryContainer.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: colorScheme.primary,
                size: isSmallScreen ? 20 : 22,
              ),
            ),
            SizedBox(width: isSmallScreen ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works & Requirements',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 14 : null,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to view instructions and requirements',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: isSmallScreen ? 11 : null,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: colorScheme.primary,
              size: isSmallScreen ? 14 : 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: size.height * 0.7,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // How it works section
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: colorScheme.primary,
                                size: isSmallScreen ? 18 : 20,
                              ),
                              SizedBox(width: isSmallScreen ? 6 : 8),
                              Text(
                                'How it works',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 15 : null,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 12),
                          Text(
                            '• Host creates a session and shares the 6-digit code\n'
                            '• Participants join using the session code\n'
                            '• Host controls drill timing for all connected devices\n'
                            '• Everyone trains simultaneously with synchronized drills\n'
                            '• Real-time synchronization with pause/resume controls',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: isSmallScreen ? 13 : null,
                              color: colorScheme.onSurface.withOpacity(0.7),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    // Requirements section
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.checklist_rounded,
                                color: Colors.blue,
                                size: isSmallScreen ? 18 : 20,
                              ),
                              SizedBox(width: isSmallScreen ? 6 : 8),
                              Text(
                                'Requirements',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 15 : null,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 12),
                          _buildRequirementItem('📱 Internet connection on all devices'),
                          _buildRequirementItem('🔗 Firebase connectivity enabled'),
                          _buildRequirementItem('⚡ Stable network for best experience'),
                          _buildRequirementItem('🔄 Real-time synchronization across devices'),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Text(
                            'Note: No special permissions required - works over internet connection.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: isSmallScreen ? 11 : null,
                              color: Colors.blue.withOpacity(0.8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 3 : 4),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: isSmallScreen ? 13 : null,
          color: Colors.blue.withOpacity(0.9),
          height: 1.3,
        ),
      ),
    );
  }

  void _navigateToHostScreen(BuildContext context) {
    context.push('/multiplayer/host');
  }

  void _navigateToJoinScreen(BuildContext context) {
    context.push('/multiplayer/join');
  }
}
