import 'package:flutter_test/flutter_test.dart';

import 'package:kurani_fisnik_app/presentation/search/unified_ranking.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/entities/note.dart';

void main() {
  group('computeUnifiedTop', () {
    test('returns empty list for empty query', () {
      final res = computeUnifiedTop(verses: const [], notes: const [], query: '   ');
      expect(res, isEmpty);
    });

    test('handles diacritics by folding query and sources', () {
      final now = DateTime.now();
      final verse = Verse(
        surahId: 1,
        verseNumber: 2,
        arabicText: '',
        translation: 'Mëshira e madhe', // includes ë
        transliteration: 'Meshira e madhe',
        verseKey: '1:2',
      );
      final note = Note(
        id: 'd1',
        verseKey: '1:2',
        content: 'shënim mbi mëshirë', // contains diacritics
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
        tags: const ['Mëshira'],
      );

      // Query without diacritics should match both translation and note
      final res = computeUnifiedTop(
        verses: [verse],
        notes: [note],
        query: 'meshira',
      );
      expect(res, isNotEmpty);
      // Note should still outrank due to base boost
      expect(res.first.note?.id, 'd1');
    });

    test('orders notes over verses due to base boost + content match', () {
      final now = DateTime.now();
      final verse = Verse(
        surahId: 1,
        verseNumber: 1,
        arabicText: '',
        translation: 'This has apple inside',
        transliteration: null,
        verseKey: '1:1',
      );
      final note = Note(
        id: 'n1',
        verseKey: '1:1',
        content: 'I wrote about apple today',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
        tags: const [],
      );

      final res = computeUnifiedTop(verses: [verse], notes: [note], query: 'apple');
      expect(res.length, 2);
      expect(res.first.note?.id, 'n1');
      expect(res.last.verse?.verseKey, '1:1');
    });

    test('tag and recency boosts influence ordering among notes', () {
      final now = DateTime.now();
      final verse = Verse(
        surahId: 1,
        verseNumber: 1,
        arabicText: '',
        translation: 'Reference to apple here',
        transliteration: null,
        verseKey: '1:1',
      );

      // Content match + fresh recency (1 day) -> strong score
      final noteContentFresh = Note(
        id: 'freshContent',
        verseKey: '1:1',
        content: 'apple note body',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
        tags: const [],
      );

      // Tag match only + fresh recency -> medium score
      final noteTagFresh = Note(
        id: 'tagFresh',
        verseKey: '1:1',
        content: 'no keyword here',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
        tags: const ['work-apple'],
      );

      // Content match but older than 30 days (no recency bonus) -> still above verse
      final noteContentOld = Note(
        id: 'oldContent',
        verseKey: '1:1',
        content: 'apple from last month',
        createdAt: now.subtract(const Duration(days: 40)),
        updatedAt: now.subtract(const Duration(days: 40)),
        tags: const [],
      );

      final res = computeUnifiedTop(
        verses: [verse],
        notes: [noteTagFresh, noteContentOld, noteContentFresh],
        query: 'apple',
        limit: 5,
      );

      // Expected order by score: content+fresh > content+old > tag-only > verse
      expect(res.map((e) => e.note?.id ?? e.verse?.verseKey).toList(),
          ['freshContent', 'oldContent', 'tagFresh', '1:1']);
    });

    test('respects limit parameter', () {
      final now = DateTime.now();
      final verses = List.generate(
        3,
        (i) => Verse(
          surahId: 1,
          verseNumber: i + 1,
          arabicText: '',
          translation: i == 0 ? 'apple and banana' : 'banana only',
          transliteration: null,
          verseKey: '1:${i + 1}',
        ),
      );
      final notes = [
        Note(
          id: 'n1',
          verseKey: '1:1',
          content: 'apple note',
          createdAt: now.subtract(const Duration(days: 3)),
          updatedAt: now.subtract(const Duration(days: 3)),
          tags: const [],
        ),
        Note(
          id: 'n2',
          verseKey: '1:2',
          content: 'banana note',
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now.subtract(const Duration(days: 10)),
          tags: const [],
        ),
      ];

      final res = computeUnifiedTop(
        verses: verses,
        notes: notes,
        query: 'apple',
        limit: 2,
      );
      expect(res.length, 2);
    });
  });
}
