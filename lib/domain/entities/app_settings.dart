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
