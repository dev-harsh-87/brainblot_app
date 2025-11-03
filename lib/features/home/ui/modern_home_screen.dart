import 'package:brainblot_app/features/home/ui/admin_section_enhanced.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:brainblot_app/core/theme/app_theme.dart';
import 'package:brainblot_app/core/widgets/subscription_widgets.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';
import 'package:brainblot_app/core/auth/models/app_user.dart';
import 'package:brainblot_app/features/subscription/domain/subscription_plan.dart';
import 'package:brainblot_app/features/auth/bloc/auth_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Modern home screen with role and subscription-based UI
class ModernHomeScreen extends StatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.authenticated && state.user != null) {
          // Check if user is admin based on email (support both spellings)
          final email = state.user!.email?.toLowerCase() ?? '';
          const adminEmails = [
            'admin@brainblot.com',
            'admin@brianblot.com',
            'support@brainblot.com',
            'support@brianblot.com',
            'root@brainblot.com',
            'root@brianblot.com',
          ];
          final isAdmin = adminEmails.contains(email);
          
          // For now, create a mock AppUser - in real app this would come from a user service
          // Admins get institute subscription with full access
          final mockUser = AppUser(
            id: state.user!.uid,
            email: state.user!.email ?? '',
            displayName: state.user!.displayName ?? (isAdmin ? 'Admin' : 'User'),
            role: isAdmin ? UserRole.admin : UserRole.user,
            subscription: isAdmin ? UserSubscription.institute() : UserSubscription.free(),
            preferences: const UserPreferences(),
            stats: const UserStats(),
          );
          return _buildAuthenticatedHome(context, mockUser);
        }
        return _buildLoadingHome();
      },
    );
  }

  Widget _buildAuthenticatedHome(BuildContext context, AppUser user) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context, user),
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildWelcomeSection(context, user),
                  const SizedBox(height: AppTheme.spacing24),
                  
                  if (user.role.isAdmin()) ...[
                    buildEnhancedAdminSection(context),
                    const SizedBox(height: AppTheme.spacing24),
                  ],
                  
                  if (!user.role.isAdmin()) ...[
                    _buildSubscriptionSection(context, user),
                    const SizedBox(height: AppTheme.spacing24),
                  ],
                  
                  _buildFeaturesSection(context, user),
                  const SizedBox(height: AppTheme.spacing24),
                  
                  _buildQuickActionsSection(context, user),
                  const SizedBox(height: AppTheme.spacing40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withOpacity(0.1),
                AppTheme.secondaryColor.withOpacity(0.05),
              ],
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            'BrainBlot',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          if (user.role.isAdmin()) ...[
            const SizedBox(width: AppTheme.spacing8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing8,
                vertical: AppTheme.spacing4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.adminColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                'ADMIN',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/profile'),
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              user.displayName.isNotEmpty 
                  ? user.displayName[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacing8),
      ],
    );
  }

  Widget _buildWelcomeSection(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    final timeOfDay = DateTime.now().hour;
    String greeting;
    
    if (timeOfDay < 12) {
      greeting = 'Good morning';
    } else if (timeOfDay < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Card(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          gradient: AppTheme.primaryGradient,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, ${user.displayName}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    'Ready to enhance your brain training?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSubscriptionSection(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subscription Status',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (user.subscription.plan != 'institute')
              TextButton(
                onPressed: () => context.push('/subscription'),
                child: const Text('Upgrade'),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        
        SubscriptionStatusWidget(
          currentPlan: _getPlanFromId(user.subscription.plan),
          usage: {
            'drills': 0, // Mock data - would come from actual stats
            'programs': 0, // Mock data - would come from actual stats
          },
          onUpgrade: () => context.push('/subscription'),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    // Admins have access to everything, regular users check subscription
    final isAdmin = user.role.isAdmin();
    final currentPlan = _getPlanFromId(user.subscription.plan);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        
        Column(
          children: [
            FeatureAccessWidget(
              featureName: 'Drills',
              description: 'Create and manage training drills',
              hasAccess: isAdmin || currentPlan.moduleAccess.contains('drills'),
              icon: Icons.fitness_center,
              onTap: () => context.push('/drills'),
              onUpgrade: () => context.push('/subscription'),
            ),
            
            const SizedBox(height: AppTheme.spacing12),
            
            FeatureAccessWidget(
              featureName: 'Programs',
              description: 'Structured training programs',
              hasAccess: currentPlan.moduleAccess.contains('programs'),
              icon: Icons.schedule,
              onTap: () => context.push('/programs'),
              onUpgrade: () => context.push('/subscription'),
            ),
            
            const SizedBox(height: AppTheme.spacing12),
            
            FeatureAccessWidget(
              featureName: 'Multiplayer',
              description: 'Train with others via Bluetooth',
              hasAccess: currentPlan.moduleAccess.contains('multiplayer'),
              icon: Icons.group,
              onTap: () => context.push('/multiplayer'),
              onUpgrade: () => context.push('/subscription'),
            ),
            
            const SizedBox(height: AppTheme.spacing12),
            
            FeatureAccessWidget(
              featureName: 'Analytics',
              description: 'Advanced performance insights',
              hasAccess: currentPlan.moduleAccess.contains('analysis'),
              icon: Icons.analytics,
              onTap: () => context.push('/stats'),
              onUpgrade: () => context.push('/subscription'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    final isAdmin = user.role.isAdmin();
    final currentPlan = _getPlanFromId(user.subscription.plan);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppTheme.spacing12,
          mainAxisSpacing: AppTheme.spacing12,
          childAspectRatio: 1.2,
          children: [
            _buildQuickActionCard(
              context,
              'Start Training',
              Icons.play_arrow,
              AppTheme.primaryColor,
              () => context.push('/training'),
            ),
            _buildQuickActionCard(
              context,
              'View Stats',
              Icons.bar_chart,
              AppTheme.secondaryColor,
              () => context.push('/stats'),
            ),
            if (currentPlan.moduleAccess.contains('programs'))
              _buildQuickActionCard(
                context,
                'My Programs',
                Icons.list,
                AppTheme.accentColor,
                () => context.push('/programs'),
              ),
            _buildQuickActionCard(
              context,
              'Settings',
              Icons.settings,
              AppTheme.neutral600,
              () => context.push('/settings'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingHome() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  SubscriptionPlan _getPlanFromId(String planId) {
    switch (planId) {
      case 'player':
        return SubscriptionPlan.playerPlan;
      case 'institute':
        return SubscriptionPlan.institutePlan;
      default:
        return SubscriptionPlan.freePlan;
    }
  }
}