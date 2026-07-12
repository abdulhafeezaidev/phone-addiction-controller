import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Font Family ───────────────────────────────────────────────────────────
  // Using Inter as the preferred font. On devices without Inter installed,
  // Flutter falls back to the default sans-serif font.
  static const String _fontFamily = 'Inter';

  // ── Seed Colors ──────────────────────────────────────────────────────────
  static const Color _primarySeed = Color(0xFF5E6AD2); // Indigo
  static const Color _errorColor = Color(0xFFCF6679);

  // ── Dark Palette ─────────────────────────────────────────────────────────
  static const Color _darkBackground = Color(0xFF121414); // Deep Charcoal
  static const Color _darkSurface = Color(0xFF212123); // Squircular cards background
  static const Color _darkSurfaceVariant = Color(0xFF1A1C1C); // Subtle secondary background
  static const Color _darkOnSurface = Color(0xFFE3E2E2);
  static const Color _darkOnSurfaceVariant = Color(0xFFC6C5D5);

  // ── Light Palette ────────────────────────────────────────────────────────
  static const Color _lightBackground = Color(0xFFF5F5FF);
  static const Color _lightSurface = Color(0xFFFFFFFF);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primarySeed,
      brightness: brightness,
      surface: isDark ? _darkSurface : _lightSurface,
      surfaceContainerHighest: isDark ? _darkSurfaceVariant : const Color(0xFFEEEEFF),
      error: _errorColor,
      onSurface: isDark ? _darkOnSurface : const Color(0xFF1A1A2E),
      onSurfaceVariant: isDark ? _darkOnSurfaceVariant : const Color(0xFF5A5A7A),
    );

    final textTheme = TextTheme(
      displayLarge: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      headlineLarge: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
      titleSmall: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? _darkBackground : _lightBackground,
      fontFamily: _fontFamily,
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
        color: isDark ? _darkSurface : const Color(0xFFEEEEFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? const Color(0xFF2C2C2E) : colorScheme.outline.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? _darkSurface : _lightSurface,
        elevation: 0,
        indicatorColor: _primarySeed,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelLarge?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _primarySeed,
            );
          }
          return textTheme.labelLarge?.copyWith(
            fontSize: 11,
            color: isDark ? _darkOnSurfaceVariant : const Color(0xFF5A5A7A),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white, size: 24);
          }
          return IconThemeData(
            color: isDark ? _darkOnSurfaceVariant : const Color(0xFF5A5A7A),
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
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primarySeed;
          return null;
        }),
      ),
      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primarySeed,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkSurfaceVariant : const Color(0xFFEEEEFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primarySeed, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primarySeed,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primarySeed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      // Divider
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.12),
        thickness: 1,
      ),
      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ── App Color Extensions ────────────────────────────────────────────────────
extension AppColors on ColorScheme {
  Color get success => const Color(0xFF4CAF7D);
  Color get warning => const Color(0xFFFFB74D);
  Color get info => const Color(0xFF42A5F5);
  Color get gradientStart => const Color(0xFF6C63FF);
  Color get gradientEnd => const Color(0xFFAB47BC);
}
