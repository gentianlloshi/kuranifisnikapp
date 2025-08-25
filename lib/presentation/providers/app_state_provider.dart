import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:kurani_fisnik_app/core/utils/logger.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/usecases/settings_usecases.dart';

class AppStateProvider extends ChangeNotifier {
  final GetSettingsUseCase? _getSettingsUseCase;
  final SaveSettingsUseCase? _saveSettingsUseCase;
  // Snackbar queue (ERR-1)
  final Queue<SnackMessage> _snackQueue = Queue<SnackMessage>();
  bool _snackShowing = false;

  AppStateProvider({
    required GetSettingsUseCase getSettingsUseCase,
    required SaveSettingsUseCase saveSettingsUseCase,
    bool simple = false,
  })  : _getSettingsUseCase = simple ? null : getSettingsUseCase,
        _saveSettingsUseCase = simple ? null : saveSettingsUseCase {
    if (!simple) {
      _loadSettings();
    } else {
      _settings = const AppSettings();
    }
  }

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;
  bool get isLoading => false; // simplified: loading only during initial fetch

  String get currentTheme => _settings.theme;
  double get fontSize => _settings.fontSize;
  double get fontSizeArabic => _settings.fontSizeArabic;
  double get fontSizeTranslation => _settings.fontSizeTranslation;
  String get selectedTranslation => _settings.selectedTranslation;
  bool get showArabic => _settings.showArabic;
  bool get showTranslation => _settings.showTranslation;
  bool get showTransliteration => _settings.showTransliteration;
  bool get showVerseNumbers => _settings.showVerseNumbers;
  bool get showWordByWord => _settings.showWordByWord;
  bool get searchInArabic => _settings.searchInArabic;
  bool get searchInTranslation => _settings.searchInTranslation;
  bool get searchInTransliteration => _settings.searchInTransliteration;
  int? get searchJuz => _settings.searchJuz;
  bool get autoScrollEnabled => _settings.autoScrollEnabled;
  bool get reduceMotion => _settings.reduceMotion;
  bool get adaptiveAutoScroll => _settings.adaptiveAutoScroll;
  bool get wordHighlightGlow => _settings.wordHighlightGlow;
  bool get useSpanWordRendering => _settings.useSpanWordRendering;
  bool get backgroundIndexingEnabled => _settings.backgroundIndexingEnabled;
  bool get verboseWbwLogging => _settings.verboseWbwLogging;
  bool get searchRankingBm25Lite => _settings.searchRankingBm25Lite;

  Future<void> _loadSettings() async {
    try {
      final getter = _getSettingsUseCase;
      if (getter == null) return;
      final loadedSettings = await getter.call();
      if (loadedSettings != null) {
        _settings = loadedSettings;
        notifyListeners();
      }
    } catch (e, st) {
      Logger.e('Error loading settings', e, st, tag: 'AppState');
    }
  }

  Future<void> updateTheme(String theme) async {
    final newSettings = _settings.copyWith(theme: theme);
    await _updateSettings(newSettings);
  }

  Future<void> updateFontSize(double fontSize) async {
    // Maintain backward compatibility by updating all related sizes if caller only supplies one value
    final newSettings = _settings.copyWith(
      fontSize: fontSize,
  fontSizeArabic: fontSizeArabic, // keep existing arabic size (legacy path)
  fontSizeTranslation: fontSizeTranslation, // keep existing translation size
    );
    await _updateSettings(newSettings);
  }

  Future<void> updateArabicFontSize(double size) async {
  final newSettings = _settings.copyWith(fontSizeArabic: size);
    await _updateSettings(newSettings);
  }

  Future<void> updateTranslationFontSize(double size) async {
  final newSettings = _settings.copyWith(fontSizeTranslation: size);
    await _updateSettings(newSettings);
  }

  Future<void> updateTranslation(String translation) async {
    final newSettings = _settings.copyWith(selectedTranslation: translation);
    await _updateSettings(newSettings);
  }

  Future<void> updatePreferredReciter(String reciter) async {
    final newSettings = _settings.copyWith(preferredReciter: reciter);
    await _updateSettings(newSettings);
  }

  Future<void> updateSearchFilters({bool? inArabic, bool? inTranslation, int? juz}) async {
    final newSettings = _settings.copyWith(
      searchInArabic: inArabic,
      searchInTranslation: inTranslation,
      searchJuz: juz,
    );
    await _updateSettings(newSettings);
  }

  Future<void> updateTransliterationFilter(bool enabled) async {
    final newSettings = _settings.copyWith(searchInTransliteration: enabled);
    await _updateSettings(newSettings);
  }

  Future<void> updateAutoScroll(bool enabled) async {
    final newSettings = _settings.copyWith(autoScrollEnabled: enabled);
    await _updateSettings(newSettings);
  }

  Future<void> updateReduceMotion(bool enabled) async {
    final newSettings = _settings.copyWith(reduceMotion: enabled);
    await _updateSettings(newSettings);
  }

  Future<void> updateAdaptiveAutoScroll(bool enabled) async {
    final newSettings = _settings.copyWith(adaptiveAutoScroll: enabled);
    await _updateSettings(newSettings);
  }

  Future<void> updateWordHighlightGlow(bool enabled) async {
    final newSettings = _settings.copyWith(wordHighlightGlow: enabled);
    await _updateSettings(newSettings);
  }

  Future<void> updateUseSpanWordRendering(bool enabled) async {
    final newSettings = _settings.copyWith(useSpanWordRendering: enabled);
    await _updateSettings(newSettings);
  }

  Future<void> updateBackgroundIndexing(bool enabled) async {
    final newSettings = _settings.copyWith(backgroundIndexingEnabled: enabled);
    await _updateSettings(newSettings);
  }

  Future<void> updateVerboseWbwLogging(bool enabled) async {
    final newSettings = _settings.copyWith(verboseWbwLogging: enabled);
    await _updateSettings(newSettings);
  }

  Future<void> updateSearchRankingBm25Lite(bool enabled) async {
    final newSettings = _settings.copyWith(searchRankingBm25Lite: enabled);
    await _updateSettings(newSettings);
  }

  Future<void> updateDisplayOptions({
    bool? showArabic,
    bool? showTranslation,
    bool? showTransliteration,
    bool? showWordByWord,
    bool? showVerseNumbers,
  }) async {
    final newSettings = _settings.copyWith(
      showArabic: showArabic,
      showTranslation: showTranslation,
      showTransliteration: showTransliteration,
      showWordByWord: showWordByWord,
      showVerseNumbers: showVerseNumbers,
    );
    await _updateSettings(newSettings);
  }

  // --- Snackbar Queue API ---
  void enqueueSnack(String text, {Duration duration = const Duration(seconds: 3)}) {
    _snackQueue.add(SnackMessage(text, duration));
    if (!_snackShowing) _drainSnackQueue();
  }

  SnackMessage? get currentSnack => _snackQueue.isEmpty ? null : _snackQueue.first;
  bool get hasSnack => _snackQueue.isNotEmpty;
  bool get isSnackDisplaying => _snackShowing;

  void markSnackDisplayed() {
    // Called by UI host right after showing SnackBar to prevent multiple show attempts
    _snackShowing = true;
  }

  void onSnackCompleted() {
    if (_snackQueue.isNotEmpty) {
      _snackQueue.removeFirst();
    }
    _snackShowing = false;
    if (_snackQueue.isNotEmpty) {
      _drainSnackQueue();
    } else {
      notifyListeners();
    }
  }

  void _drainSnackQueue() {
    if (_snackQueue.isEmpty) return;
    // Trigger listener to present first item.
    notifyListeners();
  }

  Future<void> _updateSettings(AppSettings newSettings) async {
    try {
      final saver = _saveSettingsUseCase;
      if (saver != null) {
        await saver.call(newSettings);
      }
      _settings = newSettings;
      notifyListeners();
    } catch (e, st) {
      Logger.e('Error saving settings', e, st, tag: 'AppState');
    }
  }
}

class SnackMessage {
  final String text;
  final Duration duration;
  SnackMessage(this.text, this.duration);
}
