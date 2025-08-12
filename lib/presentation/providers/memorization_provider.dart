import 'package:flutter/material.dart';

class MemorizationProvider extends ChangeNotifier {
  final Map<String, bool> _memorizedVerses = {};
  final List<String> _memorizationList = [];
  bool _isLoading = false;
  String? _error;

  Map<String, bool> get memorizedVerses => _memorizedVerses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get memorizationList => List.unmodifiable(_memorizationList);

  Future<void> loadMemorizationData() async {
    _setLoading(true);
    try {
      // TODO: Implement actual memorization data loading from repository
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMemorizationList() async {
    await loadMemorizationData();
  }

  Future<void> toggleVerseMemorization(String verseKey) async {
    try {
      final isCurrentlyMemorized = _memorizedVerses[verseKey] ?? false;
      _memorizedVerses[verseKey] = !isCurrentlyMemorized;
      if (!isCurrentlyMemorized) {
        _memorizationList.add(verseKey);
      } else {
        _memorizationList.remove(verseKey);
      }
      _error = null;
      notifyListeners();
      // TODO: Implement actual memorization data saving to repository
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Map<String, dynamic> getMemorizationStats() {
    return {
      'total': _memorizationList.length,
      'memorized': _memorizedVerses.values.where((v) => v).length,
    };
  }

  double getMemorizationPercentageForSurah(int surahId) {
    // Placeholder: compute based on verses keys starting with surahId:
    final prefix = '$surahId:';
    final total = _memorizedVerses.keys.where((k) => k.startsWith(prefix)).length;
    if (total == 0) return 0.0;
    final memorized = _memorizedVerses.entries.where((e) => e.key.startsWith(prefix) && e.value).length;
    return memorized / total;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> removeVerseFromMemorization(String verseKey) async {
    _memorizedVerses.remove(verseKey);
    _memorizationList.remove(verseKey);
    notifyListeners();
  }

  bool isVerseMemorized(String verseKey) {
    return _memorizedVerses[verseKey] ?? false;
  }

  // Legacy sync alias used in some widgets
  bool isVerseMemorizedSync(String verseKey) => isVerseMemorized(verseKey);

  double getMemorizationProgressForSurah(int surahId) {
    // TODO: Implement actual progress calculation based on verses in surah
    return 0.0;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
