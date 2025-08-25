import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/widgets/thematic_index_utils.dart';

void main() {
  group('iconForThemeLabel', () {
    test('maps Allah/Zot to auto_awesome', () {
      expect(iconForThemeLabel('Allahu dhe Besimi'), Icons.auto_awesome);
      expect(iconForThemeLabel('Zoti dhe Njësia'), Icons.auto_awesome);
    });
    test('maps Njeriu/Moral to people icon', () {
      expect(iconForThemeLabel('Njeriu dhe Morali'), Icons.people_alt_outlined);
    });
    test('fallbacks to category', () {
      expect(iconForThemeLabel('Tema e Pa Klasifikuar'), Icons.category);
    });
  });

  group('buildRefPreview', () {
    String? resolver(String ref) {
      // fake minimal resolver for tests
      if (ref == '2:255') return 'Ajeti i Kursisë';
      if (ref == '27:60') return 'Ajet i parë i vargut';
      return null;
    }

    test('single-verse preview uses resolver text', () {
      final p = buildRefPreview('2:255', resolveTextForRef: resolver);
      expect(p, 'Ajeti i Kursisë');
    });

    test('range preview uses first verse text when available', () {
      final p = buildRefPreview('27:60-64', resolveTextForRef: resolver);
      expect(p, 'Ajet i parë i vargut');
    });

    test('range preview falls back to summary when missing cache', () {
      final p = buildRefPreview('37:168-170', resolveTextForRef: resolver);
      expect(p, 'Ajetet 168–170');
    });

    test('invalid refs return null', () {
      expect(buildRefPreview('abc', resolveTextForRef: resolver), isNull);
      expect(buildRefPreview('2:', resolveTextForRef: resolver), isNull);
      expect(buildRefPreview('2:abc', resolveTextForRef: resolver), isNull);
    });
  });
}
