class AppSettings {
  final String theme;
  // Legacy combined font size (kept for backwards compatibility with any code still reading it)
  final double fontSize;
  // Separate font sizes for Arabic and translation text (newer widgets expect these)
  final double fontSizeArabic;
  final double fontSizeTranslation;
  final String selectedTranslation;
  final bool showArabic;
  final bool showTranslation;
  final bool showTransliteration;
  // Whether to display word-by-word breakdown of verses
  final bool showWordByWord;
  final bool showVerseNumbers;
  final bool enableNotifications;
  final String notificationTime;
  final bool enableAudio;
  final double audioVolume;
  final double playbackSpeed;
  final bool autoPlay;
  final String preferredReciter;
  // Search filter preferences
  final bool searchInArabic;
  final bool searchInTranslation;
  final bool searchInTransliteration;
  final int? searchJuz; // null => all
  // Reading experience
  final bool autoScrollEnabled;
  // Accessibility / motion
  final bool reduceMotion;
  // Adaptive auto-scroll alignment based on verse height
  final bool adaptiveAutoScroll;
  // Visual enhancement: glow effect on active word highlight
  final bool wordHighlightGlow;
  // Feature flag: new RichText/TextSpan based WBW rendering (vs legacy per-word widgets)
  final bool useSpanWordRendering;
  // Feature flag: allow background incremental search indexing (can disable to isolate jank)
  final bool backgroundIndexingEnabled;
  // Diagnostic flag: enable verbose word-by-word loading logs
  final bool verboseWbwLogging;

  const AppSettings({
    this.theme = 'light',
    this.fontSize = 16.0,
    this.fontSizeArabic = 24.0,
    this.fontSizeTranslation = 16.0,
    this.selectedTranslation = 'sq_ahmeti',
    this.showArabic = true,
    this.showTranslation = true,
    this.showTransliteration = false,
    this.showWordByWord = false,
    this.showVerseNumbers = true,
    this.enableNotifications = true,
    this.notificationTime = '08:00',
    this.enableAudio = true,
    this.audioVolume = 1.0,
    this.playbackSpeed = 1.0,
    this.autoPlay = false,
    this.preferredReciter = 'default',
  this.searchInArabic = true,
  this.searchInTranslation = true,
  this.searchInTransliteration = true,
  this.searchJuz = null,
  this.autoScrollEnabled = true,
  this.reduceMotion = false,
  this.adaptiveAutoScroll = true,
  this.wordHighlightGlow = true,
  this.useSpanWordRendering = true,
  this.backgroundIndexingEnabled = true,
  this.verboseWbwLogging = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      theme: json['theme'] ?? 'light',
      fontSize: (json['fontSize'] ?? 16.0).toDouble(),
      fontSizeArabic: (json['fontSizeArabic'] ?? json['fontSize'] ?? 24.0).toDouble(),
      fontSizeTranslation: (json['fontSizeTranslation'] ?? json['fontSize'] ?? 16.0).toDouble(),
      selectedTranslation: json['selectedTranslation'] ?? 'sq_ahmeti',
      showArabic: json['showArabic'] ?? true,
      showTranslation: json['showTranslation'] ?? true,
      showTransliteration: json['showTransliteration'] ?? false,
      showWordByWord: json['showWordByWord'] ?? false,
      showVerseNumbers: json['showVerseNumbers'] ?? true,
      enableNotifications: json['enableNotifications'] ?? true,
      notificationTime: json['notificationTime'] ?? '08:00',
      enableAudio: json['enableAudio'] ?? true,
      audioVolume: (json['audioVolume'] ?? 1.0).toDouble(),
      playbackSpeed: (json['playbackSpeed'] ?? 1.0).toDouble(),
      autoPlay: json['autoPlay'] ?? false,
      preferredReciter: json['preferredReciter'] ?? 'default',
  searchInArabic: json['searchInArabic'] ?? true,
  searchInTranslation: json['searchInTranslation'] ?? true,
  searchInTransliteration: json['searchInTransliteration'] ?? true,
  searchJuz: json['searchJuz'],
  autoScrollEnabled: json['autoScrollEnabled'] ?? true,
  reduceMotion: json['reduceMotion'] ?? false,
  adaptiveAutoScroll: json['adaptiveAutoScroll'] ?? true,
  wordHighlightGlow: json['wordHighlightGlow'] ?? true,
  useSpanWordRendering: json['useSpanWordRendering'] ?? true,
  backgroundIndexingEnabled: json['backgroundIndexingEnabled'] ?? true,
  verboseWbwLogging: json['verboseWbwLogging'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'fontSize': fontSize,
      'fontSizeArabic': fontSizeArabic,
      'fontSizeTranslation': fontSizeTranslation,
      'selectedTranslation': selectedTranslation,
      'showArabic': showArabic,
      'showTranslation': showTranslation,
      'showTransliteration': showTransliteration,
      'showWordByWord': showWordByWord,
      'showVerseNumbers': showVerseNumbers,
      'enableNotifications': enableNotifications,
      'notificationTime': notificationTime,
      'enableAudio': enableAudio,
      'audioVolume': audioVolume,
      'playbackSpeed': playbackSpeed,
      'autoPlay': autoPlay,
      'preferredReciter': preferredReciter,
  'searchInArabic': searchInArabic,
  'searchInTranslation': searchInTranslation,
  'searchInTransliteration': searchInTransliteration,
  'searchJuz': searchJuz,
  'autoScrollEnabled': autoScrollEnabled,
  'reduceMotion': reduceMotion,
  'adaptiveAutoScroll': adaptiveAutoScroll,
  'wordHighlightGlow': wordHighlightGlow,
  'useSpanWordRendering': useSpanWordRendering,
  'backgroundIndexingEnabled': backgroundIndexingEnabled,
  'verboseWbwLogging': verboseWbwLogging,
    };
  }

  AppSettings copyWith({
    String? theme,
    double? fontSize,
    double? fontSizeArabic,
    double? fontSizeTranslation,
    String? selectedTranslation,
    bool? showArabic,
    bool? showTranslation,
    bool? showTransliteration,
    bool? showWordByWord,
    bool? showVerseNumbers,
    bool? enableNotifications,
    String? notificationTime,
    bool? enableAudio,
    double? audioVolume,
    double? playbackSpeed,
    bool? autoPlay,
    String? preferredReciter,
    bool? searchInArabic,
    bool? searchInTranslation,
  bool? searchInTransliteration,
    int? searchJuz,
    bool? autoScrollEnabled,
  bool? reduceMotion,
  bool? adaptiveAutoScroll,
  bool? wordHighlightGlow,
  bool? useSpanWordRendering,
  bool? backgroundIndexingEnabled,
  bool? verboseWbwLogging,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      fontSizeArabic: fontSizeArabic ?? this.fontSizeArabic,
      fontSizeTranslation: fontSizeTranslation ?? this.fontSizeTranslation,
      selectedTranslation: selectedTranslation ?? this.selectedTranslation,
      showArabic: showArabic ?? this.showArabic,
      showTranslation: showTranslation ?? this.showTranslation,
      showTransliteration: showTransliteration ?? this.showTransliteration,
      showWordByWord: showWordByWord ?? this.showWordByWord,
      showVerseNumbers: showVerseNumbers ?? this.showVerseNumbers,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      notificationTime: notificationTime ?? this.notificationTime,
      enableAudio: enableAudio ?? this.enableAudio,
      audioVolume: audioVolume ?? this.audioVolume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      autoPlay: autoPlay ?? this.autoPlay,
      preferredReciter: preferredReciter ?? this.preferredReciter,
      searchInArabic: searchInArabic ?? this.searchInArabic,
      searchInTranslation: searchInTranslation ?? this.searchInTranslation,
  searchInTransliteration: searchInTransliteration ?? this.searchInTransliteration,
      searchJuz: searchJuz ?? this.searchJuz,
      autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
  reduceMotion: reduceMotion ?? this.reduceMotion,
  adaptiveAutoScroll: adaptiveAutoScroll ?? this.adaptiveAutoScroll,
  wordHighlightGlow: wordHighlightGlow ?? this.wordHighlightGlow,
  useSpanWordRendering: useSpanWordRendering ?? this.useSpanWordRendering,
  backgroundIndexingEnabled: backgroundIndexingEnabled ?? this.backgroundIndexingEnabled,
  verboseWbwLogging: verboseWbwLogging ?? this.verboseWbwLogging,
    );
  }

  static AppSettings defaultSettings() {
    return const AppSettings();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          theme == other.theme &&
          fontSize == other.fontSize &&
          fontSizeArabic == other.fontSizeArabic &&
          fontSizeTranslation == other.fontSizeTranslation &&
          selectedTranslation == other.selectedTranslation;

  @override
  int get hashCode => Object.hash(
    theme,
    fontSize,
    fontSizeArabic,
    fontSizeTranslation,
    selectedTranslation,
  );
}
