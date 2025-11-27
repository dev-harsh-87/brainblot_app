import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_app/features/auth/bloc/auth_bloc.dart';
import 'package:spark_app/core/services/preferences_service.dart';
import 'package:spark_app/features/auth/ui/device_conflict_dialog.dart';
import 'package:spark_app/features/auth/domain/device_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;
  
  late AnimationController _mainAnimationController;
  late AnimationController _logoAnimationController;
  late AnimationController _pulseAnimationController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSavedCredentials();
    
    // Add haptic feedback for professional feel
    HapticFeedback.lightImpact();
  }

  void _initializeAnimations() {
    // Main animation controller for screen entrance
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Logo animation controller
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Pulse animation controller for loading states
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    // Fade animation with staggered timing
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController, 
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );
    
    // Slide animation with elastic curve
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4), 
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainAnimationController, 
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    
    // Logo scale animation
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    
    // Logo subtle rotation
    _logoRotationAnimation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOutSine,
      ),
    );
    
    // Pulse animation for interactive elements
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start animations
    _mainAnimationController.forward();
    _logoAnimationController.forward();
    
    // Repeat pulse animation
    _pulseAnimationController.repeat(reverse: true);
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await PreferencesService.getInstance();
    final rememberMe = prefs.getRememberMe();
    
    if (rememberMe) {
      final credentials = await prefs.getSavedCredentials();
      if (credentials['email'] != null && credentials['password'] != null) {
        _emailCtrl.text = credentials['email']!;
        _passwordCtrl.text = credentials['password']!;
        setState(() {
          _rememberMe = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _logoAnimationController.dispose();
    _pulseAnimationController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      HapticFeedback.mediumImpact();
      
      final prefs = await PreferencesService.getInstance();
      
      // Save credentials if remember me is checked
      if (_rememberMe) {
        await prefs.setRememberMe(true);
        await prefs.saveCredentials(_emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await prefs.setRememberMe(false);
        await prefs.clearSavedCredentials();
      }
      
      if (mounted) {
        context.read<AuthBloc>().add(AuthLoginSubmitted(
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text,
            ),);
      }
    }
  }

  Widget _buildAnimatedLogo(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _logoAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _logoScaleAnimation.value,
          child: Transform.rotate(
            angle: _logoRotationAnimation.value,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.1),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surface,
                      colorScheme.surfaceContainerHighest.withOpacity(0.8),
                    ],
                  ),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(80),
                  child: Image.asset(
                    "assets/images/logo.png",
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if logo image is not found
                      return Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(80),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.psychology_outlined,
                          size: 80,
                          color: colorScheme.onPrimary,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfessionalTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    required ColorScheme colorScheme,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: colorScheme.primary.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon, 
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: colorScheme.outline.withOpacity(0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: colorScheme.error,
            ),
          ),
          filled: true,
          fillColor: colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildSignInButton(ColorScheme colorScheme, ThemeData theme, bool loading) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: loading ? _pulseAnimation.value : 1.0,
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: loading
                  ? colorScheme.primary.withOpacity(0.8)
                  : colorScheme.primary,
 
            ),
            child: FilledButton(
              onPressed: loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: loading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Signing In...',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Sign In',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            HapticFeedback.heavyImpact();
            context.go('/');
          }
          if (state.status == AuthStatus.deviceConflict && state.existingSessions != null) {
            HapticFeedback.heavyImpact();
            
            // Convert the session data to DeviceSession objects
            final sessions = state.existingSessions!.map((sessionData) {
              return DeviceSession(
                userId: (sessionData['userId'] as String?) ?? '',
                deviceId: (sessionData['deviceId'] as String?) ?? '',
                deviceName: (sessionData['deviceName'] as String?) ?? 'Unknown Device',
                deviceType: (sessionData['deviceType'] as String?) ?? 'Unknown',
                platform: (sessionData['platform'] as String?) ?? 'Unknown',
                appVersion: (sessionData['appVersion'] as String?) ?? '1.0.0',
                fcmToken: sessionData['fcmToken'] as String?,
                loginTime: sessionData['loginTime'] != null
                    ? (sessionData['loginTime'] as Timestamp).toDate()
                    : DateTime.now(),
                lastActiveTime: sessionData['lastActiveTime'] != null
                    ? (sessionData['lastActiveTime'] as Timestamp).toDate()
                    : DateTime.now(),
                isActive: (sessionData['isActive'] as bool?) ?? false,
              );
            }).toList();
            
            // Use WidgetsBinding to ensure dialog shows after current frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => DeviceConflictDialog(
                    existingSessions: sessions,
                    onContinue: () {
                      if (context.mounted) {
                        context.read<AuthBloc>().add(const AuthContinueWithCurrentDevice());
                      }
                    },
                    onCancel: () {
                      if (context.mounted) {
                        // User cancelled login, perform complete logout
                        context.read<AuthBloc>().add(const AuthLogoutRequested());
                      }
                    },
                  ),
                );
              }
            });
          }
          if (state.status == AuthStatus.failure && state.error != null) {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.onError),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.error!)),
                  ],
                ),
                backgroundColor: colorScheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        },
        builder: (context, state) {
          final loading = state.status == AuthStatus.loading;
          
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width > 600 ? 64 : 24,
                    vertical: 24,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Enhanced Logo Section
                            _buildAnimatedLogo(colorScheme),
                            const SizedBox(height: 40),
                         
                            
                            // Enhanced Login Form
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Email Field
                                  _buildProfessionalTextField(
                                    controller: _emailCtrl,
                                    label: 'Email Address',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    colorScheme: colorScheme,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Please enter your email';
                                      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                      if (!emailRegex.hasMatch(v)) return 'Please enter a valid email';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Password Field
                                  _buildProfessionalTextField(
                                    controller: _passwordCtrl,
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    obscureText: _obscure,
                                    colorScheme: colorScheme,
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() => _obscure = !_obscure);
                                        HapticFeedback.selectionClick();
                                      },
                                      icon: Icon(
                                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: colorScheme.primary.withOpacity(0.7),
                                      ),
                                    ),
                                    validator: (v) => (v == null || v.length < 6) 
                                        ? 'Password must be at least 6 characters' 
                                        : null,
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Enhanced Remember Me & Forgot Password
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setState(() => _rememberMe = !_rememberMe);
                                          HapticFeedback.selectionClick();
                                        },
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: _rememberMe 
                                                      ? colorScheme.primary 
                                                      : colorScheme.outline,
                                                  width: 2,
                                                ),
                                                color: _rememberMe 
                                                    ? colorScheme.primary 
                                                    : Colors.transparent,
                                              ),
                                              child: _rememberMe
                                                  ? Icon(
                                                      Icons.check,
                                                      size: 16,
                                                      color: colorScheme.onPrimary,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Remember me',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: colorScheme.onSurface.withOpacity(0.8),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          context.push('/forgot-password');
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        child: Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 40),
                                  
                                  // Enhanced Sign In Button
                                  _buildSignInButton(colorScheme, theme, loading),
                                  const SizedBox(height: 32),
                                  
                                  // Professional Divider
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 1,
                                          color: colorScheme.outline.withOpacity(0.3),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'OR',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurface.withOpacity(0.6),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 1,
                                          color: colorScheme.outline.withOpacity(0.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),
                                  
                                  // Enhanced Register Link
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: colorScheme.outline.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Don't have an account? ",
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            context.go('/register');
                                          },
                                          child: Text(
                                            'Sign Up',
                                            style: TextStyle(
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
