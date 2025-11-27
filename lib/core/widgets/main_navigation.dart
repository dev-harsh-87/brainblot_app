import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/features/auth/bloc/auth_bloc.dart';
import 'package:spark_app/core/auth/models/user_role.dart';
import 'package:spark_app/core/auth/models/app_user.dart';
import 'package:spark_app/core/widgets/profile_avatar.dart';
import 'package:spark_app/features/sharing/domain/user_profile.dart';
import 'package:spark_app/features/profile/services/profile_service.dart';
import 'package:spark_app/core/di/injection.dart';

/// Callback to provide TabBar from child screens
typedef TabBarBuilder = PreferredSizeWidget? Function(BuildContext context);

/// Inherited widget to register TabBar builder
class TabBarProvider extends InheritedWidget {
  final void Function(TabBarBuilder?) registerTabBar;

  const TabBarProvider({
    Key? key,
    required this.registerTabBar,
    required Widget child,
  }) : super(key: key, child: child);

  static TabBarProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabBarProvider>();
  }

  @override
  bool updateShouldNotify(TabBarProvider oldWidget) => false;
}

/// Main navigation scaffold with bottom navigation bar
/// Provides consistent navigation across the app with role-based tabs
class MainNavigation extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const MainNavigation({
    Key? key,
    required this.child,
    required this.currentPath,
  }) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  TabBarBuilder? _tabBarBuilder;
  late final ProfileService _profileService;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _profileService = getIt<ProfileService>();
    _updateIndexFromPath();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _profileService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  void didUpdateWidget(MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _updateIndexFromPath();
      // Clear tab bar when route changes
      setState(() {
        _tabBarBuilder = null;
      });
    }
  }

  void _registerTabBar(TabBarBuilder? builder) {
    if (mounted) {
      setState(() {
        _tabBarBuilder = builder;
      });
    }
  }

  void _updateIndexFromPath() {
    final path = widget.currentPath;
    if (path.startsWith('/home')) {
      _currentIndex = 0;
    } else if (path.startsWith('/drills')) {
      _currentIndex = 1;
    } else if (path.startsWith('/programs')) {
      _currentIndex = 2;
    } else if (path.startsWith('/subscription')) {
      _currentIndex = 3;
    } else if (path.startsWith('/admin')) {
      _currentIndex = 4; // Only for admin users
    }
  }

  void _onItemTapped(int index, bool isAdmin) {
    if (_currentIndex == index) return;

    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/drills');
        break;
      case 2:
        context.go('/programs');
        break;
      case 3:
        context.go('/subscription');
        break;
      case 4:
        if (isAdmin) {
          context.go('/admin');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status != AuthStatus.authenticated || state.user == null) {
          // Return empty scaffold if not authenticated
          return Scaffold(body: widget.child);
        }

        // Use StreamBuilder to get real-time user data
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(state.user!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(body: widget.child);
            }

            AppUser? appUser;
            bool isAdmin = false;

            try {
              appUser = AppUser.fromFirestore(snapshot.data!);
              // Check if user is admin OR has admin dashboard access
              // Only specific admin modules grant access to the admin dashboard
              final adminDashboardModules = [
                'admin_user_management',
                'admin_subscription_management',
                'admin_plan_requests',
                'admin_category_management',
                'admin_stimulus_management',
                'admin_comprehensive_activity'
              ];
              
              isAdmin = appUser.role.isAdmin() ||
                  appUser.subscription.moduleAccess.any((module) =>
                      adminDashboardModules.contains(module));
            } catch (e) {
              // If there's an error parsing user data, default to non-admin
              isAdmin = false;
            }

            // Build navigation items based on user role
            final List<BottomNavigationBarItem> items = [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fitness_center_outlined),
                activeIcon: Icon(Icons.fitness_center),
                label: 'Drills',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                activeIcon: Icon(Icons.calendar_today),
                label: 'Programs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.card_membership_outlined),
                activeIcon: Icon(Icons.card_membership),
                label: 'Subscription',
              ),
              if (isAdmin)
                BottomNavigationBarItem(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  activeIcon: Icon(Icons.admin_panel_settings),
                  label: 'Admin',
                ),
            ];

            return Scaffold(
              appBar: AppBar(
                title: Text(_getAppBarTitle()),
                actions: [
                  // Profile Avatar button in app bar
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Center(
                      child: ProfileAvatar(
                        userProfile: _userProfile,
                        size: 32,
                      ),
                    ),
                  ),
                ],
                bottom: _tabBarBuilder?.call(context),
              ),
              body: TabBarProvider(
                registerTabBar: _registerTabBar,
                child: widget.child,
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) => _onItemTapped(index, isAdmin),
                destinations: items.map((item) {
                  return NavigationDestination(
                    icon: item.icon,
                    selectedIcon: item.activeIcon,
                    label: item.label!,
                  );
                }).toList(),
                elevation: 8,
                backgroundColor: colorScheme.surface,
                indicatorColor: colorScheme.primaryContainer,
                labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              ),
            );
          },
        );
      },
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Home';
      case 1:
        return 'Drills';
      case 2:
        return 'Programs';
      case 3:
        return 'Subscription';
      case 4:
        return 'Admin';
      default:
        return 'Spark';
    }
  }

}