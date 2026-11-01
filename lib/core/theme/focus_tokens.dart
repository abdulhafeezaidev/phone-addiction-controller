import 'package:flutter/material.dart';

/// Bloomly design tokens shared by the Flutter touchpoints.
abstract class FocusTokens {
  // ── 1. Color System ────────────────────────────────────────────────────────
  // Ground & Surfaces
  static const Color canvas = Color(0xFFFAF8F5);
  static const Color surface = Color(0xFFF5EFEB);
  static const Color elevated = Color(0xFFDCFCE7);
  static const Color sunken = Color(0xFFE7DFD5);

  // Samsung Health Ambient Mesh Gradient (Warm Buttercup -> Fresh Dew Sage -> Crisp Sky Blue)
  static const LinearGradient ambientMeshGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFAF8F5),
      Color(0xFFDCFCE7),
      Color(0xFFF5EFEB),
    ],
    stops: [0.0, 0.40, 1.0],
  );

  // Samsung Health Domain & Category Palette
  static const Color healthGreen = Color(0xFF15803D);
  static const Color healthGreenSoft = Color(0x1F22C55E);
  static const Color healthBlue = Color(0xFF15803D);
  static const Color healthBlueSoft = Color(0x1F0284C7);
  static const Color healthPurple = Color(0xFF7C3AED);
  static const Color healthPurpleSoft = Color(0x1F8B5CF6);
  static const Color healthAmber = Color(0xFFFDBA74);
  static const Color healthAmberSoft = Color(0x1FF59E0B);
  static const Color healthCoral = Color(0xFFB45309);

  // Samsung Health Rich Expressive Card Gradients
  static const LinearGradient nightGradient = LinearGradient(
    colors: [Color(0xFF1B224E), Color(0xFF0F1432)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanCardGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberCardGradient = LinearGradient(
    colors: [Color(0xFFE29E38), Color(0xFFD69426)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orchidCardGradient = LinearGradient(
    colors: [Color(0xFFD946EF), Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coralCardGradient = LinearGradient(
    colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Backward compatible aliases
  static const Color canvasBase = canvas;
  static const Color surfaceDefault = surface;
  static const Color surfaceElevated = elevated;
  static const Color surfaceSunken = sunken;
  static const Color surfaceHighlight = Color(0xFFDCFCE7);

  // Sprout Meadow
  static const Color primary = Color(0xFF15803D);
  static const Color primaryHover = Color(0xFF14532D);
  static const Color primarySoft = Color(0x1F15803D);
  static const Color primaryGlow = Color(0x3315803D);
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF15803D), Color(0xFF14532D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Gentle Sage
  static const Color secondary = Color(0xFF86EFAC);
  static const Color secondarySoft = Color(0x3386EFAC);
  static const Color secondaryGlow = Color(0x3386EFAC);

  // Peach Bloom
  static const Color accent = Color(0xFFFDBA74);
  static const Color accentSoft = Color(0x33FDBA74);
  static const Color accentGlow = Color(0x33FDBA74);
  static const Color warning = accent;
  static const Color warningSoft = accentSoft;
  static const Color warningGlow = accentGlow;

  // Reserved for genuinely destructive actions only.
  static const Color danger = Color(0xFFFF453A);
  static const Color dangerSoft = Color(0x1FFF453A);
  static const Color dangerGlow = Color(0x33FF453A);

  // Warm Charcoal and Sandstone
  static const Color ink = Color(0xFF292524);
  static const Color inkMuted = Color(0xFF78716C);
  static const Color divider = Color(0xFFE7DFD5);

  // Compatibility aliases
  static const Color textPrimary = ink;
  static const Color textSecondary = inkMuted;
  static const Color textMuted = Color(0xFF78716C);
  static const Color borderSubtle = divider;
  static const Color borderStrong = Color(0xFFB9ADA2);
  static const Color borderAccent = primarySoft;

  static const Color sagePrimary = primary;
  static const Color sageHover = primaryHover;
  static const Color sageGlow = primaryGlow;
  static const Color sageSubtle = primarySoft;

  static const Color indigoPrimary = secondary;
  static const Color indigoGlow = secondaryGlow;
  static const Color indigoSubtle = secondarySoft;

  static const Color amberPrimary = accent;
  static const Color amberGlow = accentGlow;
  static const Color amberSubtle = accentSoft;

  static const Color terracottaPrimary = danger;
  static const Color terracottaGlow = dangerGlow;
  static const Color terracottaSubtle = dangerSoft;

  // ── 2. Radius Scale ────────────────────────────────────────────────────────
  static const double radiusSm = 10.0;
  static const double radiusMd = 16.0; // Input fields, app tiles
  static const double radiusLg = 24.0; // Standard cards, docks, sheets
  static const double radiusXl = 28.0;
  static const double radiusHeader = 32.0; // Curved top app bar banner
  static const double radiusPill = 999.0; // Buttons & filter chips

  // Component radius aliases
  static const double buttonRadius = radiusPill;
  static const double cardRadius = radiusLg;
  static const double dialogRadius = 24.0;
  static const double sheetRadius = 28.0;
  static const double pillRadius = radiusPill;

  static final BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static final BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static final BorderRadius borderRadiusCard =
      BorderRadius.circular(cardRadius);
  static final BorderRadius borderRadiusButton =
      BorderRadius.circular(buttonRadius);
  static final BorderRadius borderRadiusDialog =
      BorderRadius.circular(dialogRadius);
  static const BorderRadius borderRadiusSheet =
      BorderRadius.vertical(top: Radius.circular(sheetRadius));
  static final BorderRadius borderRadiusPill =
      BorderRadius.circular(radiusPill);

  static final BorderRadius borderRadiusXs = BorderRadius.circular(8.0);
  static final BorderRadius borderRadius2Xl = BorderRadius.circular(radiusXl);

  // ── 3. Spacing Scale (8pt Grid) ───────────────────────────────────────────
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space7 = 28.0;
  static const double space8 = 32.0;
  static const double space10 = 40.0;

  static const double screenPaddingX = 20.0;
  static const double screenPaddingTop = 56.0;
  static const double bottomNavClearance = 112.0;
  static const double cardPadding = 20.0;
  static const double listGap = 10.0;
  static const double sectionGap = 24.0;

  // Legacy spacing aliases
  static const double space2xs = 2.0;
  static const double spaceXs = space1;
  static const double spaceSm = space2;
  static const double spaceMd = space3;
  static const double spaceBase = space4;
  static const double spaceLg = space5;
  static const double spaceXl = space6;
  static const double space2Xl = space8;
  static const double space3Xl = space10;
  static const double space4Xl = 48.0;
  static const double screenGutter = screenPaddingX;

  // ── 4. Shadows & Elevation (Apple iOS Subtle Elevation) ──────────────────
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 16,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadowLift = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadowPrimaryButton = [
    BoxShadow(
      color: Color(0x33007AFF),
      blurRadius: 14,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> ambientShadow = shadowSoft;

  // ── 5. Motion & Transitions ───────────────────────────────────────────────
  static const Duration motionFast = Duration(milliseconds: 200);
  static const Duration motionBase = Duration(milliseconds: 250);
  static const Duration motionSlow = Duration(milliseconds: 320);
  static const Duration motionRing = Duration(milliseconds: 700);
  static const Cubic motionStandard = Cubic(0.22, 1, 0.36, 1);

  static const Curve calmEaseOut = motionStandard;
  static const Duration durationQuick = motionFast;
  static const Duration durationBase = motionBase;
  static const Duration durationSlow = motionSlow;
  static const Duration durationBreathe = Duration(milliseconds: 3200);

  // ── 6. Typography Scale (Kidsafe Bold Modern) ─────────────────────────────
  static const String fontFamily = 'Inter';
  static const String monoFontFamily = 'monospace';

  // Hero Timer Readout (Kidsafe Display Timer)
  static const TextStyle displayTimer = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ink,
  );
  static const TextStyle heroTimer = displayTimer;

  // Lock Clock
  static const TextStyle lockClock = TextStyle(
    fontFamily: fontFamily,
    fontSize: 72,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -1.0,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ink,
  );

  // Screen Title (20-24 Bold)
  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: ink,
  );
  static const TextStyle headlineHero = pageTitle;

  // Section Title (16-18 Semi-Bold)
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: ink,
  );
  static const TextStyle headlineSection = sectionTitle;
  static const TextStyle titleCard = sectionTitle;

  // Body: 14-15 Regular
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: inkMuted,
  );
  static const TextStyle bodyLarge = body;

  // Body Strong: 15 Semi-Bold
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ink,
  );
  static const TextStyle titleMedium = bodyStrong;

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: Colors.white,
  );

  // Body Medium
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: inkMuted,
  );

  // Caption: 12-13 Medium
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: inkMuted,
  );

  // Eyebrow
  static const TextStyle eyebrow = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: inkMuted,
  );

  static const TextStyle labelBadge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    color: ink,
  );

  static const TextStyle monoCounter = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ink,
  );
}

/// Global Bloomly theme
final ThemeData focusOsTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: FocusTokens.canvas,
  colorScheme: const ColorScheme.light(
    surface: FocusTokens.surface,
    primary: FocusTokens.primary,
    secondary: FocusTokens.secondary,
    tertiary: FocusTokens.accent,
    error: FocusTokens.danger,
    onSurface: FocusTokens.ink,
    onPrimary: Colors.white,
    outline: FocusTokens.divider,
  ),
  dividerColor: FocusTokens.divider,
  useMaterial3: true,
);
