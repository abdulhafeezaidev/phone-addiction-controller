import 'package:flutter/material.dart';
import 'focus_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: FocusTokens.sagePrimary,
      onPrimary: Colors.white,
      secondary: FocusTokens.indigoPrimary,
      onSecondary: Colors.white,
      error: FocusTokens.terracottaPrimary,
      onError: Colors.white,
      surface: isDark ? FocusTokens.surfaceDefault : const Color(0xFFFFFFFF),
      onSurface: isDark ? FocusTokens.textPrimary : const Color(0xFF111827),
      surfaceContainerHighest: isDark ? FocusTokens.surfaceSunken : const Color(0xFFF0F2F5),
      onSurfaceVariant: isDark ? FocusTokens.textSecondary : const Color(0xFF4B5563),
      outline: isDark ? FocusTokens.borderStrong : const Color(0x1F000000),
      outlineVariant: isDark ? FocusTokens.borderSubtle : const Color(0x0F000000),
    );

    const textTheme = TextTheme(
      displayLarge: FocusTokens.displayTimer,
      headlineLarge: FocusTokens.headlineHero,
      headlineMedium: FocusTokens.headlineSection,
      titleLarge: FocusTokens.titleCard,
      titleMedium: FocusTokens.titleMedium,
      bodyLarge: FocusTokens.bodyLarge,
      bodyMedium: FocusTokens.bodyMedium,
      labelLarge: FocusTokens.buttonLabel,
      labelSmall: FocusTokens.labelBadge,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? FocusTokens.canvasBase : const Color(0xFFF7F8FA),
      fontFamily: FocusTokens.fontFamily,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? FocusTokens.surfaceDefault : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: FocusTokens.borderRadiusXl,
          side: BorderSide(
            color: isDark ? FocusTokens.borderSubtle : const Color(0x0F000000),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: FocusTokens.screenGutter,
          vertical: FocusTokens.spaceXs,
        ),
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? FocusTokens.surfaceElevated : Colors.white,
        elevation: 0,
        indicatorColor: FocusTokens.sagePrimary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return FocusTokens.labelBadge.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: FocusTokens.sagePrimary,
            );
          }
          return FocusTokens.labelBadge.copyWith(
            fontSize: 11,
            color: FocusTokens.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: FocusTokens.sagePrimary, size: 24);
          }
          return const IconThemeData(
            color: FocusTokens.textMuted,
            size: 24,
          );
        }),
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return FocusTokens.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return FocusTokens.sagePrimary;
          return FocusTokens.surfaceSunken;
        }),
        trackOutlineColor: WidgetStateProperty.all(FocusTokens.borderSubtle),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? FocusTokens.surfaceSunken : const Color(0xFFF0F2F5),
        border: OutlineInputBorder(
          borderRadius: FocusTokens.borderRadiusMd,
          borderSide: const BorderSide(color: FocusTokens.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: FocusTokens.borderRadiusMd,
          borderSide: const BorderSide(color: FocusTokens.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: FocusTokens.borderRadiusMd,
          borderSide: const BorderSide(color: FocusTokens.sagePrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FocusTokens.spaceBase,
          vertical: FocusTokens.spaceMd,
        ),
      ),

      // Elevated & Filled Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FocusTokens.sagePrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: FocusTokens.spaceXl,
            vertical: FocusTokens.spaceMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: FocusTokens.borderRadiusPill,
          ),
          textStyle: FocusTokens.buttonLabel,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: FocusTokens.borderSubtle,
        thickness: 1,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FocusTokens.spaceBase,
          vertical: FocusTokens.space2xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: FocusTokens.borderRadiusLg),
      ),
    );
  }
}

// ── App Color Extensions ────────────────────────────────────────────────────
extension AppColors on ColorScheme {
  Color get success => FocusTokens.sagePrimary;
  Color get warning => FocusTokens.amberPrimary;
  Color get info => FocusTokens.indigoPrimary;
  Color get gradientStart => FocusTokens.sagePrimary;
  Color get gradientEnd => FocusTokens.indigoPrimary;
}
