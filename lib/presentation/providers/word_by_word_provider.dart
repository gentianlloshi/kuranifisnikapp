import 'package:flutter/material.dart';
import '../../domain/entities/word_by_word.dart';
import '../../domain/entities/verse.dart';
import '../../domain/usecases/get_word_by_word_data_usecase.dart';
import '../../domain/usecases/get_timestamp_data_usecase.dart';

class WordByWordProvider extends ChangeNotifier {
  final GetWordByWordDataUseCase getWordByWordDataUseCase;
  final GetTimestampDataUseCase getTimestampDataUseCase;

  WordByWordProvider({required this.getWordByWordDataUseCase, required this.getTimestampDataUseCase});

  bool _isLoading = false;
  String? _error;
  int? _currentSurahId;
  final Map<int, WordByWordVerse> _verses = {}; // verseNumber -> data
  final Map<int, List<WordTimestamp>> _timestamps = {}; // verseNumber -> timestamps

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WordByWordVerse> get currentWordByWordVerses => _verses.values.toList()..sort((a,b)=>a.verseNumber.compareTo(b.verseNumber));
  Map<int, List<WordTimestamp>> get allTimestamps => _timestamps; // expose full map for playlist playback

  Future<void> ensureLoaded(int surahId) async {
  if (_currentSurahId == surahId && _verses.isNotEmpty) return;
  if (_isLoading) return; // prevent concurrent loads
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
  // Fetch word-by-word data and timestamps concurrently to reduce UI stall.
  final wbwFuture = getWordByWordDataUseCase.call(surahId);
  final tsFuture = getTimestampDataUseCase.call(surahId);
  final wbw = await wbwFuture;
  final ts = await tsFuture;
      _verses
        ..clear()
        ..addEntries(wbw.map((v) => MapEntry(v.verseNumber, v)));
      _timestamps
        ..clear()
        ..addEntries(ts.map((t) => MapEntry(t.verseNumber, t.wordTimestamps)));
      _currentSurahId = surahId;
      // Simple integrity check: log mismatches (debug print for now)
      for (final v in wbw) {
        final t = _timestamps[v.verseNumber];
        if (t != null && (t.length - v.words.length).abs() > 1) {
          debugPrint('[WordByWordProvider] MISMATCH sure=$surahId verse=${v.verseNumber} words=${v.words.length} ts=${t.length}');
        }
      }
    } catch (e) {
      // Fallback: leave _verses empty so UI can decide to build naive tokens (optional)
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  WordByWordVerse? getVerseWordData(int verseNumber) => _verses[verseNumber];
  List<WordTimestamp>? getVerseTimestamps(int verseNumber) => _timestamps[verseNumber];

  // Helper to build naive data if API fails (optional usage from UI)
  WordByWordVerse buildNaiveFromVerse(Verse verse) {
    final tokens = verse.textArabic.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    int cursor = 0;
    final words = <WordData>[];
    for (final t in tokens) {
      final start = cursor;
      cursor += t.length + 1;
      words.add(WordData(arabic: t, translation: '', transliteration: '', charStart: start, charEnd: start + t.length));
    }
    return WordByWordVerse(verseNumber: verse.number, words: words);
  }
}
