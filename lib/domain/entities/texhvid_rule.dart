import 'package:kurani_fisnik_app/core/utils/text_sanitizer.dart';

class TexhvidRule {
  final String id;
  final String title;
  final String description;
  /// Flattened textual examples extracted from structured example objects.
  final List<String> examples;
  final List<QuizQuestion> quiz;
  final String category;

  const TexhvidRule({
    required this.id,
    required this.title,
    required this.description,
    required this.examples,
    required this.quiz,
    required this.category,
  });

  factory TexhvidRule.fromJson(
    Map<String, dynamic> json, {
    String? fallbackCategory,
  }) {
  final rawExamples = (json['examples'] as List<dynamic>? ?? []);
    final flattened = <String>[];
    for (final item in rawExamples) {
      if (item is String) {
    flattened.add(sanitizeHtmlLike(item));
      } else if (item is Map<String, dynamic>) {
        // Prefer 'meaning', else build from arabic/pronunciation
        if (item['meaning'] is String) {
      flattened.add(sanitizeHtmlLike(item['meaning'] as String));
        } else if (item['arabic'] is String) {
          final arabic = item['arabic'];
            final pron = item['pronunciation'];
          if (pron is String && pron.isNotEmpty) {
            flattened.add('$arabic ($pron)');
          } else {
            flattened.add(arabic as String);
          }
        }
      }
    }
    return TexhvidRule(
      id: json['id'] as String,
    title: sanitizeHtmlLike(json['title'] as String?),
    description: sanitizeHtmlLike(json['description'] as String? ?? ''),
      examples: flattened,
      quiz: (json['quiz'] as List<dynamic>?)
              ?.map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      category: (json['category'] as String?) ?? fallbackCategory ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TexhvidRule &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String? explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
  final questionText = sanitizeHtmlLike((json['question'] ?? json['text'] ?? '') as String);
    final options = <String>[];
    int correctIndex = 0;

    if (json['options'] is List) {
      final optionsList = json['options'] as List<dynamic>;
      for (int i = 0; i < optionsList.length; i++) {
        final option = optionsList[i];
        if (option is Map<String, dynamic>) {
      options.add(sanitizeHtmlLike(option['text'] as String));
          if (option['isCorrect'] == true) {
            correctIndex = i;
          }
        } else if (option is String) {
      options.add(sanitizeHtmlLike(option));
        }
      }
    }

    return QuizQuestion(
      question: questionText,
      options: options,
      correctAnswer: json['correctAnswer'] ?? correctIndex,
    explanation: sanitizeHtmlLike(json['explanation'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizQuestion &&
          runtimeType == other.runtimeType &&
          question == other.question;

  @override
  int get hashCode => question.hashCode;
}
