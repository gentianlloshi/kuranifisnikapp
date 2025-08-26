import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/data/repositories/quran_repository_impl.dart';
import 'package:kurani_fisnik_app/data/datasources/local/quran_local_data_source.dart';
import 'package:kurani_fisnik_app/data/datasources/local/storage_data_source.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/entities/app_settings.dart';
import 'package:kurani_fisnik_app/domain/entities/bookmark.dart';
import 'package:kurani_fisnik_app/domain/entities/note.dart';

class _FakeQuranLocal implements QuranLocalDataSource {
  final List<Surah> surahs;
  final Map<String,dynamic> translation;
  _FakeQuranLocal(this.surahs, this.translation);
  @override
  Future<List<Surah>> getQuranData() async => surahs;
  @override
  Future<List<Surah>> getSurahMetas() async => surahs
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
  @override
  Future<Map<String, dynamic>> getTranslationData(String translationKey) async => translation;
  @override
  Future<Map<String, dynamic>> getThematicIndex() async => {};
  @override
  Future<Map<String, dynamic>> getTransliterations() async => {};
  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) async => surahs.firstWhere((s)=>s.number==surahNumber).verses;
}
class _FakeStorage implements StorageDataSource {
  @override
  Future<void> cacheQuranData(List<Surah> surahs) async {}
  @override
  Future<List<Surah>> getCachedQuranData() async => [];
  @override
  Future<List<Surah>> getCachedQuranMetas() async => [];
  @override
  Future<void> cacheQuranMetas(List<Surah> surahMetas) async {}
  @override
  Future<List<Surah>> getCachedQuranFull() async => [];
  @override
  Future<void> cacheQuranFull(List<Surah> surahsFull) async {}
  @override
  Future<Map<String, dynamic>> getCachedTranslationData(String translationKey) async => {};
  @override
  Future<void> cacheTranslationData(String translationKey, Map<String, dynamic> data) async {}
  // unused below
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
  test('translationCoverageByKey reflects merged surahs', () async {
    final surahs = [
      Surah(number:1,nameArabic:'A',nameTransliteration:'A',nameTranslation:'A',versesCount:1,revelation:'',verses:[Verse(surahId:1,verseNumber:1,arabicText:'ar1',translation:null,transliteration:null,verseKey:'1:1')]),
      Surah(number:2,nameArabic:'B',nameTransliteration:'B',nameTranslation:'B',versesCount:1,revelation:'',verses:[Verse(surahId:2,verseNumber:1,arabicText:'ar2',translation:null,transliteration:null,verseKey:'2:1')]),
    ];
    final translation = {'quran':[{'chapter':1,'verse':1,'text':'t1'}]}; // only surah1
    final repo = QuranRepositoryImpl(_FakeQuranLocal(surahs, translation), _FakeStorage());
    await repo.getAllSurahs();
    final cov = repo.translationCoverageByKey();
    expect(cov['sq_ahmeti'], isNotNull);
  // Current repo implementation marks both surahs merged during full load; expect 2/114
  expect(cov['sq_ahmeti'], closeTo(2/114, 0.00001));
  });
}
