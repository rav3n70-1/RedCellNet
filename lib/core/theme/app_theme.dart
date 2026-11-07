// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand & Surface Colors (Per Design Specification)
  static const Color primary = Color(0xFFA41235); // Deep Burgundy - Primary Brand
  static const Color primaryDark = Color(0xFF7A0D27);
  static const Color primaryLight = Color(0xFFFFE4E6); // Rose 100
  static const Color primaryAccent = Color(0xFFE11D48); // Crimson - Emergency Accent
  static const Color primaryContainer = Color(0xFFFFF1F2); // Pale Rose - Soft Surface

  // Emergency Accent
  static const Color emergency = Color(0xFFE11D48); // Crimson
  static const Color emergencyContainer = Color(0xFFFFE4E6);

  // Healthcare Information
  static const Color secondary = Color(0xFF0284C7); // Medical Blue
  static const Color secondaryLight = Color(0xFFE0F2FE); // Pale Blue
  static const Color secondaryDark = Color(0xFF0369A1);

  // Accent Violet for achievements & gamification
  static const Color accent = Color(0xFF8B5CF6);
  static const Color accentLight = Color(0xFFF3E8FF);

  // Status & Urgency Colors
  static const Color critical = Color(0xFFDC2626); // Critical Red
  static const Color criticalLight = Color(0xFFFEE2E2);
  static const Color high = Color(0xFFEA580C); // High Priority Orange
  static const Color highLight = Color(0xFFFFEDD5);
  static const Color medium = Color(0xFFD97706); // Moderate Priority Amber
  static const Color mediumLight = Color(0xFFFEF3C7);
  static const Color warning = Color(0xFFD97706); // Warning Amber
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFB45309);
  static const Color low = Color(0xFF059669); // Scheduled / Green
  static const Color lowLight = Color(0xFFD1FAE5);
  static const Color success = Color(0xFF059669); // Success / Available Green
  static const Color successLight = Color(0xFFECFDF5);
  static const Color pointsGold = Color(0xFFF59E0B);
  static const Color goldLight = Color(0xFFFFFBEB);

  // Neutrals & Surfaces (Light)
  static const Color scaffoldBackground = Color(0xFFF8FAFC); // Off-white
  static const Color surface = Color(0xFFFFFFFF); // Card Surface White
  static const Color surfaceMuted = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceElevated = Colors.white;
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderSubtle = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFF1F5F9);

  // Typography (Light)
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate Grey 500
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Dark Theme Neutrals & Surfaces ("LifePulse" Obsidian Palette)
  static const Color darkScaffoldBackground = Color(0xFF090D16); // Deep Obsidian Canvas
  static const Color darkSurface = Color(0xFF121826); // Slate Surface 850
  static const Color darkSurfaceMuted = Color(0xFF1E293B); // Slate 800
  static const Color darkBorder = Color(0xFF243048); // Subtle border
  static const Color darkBorderSubtle = Color(0x1FFFFFFF); // 12% Translucent White
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
  static const Color darkPrimaryContainer = Color(0xFF4C0519); // Rose 950

  // LifePulse Brand Tokens
  static const Color obsidianCanvas = Color(0xFF090D16);
  static const Color obsidianSurface = Color(0xFF121826);
  static const Color lifePulseCrimson = Color(0xFFE11D48);
  static const Color vitalEmerald = Color(0xFF059669);
  static const Color vitalEmeraldLight = Color(0xFFECFDF5);
  static const Color imperialGold = Color(0xFFF59E0B);
  static const Color imperialGoldLight = Color(0xFFFFFBEB);
  static const Color cyberCyan = Color(0xFF06B6D4);
  static const Color cyberCyanLight = Color(0xFFECFEFF);

  // Controlled Gradients (Burgundy & Emergency & Glass)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFA41235), Color(0xFF7A0D27)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient heroGradient = primaryGradient;

  static const LinearGradient emergencyGradient = LinearGradient(
    colors: [Color(0xFFE11D48), Color(0xFFA41235)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient vitalGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient skyGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient glassGradient(BuildContext context) => LinearGradient(
        colors: isDark(context)
            ? [
                const Color(0xFF1E293B).withValues(alpha: 0.65),
                const Color(0xFF0F172A).withValues(alpha: 0.45)
              ]
            : [
                Colors.white.withValues(alpha: 0.90),
                Colors.white.withValues(alpha: 0.70)
              ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Soft shadows & LifePulse Neon Glows
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get glowPrimary => [
        BoxShadow(
          color: primary.withValues(alpha: 0.24),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get glowEmergency => [
        BoxShadow(
          color: emergency.withValues(alpha: 0.32),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ];

  static List<BoxShadow> get glowVital => [
        BoxShadow(
          color: vitalEmerald.withValues(alpha: 0.30),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get glowGold => [
        BoxShadow(
          color: imperialGold.withValues(alpha: 0.30),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  // Dynamic Theme Helpers (Seamless Light & Dark Mode)
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color cardBg(BuildContext context) =>
      isDark(context) ? darkSurface : Colors.white;

  static Border glassBorder(BuildContext context, {double width = 1.0}) =>
      Border.all(
        color: isDark(context)
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        width: width,
      );

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color scaffoldOf(BuildContext context) =>
      isDark(context) ? darkScaffoldBackground : scaffoldBackground;

  static Color mutedOf(BuildContext context) =>
      isDark(context) ? darkSurfaceMuted : surfaceMuted;

  static Color surfaceMutedOf(BuildContext context) =>
      isDark(context) ? darkSurfaceMuted : surfaceMuted;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static BorderSide borderSideOf(BuildContext context, {double width = 1.0}) =>
      BorderSide(color: borderOf(context), width: width);

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;
}

class AppTheme {
  static bool get _isFlutterTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  static TextTheme _buildTextTheme(TextTheme base, Color primaryColor) {
    const fallback = ['Noto Sans Bengali', 'sans-serif'];
    if (_isFlutterTest) {
      return base.apply(
        bodyColor: primaryColor,
        displayColor: primaryColor,
        fontFamilyFallback: fallback,
      );
    }
    try {
      return GoogleFonts.interTextTheme(base).apply(
        bodyColor: primaryColor,
        displayColor: primaryColor,
        fontFamilyFallback: fallback,
      );
    } catch (_) {
      return base.apply(
        bodyColor: primaryColor,
        displayColor: primaryColor,
        fontFamilyFallback: fallback,
      );
    }
  }

  // --- Light Theme ---
  static ThemeData get lightTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.critical,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.scaffoldBackground,
      textTheme: _buildTextTheme(base.textTheme, AppColors.textPrimary),
      fontFamilyFallback: const ['Noto Sans Bengali', 'sans-serif'],

      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.critical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.critical, width: 2.0),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 6,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),

      dividerColor: AppColors.divider,
    );
  }

  // --- Dark Theme ---
  static ThemeData get darkTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: const Color(0xFFE11D48),
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.critical,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.darkScaffoldBackground,
      textTheme: _buildTextTheme(base.textTheme, AppColors.darkTextPrimary),
      fontFamilyFallback: const ['Noto Sans Bengali', 'sans-serif'],

      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      ),

      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF43F5E),
          side: const BorderSide(color: Color(0xFFF43F5E), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE11D48), width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.critical),
        ),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.darkTextMuted, fontSize: 14),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFFF43F5E),
        unselectedLabelColor: AppColors.darkTextSecondary,
        indicatorColor: Color(0xFFF43F5E),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        selectedItemColor: Color(0xFFF43F5E),
        unselectedItemColor: AppColors.darkTextMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 6,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFFE11D48),
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),

      dividerColor: AppColors.darkBorder,
    );
  }
}
