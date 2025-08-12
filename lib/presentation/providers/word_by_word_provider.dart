import 'package:flutter/material.dart';

class WordByWordProvider extends ChangeNotifier {
  Map<String, dynamic> _wordByWordData = {};
  Map<String, dynamic> _timestampData = {};
  List<dynamic> _currentWordByWordVerses = [];
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get wordByWordData => _wordByWordData;
  Map<String, dynamic> get timestampData => _timestampData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<dynamic> get currentWordByWordVerses => _currentWordByWordVerses;

  Future<void> loadWordByWordData(String verseKey) async {
    _setLoading(true);
    try {
      // TODO: Implement actual word-by-word data loading
      _wordByWordData = {};
      _error = null;
  _currentWordByWordVerses = []; // placeholder
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTimestampData(String verseKey) async {
    _setLoading(true);
    try {
      // TODO: Implement actual timestamp data loading
      _timestampData = {};
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  List<Map<String, dynamic>> getWordsForVerse(String verseKey) {
    if (_wordByWordData.containsKey(verseKey)) {
      return List<Map<String, dynamic>>.from(_wordByWordData[verseKey] ?? []);
    }
    return [];
  }

  Map<String, dynamic>? getTimestampsForVerse(String verseKey) {
    return _timestampData[verseKey];
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
