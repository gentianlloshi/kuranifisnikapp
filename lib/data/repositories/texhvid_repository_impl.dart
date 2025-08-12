import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:kurani_fisnik_app/core/utils/logger.dart';
import 'package:kurani_fisnik_app/domain/entities/texhvid_rule.dart';
import 'package:kurani_fisnik_app/domain/repositories/texhvid_repository.dart';

class TexhvidRepositoryImpl implements TexhvidRepository {
  List<TexhvidRule>? _cachedRules;

  @override
  Future<List<TexhvidRule>> getTexhvidRules() async {
    if (_cachedRules != null) {
      return _cachedRules!;
    }

    final rules = <TexhvidRule>[];

    // Load all available Texhvid rule files
    final dataFiles = [
      'assets/data/texhvid/01-bazat.json',
      'assets/data/texhvid/02-shkronjat.json',
      'assets/data/texhvid/03-sifat-kundershtat.json',
      'assets/data/texhvid/04-sifat-vecanta.json',
      'assets/data/texhvid/05-nun-sakin-dhe-mim-sakin.json',
      'assets/data/texhvid/06-medd-et.json',
      'assets/data/texhvid/07-rregulla-te-pergjithshme.json',
      'assets/data/texhvid/08-tefkhim-terkik.json',
      'assets/data/texhvid/09-te-ndryshme.json',
    ];

    for (final filePath in dataFiles) {
      try {
        final jsonString = await rootBundle.loadString(filePath);
        final jsonData = json.decode(jsonString) as List<dynamic>;
        // Derive fallback category name from filename (strip path and numeric prefix)
        final fileName = filePath.split('/').last;
        final namePart = fileName.replaceAll('.json', '');
        final dashIndex = namePart.indexOf('-');
        String fallbackCategory = namePart;
        if (dashIndex >= 0 && dashIndex + 1 < namePart.length) {
          fallbackCategory = namePart.substring(dashIndex + 1).replaceAll('-', ' ');
        }
        fallbackCategory = _toTitleCase(fallbackCategory);
        for (final ruleData in jsonData) {
          final rule = TexhvidRule.fromJson(
            ruleData as Map<String, dynamic>,
            fallbackCategory: fallbackCategory,
          );
          rules.add(rule);
        }
      } catch (e, st) {
        // If file doesn't exist or has issues, continue with other files
        Logger.w('Failed loading $filePath: $e', tag: 'TexhvidRepository');
        Logger.d('Stack: $st', tag: 'TexhvidRepository');
      }
    }

    _cachedRules = rules;
    return rules;
  }

  static String _toTitleCase(String input) {
    return input.split(RegExp(r'\s+')).map((w) => w.isEmpty ? '' : ('${w[0].toUpperCase()}${w.substring(1)}')).join(' ');
  }

  @override
  Future<TexhvidRule?> getTexhvidRuleById(String id) async {
    final rules = await getTexhvidRules();
    try {
      return rules.firstWhere((rule) => rule.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<String>> getCategories() async {
    final rules = await getTexhvidRules();
    final categories = <String>{};
    
    for (final rule in rules) {
      categories.add(rule.category);
    }
    
    return categories.toList()..sort();
  }

  @override
  Future<List<TexhvidRule>> getRulesByCategory(String category) async {
    final rules = await getTexhvidRules();
    return rules.where((rule) => rule.category == category).toList();
  }
}
