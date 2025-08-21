import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/data/repositories/quran_repository_impl.dart';
import 'package:kurani_fisnik_app/data/datasources/local/quran_local_data_source.dart';
import 'package:kurani_fisnik_app/data/datasources/local/storage_data_source.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/core/metrics/perf_metrics.dart';

// Lightweight fakes
class _FakeQuranLocal implements QuranLocalDataSource {
  final List<Surah> _surahs;
  final Map<String,dynamic> _translation;
  final Map<String,dynamic> _translit;
  _FakeQuranLocal(this._surahs, this._translation, this._translit);
  @override
  Future<List<Surah>> getQuranData() async => _surahs;
  @override
  Future<Map<String, dynamic>> getTranslationData(String translationKey) async => _translation;
  @override
  Future<Map<String, dynamic>> getThematicIndex() async => {};
  @override
  Future<Map<String, dynamic>> getTransliterations() async => _translit;
  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) async => _surahs.firstWhere((s)=>s.number==surahNumber).verses;
}

class _FakeStorage implements StorageDataSource {
  List<Surah> cached = [];
  final Map<String,Map<String,dynamic>> translations = {};
  @override
  Future<void> cacheQuranData(List<Surah> surahs) async { cached = surahs; }
  @override
  Future<List<Surah>> getCachedQuranData() async => cached;
  @override
  Future<Map<String, dynamic>> getCachedTranslationData(String translationKey) async => translations[translationKey] ?? {};
  @override
  Future<void> cacheTranslationData(String translationKey, Map<String, dynamic> data) async { translations[translationKey] = data; }
  // Unused in test
  @override
  Future<List<Bookmark>> getBookmarks() async => [];
  @override
  Future<void> saveBookmarks(List<Bookmark> bookmarks) async {}
  @override
  Future<List<Note>> getNotes() async => [];
  @override
  Future<void> saveNotes(List<Note> notes) async {}
  @override
  Future<AppSettings> getSettings() async => AppSettings.defaultSettings();
  @override
  Future<void> saveSettings(AppSettings settings) async {}
  @override
  Future<List<String>> getMemorizationList() async => [];
  @override
  Future<void> saveMemorizationList(List<String> verseKeys) async {}
}

void main() {
  test('enrichment coverage updates after merges', () async {
    // Build tiny dataset of 2 surahs
    final s1 = Surah(number:1,nameArabic:'A',nameTransliteration:'A',nameTranslation:'A',versesCount:1,revelation:'',verses:[Verse(surahId:1,verseNumber:1,arabicText:'ar1',translation:null,transliteration:null,verseKey:'1:1')]);
    final s2 = Surah(number:2,nameArabic:'B',nameTransliteration:'B',nameTranslation:'B',versesCount:1,revelation:'',verses:[Verse(surahId:2,verseNumber:1,arabicText:'ar2',translation:null,transliteration:null,verseKey:'2:1')]);
    final translationMap = {'quran':[{'chapter':1,'verse':1,'text':'t1'},{'chapter':2,'verse':1,'text':'t2'}]};
    final translitMap = {'1':{'1':'tr1'},'2':{'1':'tr2'}};
    final repo = QuranRepositoryImpl(_FakeQuranLocal([s1,s2], translationMap, translitMap), _FakeStorage());

    // Initially, coverage should be 0.
    expect(PerfMetrics.instance.currentSnapshot().enrichmentCoverage, 0);
    await repo.getAllSurahs(); // triggers full load & merges
    final cov = PerfMetrics.instance.currentSnapshot().enrichmentCoverage;
    expect(cov, greaterThan(0));
    expect(cov, 1/114 * 2); // both enriched (2/114)
  });
}
