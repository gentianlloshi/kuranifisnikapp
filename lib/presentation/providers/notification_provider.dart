import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:kurani_fisnik_app/core/utils/logger.dart';
import 'package:kurani_fisnik_app/core/services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationService? _notificationService;
  bool _notificationsEnabled = true;
  String _notificationTime = '08:00';
  String? _currentPrayer;
  String? _currentHadith;
  bool _isLoading = false;
  String? _error;

  bool get notificationsEnabled => _notificationsEnabled;
  String get notificationTime => _notificationTime;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentPrayer => _currentPrayer;
  String? get currentHadith => _currentHadith;

  List<String>? _prayers;
  List<String>? _hadiths;
  final Random _rng = Random();

  NotificationProvider({NotificationService? service})
      : _notificationService = service;

  void attachService(NotificationService service) {
    _notificationService = service;
  }

  Future<void> toggleNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    // TODO: Implement actual notification service integration
  }

  Future<void> setNotificationTime(String time) async {
    _notificationTime = time;
    notifyListeners();
    // TODO: Implement actual notification scheduling
  }

  Future<void> showTestNotification() async {
    try {
      if (_notificationService != null) {
  // Make sure the plugin is initialized (safe to call multiple times)
  await _notificationService!.initialize();
        await _notificationService!.showTestNotification();
      } else {
        Logger.w('NotificationService not attached; falling back to log', tag: 'NotificationProvider');
      }
    } catch (e, st) {
      _error = 'Test njoftimi dështoi.';
      Logger.e('Failed to show test notification', e, st, tag: 'NotificationProvider');
      notifyListeners();
    }
  }

  Future<void> _ensureContentLoaded() async {
    if (_prayers != null && _hadiths != null) return;
    try {
      _isLoading = true; notifyListeners();
      // Load from assets
      final prayersJson = await rootBundle.loadString('assets/data/lutjet.json');
      final hadithsJson = await rootBundle.loadString('assets/data/thenie-hadithe.json');
      final pList = (json.decode(prayersJson) as List).cast<dynamic>();
      final hList = (json.decode(hadithsJson) as List).cast<dynamic>();

      // Map JSON objects into nicely formatted display strings.
      _prayers = pList.map((e) {
        if (e is String) return e;
        if (e is Map) {
          final title = (e['titulli'] ?? e['title'] ?? '').toString();
          final text = (e['shqip'] ?? e['text'] ?? e['content'] ?? '').toString();
          final source = (e['burimi'] ?? '').toString();
          final parts = <String>[];
          if (title.isNotEmpty) parts.add(title);
          if (text.isNotEmpty) parts.add(text);
          if (source.isNotEmpty) parts.add('Burimi: $source');
          return parts.join('\n');
        }
        return e.toString();
      }).toList();

      _hadiths = hList.map((e) {
        if (e is String) return e;
        if (e is Map) {
          final author = (e['autor'] ?? e['author'] ?? '').toString();
          final text = (e['thenia'] ?? e['text'] ?? e['content'] ?? '').toString();
          final source = (e['burimi'] ?? '').toString();
          final parts = <String>[];
          if (author.isNotEmpty) parts.add('Autori: $author');
          if (text.isNotEmpty) parts.add(text);
          if (source.isNotEmpty) parts.add('Burimi: $source');
          return parts.join('\n');
        }
        return e.toString();
      }).toList();
      _error = null;
    } catch (e) {
  _error = 'Nuk u ngarkuan përmbajtjet e njoftimeve.';
  Logger.e('Failed loading notifications content', e, StackTrace.current, tag: 'NotificationProvider');
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> loadRandomPrayer() async {
    await _ensureContentLoaded();
    if (_prayers == null || _prayers!.isEmpty) return;
    String next;
    int guard = 10;
    do {
      next = _prayers![_rng.nextInt(_prayers!.length)];
    } while (guard-- > 0 && next == _currentPrayer && _prayers!.length > 1);
    _currentPrayer = next;
    notifyListeners();
  }

  Future<void> loadRandomHadith() async {
    await _ensureContentLoaded();
    if (_hadiths == null || _hadiths!.isEmpty) return;
    String next;
    int guard = 10;
    do {
      next = _hadiths![_rng.nextInt(_hadiths!.length)];
    } while (guard-- > 0 && next == _currentHadith && _hadiths!.length > 1);
    _currentHadith = next;
    notifyListeners();
  }

  Future<void> setupNotifications() async {
  // Placeholder: In a real impl, (re)schedule daily notifications here.
  // For now, just refresh current samples from content to simulate a "refresh" UX.
  await _ensureContentLoaded();
  await loadRandomPrayer();
  await loadRandomHadith();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
