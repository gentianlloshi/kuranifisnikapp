import 'package:flutter/material.dart';

/// Spacing scale (in logical pixels)
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 6; // micro vertical rhythm between tight elements
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double block = 40; // large block separation
}

/// Border radius tokens
class AppRadii {
  static const Radius chip = Radius.circular(4);
  static const Radius small = Radius.circular(8);
  static const Radius card = Radius.circular(12);
  static const Radius panel = Radius.circular(16);
  static const StadiumBorder pill = StadiumBorder();
}

/// Elevation constraints: prefer 0,1,2 only.
class AppElevation {
  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 2;
}

/// Semantic padding helpers
class AppInsets {
  static const EdgeInsets screen = EdgeInsets.all(AppSpacing.lg);
  static const EdgeInsets cardContent = EdgeInsets.all(AppSpacing.lg);
  static const EdgeInsets listItem = EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.lg);
}

/// Color palette definitions (base values) for custom schemes.
class AppPalettes {
  // Sepia / Gold
  static const sepiaPrimary = Color(0xFF8A6A33);
  static const sepiaPrimaryContainer = Color(0xFFEEDFC2);
  static const sepiaSecondary = Color(0xFFC29B5B);
  static const sepiaBackground = Color(0xFFFAF6EF);
  static const sepiaSurface = Color(0xFFF4EBDD);
  static const sepiaSurfaceVariant = Color(0xFFE9DDCC);
  static const sepiaAccent = Color(0xFFD4AA48);
  static const sepiaError = Color(0xFFB3261E);
  static const sepiaTextPrimary = Color(0xFF2E2618);
  static const sepiaTextMuted = Color(0xFF6A5B44);
  static const sepiaDivider = Color(0xFFE2D6C4);

  // Deep Blue / Emerald
  static const deepPrimary = Color(0xFF0E4D47);
  static const deepPrimaryContainer = Color(0xFFD2ECE9);
  static const deepSecondary = Color(0xFF1F6D62);
  static const deepBackground = Color(0xFFF6FAFA);
  static const deepSurface = Color(0xFFECF3F2);
  static const deepSurfaceVariant = Color(0xFFDDE8E7);
  static const deepAccent = Color(0xFF2E877D);
  static const deepError = Color(0xFFBA1A1A);
  static const deepTextPrimary = Color(0xFF102524);
  static const deepTextMuted = Color(0xFF4A6663);
  static const deepDivider = Color(0xFFD3E2E0);

  // Minimal Dark
  static const darkPrimary = Color(0xFF6FBFAF);
  static const darkPrimaryContainer = Color(0xFF143530);
  static const darkSecondary = Color(0xFF86D3C4);
  static const darkBackground = Color(0xFF0E1514);
  static const darkSurface = Color(0xFF182120);
  static const darkSurfaceVariant = Color(0xFF24302F);
  static const darkAccent = Color(0xFF52A896);
  static const darkError = Color(0xFFFF554D);
  static const darkTextPrimary = Color(0xFFF2F8F7);
  static const darkTextMuted = Color(0xFF9AB5B0);
  static const darkDivider = Color(0xFF2C3937);
  // Overlay tints for dark tonal elevation (applied via alpha blending on surface)
  static const darkOverlayLow = Color(0xFF6FBFAF); // primary tint (4%-8%)
  static const darkOverlayMed = Color(0xFF52A896); // accent tint (8%-12%)
  static const darkOverlayHigh = Color(0xFF86D3C4); // secondary tint (12%-16%)
}

ColorScheme buildSepiaScheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  // For dark variant we could invert some values, but initial sprint focuses on light sepia.
  return ColorScheme(
    brightness: brightness,
    primary: AppPalettes.sepiaPrimary,
    onPrimary: Colors.white,
    primaryContainer: AppPalettes.sepiaPrimaryContainer,
    onPrimaryContainer: AppPalettes.sepiaTextPrimary,
    secondary: AppPalettes.sepiaSecondary,
    onSecondary: Colors.white,
    secondaryContainer: AppPalettes.sepiaSurfaceVariant,
    onSecondaryContainer: AppPalettes.sepiaTextPrimary,
    tertiary: AppPalettes.sepiaAccent,
    onTertiary: Colors.white,
  tertiaryContainer: AppPalettes.sepiaAccent.withValues(alpha: 0.15),
    onTertiaryContainer: AppPalettes.sepiaTextPrimary,
    error: AppPalettes.sepiaError,
    onError: Colors.white,
  errorContainer: AppPalettes.sepiaError.withValues(alpha: .15),
    onErrorContainer: AppPalettes.sepiaTextPrimary,
  surface: AppPalettes.sepiaBackground,
  onSurface: AppPalettes.sepiaTextPrimary,
  surfaceContainerHighest: AppPalettes.sepiaSurfaceVariant,
  onSurfaceVariant: AppPalettes.sepiaTextMuted,
    outline: AppPalettes.sepiaDivider,
    outlineVariant: AppPalettes.sepiaDivider,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: AppPalettes.sepiaTextPrimary,
  onInverseSurface: AppPalettes.sepiaSurface,
    inversePrimary: AppPalettes.sepiaAccent,
  );
}

ColorScheme buildDeepBlueScheme(Brightness brightness) {
  return ColorScheme(
    brightness: brightness,
    primary: AppPalettes.deepPrimary,
    onPrimary: Colors.white,
    primaryContainer: AppPalettes.deepPrimaryContainer,
    onPrimaryContainer: AppPalettes.deepTextPrimary,
    secondary: AppPalettes.deepSecondary,
    onSecondary: Colors.white,
    secondaryContainer: AppPalettes.deepSurfaceVariant,
    onSecondaryContainer: AppPalettes.deepTextPrimary,
    tertiary: AppPalettes.deepAccent,
    onTertiary: Colors.white,
  tertiaryContainer: AppPalettes.deepAccent.withValues(alpha: 0.15),
    onTertiaryContainer: AppPalettes.deepTextPrimary,
    error: AppPalettes.deepError,
    onError: Colors.white,
  errorContainer: AppPalettes.deepError.withValues(alpha: .15),
    onErrorContainer: AppPalettes.deepTextPrimary,
  // background/onBackground deprecated; rely on surface/onSurface
    surface: AppPalettes.deepSurface,
    onSurface: AppPalettes.deepTextPrimary,
  surfaceContainerHighest: AppPalettes.deepSurfaceVariant,
    onSurfaceVariant: AppPalettes.deepTextMuted,
    outline: AppPalettes.deepDivider,
    outlineVariant: AppPalettes.deepDivider,
  shadow: Colors.black.withValues(alpha: 0.25),
  scrim: Colors.black.withValues(alpha: 0.5),
    inverseSurface: AppPalettes.deepTextPrimary,
    onInverseSurface: AppPalettes.deepSurface,
    inversePrimary: AppPalettes.deepAccent,
  );
}

ColorScheme buildMinimalDarkScheme() {
  return const ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalettes.darkPrimary,
    onPrimary: Colors.black,
  primaryContainer: AppPalettes.darkPrimaryContainer,
    onPrimaryContainer: AppPalettes.darkTextPrimary,
    secondary: AppPalettes.darkSecondary,
    onSecondary: Colors.black,
    secondaryContainer: AppPalettes.darkSurfaceVariant,
    onSecondaryContainer: AppPalettes.darkTextPrimary,
    tertiary: AppPalettes.darkAccent,
    onTertiary: Colors.black,
    tertiaryContainer: AppPalettes.darkAccent, // using accent itself; highlight overlays done manually
    onTertiaryContainer: AppPalettes.darkTextPrimary,
    error: AppPalettes.darkError,
    onError: Colors.black,
    errorContainer: AppPalettes.darkError,
    onErrorContainer: AppPalettes.darkTextPrimary,
  // background/onBackground deprecated; use surface/onSurface
  surface: AppPalettes.darkSurface,
    onSurface: AppPalettes.darkTextPrimary,
  surfaceContainerHighest: AppPalettes.darkSurfaceVariant,
    onSurfaceVariant: AppPalettes.darkTextMuted,
    outline: AppPalettes.darkDivider,
    outlineVariant: AppPalettes.darkDivider,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppPalettes.darkTextPrimary,
    onInverseSurface: AppPalettes.darkSurface,
    inversePrimary: AppPalettes.darkPrimary,
  );
}
