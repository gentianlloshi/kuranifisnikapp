import 'package:hive/hive.dart';
import 'hive_boxes.dart';

class MemorizationHiveDataSource {
  Future<Box> _openBox() async => Hive.isBoxOpen(HiveBoxes.memorization)
      ? Hive.box(HiveBoxes.memorization)
      : await Hive.openBox(HiveBoxes.memorization);

  Future<Map<String, bool>> loadMemorizedVerses() async {
    final box = await _openBox();
    final stored = box.get('verses') as Map?;
    return stored == null
        ? <String, bool>{}
        : Map<String, bool>.from(stored.map((k, v) => MapEntry(k.toString(), v as bool)));
  }

  Future<List<String>> loadList() async {
    final box = await _openBox();
    final list = box.get('list') as List?;
    return list == null ? <String>[] : List<String>.from(list.map((e) => e.toString()));
  }

  Future<void> persist(Map<String, bool> verses, List<String> list) async {
    final box = await _openBox();
    await box.put('verses', verses);
    await box.put('list', list);
  }
}
