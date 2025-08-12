class AppConstants {
  // Storage keys
  static const String keyLastReadSurah = 'last_read_surah';
  static const String keyLastReadVerse = 'last_read_verse';
  static const String keyFavorites = 'favorites';
  static const String keyNotes = 'notes';
  static const String keySettings = 'settings';
  static const String keyTheme = 'theme';
  static const String keyFontSizeArabic = 'font_size_arabic';
  static const String keyFontSizeTranslation = 'font_size_translation';
  static const String keySelectedTranslation = 'selected_translation';
  static const String keyShowArabic = 'show_arabic';
  static const String keyShowTranslation = 'show_translation';
  static const String keyShowTransliteration = 'show_transliteration';
  static const String keyMemorizationList = 'memorization_list';
  static const String keyOnboardingCompleted = 'onboarding_completed';
  
  // Default values
  static const int defaultFontSizeArabic = 24;
  static const int defaultFontSizeTranslation = 16;
  static const String defaultTranslation = 'sq_ahmeti';
  static const String defaultTheme = 'light';
  
  // API URLs
  static const String audioApiBase1 = 'https://api.alquran.cloud/v1/ayah';
  static const String audioApiBase2 = 'https://quranapi.pages.dev/api';
  
  // Font families
  static const String fontArabic = 'AmiriQuran';
  static const String fontTranslation = 'Lora';
  
  // Themes
  static const List<String> availableThemes = [
    'light',
    'dark', 
    'sepia',
    'midnight'
  ];
  
  // Translations
  static const Map<String, String> availableTranslations = {
    'sq_ahmeti': 'Ahmeti',
    'sq_mehdiu': 'Mehdiu',
    'sq_nahi': 'Nahi',
  };
  
  // Surah data
  static const List<Map<String, dynamic>> surahsData = [
    {'number': 1, 'name': 'الفاتحة', 'transliteration': 'Al-Fatiha', 'translation': 'Hapja', 'verses': 7, 'revelation': 'Mekke'},
    {'number': 2, 'name': 'البقرة', 'transliteration': 'Al-Baqarah', 'translation': 'Lopë', 'verses': 286, 'revelation': 'Medinë'},
    {'number': 3, 'name': 'آل عمران', 'transliteration': 'Ali \'Imran', 'translation': 'Familja e Imranit', 'verses': 200, 'revelation': 'Medinë'},
    {'number': 4, 'name': 'النساء', 'transliteration': 'An-Nisa', 'translation': 'Gratë', 'verses': 176, 'revelation': 'Medinë'},
    {'number': 5, 'name': 'المائدة', 'transliteration': 'Al-Ma\'idah', 'translation': 'Sofra', 'verses': 120, 'revelation': 'Medinë'},
    // Add more surahs as needed - this is a sample
  ];
}

