import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  // Stats persistence (lazy Hive box)
  static const String _kStatsBox = 'texhvidStatsBox';
  static const String _kSessionsKey = 'sessions_v1';
  static const String _kTotalsKey = 'totals_v1';
  // Cached summaries
  int _lifetimeAnswered = 0;
  int _lifetimeCorrect = 0;
  int _totalQuizzes = 0;
  DateTime? _lastQuizAt;

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
  // Public stats getters
  int get lifetimeAnswered => _lifetimeAnswered;
  int get lifetimeCorrect => _lifetimeCorrect;
  int get totalQuizzes => _totalQuizzes;
  double get lifetimeAccuracy => _lifetimeAnswered == 0 ? 0.0 : _lifetimeCorrect / _lifetimeAnswered;
  DateTime? get lastQuizAt => _lastQuizAt;

  Future<void> loadTexhvidRules() async {
    _setLoading(true);
    try {
      _rules = await _texhvidUseCases.getTexhvidRules();
      _error = null;
      // Load stats lazily once rules are available
      await _loadStatsSummary();
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
  // Prefer finishQuiz() from UI to persist results
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

  Future<void> _ensureStatsBoxOpen() async {
    if (!Hive.isBoxOpen(_kStatsBox)) {
      await Hive.openBox(_kStatsBox);
    }
  }

  Future<void> _loadStatsSummary() async {
    try {
      await _ensureStatsBoxOpen();
      final box = Hive.box(_kStatsBox);
      final totals = box.get(_kTotalsKey);
      if (totals is Map) {
        _lifetimeAnswered = (totals['answered'] as num?)?.toInt() ?? 0;
        _lifetimeCorrect = (totals['correct'] as num?)?.toInt() ?? 0;
        _totalQuizzes = (totals['quizzes'] as num?)?.toInt() ?? 0;
        final lastTs = (totals['lastTs'] as num?);
        _lastQuizAt = lastTs != null ? DateTime.fromMillisecondsSinceEpoch(lastTs.toInt()) : null;
      }
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _appendSession({required int correct, required int total, String? category}) async {
    try {
      await _ensureStatsBoxOpen();
      final box = Hive.box(_kStatsBox);
      final now = DateTime.now();
      final sessions = (box.get(_kSessionsKey) as List?)?.cast<Map>() ?? <Map>[];
      sessions.add({
        'ts': now.millisecondsSinceEpoch,
        'correct': correct,
        'total': total,
        if (category != null) 'category': category,
      });
      // Keep last 50 sessions
      final trimmed = sessions.length > 50 ? sessions.sublist(sessions.length - 50) : sessions;
      await box.put(_kSessionsKey, trimmed);
      // Update totals
      _lifetimeAnswered += total;
      _lifetimeCorrect += correct;
      _totalQuizzes += 1;
      _lastQuizAt = now;
      await box.put(_kTotalsKey, {
        'answered': _lifetimeAnswered,
        'correct': _lifetimeCorrect,
        'quizzes': _totalQuizzes,
        'lastTs': _lastQuizAt!.millisecondsSinceEpoch,
      });
    } catch (_) {
      // swallow persistence errors
    }
  }

  Future<QuizResult> finishQuiz({String? category}) async {
    final result = QuizResult(correct: _score, total: totalQuestions);
    await _appendSession(correct: result.correct, total: result.total, category: category);
    exitQuiz();
    notifyListeners();
    return result;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

class QuizResult {
  final int correct;
  final int total;
  const QuizResult({required this.correct, required this.total});
  double get accuracy => total == 0 ? 0.0 : correct / total;
}
