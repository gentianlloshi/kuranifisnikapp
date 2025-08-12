abstract class ThematicIndexRepository {
  Future<Map<String, dynamic>> getThematicIndex();
  Future<List<String>> getThemesByCategory(String category);
  Future<List<Map<String, dynamic>>> getVersesByTheme(String theme);
  Future<List<String>> searchThemes(String query);
  Future<Map<String, List<String>>> getAllThemes();
}

