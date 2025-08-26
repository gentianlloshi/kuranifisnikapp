import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/data/repositories/quran_repository_impl.dart';
import 'package:kurani_fisnik_app/data/datasources/local/quran_local_data_source.dart';
import 'package:kurani_fisnik_app/data/datasources/local/storage_data_source.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/entities/app_settings.dart';
import 'package:kurani_fisnik_app/domain/entities/bookmark.dart';
import 'package:kurani_fisnik_app/domain/entities/note.dart';

class FakeQuranLocalDataSource implements QuranLocalDataSource {
  final List<Surah> surahs;
  int getQuranDataCalls = 0;
  FakeQuranLocalDataSource(this.surahs);
  @override
  Future<List<Surah>> getQuranData() async { getQuranDataCalls++; return surahs; }
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
  Future<Map<String, dynamic>> getTranslationData(String translationKey) async => {'quran': []};
  @override
  Future<Map<String, dynamic>> getThematicIndex() async => {};
  @override
  Future<Map<String, dynamic>> getTransliterations() async => {};
  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) async => surahs.firstWhere((s)=>s.number==surahNumber).verses;
}

class FakeStorageDataSource implements StorageDataSource {
  List<Surah>? cached;
  Map<String, Map<String,dynamic>> translationCache = {};
  int getCacheCalls = 0;
  int cacheWrites = 0;
  @override
  Future<void> cacheQuranData(List<Surah> surahs) async { cached = surahs; cacheWrites++; }
  @override
  Future<List<Surah>> getCachedQuranData() async { getCacheCalls++; return cached ?? []; }
  @override
  Future<Map<String, dynamic>> getCachedTranslationData(String translationKey) async => translationCache[translationKey] ?? {};
  @override
  Future<void> cacheTranslationData(String translationKey, Map<String, dynamic> data) async { translationCache[translationKey]=data; }
  // Unused features
  @override
  Future<List<String>> getMemorizationList() async => [];
  @override
  Future<void> saveMemorizationList(List<String> verseKeys) async {}
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
}

void main() {
  late QuranRepositoryImpl repository;
  late FakeQuranLocalDataSource localDataSource;
  late FakeStorageDataSource storageDataSource;

  setUp(() {
    // Initialized per test
  });

  group('QuranRepositoryImpl', () {
    final tSurahs = [
      Surah(number: 1, nameArabic: 'الفاتحة', nameTransliteration: 'Al-Fatiha', nameTranslation: 'Hapja', versesCount: 7, revelation: 'Mekke'),
      Surah(number: 2, nameArabic: 'البقرة', nameTransliteration: 'Al-Baqarah', nameTranslation: 'Lopë', versesCount: 286, revelation: 'Medinë'),
    ];
  test('should return all surahs when cache is empty', () async {
    storageDataSource = FakeStorageDataSource();
    localDataSource = FakeQuranLocalDataSource(tSurahs);
    repository = QuranRepositoryImpl(localDataSource, storageDataSource);
    final result = await repository.getAllSurahs();
    expect(result, equals(tSurahs));
    expect(storageDataSource.getCacheCalls, 1);
    expect(localDataSource.getQuranDataCalls, 1);
    expect(storageDataSource.cacheWrites, 1);
  });

  test('should return cached surahs when available', () async {
    storageDataSource = FakeStorageDataSource()..cached = tSurahs;
    localDataSource = FakeQuranLocalDataSource(tSurahs);
    repository = QuranRepositoryImpl(localDataSource, storageDataSource);
    final result = await repository.getAllSurahs();
    expect(result, equals(tSurahs));
    expect(storageDataSource.getCacheCalls, 1);
    expect(localDataSource.getQuranDataCalls, 0); // no asset load
  });
  });
}
