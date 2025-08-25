import 'dart:async';
import 'package:kurani_fisnik_app/core/utils/logger.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';
import 'package:kurani_fisnik_app/data/datasources/local/quran_local_data_source.dart';
import 'package:kurani_fisnik_app/data/datasources/local/storage_data_source.dart';
import 'package:kurani_fisnik_app/core/metrics/perf_metrics.dart';

class QuranRepositoryImpl implements QuranRepository {
  final QuranLocalDataSource _localDataSource;
  final StorageDataSource _storageDataSource;
  // Track which surahs have translation / transliteration merged (by translation key)
  final Map<String, Set<int>> _translationMerged = {}; // key -> set of surahNumbers
  final Set<int> _transliterationMerged = <int>{};
  // Reactive controllers (broadcast) for coverage updates
  final StreamController<double> _enrichmentCoverageController = StreamController<double>.broadcast();
  final StreamController<Map<String,double>> _translationCoverageController = StreamController<Map<String,double>>.broadcast();

  @override
  Stream<double> get enrichmentCoverageStream => _enrichmentCoverageController.stream;
  @override
  Stream<Map<String,double>> get translationCoverageStream => _translationCoverageController.stream;

  QuranRepositoryImpl(this._localDataSource, this._storageDataSource);

  @override
  Future<List<Surah>> getAllSurahs() async {
    // Full load (Arabic + default translation + transliteration) – invoked by legacy callers.
    final sw = Stopwatch()..start();
    List<Surah> surahs = await _storageDataSource.getCachedQuranData();
    if (surahs.isEmpty) {
      Logger.i('Loading Quran data (full) from assets...', tag: 'QuranRepo');
      surahs = await _localDataSource.getQuranData();
    }
    // Merge if missing (lazy augmentation) – keep cost deferred until requested.
    final needsTranslation = surahs.isNotEmpty && surahs.first.verses.any((v) => v.textTranslation == null);
    final needsTransliteration = surahs.isNotEmpty && surahs.first.verses.any((v) => v.textTransliteration == null);
    if (needsTranslation) {
      await _loadAndMergeTranslation('sq_ahmeti', surahs);
    }
    if (needsTransliteration) {
      await _loadAndMergeTransliteration(surahs);
    }
    await _storageDataSource.cacheQuranData(surahs);
    Logger.d('getAllSurahs full ${sw.elapsedMilliseconds}ms', tag: 'Perf');
  _updateEnrichmentCoverage(); // full load likely enriched now
    return surahs;
  }

  // Lightweight meta fetch (no translation / transliteration merging). Used by lazy UI list / indexing pre-stage.
  Future<List<Surah>> getArabicOnly() async {
    final sw = Stopwatch()..start();
    List<Surah> surahs = await _storageDataSource.getCachedQuranData();
    if (surahs.isNotEmpty) {
      Logger.d('getArabicOnly cache ${sw.elapsedMilliseconds}ms', tag: 'Perf');
      return surahs;
    }
    Logger.i('Loading Arabic-only Quran data (no merges) from assets...', tag: 'QuranRepo');
    surahs = await _localDataSource.getQuranData();
    // Intentionally NOT merging translation/transliteration here.
    await _storageDataSource.cacheQuranData(surahs);
    Logger.d('getArabicOnly fresh ${sw.elapsedMilliseconds}ms', tag: 'Perf');
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
          bool any = false;
          for (int i = 0; i < surah.verses.length; i++) {
            final verse = surah.verses[i];
            final verseKey = '${verse.surahNumber}:${verse.number}';
            surah.verses[i] = verse.copyWith(textTranslation: () => translationMap[verseKey]);
            any = true;
          }
          if (any) {
            (_translationMerged[translationKey] ??= <int>{}).add(surah.number);
          }
        }
    } catch (e) {
  Logger.w('Error loading translation $translationKey: $e', tag: 'QuranRepo');
    }
  _updateEnrichmentCoverage();
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
          _transliterationMerged.add(surah.number);
        }
      }
    } catch (e) {
  Logger.w('Error loading transliterations: $e', tag: 'QuranRepo');
    }
  _updateEnrichmentCoverage();
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
  Logger.i('Loaded translation $translationKey from cache', tag: 'QuranRepo');
      return translation;
    }

    // If not in cache, load from local assets and then cache it
  Logger.i('Loading translation $translationKey from assets and caching...', tag: 'QuranRepo');
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

  // On-demand enrichment implementations
  @override
  Future<void> ensureSurahTranslation(int surahNumber, {String translationKey = 'sq_ahmeti'}) async {
    final already = _translationMerged[translationKey]?.contains(surahNumber) ?? false;
    if (already) return;
    final surahs = await getArabicOnly();
    final target = surahs.firstWhere((s) => s.number == surahNumber, orElse: () => throw Exception('Surah $surahNumber not found'));
    await _loadAndMergeTranslation(translationKey, [target]);
    await _storageDataSource.cacheQuranData(surahs); // persist enriched one
  }

  @override
  Future<void> ensureSurahTransliteration(int surahNumber) async {
    if (_transliterationMerged.contains(surahNumber)) return;
    final surahs = await getArabicOnly();
    final target = surahs.firstWhere((s) => s.number == surahNumber, orElse: () => throw Exception('Surah $surahNumber not found'));
    await _loadAndMergeTransliteration([target]);
    await _storageDataSource.cacheQuranData(surahs);
  }

  @override
  bool isSurahFullyEnriched(int surahNumber) {
    final hasTrans = (_translationMerged['sq_ahmeti']?.contains(surahNumber) ?? false);
    final hasTranslit = _transliterationMerged.contains(surahNumber);
    return hasTrans && hasTranslit;
  }

  void _updateEnrichmentCoverage() {
    // Compute fraction of surahs that have both translation+transliteration merged for default translation.
    final enriched = _transliterationMerged.where((s) => _translationMerged['sq_ahmeti']?.contains(s) ?? false).length;
    final coverage = enriched / 114.0;
    PerfMetrics.instance.setEnrichmentCoverage(coverage);
    // Emit to reactive stream (ignore if closed)
    if (!_enrichmentCoverageController.isClosed) {
      _enrichmentCoverageController.add(coverage);
    }
    // Also emit translation coverage map to unify updates for panel dialog if both shift.
    if (!_translationCoverageController.isClosed) {
      _translationCoverageController.add(translationCoverageByKey());
    }
  }

  @override
  Map<String,double> translationCoverageByKey() {
    final Map<String,double> out = {};
    for (final entry in _translationMerged.entries) {
      out[entry.key] = entry.value.length / 114.0;
    }
    return out;
  }

  // Ensure controllers are closed when repository disposed (if ever) – defensive
  void dispose() {
    _enrichmentCoverageController.close();
    _translationCoverageController.close();
  }
}
