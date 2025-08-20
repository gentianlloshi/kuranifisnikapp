import 'dart:ui';

enum AppLocale { sq, en }

class Strings {
  static const _data = <AppLocale, Map<String, String>>{
    AppLocale.sq: {
      'bookmark_added': 'Ajeti u shtua në favoritë',
      'bookmark_removed': 'Ajeti u hoq nga favoritët',
      'copy_success': 'Ajeti u kopjua',
      'memorization_updated': 'U përditësua statusi i memorizimit',
      'note_saved': 'Shënimi u ruajt',
    },
    AppLocale.en: {
      'bookmark_added': 'Verse added to bookmarks',
      'bookmark_removed': 'Verse removed from bookmarks',
      'copy_success': 'Verse copied',
      'memorization_updated': 'Memorization status updated',
      'note_saved': 'Note saved',
    },
  };

  final AppLocale locale;
  const Strings(this.locale);

  String t(String key) => _data[locale]?[key] ?? key;

  static AppLocale resolve(Locale locale) {
    switch (locale.languageCode) {
      case 'sq':
        return AppLocale.sq;
      default:
        return AppLocale.en;
    }
  }
}
