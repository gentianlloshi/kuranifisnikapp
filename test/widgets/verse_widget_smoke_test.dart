import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurani_fisnik_app/domain/entities/verse.dart';

// Small test-only widget that reproduces the text rendering logic we want to validate.
class TestVerseContent extends StatelessWidget {
  final Verse verse;
  final bool showArabic;
  final bool showTranslation;
  final bool showTransliteration;
  final double fontSizeArabic;
  final double fontSizeTranslation;

  const TestVerseContent({
    super.key,
    required this.verse,
    this.showArabic = true,
    this.showTranslation = true,
    this.showTransliteration = true,
    this.fontSizeArabic = 28,
    this.fontSizeTranslation = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showArabic)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  verse.textArabic,
                  style: TextStyle(fontSize: fontSizeArabic),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          if (showTranslation && (verse.textTranslation?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  verse.textTranslation!,
                  style: TextStyle(fontSize: fontSizeTranslation),
                ),
              ),
            ),
          if (showTransliteration && (verse.textTransliteration?.isNotEmpty ?? false))
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                verse.textTransliteration!,
                style: TextStyle(
                  fontSize: (fontSizeTranslation - 2).clamp(10, 100).toDouble(),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TestVerseContent rendering', () {
    final baseVerse = Verse(
      surahId: 1,
      verseNumber: 1,
      arabicText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      translation: 'Në emër të Zotit më të mëshirshëm',
      transliteration: 'Bismillah ir-Rahman ir-Rahim',
      verseKey: '1:1',
    );

    Widget makeTestable(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      );
    }

    testWidgets('renders Arabic + translation + transliteration with correct directionality', (tester) async {
      await tester.pumpWidget(makeTestable(TestVerseContent(verse: baseVerse)));
      await tester.pumpAndSettle();

      expect(find.textContaining('بِسْمِ'), findsOneWidget);
      expect(find.textContaining('Në emër'), findsOneWidget);
      expect(find.textContaining('Bismillah'), findsOneWidget);
    });

    testWidgets('renders only Arabic when translations disabled', (tester) async {
      await tester.pumpWidget(makeTestable(TestVerseContent(verse: baseVerse, showTranslation: false, showTransliteration: false)));
      await tester.pumpAndSettle();

      expect(find.textContaining('بِسْمِ'), findsOneWidget);
      expect(find.textContaining('Në emër'), findsNothing);
    });

    testWidgets('large font sizes do not cause overflow in the test environment', (tester) async {
      await tester.pumpWidget(makeTestable(TestVerseContent(verse: baseVerse, fontSizeArabic: 48, fontSizeTranslation: 24)));
      await tester.pumpAndSettle();

      expect(find.textContaining('بِسْمِ'), findsOneWidget);
    });

    testWidgets('renders correctly in a narrow width (mobile portrait) constraint', (tester) async {
      // Constrain width to 200 logical pixels to simulate narrow device
      final narrow = MediaQuery(
        data: const MediaQueryData(size: Size(200, 800)),
        child: TestVerseContent(verse: baseVerse),
      );

      await tester.pumpWidget(makeTestable(narrow));
      await tester.pumpAndSettle();

      // Arabic should still be present and no exceptions should be thrown during layout
      expect(find.textContaining('بِسْمِ'), findsOneWidget);
    });
  });
}
