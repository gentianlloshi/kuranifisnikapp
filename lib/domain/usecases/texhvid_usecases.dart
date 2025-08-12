import '../entities/texhvid_rule.dart';
import '../repositories/texhvid_repository.dart';

class TexhvidUseCases {
  final TexhvidRepository repository;

  TexhvidUseCases(this.repository);

  Future<List<TexhvidRule>> getTexhvidRules() async {
    try {
      return await repository.getTexhvidRules();
    } catch (e) {
      throw Exception('Failed to get texhvid rules: $e');
    }
  }

  Future<List<TexhvidRule>> getRulesByCategory(String category) async {
    try {
      return await repository.getRulesByCategory(category);
    } catch (e) {
      throw Exception('Failed to get texhvid rules by category: $e');
    }
  }

  Future<TexhvidRule?> getRuleById(String id) async {
    try {
      return await repository.getTexhvidRuleById(id);
    } catch (e) {
      throw Exception('Failed to get texhvid rule by id: $e');
    }
  }

  Future<List<String>> getCategories() async {
    try {
      return await repository.getCategories();
    } catch (e) {
      throw Exception('Failed to get texhvid categories: $e');
    }
  }
}

// Legacy single-purpose use case classes removed; consolidated into TexhvidUseCases.
