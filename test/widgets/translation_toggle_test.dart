import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurani_fisnik_app/domain/entities/verse.dart';

class _ToggleTestVerseContent extends StatefulWidget {
  final Verse verse;
  final bool initialShowTranslation;
  const _ToggleTestVerseContent({super.key, required this.verse, this.initialShowTranslation = true});

  @override
  State<_ToggleTestVerseContent> createState() => _ToggleTestVerseContentState();
}

class _ToggleTestVerseContentState extends State<_ToggleTestVerseContent> {
  late bool showTranslation;
  @override
  void initState() {
    super.initState();
    showTranslation = widget.initialShowTranslation;
  }

  void setShowTranslation(bool v) {
    setState(() => showTranslation = v);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  widget.verse.textArabic,
                  textAlign: TextAlign.right,
                ),
              ),
              if (showTranslation && (widget.verse.textTranslation?.isNotEmpty ?? false))
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(widget.verse.textTranslation!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('translation toggles off and back on without disappearing permanently', (tester) async {
    final verse = Verse(
      surahId: 1,
      verseNumber: 1,
      arabicText: 'بِسْمِ اللّٰهِ',
      translation: 'Në emër të Allahut',
      transliteration: 'Bismillah',
      verseKey: '1:1',
    );
    final key = GlobalKey<_ToggleTestVerseContentState>();

    await tester.pumpWidget(_ToggleTestVerseContent(key: key, verse: verse, initialShowTranslation: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('Në emër'), findsOneWidget);

    key.currentState!.setShowTranslation(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Në emër'), findsNothing);

    key.currentState!.setShowTranslation(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Në emër'), findsOneWidget);
  });
}
