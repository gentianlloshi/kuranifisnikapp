import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kurani_fisnik_app/domain/entities/app_settings.dart';
import 'package:kurani_fisnik_app/domain/entities/bookmark.dart';
import 'package:kurani_fisnik_app/domain/entities/note.dart';
import 'package:kurani_fisnik_app/domain/entities/surah.dart';

abstract class StorageDataSource {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<List<Bookmark>> getBookmarks();
  Future<void> saveBookmarks(List<Bookmark> bookmarks);
  Future<List<Note>> getNotes();
  Future<void> saveNotes(List<Note> notes);
  Future<List<Surah>> getCachedQuranData();
  Future<void> cacheQuranData(List<Surah> surahs);
  Future<Map<String, dynamic>> getCachedTranslationData(String translationKey);
  Future<void> cacheTranslationData(String translationKey, Map<String, dynamic> data);
  Future<List<String>> getMemorizationList();
  Future<void> saveMemorizationList(List<String> verseKeys);
}

class StorageDataSourceImpl implements StorageDataSource {
  static const String _settingsKey = 'app_settings';
  static const String _bookmarksKey = 'bookmarks';
  static const String _notesKey = 'notes';
  static const String _quranCacheKey = 'quran_cache';
  static const String _memorizationKey = 'memorization_list';

  @override
  Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    if (settingsJson != null) {
      final Map<String, dynamic> data = json.decode(settingsJson);
      return AppSettings.fromJson(data);
    }
    return AppSettings.defaultSettings();
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = json.encode(settings.toJson());
    await prefs.setString(_settingsKey, settingsJson);
  }

  @override
  Future<List<Bookmark>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = prefs.getString(_bookmarksKey);
    if (bookmarksJson != null) {
      final List<dynamic> data = json.decode(bookmarksJson);
      return data.map((item) => Bookmark.fromJson(item)).toList();
    }
    return [];
  }

  @override
  Future<void> saveBookmarks(List<Bookmark> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = json.encode(bookmarks.map((b) => b.toJson()).toList());
    await prefs.setString(_bookmarksKey, bookmarksJson);
  }

  @override
  Future<List<Note>> getNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString(_notesKey);
    if (notesJson != null) {
      final List<dynamic> data = json.decode(notesJson);
      return data.map((item) => Note.fromJson(item)).toList();
    }
    return [];
  }

  @override
  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = json.encode(notes.map((n) => n.toJson()).toList());
    await prefs.setString(_notesKey, notesJson);
  }

  @override
  Future<List<Surah>> getCachedQuranData() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(_quranCacheKey);
    if (cacheJson != null) {
      final List<dynamic> data = json.decode(cacheJson);
      return data.map((item) => Surah.fromJson(item)).toList();
    }
    return [];
  }

  @override
  Future<void> cacheQuranData(List<Surah> surahs) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = json.encode(surahs.map((s) => s.toJson()).toList());
    await prefs.setString(_quranCacheKey, cacheJson);
  }

  @override
  Future<Map<String, dynamic>> getCachedTranslationData(String translationKey) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'translation_$translationKey';
    final cacheJson = prefs.getString(cacheKey);
    if (cacheJson != null) {
      return json.decode(cacheJson);
    }
    return {};
  }

  @override
  Future<void> cacheTranslationData(String translationKey, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'translation_$translationKey';
    final cacheJson = json.encode(data);
    await prefs.setString(cacheKey, cacheJson);
  }

  @override
  Future<List<String>> getMemorizationList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_memorizationKey) ?? [];
  }

  @override
  Future<void> saveMemorizationList(List<String> verseKeys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_memorizationKey, verseKeys);
  }
}
