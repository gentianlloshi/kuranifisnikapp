import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/core/search/stemmer.dart';

void main() {
  group('lightStem', () {
    test('leaves short tokens unchanged', () {
      expect(lightStem('di'), 'di');
      expect(lightStem('bum'), 'bum');
    });
    test('strips common Albanian suffixes conservatively', () {
      expect(lightStem('dobishëm'), 'dobish');
      expect(lightStem('dobishme'), 'dobish');
      expect(lightStem('faraonit'), 'faraon');
      expect(lightStem('besimtarëve'), 'besimtar');
    });
    test('does not over-stem below 3 chars', () {
      expect(lightStem('ve'), 've');
      expect(lightStem('rit'), 'rit');
    });
  });
}
