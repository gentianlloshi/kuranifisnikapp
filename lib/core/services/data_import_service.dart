import 'dart:convert';
import 'dart:async';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/local/hive_boxes.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/memorization_verse.dart';
import '../../domain/repositories/storage_repository.dart';

/// DATA-1: Initial skeleton (completed)
/// DATA-2 (Batch D): Implement applyImport + extended diff (memorization + reading progress)
/// Supported merge strategies (v1):
///  - Settings: overwrite (future: selective/partial)
///  - Bookmarks: merge on verseKey, prefer newer createdAt
///  - Notes: merge on id, prefer newer updatedAt
///  - Memorization: union of verses; status resolved by max status ordinal (mastered > inProgress > newVerse)
///  - ReadingProgress: choose higher verse OR newer timestamp (keeps imported timestamp when chosen)
class DataImportService {
  final StorageRepository storageRepository;
  DataImportService({required this.storageRepository});

  // DATA-3: Progress stream + cancelation support
  final StreamController<ImportProgress> _progressController = StreamController<ImportProgress>.broadcast();
  bool _cancelRequested = false;

  Stream<ImportProgress> get progressStream => _progressController.stream;
  void cancelImport() { _cancelRequested = true; }
  void _emit(ImportProgress p) {
    if (_progressController.hasListener && !_progressController.isClosed) {
      _progressController.add(p);
    }
  }

  Future<ImportBundle> parse(String jsonString) async {
    final map = json.decode(jsonString) as Map<String, dynamic>;
    final version = (map['version'] as num?)?.toInt() ?? 1;
    const supported = 2; // keep in sync with DataExportService.exportVersion
    if (version > supported) {
      throw UnsupportedError('Unsupported export bundle version=$version (max supported=$supported)');
    }
    return ImportBundle(root: map);
  }

  /// Compute a dry-run diff between current state and bundle (including memorization & reading progress)
  Future<ImportDiff> dryRunDiff(ImportBundle bundle) async {
    // Current state fetch
    final currentBookmarks = await storageRepository.getBookmarks();
    final currentNotes = await storageRepository.getNotes();
    final currentPositions = await storageRepository.getLastReadPosition();
    final currentTimestamps = await storageRepository.getLastReadTimestamps();
    // Memorization (structured via Hive)
    final memorizationBox = Hive.isBoxOpen(HiveBoxes.memorization)
        ? Hive.box(HiveBoxes.memorization)
        : await Hive.openBox(HiveBoxes.memorization);
    final existingMemList = (memorizationBox.get('verses_v1') as List?)?.cast<Map>() ?? const [];
    final existingMemMap = <String, int>{}; // key->statusIndex
    for (final m in existingMemList) {
      final s = m['s']; final v = m['v']; final st = (m['st'] ?? 0) as int; if (s is int && v is int) {
        existingMemMap['$s:$v'] = st;
      }
    }

    // Exported roots
    final exportedSettings = bundle.root['settings'] as Map<String, dynamic>?;
    final exportedBookmarks = (bundle.root['bookmarks'] as List?)?.cast<Map>() ?? const [];
    final exportedNotes = (bundle.root['notes'] as List?)?.cast<Map>() ?? const [];
    final exportedMem = (bundle.root['memorization'] as Map?)?['verses'] as List? ?? const [];
    final exportedReading = bundle.root['readingProgress'] as Map? ?? const {};
    final exportedPositions = (exportedReading['positions'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? const {};
    final exportedTimestamps = (exportedReading['timestamps'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? const {};

    // Bookmarks diff
    final bookmarkAdds = <Map<String, dynamic>>[];
    final bookmarkUpdates = <Map<String, dynamic>>[];
    final existingBookmarkMap = { for (final b in currentBookmarks) b.verseKey : b };
    for (final raw in exportedBookmarks) {
      final verseKey = raw['verseKey'] as String?; if (verseKey == null) continue;
      final existing = existingBookmarkMap[verseKey];
      if (existing == null) {
        bookmarkAdds.add(raw.cast<String,dynamic>());
      } else {
        // Only mark update if incoming createdAt is newer
        try {
          final impTs = DateTime.parse(raw['createdAt']);
          if (impTs.isAfter(existing.createdAt)) {
            bookmarkUpdates.add(raw.cast<String,dynamic>());
          }
        } catch (_) {
          // If parse fails, still mark as potential update
          bookmarkUpdates.add(raw.cast<String,dynamic>());
        }
      }
    }

    // Notes diff
    final noteAdds = <Map<String, dynamic>>[];
    final noteUpdates = <Map<String, dynamic>>[];
    final noteConflicts = <NoteConflict>[]; // near-simultaneous edits
    const conflictThreshold = Duration(seconds: 5);
    final existingNoteMap = { for (final n in currentNotes) n.id : n };
    for (final raw in exportedNotes) {
      final id = raw['id'] as String?; if (id == null) continue;
      final existing = existingNoteMap[id];
      if (existing == null) {
        noteAdds.add(raw.cast<String,dynamic>());
      } else {
        try {
          final impTs = DateTime.parse(raw['updatedAt']);
          if (impTs.isAfter(existing.updatedAt)) {
            final delta = impTs.difference(existing.updatedAt).abs();
            if (delta <= conflictThreshold) {
              noteConflicts.add(NoteConflict(
                id: id,
                local: existing.toJson(),
                imported: raw.cast<String,dynamic>(),
              ));
            } else {
              noteUpdates.add(raw.cast<String,dynamic>());
            }
          }
        } catch (_) {}
      }
    }

    // Memorization diff
    final memorizationAdds = <Map<String, dynamic>>[]; // new keys
    final memorizationStatusUpgrades = <Map<String, dynamic>>[]; // existing but higher status
    for (final raw in exportedMem) {
      if (raw is! Map) continue;
      final s = raw['surah'] ?? raw['s'];
      final v = raw['verse'] ?? raw['v'];
      final statusStr = raw['status'] as String?;
      if (s is! int || v is! int) continue;
      final key = '$s:$v';
      final importedStatusIndex = _statusIndexFromName(statusStr);
      final existingStatusIndex = existingMemMap[key];
      if (existingStatusIndex == null) {
        memorizationAdds.add({'s': s, 'v': v, 'st': importedStatusIndex});
      } else if (importedStatusIndex > existingStatusIndex) {
        memorizationStatusUpgrades.add({'s': s, 'v': v, 'from': existingStatusIndex, 'to': importedStatusIndex});
      }
    }

    // Reading progress diff
    final readingProgressImproved = <String, Map<String, int>>{}; // surah -> {oldVerse,newVerse,oldTs,newTs}
    exportedPositions.forEach((surah, pos) {
      final existingPos = currentPositions[surah] ?? 0;
      final existingTs = currentTimestamps[surah] ?? 0;
      final importedTs = exportedTimestamps[surah] ?? 0;
      final improved = pos > existingPos || importedTs > existingTs;
      if (improved) {
        readingProgressImproved[surah] = {
          'oldVerse': existingPos,
          'newVerse': pos,
          'oldTs': existingTs,
          'newTs': importedTs,
        };
      }
    });

    SettingsChange settingsChange = SettingsChange.none;
    if (exportedSettings != null) {
      // Detect partial vs full based on expected keys present
      const expectedKeys = {
        'theme','fontSize','fontSizeArabic','fontSizeTranslation','selectedTranslation','showArabic','showTranslation','showTransliteration','showWordByWord','showVerseNumbers','enableNotifications','notificationTime','enableAudio','audioVolume','playbackSpeed','autoPlay','preferredReciter','searchInArabic','searchInTranslation','searchInTransliteration','searchJuz','autoScrollEnabled','reduceMotion','adaptiveAutoScroll','wordHighlightGlow','useSpanWordRendering','backgroundIndexingEnabled','verboseWbwLogging'
      };
      final missing = expectedKeys.difference(exportedSettings.keys.toSet());
      settingsChange = missing.isEmpty ? SettingsChange.overwrite : SettingsChange.partial;
    }

    return ImportDiff(
      settingsChange: settingsChange,
      bookmarkAdds: bookmarkAdds,
      bookmarkUpdates: bookmarkUpdates,
      noteAdds: noteAdds,
      noteUpdates: noteUpdates,
      memorizationAdds: memorizationAdds,
      memorizationStatusUpgrades: memorizationStatusUpgrades,
      readingProgressImprovements: readingProgressImproved,
      noteConflicts: noteConflicts,
    );
  }

  /// Apply an import bundle using provided options. Returns a result summary.
  Future<DataImportResult> applyImport({
    required ImportBundle bundle,
    required DataImportOptions options,
    ImportDiff? precomputedDiff,
  }) async {
    _cancelRequested = false;
    final diff = precomputedDiff ?? await dryRunDiff(bundle);
    final result = DataImportResult();
    void checkCancel(String phase) {
      if (_cancelRequested) {
        result.canceled = true;
        result.errors.add('Import canceled by user during $phase');
        throw _Canceled();
      }
    }

    try {
      _emit(ImportProgress.phase('init', message: 'Përgatitja e importit'));

      // SETTINGS
      if (options.overwriteSettings && bundle.root['settings'] is Map<String,dynamic>) {
        try {
          checkCancel('settings');
          _emit(ImportProgress.phase('settings', message: 'Po aplikohen cilësimet'));
          final raw = (bundle.root['settings'] as Map<String,dynamic>);
          final incoming = AppSettings.fromJson(raw);
          if (precomputedDiff?.settingsChange == SettingsChange.partial) {
            final existing = await storageRepository.getSettings() ?? AppSettings.defaultSettings();
            // Preserve local audio + font fields if absent in bundle map
            AppSettings merged = incoming;
            if (!raw.containsKey('preferredReciter')) {
              merged = merged.copyWith(preferredReciter: existing.preferredReciter);
            }
            if (!raw.containsKey('audioVolume')) {
              merged = merged.copyWith(audioVolume: existing.audioVolume);
            }
            if (!raw.containsKey('playbackSpeed')) {
              merged = merged.copyWith(playbackSpeed: existing.playbackSpeed);
            }
            if (!raw.containsKey('autoPlay')) {
              merged = merged.copyWith(autoPlay: existing.autoPlay);
            }
            if (!raw.containsKey('fontSizeArabic')) {
              merged = merged.copyWith(fontSizeArabic: existing.fontSizeArabic);
            }
            if (!raw.containsKey('fontSizeTranslation')) {
              merged = merged.copyWith(fontSizeTranslation: existing.fontSizeTranslation);
            }
            if (!raw.containsKey('fontSize')) { // legacy single size
              merged = merged.copyWith(fontSize: existing.fontSize);
            }
            await storageRepository.saveSettings(merged);
          } else {
            await storageRepository.saveSettings(incoming);
          }
          result.settingsOverwritten = true;
        } catch (e) {
          if (e is! _Canceled) {
            result.errors.add('Settings import failed: $e');
          } else {
            rethrow;
          }
        }
      }

      // BOOKMARKS
      if (options.importBookmarks) {
        try {
          checkCancel('bookmarks');
          final total = diff.bookmarkAdds.length + diff.bookmarkUpdates.length;
          int processed = 0;
          _emit(ImportProgress('bookmarks', processed, total, 'Favoritet'));
          final existing = await storageRepository.getBookmarks();
          final map = { for (final b in existing) b.verseKey : b };
          for (final raw in [...diff.bookmarkAdds, ...diff.bookmarkUpdates]) {
            checkCancel('bookmarks');
            try {
              final b = Bookmark.fromJson(raw);
              final current = map[b.verseKey];
              if (current == null) {
                map[b.verseKey] = b;
                result.bookmarksAdded++;
              } else if (b.createdAt.isAfter(current.createdAt)) {
                map[b.verseKey] = b;
                result.bookmarksUpdated++;
              }
            } catch (e) {
              result.errors.add('Bookmark parse failed: $e');
            } finally {
              processed++; _emit(ImportProgress('bookmarks', processed, total, 'Favoritet'));
            }
          }
          checkCancel('bookmarks');
          await storageRepository.saveBookmarks(map.values.toList());
        } catch (e) {
          if (e is! _Canceled) {
            result.errors.add('Bookmark import failed: $e');
          } else { rethrow; }
        }
      }

      // NOTES
      if (options.importNotes) {
        try {
          checkCancel('notes');
          final existing = await storageRepository.getNotes();
          final map = { for (final n in existing) n.id : n };
          final toProcess = [...diff.noteAdds, ...diff.noteUpdates];
          int processed = 0; final total = toProcess.length + diff.noteConflicts.length;
          _emit(ImportProgress('notes', processed, total, 'Shënimet'));
          for (final raw in toProcess) {
            checkCancel('notes');
            try {
              final n = Note.fromJson(raw);
              final current = map[n.id];
              if (current == null) { map[n.id] = n; result.notesAdded++; }
              else if (n.updatedAt.isAfter(current.updatedAt)) { map[n.id] = n; result.notesUpdated++; }
            } catch (e) { result.errors.add('Note parse failed: $e'); }
            finally { processed++; _emit(ImportProgress('notes', processed, total, 'Shënimet')); }
          }
          // Resolve conflicts
          for (final conflict in diff.noteConflicts) {
            checkCancel('notes');
            final resolution = options.noteConflictResolutions[conflict.id] ?? NoteConflictResolution.import;
            if (resolution == NoteConflictResolution.import) {
              try { final n = Note.fromJson(conflict.imported); map[n.id] = n; result.noteConflictsImported++; }
              catch (e) { result.errors.add('Conflict import parse failed: $e'); }
            } else { result.noteConflictsKeptLocal++; }
            processed++; _emit(ImportProgress('notes', processed, total, 'Shënimet'));
          }
          checkCancel('notes');
          // Persist each via repository API (no bulk API exposed)
          for (final n in map.values) {
            checkCancel('notes');
            await storageRepository.saveNote(n);
          }
        } catch (e) { if (e is! _Canceled) { result.errors.add('Notes import failed: $e'); } else { rethrow; } }
      }

      // MEMORIZATION
      if (options.importMemorization && bundle.root['memorization'] != null) {
        try {
          checkCancel('memorization');
          _emit(ImportProgress.phase('memorization', message: 'Po përditësohet memorisja'));
          final box = Hive.isBoxOpen(HiveBoxes.memorization)
              ? Hive.box(HiveBoxes.memorization)
              : await Hive.openBox(HiveBoxes.memorization);
          final existingList = (box.get('verses_v1') as List?)?.cast<Map>() ?? [];
          final map = <String, int>{};
          for (final m in existingList) {
            final s = m['s']; final v = m['v']; final st = (m['st'] ?? 0) as int; if (s is int && v is int) map['$s:$v']=st; }
          // Apply adds / status upgrades
          for (final add in diff.memorizationAdds) {
            checkCancel('memorization');
            final s = add['s'] as int; final v = add['v'] as int; final st = add['st'] as int; map['$s:$v']=st; result.memorizationAdded++; }
          for (final up in diff.memorizationStatusUpgrades) {
            checkCancel('memorization');
            final s = up['s'] as int; final v = up['v'] as int; final to = up['to'] as int; map['$s:$v']=to; result.memorizationUpgraded++; }
          // Persist
          checkCancel('memorization');
          final outList = map.entries.map((e){ final parts = e.key.split(':'); return {'s': int.parse(parts[0]), 'v': int.parse(parts[1]), 'st': e.value}; }).toList();
          await box.put('verses_v1', outList);
        } catch (e) { if (e is! _Canceled) { result.errors.add('Memorization import failed: $e'); } else { rethrow; } }
      }

      // READING PROGRESS
      if (options.importReadingProgress && bundle.root['readingProgress'] != null) {
        try {
          checkCancel('readingProgress');
          final total = diff.readingProgressImprovements.length; int processed = 0;
          _emit(ImportProgress('readingProgress', processed, total, 'Progresi i leximit'));
          final prefs = await SharedPreferences.getInstance();
          // Load current
          Map<String,int> positions = await storageRepository.getLastReadPosition();
          Map<String,int> timestamps = await storageRepository.getLastReadTimestamps();
          diff.readingProgressImprovements.forEach((surah, info) {
            positions[surah] = info['newVerse']!;
            timestamps[surah] = info['newTs']!;
          processed++; _emit(ImportProgress('readingProgress', processed, total, 'Progresi i leximit'));
          });
          checkCancel('readingProgress');
          await prefs.setString('last_read_positions_v1', json.encode(positions));
          await prefs.setString('last_read_timestamps_v1', json.encode(timestamps));
        } catch (e) { if (e is! _Canceled) { result.errors.add('Reading progress import failed: $e'); } else { rethrow; } }
      }

      _emit(ImportProgress.phase('done', message: result.canceled ? 'U anulua' : 'Importi përfundoi'));
      return result;
    } on _Canceled {
      _emit(ImportProgress.phase('canceled', message: 'U anulua'));
      return result;
    } finally {
      if (!_progressController.isClosed) {
        // Do not close controller; it’s tied to service lifecycle. Just emit done phase above.
      }
    }
  }

  int _statusIndexFromName(String? name) {
    if (name == null) return 0;
    final idx = MemorizationStatus.values.indexWhere((e) => e.name == name);
    return idx >= 0 ? idx : 0;
  }
}

class ImportBundle {
  final Map<String, dynamic> root;
  ImportBundle({required this.root});
  int get version => root['version'] as int? ?? 0;
}

enum SettingsChange { none, overwrite, partial }

class ImportDiff {
  final SettingsChange settingsChange;
  final List<Map<String,dynamic>> bookmarkAdds;
  final List<Map<String,dynamic>> bookmarkUpdates;
  final List<Map<String,dynamic>> noteAdds;
  final List<Map<String,dynamic>> noteUpdates;
  final List<Map<String,dynamic>> memorizationAdds; // {s,v,st}
  final List<Map<String,dynamic>> memorizationStatusUpgrades; // {s,v,from,to}
  final Map<String, Map<String,int>> readingProgressImprovements; // surah->{oldVerse,newVerse,oldTs,newTs}
  final List<NoteConflict> noteConflicts;
  ImportDiff({
    required this.settingsChange,
    required this.bookmarkAdds,
    required this.bookmarkUpdates,
    required this.noteAdds,
    required this.noteUpdates,
    required this.memorizationAdds,
    required this.memorizationStatusUpgrades,
    required this.readingProgressImprovements,
    required this.noteConflicts,
  });

  Map<String, dynamic> toJson() => {
    'settingsChange': settingsChange.name,
    'bookmarkAdds': bookmarkAdds,
    'bookmarkUpdates': bookmarkUpdates,
    'noteAdds': noteAdds,
    'noteUpdates': noteUpdates,
    'memorizationAdds': memorizationAdds,
    'memorizationStatusUpgrades': memorizationStatusUpgrades,
    'readingProgressImprovements': readingProgressImprovements,
  'noteConflicts': noteConflicts.map((c)=>c.toJson()).toList(),
  };
}

/// Options controlling which domains to import & merge strategy toggles
class DataImportOptions {
  final bool overwriteSettings;
  final bool importBookmarks;
  final bool importNotes;
  final bool importMemorization;
  final bool importReadingProgress;
  final Map<String, NoteConflictResolution> noteConflictResolutions; // noteId -> resolution

  const DataImportOptions({
    this.overwriteSettings = true,
    this.importBookmarks = true,
    this.importNotes = true,
    this.importMemorization = true,
    this.importReadingProgress = true,
  this.noteConflictResolutions = const {},
  });
}

/// Result summary after applying an import
class DataImportResult {
  bool settingsOverwritten = false;
  int bookmarksAdded = 0;
  int bookmarksUpdated = 0;
  int notesAdded = 0;
  int notesUpdated = 0;
  int memorizationAdded = 0;
  int memorizationUpgraded = 0;
  int readingProgressUpdated = 0;
  int noteConflictsImported = 0;
  int noteConflictsKeptLocal = 0;
  bool canceled = false;
  final List<String> errors = [];

  Map<String, dynamic> toJson() => {
    'settingsOverwritten': settingsOverwritten,
    'bookmarksAdded': bookmarksAdded,
    'bookmarksUpdated': bookmarksUpdated,
    'notesAdded': notesAdded,
    'notesUpdated': notesUpdated,
    'memorizationAdded': memorizationAdded,
    'memorizationUpgraded': memorizationUpgraded,
    'readingProgressUpdated': readingProgressUpdated,
    'noteConflictsImported': noteConflictsImported,
    'noteConflictsKeptLocal': noteConflictsKeptLocal,
  'canceled': canceled,
    'errors': errors,
  };
}

class NoteConflict {
  final String id;
  final Map<String,dynamic> local;
  final Map<String,dynamic> imported;
  NoteConflict({required this.id, required this.local, required this.imported});
  Map<String,dynamic> toJson() => {
    'id': id,
    'local': local,
    'imported': imported,
  };
}

enum NoteConflictResolution { local, import }

/// Progress model for DATA-3 streamed import
class ImportProgress {
  final String phase; // e.g., init, settings, bookmarks, notes, memorization, readingProgress, done, canceled
  final int current; // 0..total
  final int total; // may be 0 if not applicable
  final String? message;
  ImportProgress(this.phase, this.current, this.total, [this.message]);
  ImportProgress.phase(this.phase, {this.message}) : current = 0, total = 0;
  double? get ratio => total > 0 ? current / total : null;
}

class _Canceled implements Exception {}
