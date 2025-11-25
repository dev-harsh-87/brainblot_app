import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/core/theme/app_theme.dart';
import 'package:spark_app/core/widgets/subscription_widgets.dart';
import 'package:spark_app/core/widgets/enhanced_subscription_card.dart';
import 'package:spark_app/core/widgets/feature_not_available_dialog.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/features/subscription/domain/subscription_plan.dart';
import 'package:spark_app/features/subscription/domain/subscription_request.dart';
import 'package:spark_app/features/subscription/services/subscription_request_service.dart';
import 'package:spark_app/features/auth/bloc/auth_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/features/subscription/data/subscription_plan_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/drills/data/drill_category_repository.dart';
import 'package:spark_app/features/drills/domain/drill_category.dart';
import 'package:spark_app/core/di/injection.dart';

/// Modern home screen with professional UI design
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ),);

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.authenticated && state.user != null) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(state.user!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingHome();
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  !snapshot.data!.exists) {
                return _buildLoadingHome();
              }

              try {
                final appUser = AppUser.fromFirestore(snapshot.data!);
                return _buildAuthenticatedHome(context, appUser);
              } catch (e) {
                return _buildLoadingHome();
              }
            },
          );
        }
        return _buildLoadingHome();
      },
    );
  }

  Widget _buildAuthenticatedHome(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                // User Subscription Requests (if not admin)
                if (!user.role.isAdmin())
                  _buildUserRequestsSection(context, user),

                // Features Grid
                _buildFeaturesSection(context, user),

                // Drill Categories Section
                _buildCategoriesSection(context, user),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserRequestsSection(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final requestService = SubscriptionRequestService();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<List<SubscriptionRequest>>(
        stream: requestService.getUserRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Your Requests',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 16),
                      Text(
                        'Loading your requests...',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            );
          }

          if (snapshot.hasError) {
            // Handle index error specifically
            final error = snapshot.error.toString();
            if (error.contains('index') ||
                error.contains('failed-precondition')) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your Requests',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Database index is being built. This usually takes a few minutes. Please refresh the app shortly.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              );
            }
          }

          final requests = snapshot.data ?? [];
          print('📋 Displaying ${requests.length} requests');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header with View All button
              Row(
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Requests',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: requests.isEmpty
                          ? colorScheme.outline
                          : colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${requests.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/user-requests'),
                    child: const Text('View All', style: TextStyle(
                      fontSize: 13,
                    ),),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Content Area
              if (requests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No subscription requests pending. Request an upgrade from the subscription section below.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Show only the most recent request
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildUserRequestCard(context, requests.first),
                ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserRequestCard(
      BuildContext context, SubscriptionRequest request,) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (request.isPending) {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
      statusText = 'PENDING';
    } else if (request.isApproved) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'APPROVED';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'REJECTED';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to ${request.requestedPlan.toUpperCase()}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'From ${request.currentPlan} plan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatRequestDate(request.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRequestDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }



  Widget _buildFeaturesSection(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAdmin = user.role.isAdmin();
    // Use real subscription data from user, no need for fake plan creation
    final userSubscription = user.subscription;

    final allFeatures = [
      _FeatureItem(
        name: 'Multiplayer',
        description: 'Train together',
        icon: Icons.group,
        hasAccess:
            isAdmin || userSubscription.moduleAccess.contains('multiplayer'),
        route: '/multiplayer',
        color: Colors.blue,
      ),
      _FeatureItem(
        name: 'Analytics',
        description: 'Track progress',
        icon: Icons.analytics,
        hasAccess:
            isAdmin || userSubscription.moduleAccess.contains('analysis'),
        route: '/stats',
        color: Colors.green,
      ),
    ];

    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Features',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          // Show all features in a grid - both accessible and inaccessible
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: allFeatures.length,
            itemBuilder: (context, index) {
              final feature = allFeatures[index];
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 800 + (index * 100)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: _buildFeatureCard(context, feature),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, _FeatureItem feature) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () {
        if (feature.hasAccess) {
          // User has access, navigate to the feature
          context.push(feature.route);
        } else {
          // User doesn't have access, show upgrade dialog
          FeatureNotAvailableDialog.show(
            context,
            featureName: feature.name,
            description: feature.description,
            onUpgradePressed: () {
              Navigator.of(context).pop();
              context.push('/subscription');
            },
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: feature.color.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: feature.color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    feature.color,
                    feature.color.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                feature.icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const Spacer(),
            Text(
              feature.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              feature.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryRepository = getIt<DrillCategoryRepository>();

    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.category,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Drill Categories',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<DrillCategory>>(
            future: categoryRepository.getActiveCategories(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 16),
                      Text(
                        'Loading categories...',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No drill categories available',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final categories = snapshot.data!;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categories.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 800 + (index * 100)),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: _buildCategoryCard(context, category),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, DrillCategory category) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Define colors for different categories
    final categoryColors = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    
    final color = categoryColors[category.order % categoryColors.length];

    return InkWell(
      onTap: () {
        // Navigate to drills screen with category filter
        context.push('/drills?category=${category.name}');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.fitness_center,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'View drills',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
}

class _FeatureItem {
  final String name;
  final String description;
  final IconData icon;
  final bool hasAccess;
  final String route;
  final Color color;

  _FeatureItem({
    required this.name,
    required this.description,
    required this.icon,
    required this.hasAccess,
    required this.route,
    required this.color,
  });
}

