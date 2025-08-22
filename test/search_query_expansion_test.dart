import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/core/search/token_utils.dart';
import 'package:kurani_fisnik_app/core/search/stemmer.dart';

void main() {
  group('Query expansion (light morphological + diacritics)', () {
    test('expands tokens with stemming and diacritic folding', () {
      final expanded = expandQueryTokens('Faraonit dobishëm', lightStem);
      // Should include original lowercase tokens
      expect(expanded, contains('faraonit'));
      expect(expanded, contains('dobishëm'.toLowerCase()));
      // Should include normalized without diacritics
      expect(expanded, contains('dobishem'));
      // Should include stems
      expect(expanded, contains('faraon'));
      expect(expanded, contains('dobish'));
    });
  });
}
