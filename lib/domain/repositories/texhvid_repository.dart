import '../entities/texhvid_rule.dart';

abstract class TexhvidRepository {
  Future<List<TexhvidRule>> getTexhvidRules();
  Future<TexhvidRule?> getTexhvidRuleById(String id);
  Future<List<TexhvidRule>> getRulesByCategory(String category);
  Future<List<String>> getCategories();
}
