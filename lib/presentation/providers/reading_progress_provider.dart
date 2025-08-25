import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/storage_repository.dart';

/// ReadingProgressProvider maintains per-surah last read verse and timestamps.
/// Lightweight: loads lazily on first access; writes are debounced.
class ReadingProgressProvider extends ChangeNotifier {
  final StorageRepository storage;
  ReadingProgressProvider({required this.storage});

  Map<int,int> _lastReadVerse = {}; // surah -> verse
  Map<int,int> _lastTimestamps = {}; // surah -> epochSeconds
  bool _loaded = false;
  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 500);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final pos = await storage.getLastReadPosition();
    _lastReadVerse = pos.map((k,v)=> MapEntry(int.parse(k), v));
    final ts = await storage.getLastReadTimestamps();
    _lastTimestamps = ts.map((k,v)=> MapEntry(int.parse(k), v));
    _loaded = true;
  }

  Future<int?> getLastReadVerse(int surah) async {
    await _ensureLoaded();
    return _lastReadVerse[surah];
  }

  Future<double> getProgressPercent(int surah, {required int totalVerses}) async {
    await _ensureLoaded();
    final v = _lastReadVerse[surah];
    if (v == null || totalVerses <= 0) return 0;
    return (v / totalVerses).clamp(0.0,1.0);
  }

  /// Update last read; if verse is behind existing value we still keep the furthest.
  void updateProgress(int surah, int verse) {
    if (verse <= 0) return;
    final existing = _lastReadVerse[surah] ?? 0;
    if (verse < existing) return; // monotonic forward
    _lastReadVerse[surah] = verse;
    _lastTimestamps[surah] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () async {
      try { await storage.saveLastReadPosition(surah, verse); } catch (_) {}
    });
    notifyListeners();
  }

  /// Return the most recently accessed surah + verse.
  Future<ReadingResumePoint?> getMostRecent() async {
    await _ensureLoaded();
    if (_lastTimestamps.isEmpty) return null;
    int? surah; int bestTs = -1;
    _lastTimestamps.forEach((s, ts) { if (ts > bestTs) { bestTs = ts; surah = s; } });
    if (surah == null) return null;
    return ReadingResumePoint(surah: surah!, verse: _lastReadVerse[surah] ?? 1, timestamp: bestTs);
  }
}

class ReadingResumePoint {
  final int surah; final int verse; final int timestamp;
  ReadingResumePoint({required this.surah, required this.verse, required this.timestamp});
}
