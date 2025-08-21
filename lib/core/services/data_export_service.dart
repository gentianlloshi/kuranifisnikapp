import 'dart:convert';
import 'package:hive/hive.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/memorization_verse.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../presentation/providers/memorization_provider.dart';
import '../../data/datasources/local/hive_boxes.dart';

/// DATA-1: Draft export skeleton for favorites (bookmarks), notes, memorization, settings.
/// This service builds a versioned JSON bundle that can be later imported / merged.
/// Focus: read-only aggregation; NO import logic yet.
class DataExportService {
  static const int exportVersion = 2; // bumped v2: adds readingProgress, audio loop prefs, reciter preference explicit
  final StorageRepository storageRepository;

  DataExportService({required this.storageRepository});

  /// Build the raw map structure representing the export bundle.
  /// [memorizationProvider] optional; if supplied and already loaded we reuse its in-memory
  /// state (including session selection). Otherwise we read from Hive directly.
  Future<Map<String, dynamic>> buildExportBundle({MemorizationProvider? memorizationProvider}) async {
  final settings = await storageRepository.getSettings() ?? AppSettings.defaultSettings();
  // Audio related lightweight prefs (loop, singleVerseLoopCount etc.) – if not present in settings yet, read from storage keys (graceful fallback)
  // (Assumes storage has generic getString/getInt; if not, these can be appended later.)
    final bookmarks = await storageRepository.getBookmarks();
    final notes = await storageRepository.getNotes();

  final memorization = await _readMemorization(memorizationProvider);
  final readingProgress = await _readReadingProgress();

    return <String, dynamic>{
      'version': exportVersion,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
  'settings': settings.toJson(), // includes preferredReciter, font sizes, feature toggles
      'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
      'notes': notes.map((n) => n.toJson()).toList(),
  'memorization': memorization,
  'readingProgress': readingProgress,
  // v2 additions placeholder: 'audio': {'loopMode': settings.autoPlay ? 'auto' : 'manual'} etc.
      // Future (not in skeleton scope yet): readingProgress, thematicIndex, texhvid, audio prefs history, etc.
    };
  }

  /// Returns a pretty JSON string of the export bundle.
  Future<String> exportAsJsonString({MemorizationProvider? memorizationProvider, bool pretty = true}) async {
    final map = await buildExportBundle(memorizationProvider: memorizationProvider);
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(map);
    }
    return json.encode(map);
  }

  /// Internal: gather memorization structured data.
  Future<Map<String, dynamic>> _readMemorization(MemorizationProvider? provider) async {
    // Attempt to use provider if loaded (has verses or isLoading false after load call)
    if (provider != null) {
      // Provider stores verses in private map; we can't access directly. We reconstruct from public API.
      // Public API exposes: groupedSurahs(), versesForActiveSurah (only for active), memorizationList.
      // For export we need all verses with status. Since provider does not expose them all yet,
      // we fallback to reading the Hive box explicitly below. (Enhancement later: add getter.)
    }

    // Direct Hive read to capture structured status list (verses_v1).
    try {
      final box = Hive.isBoxOpen(HiveBoxes.memorization)
          ? Hive.box(HiveBoxes.memorization)
          : await Hive.openBox(HiveBoxes.memorization);
      final rawList = box.get('verses_v1') as List?; // list of {s, v, st}
      List<Map<String, dynamic>> verses = [];
      if (rawList != null) {
        for (final item in rawList) {
          if (item is Map) {
            final s = item['s'] as int?;
            final v = item['v'] as int?;
            final st = item['st'] as int?; // index
            if (s != null && v != null) {
              final statusEnum = MemorizationStatus.values[(st ?? 0).clamp(0, MemorizationStatus.values.length - 1)];
              verses.add({
                'surah': s,
                'verse': v,
                'status': statusEnum.name,
              });
            }
          }
        }
      } else {
        // Fallback legacy list (simple strings surah:verse) if structured not present.
        final legacyList = box.get('list') as List?; // legacy simple strings
        if (legacyList != null) {
          for (final k in legacyList) {
            final parts = k.toString().split(':');
            if (parts.length == 2) {
              final s = int.tryParse(parts[0]);
              final v = int.tryParse(parts[1]);
              if (s != null && v != null) {
                verses.add({'surah': s, 'verse': v, 'status': MemorizationStatus.newVerse.name});
              }
            }
          }
        }
      }

      // Session selection (if provider injected we can include live selection & repeatTarget)
      Map<String, dynamic>? session;
      if (provider?.session != null) {
        session = {
          'surah': provider!.session!.surah,
          'selected': provider.session!.selectedVerseKeys.toList()..sort(),
          'repeatTarget': provider.session!.repeatTarget,
        };
      } else {
        // Try to read persisted session selection if provider absent
        final sel = (box.get('session_selection_v1') as List?)?.cast<String>() ?? const [];
        if (sel.isNotEmpty) {
          // Attempt to infer surah from first item
            final parts = sel.first.split(':');
            final surah = parts.length == 2 ? int.tryParse(parts[0]) : null;
            session = {
              if (surah != null) 'surah': surah,
              'selected': sel..sort(),
            };
        }
      }

      return {
        'modelVersion': rawList != null ? 'v1' : 'legacy',
        'verses': verses,
        if (session != null) 'session': session,
      };
    } catch (e) {
      // Non-fatal; return error info placeholder.
      return {
        'modelVersion': 'error',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _readReadingProgress() async {
    try {
      // StorageRepositoryImpl persists maps as String->int; we expose directly.
      final positions = await storageRepository.getLastReadPosition(); // Map<String,int>
      final timestamps = await storageRepository.getLastReadTimestamps(); // Map<String,int>
      return {
        'modelVersion': 'v1',
        'positions': positions, // surah(str)->verse(int)
        'timestamps': timestamps, // surah(str)->epochSeconds
      };
    } catch (e) {
      return {
        'modelVersion': 'error',
        'error': e.toString(),
      };
    }
  }
}
