import 'package:flutter/material.dart';
import 'package:spark_app/core/theme/app_theme.dart';

/// Professional loader widget for consistent UI across the application
class AppLoader extends StatefulWidget {
  /// Size of the loader
  final double size;
  
  /// Optional message to display below the loader
  final String? message;
  
  /// Whether to show the loader in a card container
  final bool showCard;
  
  /// Custom color for the loader (defaults to theme primary color)
  final Color? color;

  const AppLoader({
    super.key,
    this.size = 40.0,
    this.message,
    this.showCard = false,
    this.color,
  });

  /// Full screen loader with optional message
  const AppLoader.fullScreen({
    super.key,
    this.message,
    this.color,
  }) : size = 48.0, showCard = true;

  /// Small inline loader
  const AppLoader.small({
    super.key,
    this.message,
    this.color,
  }) : size = 24.0, showCard = false;

  /// Medium loader for cards and sections
  const AppLoader.medium({
    super.key,
    this.message,
    this.color,
  }) : size = 32.0, showCard = false;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loaderColor = widget.color ?? context.colors.primary;
    
    Widget loader = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      loaderColor.withOpacity(0.1),
                      loaderColor.withOpacity(0.3),
                      loaderColor.withOpacity(0.6),
                      loaderColor,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                    transform: GradientRotation(_animation.value * 2 * 3.14159),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.size * 0.15),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.surface,
                    ),
                    child: Center(
                      child: Container(
                        width: widget.size * 0.3,
                        height: widget.size * 0.3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: loaderColor,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.message != null) ...[
            SizedBox(height: widget.size * 0.4),
            Text(
              widget.message!,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    if (widget.showCard) {
      return Container(
        padding: EdgeInsets.all(widget.size * 0.8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: loader,
      );
    }

    return loader;
  }
}


/// Overlay loader that can be shown on top of content
class AppOverlayLoader extends StatelessWidget {
  final String? message;
  final bool isVisible;
  final Widget child;
  final Color? backgroundColor;

  const AppOverlayLoader({
    super.key,
    required this.child,
    required this.isVisible,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isVisible)
          Container(
            color: (backgroundColor ?? Colors.black).withOpacity(0.5),
            child: const AppLoader.fullScreen(),
          ),
      ],
    );
  }
}

/// Loading button that shows loader when pressed
class AppLoadingButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final ButtonStyle? style;

  const AppLoadingButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: isLoading
          ? const AppLoader.small()
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: 8),
                ],
                Text(text),
              ],
            ),
    );
  }
}