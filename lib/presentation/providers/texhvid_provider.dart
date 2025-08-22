import 'package:flutter/material.dart';
import '../../domain/entities/texhvid_rule.dart';
import '../../domain/usecases/texhvid_usecases.dart';

class TexhvidProvider extends ChangeNotifier {
  final TexhvidUseCases _texhvidUseCases;

  TexhvidProvider({
    required TexhvidUseCases texhvidUseCases,
  }) : _texhvidUseCases = texhvidUseCases;

  List<TexhvidRule> _rules = [];
  bool _isLoading = false;
  String? _error;
  bool _isQuizMode = false;
  int _currentQuestionIndex = 0;
  // Flattened quiz pool across rules when in quiz mode
  List<QuizQuestion> _quizPool = const [];
  int _score = 0;
  String? _selectedAnswer;
  bool _hasAnswered = false;

  List<TexhvidRule> get rules => _rules;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isQuizMode => _isQuizMode;
  int get currentQuestionIndex => _currentQuestionIndex;
  int get score => _score;
  String? get selectedAnswer => _selectedAnswer;
  bool get hasAnswered => _hasAnswered;
  bool get isLastQuestion => _isQuizMode
    ? _currentQuestionIndex >= (_quizPool.length - 1)
    : _currentQuestionIndex >= (_rules.length - 1);
  int get totalQuestions => _isQuizMode ? _quizPool.length : _rules.length;
  QuizQuestion? get currentQuestion =>
    _isQuizMode
      ? (_currentQuestionIndex >= 0 && _currentQuestionIndex < _quizPool.length
        ? _quizPool[_currentQuestionIndex]
        : null)
      : null;
  List<String> get categories => _rules.map((r) => r.category).where((c) => c.isNotEmpty).toSet().toList();

  Future<void> loadTexhvidRules() async {
    _setLoading(true);
    try {
      _rules = await _texhvidUseCases.getTexhvidRules();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  List<TexhvidRule> getRulesByCategory(String category) {
    return _rules.where((rule) => rule.category == category).toList();
  }

  void startQuiz({String? category, int? limit, bool shuffle = true}) {
    // Build pool
    Iterable<TexhvidRule> source = _rules;
    if (category != null && category.isNotEmpty) {
      source = source.where((r) => r.category == category);
    }
    final pool = <QuizQuestion>[];
    for (final r in source) {
      pool.addAll(r.quiz);
    }
    if (shuffle) {
      pool.shuffle();
    }
    if (limit != null && limit > 0 && limit < pool.length) {
      _quizPool = List.of(pool.take(limit));
    } else {
      _quizPool = List.of(pool);
    }
    _isQuizMode = true;
    _currentQuestionIndex = 0;
    _score = 0;
    _selectedAnswer = null;
    _hasAnswered = false;
    notifyListeners();
  }

  void exitQuiz() {
    _isQuizMode = false;
    _currentQuestionIndex = 0;
    _score = 0;
  _selectedAnswer = null;
  _hasAnswered = false;
  _quizPool = const [];
    notifyListeners();
  }

  void nextQuestion() {
    if (!_isQuizMode) return;
    if (_currentQuestionIndex < totalQuestions - 1) {
      _currentQuestionIndex++;
      _selectedAnswer = null;
      _hasAnswered = false;
      notifyListeners();
    } else {
      // End of quiz
      exitQuiz();
    }
  }

  void answerQuestion(bool isCorrect) {
    if (isCorrect) {
      _score++;
    }
    _hasAnswered = true;
    notifyListeners();
  }

  void selectAnswer(String answerId) {
    _selectedAnswer = answerId;
    notifyListeners();
  }

  void submitAnswer() {
    if (_selectedAnswer == null || currentQuestion == null) return;
    final question = currentQuestion;
    if (question == null) return;
    final selectedIndex = question.options.indexOf(_selectedAnswer!);
    final isCorrect = selectedIndex == question.correctAnswer;
    answerQuestion(isCorrect);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
