import 'package:flutter/material.dart';
import 'design_tokens.dart';

TextTheme buildBaseTextTheme({required String latinFont, required String arabicFont, double scaleFactor = 1.0}) {
  // Helper to convert line height multiplier into height property relative to font size.
  TextStyle base(String fontFamily, double size, double lineHeight, FontWeight weight, {double? letterSpacing, FontStyle? fontStyle}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: size * scaleFactor,
        height: lineHeight,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
      );

  // Arabic style token (bodyArabic from plan) with clamp (max ~34px when scaled)
  final rawArabicSize = 26 * scaleFactor;
  final arabicSize = rawArabicSize.clamp(22, 34).toDouble(); // ensure double
  final arabic = base(arabicFont, arabicSize, 1.65, FontWeight.w500, letterSpacing: -0.5);

  return TextTheme(
    displayLarge: base(latinFont, 34, 1.15, FontWeight.w700),
    headlineMedium: base(latinFont, 24, 1.25, FontWeight.w600),
    headlineSmall: arabic, // store arabic for extension retrieval
    titleLarge: base(latinFont, 20, 1.30, FontWeight.w600),
    titleMedium: base(latinFont, 18, 1.30, FontWeight.w600),
    bodyLarge: base(latinFont, 16, 1.55, FontWeight.w400),
    bodyMedium: base(latinFont, 14, 1.50, FontWeight.w400),
    bodySmall: base(latinFont, 13, 1.35, FontWeight.w500),
    labelMedium: base(latinFont, 12, 1.20, FontWeight.w500),
  ).apply();
}

extension AppTextStyles on TextTheme {
  TextStyle get bodyArabic => headlineSmall ?? const TextStyle(
        fontFamily: 'AmiriQuran',
        fontSize: 26,
        height: 1.65,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
      );
}

extension TextThemeContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

ThemeData buildAppTheme(ColorScheme scheme, {double scaleFactor = 1.0}) {
  // Scale factor applied to base text theme (responsive typography)
  final baseTextTheme = buildBaseTextTheme(latinFont: 'Lora', arabicFont: 'AmiriQuran', scaleFactor: scaleFactor);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.background,
  textTheme: baseTextTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
  cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: AppElevation.level1,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadii.card),
        side: BorderSide(color: Colors.transparent),
      ),
      shadowColor: scheme.shadow.withOpacity(0.08),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: scheme.surface,
      elevation: AppElevation.level1,
      selectedItemColor: scheme.primary,
      unselectedItemColor: scheme.onSurface.withOpacity(0.6),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outline.withOpacity(0.6),
      thickness: 0.6,
      space: 0.6,
    ),
    iconTheme: IconThemeData(color: scheme.onSurface),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.surfaceVariant,
      behavior: SnackBarBehavior.floating,
      contentTextStyle: baseTextTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card.x)),
    ),
  );
}
