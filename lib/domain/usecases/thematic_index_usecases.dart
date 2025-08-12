import '../repositories/thematic_index_repository.dart';

class ThematicIndexUseCases {
  final ThematicIndexRepository repository;

  ThematicIndexUseCases(this.repository);

  Future<Map<String, dynamic>> getThematicIndex() async {
    try {
      return await repository.getThematicIndex();
    } catch (e) {
      throw Exception('Failed to get thematic index: $e');
    }
  }

  Future<List<String>> searchThemes(String query) async {
    try {
      return await repository.searchThemes(query);
    } catch (e) {
      throw Exception('Failed to search themes: $e');
    }
  }
}

class GetThematicIndexUseCase {
  final ThematicIndexRepository repository;

  GetThematicIndexUseCase(this.repository);

  Future<Map<String, dynamic>> call() async {
    try {
      return await repository.getThematicIndex();
    } catch (e) {
      throw Exception('Failed to get thematic index: $e');
    }
  }
}

class SearchThemesUseCase {
  final ThematicIndexRepository repository;

  SearchThemesUseCase(this.repository);

  Future<List<String>> call(String query) async {
    try {
      return await repository.searchThemes(query);
    } catch (e) {
      throw Exception('Failed to search themes: $e');
    }
  }
}

class GetVersesByThemeUseCase {
  final ThematicIndexRepository repository;

  GetVersesByThemeUseCase(this.repository);

  Future<List<Map<String, dynamic>>> call(String theme) async {
    try {
      return await repository.getVersesByTheme(theme);
    } catch (e) {
      throw Exception('Failed to get verses by theme: $e');
    }
  }
}

class GetThemesByCategoryUseCase {
  final ThematicIndexRepository repository;

  GetThemesByCategoryUseCase(this.repository);

  Future<List<String>> call(String category) async {
    try {
      return await repository.getThemesByCategory(category);
    } catch (e) {
      throw Exception('Failed to get themes by category: $e');
    }
  }
}
