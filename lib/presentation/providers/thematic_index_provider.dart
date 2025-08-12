import 'package:flutter/material.dart';
import '../../domain/usecases/thematic_index_usecases.dart';

class ThematicIndexProvider extends ChangeNotifier {
  final GetThematicIndexUseCase _getThematicIndexUseCase;

  ThematicIndexProvider({
    required GetThematicIndexUseCase getThematicIndexUseCase,
  }) : _getThematicIndexUseCase = getThematicIndexUseCase;

  Map<String, dynamic> _thematicIndex = {};
  List<String> _filteredThemes = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  final Set<String> _expandedThemes = <String>{};

  Map<String, dynamic> get thematicIndex => _thematicIndex;
  List<String> get filteredThemes => _filteredThemes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  Set<String> get expandedThemes => _expandedThemes;

  Future<void> loadThematicIndex() async {
    _setLoading(true);
    try {
      final rawIndex = await _getThematicIndexUseCase.call();

      // Adapt raw JSON structure (theme -> { subtheme: [verses] })
      // to internal structure expected by the widget: theme -> { 'subthemes': { subtheme: [verses] } }
      _thematicIndex = rawIndex.map((theme, data) {
        if (data is Map<String, dynamic>) {
          return MapEntry(theme, { 'subthemes': data });
        }
        return MapEntry(theme, { 'subthemes': <String, dynamic>{} });
      });

      _filteredThemes = _thematicIndex.keys.toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void searchThemes(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredThemes = _thematicIndex.keys.toList();
    } else {
      _filteredThemes = _thematicIndex.keys
          .where((theme) => theme.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> getVersesByTheme(String theme) {
    final themeObj = _thematicIndex[theme];
    if (themeObj is Map<String, dynamic>) {
      final subthemes = themeObj['subthemes'];
      if (subthemes is Map<String, dynamic>) {
        final List<Map<String, dynamic>> verses = [];
        for (final entry in subthemes.entries) {
          final subthemeName = entry.key;
            final value = entry.value;
            if (value is List) {
              for (final verseRef in value) {
                verses.add({
                  'verseRef': verseRef.toString(),
                  'subtheme': subthemeName,
                  'theme': theme,
                });
              }
            }
        }
        return verses;
      }
    }
    return [];
  }

  bool isThemeExpanded(String theme) => _expandedThemes.contains(theme);

  void toggleThemeExpansion(String theme) {
    if (_expandedThemes.contains(theme)) {
      _expandedThemes.remove(theme);
    } else {
      _expandedThemes.add(theme);
    }
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
