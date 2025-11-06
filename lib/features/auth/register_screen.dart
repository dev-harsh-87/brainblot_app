import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/features/auth/bloc/auth_bloc.dart';

import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please accept the terms and conditions')),
        );
        return;
      }
      context.read<AuthBloc>().add(AuthRegisterSubmitted(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          ));
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            context.go('/');
          }
          if (state.status == AuthStatus.failure && state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final loading = state.status == AuthStatus.loading;
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo/Brand Section
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colorScheme.primary, colorScheme.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.psychology,
                            size: 60,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Welcome Text
                        Text(
                          'Create Account',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join thousands of users improving their cognitive abilities',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        
                        // Register Form
                        Container(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Email Field
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Please enter your email';
                                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                    if (!emailRegex.hasMatch(v)) return 'Please enter a valid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                
                                // Password Field
                                TextFormField(
                                  controller: _passwordCtrl,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.length < 6) return 'Password must be at least 6 characters';
                                    if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(v)) {
                                      return 'Password must contain letters and numbers';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                
                                // Confirm Password Field
                                TextFormField(
                                  controller: _confirmCtrl,
                                  obscureText: _obscureConfirm,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                      icon: Icon(
                                        _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                  ),
                                  validator: (v) => (v != _passwordCtrl.text) ? 'Passwords do not match' : null,
                                ),
                                const SizedBox(height: 20),
                                
                                // Terms and Conditions
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _acceptTerms,
                                      onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                          children: [
                                            const TextSpan(text: 'I agree to the '),
                                            TextSpan(
                                              text: 'Terms of Service',
                                              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                                            ),
                                            const TextSpan(text: ' and '),
                                            TextSpan(
                                              text: 'Privacy Policy',
                                              style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                
                                // Register Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: FilledButton(
                                    onPressed: loading ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: loading
                                        ? SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                                            ),
                                          )
                                        : Text(
                                            'Create Account',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onPrimary,
                                            ),
                                          ),
                                  ),
                                ),
              
                                
                                // Login Link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account? ',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => context.go('/login'),
                                      child: Text(
                                        'Sign In',
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
