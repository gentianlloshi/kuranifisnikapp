import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/providers/quran_provider.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/entities/surah_meta.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surahs_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surah_verses_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/get_surahs_arabic_only_usecase.dart';
import 'package:kurani_fisnik_app/domain/usecases/search_verses_usecase.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';
import 'package:kurani_fisnik_app/data/repositories/quran_repository_impl.dart';
import 'package:kurani_fisnik_app/data/datasources/local/quran_local_data_source.dart';
import 'package:kurani_fisnik_app/data/datasources/local/storage_data_source.dart';
import 'package:kurani_fisnik_app/domain/entities/app_settings.dart';
import 'package:kurani_fisnik_app/domain/entities/bookmark.dart';
import 'package:kurani_fisnik_app/domain/entities/note.dart';

class _FakeQuranRepo implements QuranRepository {
  final List<Surah> _surahs = [
    Surah(
      id: 1,
      number: 1,
      nameArabic: 'Al-Fatiha',
      nameTranslation: 'Hapja',
      nameTransliteration: 'Al-Fatiha',
      revelation: 'Meccan',
      versesCount: 7,
      verses: const [],
    ),
  ];

  Future<List<Surah>> getSurahs() async => _surahs;
  @override
  Future<List<Surah>> getAllSurahs() async => _surahs;
  @override
  Future<Surah> getSurah(int surahNumber) async => _surahs.firstWhere((s) => s.number == surahNumber);
  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) async => getVersesBySurah(surahNumber);
  @override
  Future<Verse> getVerse(int surahNumber, int verseNumber) async => (await getVersesBySurah(surahNumber)).firstWhere((v) => v.verseNumber == verseNumber);
  @override
  Future<Map<String, dynamic>> getTranslation(String translationKey) async => {};
  @override
  Future<Map<String, dynamic>> getThematicIndex() async => {};
  @override
  Future<Map<String, dynamic>> getTransliterations() async => {};
  @override
  Future<List<SurahMeta>> getSurahList() async => _surahs.map((s) => SurahMeta.fromSurah(s)).toList();
  @override
  Future<List<Verse>> getVersesForSurah(int surahId) async => getVersesBySurah(surahId);

  @override
  Future<List<Verse>> getVersesBySurah(int surahId) async => List.generate(7, (i) => Verse(
        surahId: surahId,
        verseNumber: i + 1,
        arabicText: 'Ajeti ${i + 1}',
        translation: 'Përkthimi ${i + 1}',
        transliteration: 'Trans ${i + 1}',
        verseKey: '$surahId:${i + 1}',
      ));

  @override
  Future<List<Verse>> searchVerses(String query, {String? translationKey}) async => [];

  // New API members for enrichment coverage
  @override
  Future<void> ensureSurahTranslation(int surahNumber, {String translationKey = 'sq_ahmeti'}) async {}
  @override
  Future<void> ensureSurahTransliteration(int surahNumber) async {}
  @override
  bool isSurahFullyEnriched(int surahNumber) => true;
  @override
  Map<String, double> translationCoverageByKey() => const {};
  @override
  Stream<double> get enrichmentCoverageStream => const Stream<double>.empty();
  @override
  Stream<Map<String, double>> get translationCoverageStream => const Stream<Map<String, double>>.empty();
  @override
  void setPreferredTranslationKey(String translationKey) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('QuranProvider.openSurahAtVerse', () {
    late QuranProvider provider;

    setUp(() {
      final repo = _FakeQuranRepo();
      provider = QuranProvider(
        getSurahsUseCase: GetSurahsUseCase(repo),
        getSurahsArabicOnlyUseCase: GetSurahsArabicOnlyUseCase(FakeRepoWrapper(repo)),
        searchVersesUseCase: SearchVersesUseCase(repo),
        getSurahVersesUseCase: GetSurahVersesUseCase(repo),
      );
    });

    test('sets pending verse and consumes after load', () async {
  provider.openSurahAtVerse(1, 5);
      // After openSurahAtVerse the surah is loaded and pending scroll stored.
      final pending = provider.consumePendingScrollTarget();
      expect(pending, 5);
      // Consuming again should return null.
      expect(provider.consumePendingScrollTarget(), isNull);
    });
  });
}

// Minimal wrapper to satisfy concrete type of GetSurahsArabicOnlyUseCase which expects impl
class FakeRepoWrapper extends QuranRepositoryImpl {
  FakeRepoWrapper(QuranRepository base)
      : super(_LocalAdapter(base), _StorageAdapter());
}

class _LocalAdapter implements QuranLocalDataSource {
  final QuranRepository base;
  _LocalAdapter(this.base);
  @override
  Future<List<Surah>> getQuranData() => base.getAllSurahs();
  @override
  Future<List<Surah>> getSurahMetas() async {
    final surahs = await base.getAllSurahs();
    return surahs
        .map((s) => Surah(
              id: s.id,
              number: s.number,
              nameArabic: s.nameArabic,
              nameTransliteration: s.nameTransliteration,
              nameTranslation: s.nameTranslation,
              versesCount: s.versesCount,
              revelation: s.revelation,
              verses: const [],
            ))
        .toList();
  }
  @override
  Future<Map<String, dynamic>> getTranslationData(String translationKey) async => {};
  @override
  Future<Map<String, dynamic>> getThematicIndex() async => {};
  @override
  Future<Map<String, dynamic>> getTransliterations() async => {};
  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) => base.getSurahVerses(surahNumber);
}

class _StorageAdapter implements StorageDataSource {
  List<Surah> cache = [];
  List<Surah> metas = [];
  List<Surah> full = [];
  @override
  Future<AppSettings> getSettings() async => AppSettings.defaultSettings();
  @override
  Future<void> saveSettings(AppSettings settings) async {}
  @override
  Future<List<Bookmark>> getBookmarks() async => [];
  @override
  Future<void> saveBookmarks(List<Bookmark> bookmarks) async {}
  @override
  Future<List<Note>> getNotes() async => [];
  @override
  Future<void> saveNotes(List<Note> notes) async {}
  @override
  Future<List<Surah>> getCachedQuranData() async => cache;
  @override
  Future<void> cacheQuranData(List<Surah> surahs) async { cache = surahs; }
  @override
  Future<List<Surah>> getCachedQuranMetas() async => metas.isNotEmpty ? metas : cache;
  @override
  Future<void> cacheQuranMetas(List<Surah> surahMetas) async { metas = surahMetas; }
  @override
  Future<List<Surah>> getCachedQuranFull() async => full.isNotEmpty ? full : cache;
  @override
  Future<void> cacheQuranFull(List<Surah> surahsFull) async { full = surahsFull; }
  @override
  Future<Map<String, dynamic>> getCachedTranslationData(String translationKey) async => {};
  @override
  Future<void> cacheTranslationData(String translationKey, Map<String, dynamic> data) async {}
  @override
  Future<List<String>> getMemorizationList() async => [];
  @override
  Future<void> saveMemorizationList(List<String> verseKeys) async {}
}
