import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../data/datasources/local/hive_boxes.dart';
import '../../domain/entities/memorization_verse.dart';
import 'memorization_session.dart';

class MemorizationProvider extends ChangeNotifier {
  static const String _versesKey = 'verses_v1';
  static const String _activeSurahKey = 'active_surah';
  static const String _repeatTargetKey = 'repeat_target';
  static const String _hiddenModeKey = 'hidden_mode';

  Box? _box;
  final Map<String, MemorizationVerse> _verses = {};
  int? _activeSurah;
  bool _hideText = false;
  MemorizationSession? _session;
  bool _isLoading = false;
  String? _error;

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
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
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

  bool isVerseMemorized(String verseKey) => _verses.containsKey(verseKey);
  bool isVerseMemorizedSync(String verseKey) => isVerseMemorized(verseKey);

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
}

extension FirstOrNull<E> on List<E> { E? get firstOrNull => isEmpty ? null : first; }
