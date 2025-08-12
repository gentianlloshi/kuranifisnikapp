import '../repositories/content_repository.dart';
import '../../core/services/notification_service.dart';

class SetupDailyNotificationsUseCase {
  final ContentRepository _contentRepository;
  final NotificationService _notificationService;

  SetupDailyNotificationsUseCase(this._contentRepository, this._notificationService);

  Future<void> call() async {
    try {
      // Get prayers and hadiths
      final prayers = await _contentRepository.getPrayers();
      final hadiths = await _contentRepository.getHadiths();

      // Schedule daily notifications
      await _notificationService.scheduleDailyPrayerNotification(prayers);
      await _notificationService.scheduleDailyHadithNotification(hadiths);
    } catch (e) {
      throw Exception('Failed to setup daily notifications: $e');
    }
  }
}

class CancelNotificationsUseCase {
  final NotificationService _notificationService;

  CancelNotificationsUseCase(this._notificationService);

  Future<void> call() async {
    await _notificationService.cancelAllNotifications();
  }
}

class ShowTestNotificationUseCase {
  final NotificationService _notificationService;

  ShowTestNotificationUseCase(this._notificationService);

  Future<void> call() async {
    await _notificationService.showTestNotification();
  }
}

class GetRandomPrayerUseCase {
  final ContentRepository _contentRepository;

  GetRandomPrayerUseCase(this._contentRepository);

  Future<String> call() async {
    final prayer = await _contentRepository.getRandomPrayer();
    return '${prayer.title}\n\n${prayer.textAlbanian}\n\n— ${prayer.source}';
  }
}

class GetRandomHadithUseCase {
  final ContentRepository _contentRepository;

  GetRandomHadithUseCase(this._contentRepository);

  Future<String> call() async {
    final hadith = await _contentRepository.getRandomHadith();
    return '${hadith.text}\n\n— ${hadith.author}\n${hadith.source}';
  }
}

