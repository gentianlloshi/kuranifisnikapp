import 'package:flutter/material.dart';

class NotificationProvider extends ChangeNotifier {
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
    // TODO: Implement test notification
    debugPrint('Test notification triggered');
  }

  Future<void> loadRandomPrayer() async {
    // Placeholder random prayer
    _currentPrayer = 'O ZOT, më shto dituri.';
    notifyListeners();
  }

  Future<void> loadRandomHadith() async {
    _currentHadith = 'Veprat vlejnë sipas qëllimeve.';
    notifyListeners();
  }

  Future<void> setupNotifications() async {
    // Placeholder
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
