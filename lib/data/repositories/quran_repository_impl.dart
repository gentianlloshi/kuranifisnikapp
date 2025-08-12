import 'package:flutter/foundation.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';
import 'package:kurani_fisnik_app/data/datasources/local/quran_local_data_source.dart';
import 'package:kurani_fisnik_app/data/datasources/local/storage_data_source.dart';

class QuranRepositoryImpl implements QuranRepository {
  final QuranLocalDataSource _localDataSource;
  final StorageDataSource _storageDataSource;

  QuranRepositoryImpl(this._localDataSource, this._storageDataSource);

  @override
  Future<List<Surah>> getAllSurahs() async {
    // Try to get from cache first
    List<Surah> surahs = await _storageDataSource.getCachedQuranData();
    if (surahs.isNotEmpty) {
      debugPrint('Loaded Quran data from cache');
      // Kontrollo nëse mungojnë përkthimet / transliterimet (kjo ndodhi para se të shtonim logjikën e bashkimit)
      final needsTranslation = surahs.isNotEmpty && surahs.first.verses.any((v) => v.textTranslation == null);
      final needsTransliteration = surahs.isNotEmpty && surahs.first.verses.any((v) => v.textTransliteration == null);
      if (needsTranslation || needsTransliteration) {
        debugPrint('Merging missing translation / transliteration into cached data...');
        if (needsTranslation) {
          await _loadAndMergeTranslation('sq_ahmeti', surahs);
        }
        if (needsTransliteration) {
          await _loadAndMergeTransliteration(surahs);
        }
        // Ruaj përsëri cache me të dhënat e pasuruara
        await _storageDataSource.cacheQuranData(surahs);
      }
      return surahs;
    }

    // If not in cache, load from local assets and then cache it
    debugPrint('Loading Quran data from assets and caching...');
    surahs = await _localDataSource.getQuranData();
    await _storageDataSource.cacheQuranData(surahs);
    
  // Load default translation and transliteration and merge with Arabic text
  await _loadAndMergeTranslation('sq_ahmeti', surahs);
  await _loadAndMergeTransliteration(surahs);
  await _storageDataSource.cacheQuranData(surahs); // cache pas bashkimit
    
    return surahs;
  }

  Future<void> _loadAndMergeTranslation(String translationKey, List<Surah> surahsToUpdate) async {
    try {
      final translationData = await getTranslation(translationKey);
      final List<dynamic> translationVerses = translationData['quran'] ?? [];
      
      final Map<String, String> translationMap = {};
      for (final verse in translationVerses) {
        final key = '${verse['chapter']}:${verse['verse']}';
        translationMap[key] = verse['text'];
      }
      
        for (final surah in surahsToUpdate) {
          for (int i = 0; i < surah.verses.length; i++) {
            final verse = surah.verses[i];
            final verseKey = '${verse.surahNumber}:${verse.number}';
            surah.verses[i] = verse.copyWith(textTranslation: () => translationMap[verseKey]);
          }
        }
    } catch (e) {
      debugPrint('Error loading translation $translationKey: $e');
    }
  }

  Future<void> _loadAndMergeTransliteration(List<Surah> surahsToUpdate) async {
    try {
      final translitData = await getTransliterations();
      // transliterations.json structure: { "surah": { "verse": "text" } }
      for (final surah in surahsToUpdate) {
        final surahMap = translitData['${surah.number}'];
        if (surahMap is Map<String, dynamic>) {
          for (int i = 0; i < surah.verses.length; i++) {
            final verse = surah.verses[i];
            final vStr = verse.number.toString();
            final transliteration = surahMap[vStr];
            if (transliteration is String) {
              surah.verses[i] = verse.copyWith(transliteration: transliteration);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading transliterations: $e');
    }
  }

  @override
  Future<Surah> getSurah(int surahNumber) async {
    final surahs = await getAllSurahs();
    return surahs.firstWhere(
      (surah) => surah.number == surahNumber,
      orElse: () => throw Exception('Surah $surahNumber not found'),
    );
  }

  @override
  Future<List<Verse>> getSurahVerses(int surahNumber) async {
    final surah = await getSurah(surahNumber);
    return surah.verses;
  }

  @override
  Future<List<Verse>> getVersesBySurah(int surahId) async {
    // Implementimi i metodës që mungonte
    return await getSurahVerses(surahId);
  }

  @override
  Future<Verse> getVerse(int surahNumber, int verseNumber) async {
    final surah = await getSurah(surahNumber);
    return surah.verses.firstWhere(
      (verse) => verse.number == verseNumber,
      orElse: () => throw Exception('Verse $surahNumber:$verseNumber not found'),
    );
  }

  @override
  Future<Map<String, dynamic>> getTranslation(String translationKey) async {
    // Try to get from cache first
    Map<String, dynamic> translation = await _storageDataSource.getCachedTranslationData(translationKey);
    if (translation.isNotEmpty) {
      debugPrint('Loaded translation $translationKey from cache');
      return translation;
    }

    // If not in cache, load from local assets and then cache it
    debugPrint('Loading translation $translationKey from assets and caching...');
    translation = await _localDataSource.getTranslationData(translationKey);
    await _storageDataSource.cacheTranslationData(translationKey, translation);
    return translation;
  }

  @override
  Future<Map<String, dynamic>> getThematicIndex() async {
    return await _localDataSource.getThematicIndex();
  }

  @override
  Future<Map<String, dynamic>> getTransliterations() async {
    return await _localDataSource.getTransliterations();
  }

  @override
  Future<List<Verse>> searchVerses(String query, {String? translationKey}) async {
    final surahs = await getAllSurahs();
    final List<Verse> allVerses = [];
    
    for (final surah in surahs) {
      allVerses.addAll(surah.verses);
    }

    final queryLower = query.toLowerCase();
    return allVerses.where((verse) {
      final arabicMatch = verse.textArabic.toLowerCase().contains(queryLower);
      final translationMatch = verse.textTranslation?.toLowerCase().contains(queryLower) ?? false;
      return arabicMatch || translationMatch;
    }).toList();
  }
}
