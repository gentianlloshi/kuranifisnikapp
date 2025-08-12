import 'dart:math';
import '../../domain/entities/prayer.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/repositories/content_repository.dart';
import '../datasources/local/content_local_data_source.dart';

class ContentRepositoryImpl implements ContentRepository {
  final ContentLocalDataSource _localDataSource;
  List<Prayer>? _cachedPrayers;
  List<Hadith>? _cachedHadiths;

  ContentRepositoryImpl(this._localDataSource);

  @override
  Future<List<Prayer>> getPrayers() async {
    if (_cachedPrayers != null) {
      return _cachedPrayers!;
    }

    final prayerModels = await _localDataSource.getPrayers();
    _cachedPrayers = prayerModels.map((model) => model.toEntity()).toList();
    return _cachedPrayers!;
  }

  @override
  Future<List<Hadith>> getHadiths() async {
    if (_cachedHadiths != null) {
      return _cachedHadiths!;
    }

    final hadithModels = await _localDataSource.getHadiths();
    _cachedHadiths = hadithModels.map((model) => model.toEntity()).toList();
    return _cachedHadiths!;
  }

  @override
  Future<Prayer> getRandomPrayer() async {
    final prayers = await getPrayers();
    if (prayers.isEmpty) {
      throw Exception('No prayers available');
    }
    
    final random = Random();
    return prayers[random.nextInt(prayers.length)];
  }

  @override
  Future<Hadith> getRandomHadith() async {
    final hadiths = await getHadiths();
    if (hadiths.isEmpty) {
      throw Exception('No hadiths available');
    }
    
    final random = Random();
    return hadiths[random.nextInt(hadiths.length)];
  }
}

