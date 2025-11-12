import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Edge-to-edge functionality for immersive full-screen experience
class EdgeToEdge {
  static bool _isInitialized = false;

  /// Initialize edge-to-edge mode
  static void initialize() {
    if (_isInitialized) return;
    
    // Enable edge-to-edge on Android
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    
    _isInitialized = true;
  }

  /// Set system UI overlay style for different contexts
  static void setSystemUIOverlayStyle({
    required BuildContext context,
    bool isDark = false,
    Color? statusBarColor,
    Brightness? statusBarIconBrightness,
  }) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor ?? Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness ?? 
            (isDark ? Brightness.light : Brightness.dark),
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
    );
  }

  /// Set light system UI (for dark backgrounds)
  static void setLightSystemUI(BuildContext context) {
    setSystemUIOverlayStyle(
      context: context,
      isDark: true,
      statusBarIconBrightness: Brightness.light,
    );
  }

  /// Set dark system UI (for light backgrounds)
  static void setDarkSystemUI(BuildContext context) {
    setSystemUIOverlayStyle(
      context: context,
      statusBarIconBrightness: Brightness.dark,
    );
  }

  /// Set system UI for primary colored backgrounds
  static void setPrimarySystemUI(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Determine if primary color is dark or light
    final primaryLuminance = colorScheme.primary.computeLuminance();
    final isDarkPrimary = primaryLuminance < 0.5;
    
    setSystemUIOverlayStyle(
      context: context,
      isDark: isDarkPrimary,
      statusBarIconBrightness: isDarkPrimary ? Brightness.light : Brightness.dark,
    );
  }

  /// Hide system UI for immersive experience (games, media)
  static void hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersive,
    );
  }

  /// Show system UI (restore normal mode)
  static void showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  /// Toggle immersive mode
  static void toggleImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }
}

/// Widget that provides edge-to-edge safe area handling
class EdgeToEdgeScaffold extends StatelessWidget {
  final Widget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool automaticallyImplyLeading;
  final bool resizeToAvoidBottomInset;

  const EdgeToEdgeScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.extendBody = true,
    this.extendBodyBehindAppBar = true,
    this.automaticallyImplyLeading = true,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar as PreferredSizeWidget?,
      body: SafeArea(
        top: false,
        child: body,
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Widget that handles system UI padding for edge-to-edge content
class EdgeToEdgeContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool handleStatusBar;
  final bool handleNavigationBar;
  final Color? backgroundColor;

  const EdgeToEdgeContainer({
    super.key,
    required this.child,
    this.padding,
    this.handleStatusBar = true,
    this.handleNavigationBar = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewPadding = mediaQuery.viewPadding;
    
    EdgeInsets safePadding = EdgeInsets.only(
      top: handleStatusBar ? viewPadding.top : 0,
      bottom: handleNavigationBar ? viewPadding.bottom : 0,
    );
    
    if (padding != null) {
      safePadding = EdgeInsets.only(
        top: safePadding.top + padding!.top,
        bottom: safePadding.bottom + padding!.bottom,
        left: safePadding.left + padding!.left,
        right: safePadding.right + padding!.right,
      );
    }

    return Container(
      color: backgroundColor,
      padding: safePadding,
      child: child,
    );
  }
}

/// AppBar that works with edge-to-edge
class EdgeToEdgeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final Widget? flexibleSpace;
  final bool centerTitle;
  final double toolbarHeight;

  const EdgeToEdgeAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 0,
    this.flexibleSpace,
    this.centerTitle = false,
    this.toolbarHeight = kToolbarHeight,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.viewPadding.top;
    final totalHeight = toolbarHeight + statusBarHeight;
    
    return Container(
      height: totalHeight,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.primary,
      ),
      child: Stack(
        children: [
          if (flexibleSpace != null) flexibleSpace!,
          Positioned(
            top: statusBarHeight,
            left: 0,
            right: 0,
            child: AppBar(
              title: title,
              actions: actions,
              leading: leading,
              automaticallyImplyLeading: automaticallyImplyLeading,
              backgroundColor: Colors.transparent,
              foregroundColor: foregroundColor,
              elevation: 0,
              centerTitle: centerTitle,
              toolbarHeight: toolbarHeight,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize {
    // Use a larger value to ensure it works on devices with notches/Dynamic Island
    // The actual height is calculated in build() using the real MediaQuery values
    return Size.fromHeight(toolbarHeight + 60);
  }
}
