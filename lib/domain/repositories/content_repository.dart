import '../entities/prayer.dart';
import '../entities/hadith.dart';

abstract class ContentRepository {
  Future<List<Prayer>> getPrayers();
  Future<List<Hadith>> getHadiths();
  Future<Prayer> getRandomPrayer();
  Future<Hadith> getRandomHadith();
}

