class Verse {
  final int surahId;
  final int verseNumber;
  final String arabicText;
  final String? translation;
  final String? transliteration;
  final String verseKey;
  final int? juz;
  final int? hizb;
  final int? page;
  final int? manzil;
  final int? ruku;

  // Additional properties that existing code expects
  final int surahNumber;
  final int number;
  final String textArabic;
  final String? textTranslation;
  final String? textTransliteration;

  const Verse({
    required this.surahId,
    required this.verseNumber,
    required this.arabicText,
    this.translation,
    this.transliteration,
    required this.verseKey,
    this.juz,
    this.hizb,
    this.page,
    this.manzil,
    this.ruku,
  })  : surahNumber = surahId,
        number = verseNumber,
        textArabic = arabicText,
        textTranslation = translation,
        textTransliteration = transliteration;

  factory Verse.fromJson(Map<String, dynamic> json) {
    return Verse(
      surahId: json['surah_id'] ?? json['surahId'] ?? json['surahNumber'] ?? 0,
      verseNumber: json['verse_number'] ?? json['verseNumber'] ?? json['number'] ?? 0,
      arabicText: json['arabic_text'] ?? json['arabicText'] ?? json['textArabic'] ?? '',
      translation: json['translation'] ?? json['textTranslation'],
      transliteration: json['transliteration'] ?? json['textTransliteration'],
      verseKey: json['verse_key'] ?? json['verseKey'] ?? '${json['surah_id'] ?? json['surahNumber'] ?? 0}:${json['verse_number'] ?? json['number'] ?? 0}',
      juz: json['juz'],
      hizb: json['hizb'],
      page: json['page'],
      manzil: json['manzil'],
      ruku: json['ruku'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surah_id': surahId,
      'verse_number': verseNumber,
      'arabic_text': arabicText,
      'translation': translation,
      'transliteration': transliteration,
      'verse_key': verseKey,
      'juz': juz,
      'hizb': hizb,
      'page': page,
      'manzil': manzil,
      'ruku': ruku,
      'surahNumber': surahNumber,
      'number': number,
      'textArabic': textArabic,
      'textTranslation': textTranslation,
      'textTransliteration': textTransliteration,
    };
  }

  Verse copyWith({
    int? surahId,
    int? verseNumber,
    String? arabicText,
    String? translation,
    String? transliteration,
    String? verseKey,
    int? juz,
    int? hizb,
    int? page,
    int? manzil,
    int? ruku,
    String? Function()? textTranslation,
  }) {
    return Verse(
      surahId: surahId ?? this.surahId,
      verseNumber: verseNumber ?? this.verseNumber,
      arabicText: arabicText ?? this.arabicText,
      translation: textTranslation != null ? textTranslation() : (translation ?? this.translation),
      transliteration: transliteration ?? this.transliteration,
      verseKey: verseKey ?? this.verseKey,
      juz: juz ?? this.juz,
      hizb: hizb ?? this.hizb,
      page: page ?? this.page,
      manzil: manzil ?? this.manzil,
      ruku: ruku ?? this.ruku,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Verse &&
        other.surahId == surahId &&
        other.verseNumber == verseNumber;
  }

  @override
  int get hashCode => Object.hash(surahId, verseNumber);

  @override
  String toString() {
    return 'Verse(surahId: $surahId, verseNumber: $verseNumber, verseKey: $verseKey)';
  }

  // Backwards compatibility for widgets expecting a 'tag' field (used for audio highlighting)
  String get tag => verseKey;
}
