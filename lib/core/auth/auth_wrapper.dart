import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:brainblot_app/features/auth/bloc/auth_bloc.dart';

class AuthWrapper extends StatelessWidget {
  final Widget child;
  
  const AuthWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Safely get current location
        String? currentLocation;
        try {
          currentLocation = GoRouterState.of(context).uri.toString();
        } catch (e) {
          // If GoRouterState is not available, skip navigation logic
          return;
        }
        
        if (state.status == AuthStatus.authenticated) {
          // If user is authenticated and on auth screens, redirect to home
          if (currentLocation == '/login' || currentLocation == '/register') {
            context.go('/');
          }
        } else if (state.status == AuthStatus.initial) {
          // If user is not authenticated and not on auth screens, redirect to login
          if (currentLocation != '/login' && currentLocation != '/register') {
            context.go('/login');
          }
        }
      },
      child: child,
    );
  }
}

class AuthGuard extends StatelessWidget {
  final Widget child;
  
  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (state.status == AuthStatus.authenticated) {
          return child;
        }
        
        // Redirect to login if not authenticated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/login');
        });
        
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
