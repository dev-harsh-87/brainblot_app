import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/features/auth/bloc/auth_bloc.dart';
import 'package:spark_app/core/theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
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
    _emailController.dispose();
    super.dispose();
  }

  void _submitForgotPassword() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        AuthForgotPasswordSubmitted(email: _emailController.text.trim()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.passwordResetSent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message ?? 'Password reset email sent!'),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
            // Navigate back to login after showing success message
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) context.pop();
            });
          } else if (state.status == AuthStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error ?? 'An error occurred'),
                backgroundColor: colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.lock_reset,
                        size: 32,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No worries! Enter your email address and we\'ll send you a link to reset your password.',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface.withOpacity(0.7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email Field
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                                prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                                border: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: colorScheme.surface,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              ),
                              style: TextStyle(color: colorScheme.onSurface),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Submit Button
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) {
                              final isLoading = state.status == AuthStatus.loading;
                              return SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _submitForgotPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: isLoading
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                                          ),
                                        )
                                      : const Text(
                                          'Send Reset Link',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Back to Login
                    Center(
                      child: TextButton(
                        onPressed: () => context.pop(),
                        child: RichText(
                          text: TextSpan(
                            text: 'Remember your password? ',
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: 'Back to Login',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
