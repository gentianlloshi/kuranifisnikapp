import '../entities/app_settings.dart';
import '../repositories/storage_repository.dart';

class SettingsUseCases {
  final StorageRepository repository;

  SettingsUseCases(this.repository);

  Future<AppSettings?> getSettings() async {
    try {
      return await repository.getSettings();
    } catch (e) {
      throw Exception('Failed to get settings: $e');
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    try {
      await repository.saveSettings(settings);
    } catch (e) {
      throw Exception('Failed to save settings: $e');
    }
  }
}

class GetSettingsUseCase {
  final StorageRepository repository;

  GetSettingsUseCase(this.repository);

  Future<AppSettings?> call() async {
    try {
      return await repository.getSettings();
    } catch (e) {
      throw Exception('Failed to get settings: $e');
    }
  }
}

class SaveSettingsUseCase {
  final StorageRepository repository;

  SaveSettingsUseCase(this.repository);

  Future<void> call(AppSettings settings) async {
    try {
      await repository.saveSettings(settings);
    } catch (e) {
      throw Exception('Failed to save settings: $e');
    }
  }
}
