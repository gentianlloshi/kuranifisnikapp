import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/theme/theme.dart';

void main() {
  group('surfaceElevated extension', () {
    late ColorScheme darkScheme;
    late ColorScheme lightScheme;

    setUp(() {
      darkScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF336655), brightness: Brightness.dark);
      lightScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF336655), brightness: Brightness.light);
    });

    Color expected(ColorScheme scheme, int level) {
      if (scheme.brightness != Brightness.dark || level <= 0) return scheme.surface;
      final double alpha = switch (level) { 1 => 0.04, 2 => 0.08, 3 => 0.12, 4 => 0.16, _ => 0.20 };
      return Color.alphaBlend(scheme.primary.withOpacity(alpha), scheme.surface);
    }

    test('returns base surface for light mode all levels', () {
      for (var i = -1; i <= 5; i++) {
        expect(lightScheme.surfaceElevated(i), equals(lightScheme.surface), reason: 'Level $i should be base in light mode');
      }
    });

    test('level 0 and negative return base surface in dark mode', () {
      expect(darkScheme.surfaceElevated(0), equals(darkScheme.surface));
      expect(darkScheme.surfaceElevated(-2), equals(darkScheme.surface));
    });

    test('produces expected blended colors for levels 1-4 in dark mode', () {
      for (var level = 1; level <= 4; level++) {
        expect(darkScheme.surfaceElevated(level), equals(expected(darkScheme, level)), reason: 'Mismatch at level $level');
      }
    });

    test('level progression increases distance from base surface', () {
      final base = darkScheme.surface;
      Color prev = base;
      for (var level = 1; level <= 4; level++) {
        final current = darkScheme.surfaceElevated(level);
        expect(current, isNot(equals(prev)), reason: 'Level $level should differ from previous');
        // Check channel difference grows or at least not zero (heuristic)
        final prevDiff = (prev.red - base.red).abs() + (prev.green - base.green).abs() + (prev.blue - base.blue).abs();
        final currDiff = (current.red - base.red).abs() + (current.green - base.green).abs() + (current.blue - base.blue).abs();
        expect(currDiff >= prevDiff, isTrue, reason: 'Level $level should not reduce distance from base');
        prev = current;
      }
    });

    test('levels beyond defined (>=5) clamp to last alpha (0.20)', () {
      final l5 = darkScheme.surfaceElevated(5);
      final expectedL5 = expected(darkScheme, 5);
      expect(l5, equals(expectedL5));
      final l10 = darkScheme.surfaceElevated(10);
      expect(l10, equals(expectedL5));
    });
  });
}
