import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:kurani_fisnik_app/domain/repositories/thematic_index_repository.dart';

class ThematicIndexRepositoryImpl implements ThematicIndexRepository {
  Map<String, dynamic>? _cachedIndex;

  @override
  Future<Map<String, dynamic>> getThematicIndex() async {
    if (_cachedIndex != null) {
      return _cachedIndex!;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/data/temat.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      _cachedIndex = jsonData;
      return jsonData;
    } catch (e) {
      throw Exception('Failed to load thematic index: $e');
    }
  }

  @override
  Future<List<String>> getThemesByCategory(String category) async {
    final index = await getThematicIndex();
    final themes = <String>[];

    for (final themeName in index.keys) {
      if (themeName.toLowerCase().contains(category.toLowerCase())) {
        themes.add(themeName);
      }
    }

    return themes;
  }

  @override
  Future<List<Map<String, dynamic>>> getVersesByTheme(String theme) async {
    final index = await getThematicIndex();
    final themeData = index[theme] as Map<String, dynamic>?;

    if (themeData == null) return [];

    final verses = <Map<String, dynamic>>[];

    for (final entry in themeData.entries) {
      final subthemeName = entry.key;
      final verseRefs = entry.value as List<dynamic>;

      for (final verseRef in verseRefs) {
        verses.add({
          'verseRef': verseRef.toString(),
          'subtheme': subthemeName,
          'theme': theme,
        });
      }
    }

    return verses;
  }

  @override
  Future<List<String>> searchThemes(String query) async {
    final index = await getThematicIndex();
    final results = <String>[];

    final queryLower = query.toLowerCase();

    for (final themeName in index.keys) {
      if (themeName.toLowerCase().contains(queryLower)) {
        results.add(themeName);
      }
    }

    return results;
  }

  @override
  Future<Map<String, List<String>>> getAllThemes() async {
    final index = await getThematicIndex();
    final allThemes = <String, List<String>>{};

    for (final entry in index.entries) {
      final themeName = entry.key;
      final themeData = entry.value as Map<String, dynamic>;

      allThemes[themeName] = themeData.keys.toList();
    }

    return allThemes;
  }
}
