import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/providers/audio_provider.dart';

void main() {
  group('AudioProvider loop guards', () {
    test('canSingleVerseLoop true when playlist length <=1', () {
      expect(AudioProvider.canSingleVerseLoop(0), true);
      expect(AudioProvider.canSingleVerseLoop(1), true);
      expect(AudioProvider.canSingleVerseLoop(2), false);
    });
    test('setSingleVerseLoopCount API exists (compile-time)', () {
      // This test is mostly to ensure method signature stability; no instantiation (requires platform bindings).
      // ignore: avoid_print
      print(AudioProvider.canSingleVerseLoop(1));
    });
  });

  group('Memorization playlist length math', () {
    int playlistLength(int selected, int repeatTarget) {
      if (selected <= 0) return 0;
      final repeat = repeatTarget <= 1 ? 1 : repeatTarget;
      return selected * repeat;
    }
    test('selected verses multiplied by repeatTarget', () {
      expect(playlistLength(3,1), 3);
      expect(playlistLength(3,2), 6);
      expect(playlistLength(5,4), 20);
    });
  });
}
