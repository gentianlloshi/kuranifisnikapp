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
  final bool isDark = scheme.brightness == Brightness.dark;
  // Derived elevated surface colors (soft layering) for dark mode contrast improvement
  final Color surface1 = isDark ? scheme.surface : scheme.surface;
  final Color surface2 = isDark ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.04), scheme.surface) : scheme.surface;
  final Color surface3 = isDark ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), scheme.surface) : scheme.surface;
  final Color surface4 = isDark ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.12), scheme.surface) : scheme.surface;
  final Color dividerColor = isDark ? scheme.outline.withValues(alpha: 0.35) : scheme.outline.withValues(alpha: 0.6);
  final Color outlineVariant = isDark ? scheme.outlineVariant.withValues(alpha: 0.35) : scheme.outlineVariant;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface1,
    textTheme: baseTextTheme,
    canvasColor: surface1,
    dialogTheme: DialogThemeData(
      backgroundColor: surface2,
    ),
    cardColor: surface2,
    appBarTheme: AppBarTheme(
      backgroundColor: surface2,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: surface2,
      elevation: AppElevation.level1,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadii.card),
        side: BorderSide(color: Colors.transparent),
      ),
  shadowColor: isDark ? Colors.black.withValues(alpha: 0.6) : scheme.shadow.withValues(alpha: 0.08),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface2,
      elevation: AppElevation.level1,
      selectedItemColor: scheme.primary,
  unselectedItemColor: scheme.onSurface.withValues(alpha: 0.6),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    dividerTheme: DividerThemeData(
      color: dividerColor,
      thickness: 0.6,
      space: 0.6,
    ),
    iconTheme: IconThemeData(color: scheme.onSurface),
    snackBarTheme: SnackBarThemeData(
  backgroundColor: isDark ? surface3 : scheme.surfaceContainerHighest,
      behavior: SnackBarBehavior.floating,
  contentTextStyle: baseTextTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: isDark ? 0.9 : 1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card.x)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? surface4 : scheme.inverseSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dividerColor.withValues(alpha: 0.4)),
      ),
      textStyle: baseTextTheme.bodySmall?.copyWith(color: isDark ? scheme.onSurface : scheme.onInverseSurface),
    ),
    dividerColor: dividerColor,
      highlightColor: scheme.primary.withValues(alpha: 0.08),
      splashColor: scheme.primary.withValues(alpha: 0.12),
  );
}

// Convenience extensions for spacing & radii in widgets (future gradual adoption)
extension Space on BuildContext {
  double get spaceXxs => AppSpacing.xxs;
  double get spaceXs => AppSpacing.xs;
  double get spaceSm => AppSpacing.sm;
  double get spaceMd => AppSpacing.md;
  double get spaceLg => AppSpacing.lg;
  double get spaceXl => AppSpacing.xl;
  double get spaceXxl => AppSpacing.xxl;
}

extension Radii on BuildContext {
  Radius get radiusSmall => AppRadii.small;
  Radius get radiusCard => AppRadii.card;
  Radius get radiusPanel => AppRadii.panel;
}

/// Unified bottom sheet container helper for consistent styling.
class BottomSheetWrapper extends StatelessWidget {
  final Widget child;
  final bool useSafe;
  final EdgeInsets? padding;
  const BottomSheetWrapper({super.key, required this.child, this.useSafe = true, this.padding});
  @override
  Widget build(BuildContext context) {
    final pad = padding ?? EdgeInsets.symmetric(horizontal: context.spaceLg, vertical: context.spaceLg);
    final content = Padding(padding: pad, child: child);
    final inner = useSafe ? SafeArea(top: false, child: content) : content;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: context.radiusPanel),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: inner,
    );
  }
}

extension DarkSurfaces on ColorScheme {
  // Provides softly elevated tonal surfaces for dark mode; for light returns original surface.
  Color surfaceElevated(int level) {
    if (brightness != Brightness.dark || level <= 0) return surface;
    final double alpha = switch (level) { 1 => 0.04, 2 => 0.08, 3 => 0.12, 4 => 0.16, _ => 0.20 };
  return Color.alphaBlend(primary.withValues(alpha: alpha), surface);
  }
}
