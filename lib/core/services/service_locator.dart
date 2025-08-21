import 'package:kurani_fisnik_app/domain/repositories/quran_repository.dart';

/// Minimal lightweight service locator to expose core repositories
/// without introducing a heavy DI framework. Primarily for
/// diagnostics / perf instrumentation panels.
class ServiceLocator {
  ServiceLocator._();
  static final ServiceLocator instance = ServiceLocator._();

  QuranRepository? _quranRepository;
  void registerQuranRepository(QuranRepository repo) { _quranRepository = repo; }
  QuranRepository? get quranRepository => _quranRepository;
}
