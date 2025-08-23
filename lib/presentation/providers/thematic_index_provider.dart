import 'package:flutter/material.dart';
import '../../domain/usecases/thematic_index_usecases.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thematic index hierarchical node representation for virtual / lazy tree.
class ThematicNode {
  final String id; // theme or theme/subtheme composite
  final String label;
  final bool isLeaf; // true for subtheme (verse list)
  final List<String> verseRefs; // only populated for leaves
  final List<ThematicNode> children; // for themes -> subthemes on demand
  const ThematicNode({
    required this.id,
    required this.label,
    required this.isLeaf,
    this.verseRefs = const [],
    this.children = const [],
  });

  ThematicNode copyWith({List<ThematicNode>? children}) => ThematicNode(
    id: id,
    label: label,
    isLeaf: isLeaf,
    verseRefs: verseRefs,
    children: children ?? this.children,
  );
}

class ThematicIndexProvider extends ChangeNotifier {
  final GetThematicIndexUseCase _getThematicIndexUseCase;

  ThematicIndexProvider({
    required GetThematicIndexUseCase getThematicIndexUseCase,
  }) : _getThematicIndexUseCase = getThematicIndexUseCase;

  Map<String, dynamic> _rawIndex = {}; // raw loaded json
  List<String> _filteredThemes = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  final Set<String> _expandedThemes = <String>{};
  final Map<String, ThematicNode> _themeNodes = {}; // root themes cached
  static const String _prefsExpandedKey = 'thematic_expanded_v1';

  Map<String, dynamic> get thematicIndex => _rawIndex;
  List<String> get filteredThemes => _filteredThemes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  Set<String> get expandedThemes => _expandedThemes;
  List<ThematicNode> get rootNodes => _filteredThemes.map((t) => _themeNodes[t]!).toList();

  Future<void> loadThematicIndex() async {
    _setLoading(true);
    try {
      final rawIndex = await _getThematicIndexUseCase.call();
      _rawIndex = rawIndex;
      _filteredThemes = _rawIndex.keys.toList()..sort();
      // Build lightweight root nodes (children deferred)
      _themeNodes.clear();
      for (final theme in _filteredThemes) {
        _themeNodes[theme] = ThematicNode(id: theme, label: theme, isLeaf: false);
      }
      await _restoreExpanded();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void searchThemes(String query) {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _filteredThemes = _rawIndex.keys.toList();
      notifyListeners();
      return;
    }
    String norm(String s) {
      s = s.toLowerCase();
      s = s.replaceAll('ç', 'c').replaceAll('ë', 'e');
      const mapping = {
        'á':'a','à':'a','ä':'a','â':'a','ã':'a','å':'a','ā':'a','ă':'a','ą':'a',
        'é':'e','è':'e','ë':'e','ê':'e','ě':'e','ē':'e','ę':'e','ė':'e',
        'í':'i','ì':'i','ï':'i','î':'i','ī':'i','į':'i','ı':'i',
        'ó':'o','ò':'o','ö':'o','ô':'o','õ':'o','ø':'o','ō':'o','ő':'o',
        'ú':'u','ù':'u','ü':'u','û':'u','ū':'u','ů':'u','ű':'u','ť':'t','š':'s','ž':'z','ñ':'n'
      };
      final sb = StringBuffer();
      for (final ch in s.split('')) { sb.write(mapping[ch] ?? ch); }
      return sb.toString();
    }
    final q = norm(query.trim());
    final matches = <String>{};
    // Match theme titles
    for (final theme in _rawIndex.keys) {
      if (norm(theme).contains(q)) {
        matches.add(theme);
        continue;
      }
      // Also match subtheme labels
      final sub = _rawIndex[theme];
      if (sub is Map<String, dynamic>) {
        bool hit = false;
        sub.forEach((subName, _) {
          if (!hit && norm(subName).contains(q)) {
            hit = true;
          }
        });
        if (hit) matches.add(theme);
      }
    }
    _filteredThemes = matches.toList()..sort();
    notifyListeners();
  }

  List<Map<String, dynamic>> getVersesByTheme(String theme) {
    final themeObj = _rawIndex[theme];
    if (themeObj is Map<String, dynamic>) {
      final List<Map<String, dynamic>> verses = [];
      themeObj.forEach((sub, list) {
        if (list is List) {
          for (final v in list) {
            verses.add({'verseRef': v.toString(), 'subtheme': sub, 'theme': theme});
          }
        }
      });
      return verses;
    }
    return [];
  }

  bool isThemeExpanded(String theme) => _expandedThemes.contains(theme);

  Future<void> toggleThemeExpansion(String theme) async {
    if (_expandedThemes.contains(theme)) {
      _expandedThemes.remove(theme);
    } else {
      _expandedThemes.add(theme);
      // Lazy build children if not already built
      final node = _themeNodes[theme];
      if (node != null && node.children.isEmpty) {
        final sub = _rawIndex[theme];
        if (sub is Map<String, dynamic>) {
          final children = <ThematicNode>[];
          sub.forEach((subName, verses) {
            if (verses is List) {
              children.add(ThematicNode(
                id: '$theme::$subName',
                label: subName,
                isLeaf: true,
                verseRefs: verses.map((e) => e.toString()).toList(),
              ));
            }
          });
          _themeNodes[theme] = node.copyWith(children: children);
        }
      }
    }
    await _persistExpanded();
    notifyListeners();
  }

  Future<void> _persistExpanded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsExpandedKey, _expandedThemes.toList()..sort());
    } catch (_) {}
  }

  Future<void> _restoreExpanded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsExpandedKey) ?? const [];
      for (final t in list) { _expandedThemes.add(t); }
      // Pre-build children for restored expansions
      for (final t in _expandedThemes) {
        final sub = _rawIndex[t];
        if (sub is Map<String, dynamic>) {
          final children = <ThematicNode>[];
          sub.forEach((subName, verses) {
            if (verses is List) {
              children.add(ThematicNode(
                id: '$t::$subName',
                label: subName,
                isLeaf: true,
                verseRefs: verses.map((e) => e.toString()).toList(),
              ));
            }
          });
          final existing = _themeNodes[t];
          if (existing != null) {
            _themeNodes[t] = existing.copyWith(children: children);
          }
        }
      }
    } catch (_) {}
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
