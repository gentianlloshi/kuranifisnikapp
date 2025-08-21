import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import '../../data/datasources/local/hive_boxes.dart';
import '../../domain/entities/memorization_verse.dart';
import 'memorization_session.dart';

class MemorizationProvider extends ChangeNotifier {
  static const String _versesKey = 'verses_v1';
  static const String _activeSurahKey = 'active_surah';
  static const String _repeatTargetKey = 'repeat_target';
  static const String _hiddenModeKey = 'hidden_mode';
  static const String _sessionSelectionKey = 'session_selection_v1';
  // Legacy keys (pre-structured model) for MEMO-6 migration
  static const String _legacyVersesBoolMapKey = 'verses'; // Map<String,bool>
  static const String _legacyListKey = 'list'; // List<String>

  Box? _box;
  final Map<String, MemorizationVerse> _verses = {};
  int? _activeSurah;
  bool _hideText = false;
  MemorizationSession? _session;
  bool _isLoading = false;
  String? _error;
  Timer? _sessionDebounce;
  static const _sessionDebounceDuration = Duration(milliseconds: 600);

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hideText => _hideText;
  int? get activeSurah => _activeSurah;
  MemorizationSession? get session => _session;

  List<int> get groupedSurahs {
    final set = <int>{};
    for (final v in _verses.values) set.add(v.surah);
    final list = set.toList()..sort();
    return list;
  }

  List<MemorizationVerse> versesForActiveSurah() {
    if (_activeSurah == null) return const [];
    final list = _verses.values.where((v) => v.surah == _activeSurah).toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    return list;
  }

  bool isVerseMemorized(String verseKey) => _verses.containsKey(verseKey);

  Future<void> _ensureBox() async {
    if (_box != null && _box!.isOpen) return;
    _box = Hive.isBoxOpen(HiveBoxes.memorization)
        ? Hive.box(HiveBoxes.memorization)
        : await Hive.openBox(HiveBoxes.memorization);
  }

  Future<void> load() async {
    _setLoading(true);
    try {
      await _ensureBox();
  // MEMO-6: one-time migration from legacy simple formats to structured list
  await _maybeMigrateLegacy();
      final raw = _box!.get(_versesKey) as List?;
      if (raw != null) {
        for (final item in raw) {
          if (item is Map) {
            final surah = item['s'] as int?;
            final verse = item['v'] as int?;
            final st = item['st'] as int?;
            if (surah != null && verse != null) {
              final status = MemorizationStatus.values[(st ?? 0).clamp(0, MemorizationStatus.values.length - 1)];
              final mv = MemorizationVerse(surah: surah, verse: verse, status: status);
              _verses[mv.key] = mv;
            }
          }
        }
      }
      _activeSurah = _box!.get(_activeSurahKey) as int? ?? groupedSurahs.firstOrNull;
      _hideText = _box!.get(_hiddenModeKey) as bool? ?? false;
      final repeatTarget = _box!.get(_repeatTargetKey) as int? ?? 1;
      if (_activeSurah != null) {
        _session = MemorizationSession(surah: _activeSurah!, repeatTarget: repeatTarget);
      }
      // Restore persisted session selection if matches active surah
      final persistedSel = (_box!.get(_sessionSelectionKey) as List?)?.cast<String>() ?? const [];
      if (persistedSel.isNotEmpty) {
        // Determine surah from first key if active missing
        final first = persistedSel.first;
        final parts = first.split(':');
        final surahFromSel = parts.length == 2 ? int.tryParse(parts[0]) : null;
        final sesSurah = surahFromSel ?? _activeSurah;
        if (sesSurah != null) {
          _activeSurah ??= sesSurah;
          _session = MemorizationSession(
            surah: sesSurah,
            repeatTarget: repeatTarget,
            selectedVerseKeys: persistedSel.where((k) => k.startsWith('$sesSurah:')).toSet(),
          );
        }
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _maybeMigrateLegacy() async {
    if (_box == null) return;
    // If new key already populated, skip
    if (_box!.get(_versesKey) != null) return;
    final legacyMap = _box!.get(_legacyVersesBoolMapKey) as Map?; // map of verseKey->bool
    final legacyList = _box!.get(_legacyListKey) as List?; // list of verseKey strings
    if (legacyMap == null && legacyList == null) return; // nothing to migrate
    final mergedKeys = <String>{};
    if (legacyMap != null) {
      legacyMap.forEach((k, v) {
        if (v == true) mergedKeys.add(k.toString());
      });
    }
    if (legacyList != null) {
      for (final k in legacyList) {
        mergedKeys.add(k.toString());
      }
    }
    if (mergedKeys.isEmpty) return;
    final migrated = <Map<String, dynamic>>[];
    for (final key in mergedKeys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final s = int.tryParse(parts[0]);
      final v = int.tryParse(parts[1]);
      if (s == null || v == null) continue;
      migrated.add({'s': s, 'v': v, 'st': MemorizationStatus.newVerse.index});
    }
    await _box!.put(_versesKey, migrated);
    // Optionally clear legacy to avoid re-migration
    await _box!.delete(_legacyVersesBoolMapKey);
    await _box!.delete(_legacyListKey);
  }

  Future<void> addVerse(int surah, int verse) async {
    await _ensureBox();
    final key = '$surah:$verse';
    if (_verses.containsKey(key)) return;
    final mv = MemorizationVerse(surah: surah, verse: verse, status: MemorizationStatus.newVerse);
    _verses[key] = mv;
    _activeSurah ??= surah;
    await _persist();
    notifyListeners();
  }

  Future<void> removeVerse(int surah, int verse) async {
    await _ensureBox();
    _verses.remove('$surah:$verse');
    if (_activeSurah != null && !_verses.values.any((v) => v.surah == _activeSurah)) {
      final list = groupedSurahs;
      _activeSurah = list.isEmpty ? null : list.first;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> cycleStatus(MemorizationVerse mv) async {
    final next = switch (mv.status) {
      MemorizationStatus.newVerse => MemorizationStatus.inProgress,
      MemorizationStatus.inProgress => MemorizationStatus.mastered,
      MemorizationStatus.mastered => MemorizationStatus.newVerse,
    };
    mv.status = next;
    await _persist();
    notifyListeners();
  }

  Future<void> toggleSelection(int surah, int verse) async {
    if (_session == null || _session!.surah != surah) {
      _session = MemorizationSession(surah: surah, selectedVerseKeys: {'$surah:$verse'});
    } else {
      final set = Set<String>.from(_session!.selectedVerseKeys);
      final key = '$surah:$verse';
      if (!set.add(key)) set.remove(key);
      _session = _session!.copyWith(selectedVerseKeys: set);
    }
  _schedulePersistSession();
    notifyListeners();
  }

  Future<void> selectAllForActive() async {
    if (_activeSurah == null) return;
    final keys = versesForActiveSurah().map((v) => v.key).toSet();
    if (_session == null || _session!.surah != _activeSurah) {
      _session = MemorizationSession(surah: _activeSurah!, selectedVerseKeys: keys);
    } else {
      final allSelected = _session!.selectedVerseKeys.length == keys.length;
      _session = _session!.copyWith(selectedVerseKeys: allSelected ? <String>{} : keys);
    }
  _schedulePersistSession();
    notifyListeners();
  }

  Future<void> setRepeatTarget(int value) async {
    await _ensureBox();
    if (_session != null) {
      _session = _session!.copyWith(repeatTarget: value.clamp(1, 99));
    }
    await _box!.put(_repeatTargetKey, value.clamp(1, 99));
    notifyListeners();
  }

  Future<void> toggleHideText() async {
    await _ensureBox();
    _hideText = !_hideText;
    await _box!.put(_hiddenModeKey, _hideText);
    notifyListeners();
  }

  Future<void> goToNextGroup() async {
    if (groupedSurahs.isEmpty || _activeSurah == null) return;
    final list = groupedSurahs;
    final idx = list.indexOf(_activeSurah!);
    if (idx >= 0 && idx < list.length - 1) {
      _activeSurah = list[idx + 1];
      _session = MemorizationSession(surah: _activeSurah!, repeatTarget: _session?.repeatTarget ?? 1);
      await _persistMeta();
  _schedulePersistSession();
      notifyListeners();
    }
  }

  Future<void> goToPrevGroup() async {
    if (groupedSurahs.isEmpty || _activeSurah == null) return;
    final list = groupedSurahs;
    final idx = list.indexOf(_activeSurah!);
    if (idx > 0) {
      _activeSurah = list[idx - 1];
      _session = MemorizationSession(surah: _activeSurah!, repeatTarget: _session?.repeatTarget ?? 1);
      await _persistMeta();
  _schedulePersistSession();
      notifyListeners();
    }
  }

  Map<String, int> statusCountsForActive() {
    final map = {'new': 0, 'inProgress': 0, 'mastered': 0};
    for (final v in versesForActiveSurah()) {
      switch (v.status) {
        case MemorizationStatus.newVerse:
          map['new'] = map['new']! + 1;
          break;
        case MemorizationStatus.inProgress:
          map['inProgress'] = map['inProgress']! + 1;
          break;
        case MemorizationStatus.mastered:
          map['mastered'] = map['mastered']! + 1;
          break;
      }
    }
    return map;
  }

  Map<String, int> globalStatusCounts() {
    final map = {'new': 0, 'inProgress': 0, 'mastered': 0};
    for (final v in _verses.values) {
      switch (v.status) {
        case MemorizationStatus.newVerse:
          map['new'] = map['new']! + 1;
          break;
        case MemorizationStatus.inProgress:
          map['inProgress'] = map['inProgress']! + 1;
          break;
        case MemorizationStatus.mastered:
          map['mastered'] = map['mastered']! + 1;
          break;
      }
    }
    return map;
  }

  bool isSelected(int surah, int verse) => _session?.selectedVerseKeys.contains('$surah:$verse') ?? false;
  bool containsVerse(int surah, int verse) => _verses.containsKey('$surah:$verse');

  List<int> sessionVerseNumbersOrdered() {
    if (_session == null) return const [];
    final keys = _session!.selectedVerseKeys;
    final nums = <int>[];
    for (final k in keys) {
      final parts = k.split(':');
      if (parts.length == 2 && int.tryParse(parts[0]) == _session!.surah) {
        final v = int.tryParse(parts[1]);
        if (v != null) nums.add(v);
      }
    }
    nums.sort();
    return nums;
  }

  // Legacy API compatibility -------------------------------------------------
  Future<void> toggleVerseMemorization(String verseKey) async {
    // verseKey format surah:verse
    final parts = verseKey.split(':');
    if (parts.length != 2) return;
    final surah = int.tryParse(parts[0]);
    final verse = int.tryParse(parts[1]);
    if (surah == null || verse == null) return;
    if (containsVerse(surah, verse)) {
      await removeVerse(surah, verse);
    } else {
      await addVerse(surah, verse);
    }
  }

  bool isVerseMemorizedSync(String verseKey) => isVerseMemorized(verseKey);

  // Legacy widget compatibility (stats & list) --------------------------------
  List<String> get memorizationList => _verses.values.map((v) => v.key).toList(growable: false);
  Future<void> loadMemorizationList() async { if (_verses.isEmpty && !_isLoading) await load(); }
  Map<String, dynamic> getMemorizationStats() {
    final totalVerses = _verses.length;
    // In old logic 'memorized' likely counted all; we align to mastered count now
    final mastered = _verses.values.where((v) => v.status == MemorizationStatus.mastered).length;
    return { 'total': totalVerses, 'memorized': mastered };
  }
  int getMemorizationProgressForSurah(int surahNumber) => _verses.values.where((v) => v.surah == surahNumber).length;
  double getMemorizationPercentageForSurah(int surahNumber) {
    final count = getMemorizationProgressForSurah(surahNumber);
    // We do not have verse count here; returning count as percentage stand-in if unknown.
    return count.toDouble();
  }
  void removeVerseFromMemorization(String verseKey) async {
    final parts = verseKey.split(':');
    if (parts.length != 2) return;
    final s = int.tryParse(parts[0]);
    final v = int.tryParse(parts[1]);
    if (s == null || v == null) return;
    await removeVerse(s, v);
  }

  Future<void> _persist() async {
    await _ensureBox();
    final list = _verses.values.map((v) => {'s': v.surah, 'v': v.verse, 'st': v.status.index}).toList(growable: false);
    await _box!.put(_versesKey, list);
    await _persistMeta();
  }

  Future<void> _persistMeta() async {
    await _ensureBox();
    if (_activeSurah != null) await _box!.put(_activeSurahKey, _activeSurah);
    await _box!.put(_hiddenModeKey, _hideText);
    if (_session != null) await _box!.put(_repeatTargetKey, _session!.repeatTarget);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _schedulePersistSession() {
    _sessionDebounce?.cancel();
    _sessionDebounce = Timer(_sessionDebounceDuration, () {
      _persistSessionSelection();
    });
  }

  Future<void> _persistSessionSelection() async {
    if (_box == null) return;
    final sel = _session?.selectedVerseKeys.toList() ?? const [];
    await _box!.put(_sessionSelectionKey, sel);
  }

  @override
  void dispose() {
    _sessionDebounce?.cancel();
    super.dispose();
  }
}

extension FirstOrNull<E> on List<E> { E? get firstOrNull => isEmpty ? null : first; }
