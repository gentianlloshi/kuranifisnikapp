import 'package:flutter/material.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/usecases/settings_usecases.dart';

class AppStateProvider extends ChangeNotifier {
  final GetSettingsUseCase? _getSettingsUseCase;
  final SaveSettingsUseCase? _saveSettingsUseCase;

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

  Future<void> _loadSettings() async {
    if (_getSettingsUseCase == null) return; // Skip loading if no use case

    try {
      final loadedSettings = await _getSettingsUseCase!.call();
      if (loadedSettings != null) {
        _settings = loadedSettings;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
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

  Future<void> _updateSettings(AppSettings newSettings) async {
    try {
      await _saveSettingsUseCase!.call(newSettings);
      _settings = newSettings;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }
}
