// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// Path to the uploaded SPARK logo image (developer-provided file).
/// Use as: Image.asset(AppTheme.logoPath) or Image.file(File(AppTheme.logoPath))
const String kSparkLogoPath = '/mnt/data/1000069737.jpg';

class AppTheme {
  // -------------------------
  // Branding / Core Colors
  // -------------------------
  static const Color goldPrimary = Color(0xFFF6C341); // Smooth luxury gold
  static const Color goldBright = Color(0xFFFFD76A);  // Highlight gold
  static const Color goldDeep = Color(0xFFBF8A2C);    // Deeper gold for borders/shadows

  // Neutral palette (professional)
  static const Color whitePure = Color(0xFFFFFFFF);
  static const Color whiteSoft = Color(0xFFF7F7F7);
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral200 = Color(0xFFE2E8F0);
  static const Color neutral300 = Color(0xFFCBD5E1);
  static const Color neutral400 = Color(0xFF94A3B8);
  static const Color neutral500 = Color(0xFF64748B);
  static const Color neutral600 = Color(0xFF475569);
  static const Color neutral700 = Color(0xFF334155);
  static const Color neutral800 = Color(0xFF1E293B);
  static const Color neutral900 = Color(0xFF0F172A);

  // Dark-specific neutrals
  static const Color blackPure = Color(0xFF000000);
  static const Color blackSoft = Color(0xFF0B0B0B);
  static const Color greyDark = Color(0xFF18181B);
  static const Color greyMedium = Color(0xFF2C2C2E);

  // Semantic colors
  static const Color successColor = Color(0xFF10B981); // Emerald
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444);   // Red
  static const Color infoColor = Color(0xFF06B6D4);    // Cyan/Teal

  // Subscription & role colors
  static const Color freeColor = Color(0xFF6B7280);       // Gray
  static const Color playerColor = Color(0xFF3B82F6);     // Blue
  static const Color instituteColor = Color(0xFF8B5CF6);  // Purple
  static const Color adminColor = Color(0xFFDC2626);      // Admin red

  // Spacing & radii commonly used
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // -------------------------
  // Light Theme
  // -------------------------
  static ThemeData light() {
    final base = ThemeData.light();
    return base.copyWith(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: whiteSoft,
      primaryColor: goldPrimary,
      // Color scheme
      colorScheme: ColorScheme.light(
        brightness: Brightness.light,
        primary: goldPrimary,
        onPrimary: blackPure,
        secondary: neutral900,
        onSecondary: whitePure,
        background: whiteSoft,
        onBackground: neutral900,
        surface: whitePure,
        onSurface: neutral900,
        error: errorColor,
      ),

      // -------------------------
      // AppBar
      // -------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: whitePure,
        foregroundColor: neutral900,
        elevation: 0,
        iconTheme: const IconThemeData(color: neutral700),
        titleTextStyle: const TextStyle(
          color: neutral900,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      // -------------------------
      // TextTheme (comprehensive)
      // -------------------------
      textTheme: _buildTextTheme(
        base.textTheme,
        onPrimary: blackPure,
        onSurface: neutral900,
        headlineColor: neutral900,
      ),

      // -------------------------
      // Card / Surface
      // -------------------------
      cardTheme: CardThemeData(
        color: whitePure,
        elevation: 0,
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: neutral200.withOpacity(0.6), width: 1),
        ),
        shadowColor: Colors.black.withOpacity(0.05),
      ),

      // -------------------------
      // Buttons
      // -------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldPrimary,
          foregroundColor: blackPure,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neutral900,
          side: BorderSide(color: neutral300, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neutral900,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      // -------------------------
      // Input / Form fields
      // -------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neutral50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: neutral400, fontSize: 15),
        labelStyle: TextStyle(color: neutral600, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: neutral300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: neutral300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: goldPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
      ),

      // -------------------------
      // Bottom Navigation
      // -------------------------
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: whitePure,
        selectedItemColor: goldPrimary,
        unselectedItemColor: neutral400,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
      ),

      // -------------------------
      // Chips
      // -------------------------
      chipTheme: ChipThemeData(
        backgroundColor: neutral100,
        selectedColor: goldPrimary.withOpacity(0.12),
        labelStyle: TextStyle(color: neutral700, fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),

      // -------------------------
      // Divider
      // -------------------------
      dividerTheme: DividerThemeData(color: neutral200, thickness: 1, space: 1),

      // -------------------------
      // Icons / tooltips / overlays
      // -------------------------
      iconTheme: const IconThemeData(color: neutral700, size: 20),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: neutral900, borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(color: whitePure, fontSize: 12),
      ),

      // -------------------------
      // Floating Action Button
      // -------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: goldPrimary,
        foregroundColor: blackPure,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // -------------------------
      // SnackBar
      // -------------------------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: neutral900,
        contentTextStyle: const TextStyle(color: whitePure, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      // -------------------------
      // Dialogs
      // -------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: whitePure,
        titleTextStyle: const TextStyle(color: neutral900, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(color: neutral700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
      ),

      // -------------------------
      // Tab Bar
      // -------------------------
      tabBarTheme: TabBarThemeData(
        labelColor: goldPrimary,
        unselectedLabelColor: neutral500,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: goldPrimary, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 16),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),

      // -------------------------
      // Switch/Checkbox/Radio/Slider
      // -------------------------
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return goldPrimary;
          return neutral100;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return goldPrimary.withOpacity(0.4);
          return neutral300.withOpacity(0.4);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return goldPrimary;
          return neutral400;
        }),
        checkColor: MaterialStateProperty.all(blackPure),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return goldPrimary;
          return neutral400;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: goldPrimary,
        inactiveTrackColor: neutral300,
        thumbColor: goldPrimary,
        overlayColor: goldPrimary.withOpacity(0.12),
        valueIndicatorColor: goldPrimary,
      ),

      // -------------------------
      // Progress indicators
      // -------------------------
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: neutral200,
        color: goldPrimary,
      ),
    );
  }

  // -------------------------
  // Dark Theme
  // -------------------------
  static ThemeData dark() {
    final base = ThemeData.dark();
    return base.copyWith(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: blackSoft,
      primaryColor: goldBright,
      colorScheme: ColorScheme.dark(
        brightness: Brightness.dark,
        primary: goldBright,
        onPrimary: blackPure,
        secondary: greyMedium,
        onSecondary: whitePure,
        background: blackSoft,
        onBackground: whitePure,
        surface: greyDark,
        onSurface: whitePure,
        error: errorColor,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: greyDark,
        foregroundColor: whitePure,
        elevation: 0,
        iconTheme: const IconThemeData(color: neutral300),
        titleTextStyle: const TextStyle(
          color: whitePure,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Text theme (dark)
      textTheme: _buildTextTheme(
        base.textTheme,
        onPrimary: blackPure,
        onSurface: neutral100,
        headlineColor: neutral100,
        isDark: true,
      ),

      // Cards / surfaces
      cardTheme: CardThemeData(
        color: greyDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: neutral700.withOpacity(0.35), width: 1),
        ),
        shadowColor: Colors.black.withOpacity(0.45),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldPrimary,
          foregroundColor: blackPure,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldPrimary,
          side: BorderSide(color: neutral600, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neutral100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neutral800,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: neutral500, fontSize: 15),
        labelStyle: TextStyle(color: neutral400, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: neutral700, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: neutral700, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: goldBright, width: 2),
        ),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: greyDark,
        selectedItemColor: goldBright,
        unselectedItemColor: neutral500,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: neutral800,
        selectedColor: goldBright.withOpacity(0.12),
        labelStyle: TextStyle(color: neutral200, fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Divider
      dividerTheme: DividerThemeData(color: neutral700, thickness: 1, space: 1),

      // Icons / tooltips / overlays
      iconTheme: const IconThemeData(color: neutral300, size: 20),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: neutral100.withOpacity(0.95), borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(color: blackPure, fontSize: 12),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: goldBright,
        foregroundColor: blackPure,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: neutral900,
        contentTextStyle: const TextStyle(color: whitePure, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: greyDark,
        titleTextStyle: const TextStyle(color: neutral100, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(color: neutral300, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
      ),

      // Tabs
      tabBarTheme: TabBarThemeData(
        labelColor: goldBright,
        unselectedLabelColor: neutral500,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: goldBright, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 16),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),

      // Switch/Checkbox/Radio/Slider
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return goldBright;
          return neutral100;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return goldBright.withOpacity(0.4);
          return neutral700.withOpacity(0.3);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return goldBright;
          return neutral400;
        }),
        checkColor: MaterialStateProperty.all(blackPure),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return goldBright;
          return neutral400;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: goldBright,
        inactiveTrackColor: neutral700,
        thumbColor: goldBright,
        overlayColor: goldBright.withOpacity(0.12),
        valueIndicatorColor: goldBright,
      ),

      // Progress indicators
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: neutral700,
        color: goldBright,
      ),
    );
  }

  // -------------------------
  // Helpers & Utilities
  // -------------------------
  /// Returns a color for subscription plans
  static Color getSubscriptionColor(String planId) {
    switch (planId.toLowerCase()) {
      case 'free':
        return freeColor;
      case 'player':
        return playerColor;
      case 'institute':
        return instituteColor;
      case 'admin':
        return adminColor;
      default:
        return freeColor;
    }
  }

  /// Returns a role color
  static Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return adminColor;
      case 'user':
        return neutral600;
      default:
        return neutral600;
    }
  }

  // Internal: builds a robust TextTheme used by both light/dark themes.
  static TextTheme _buildTextTheme(
    TextTheme base, {
    required Color onPrimary,
    required Color onSurface,
    required Color headlineColor,
    bool isDark = false,
  }) {
    // Choose body colors depending on theme brightness
    final Color bodyColor = onSurface;
    final Color captionColor = isDark ? neutral400 : neutral600;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: headlineColor,
        letterSpacing: -1,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: headlineColor,
        letterSpacing: -0.8,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: headlineColor,
        letterSpacing: -0.5,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: headlineColor,
        letterSpacing: -0.4,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: headlineColor,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: headlineColor,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: bodyColor,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: bodyColor,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: bodyColor,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: bodyColor,
        height: 1.5,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: bodyColor,
        height: 1.5,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: captionColor,
        height: 1.4,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: bodyColor,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: bodyColor,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: captionColor,
      ),
    );
  }
}

/// BuildContext extension helpers
extension ThemeHelpers on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  TextTheme get textStyles => theme.textTheme;
}
