import 'dart:convert';
import 'dart:io';
import 'package:kurani_fisnik_app/presentation/providers/search_snapshot_store.dart';

class TestSnapshotStore implements SnapshotStore {
  final Directory dir;
  final String fileName;
  String currentDataVersion;

  TestSnapshotStore({required this.dir, this.fileName = 'search_index_v2.json', this.currentDataVersion = 'v2:test'})
      : assert(fileName.isNotEmpty);

  File get _file => File('${dir.path}/$fileName');

  @override
  Future<Map<String, dynamic>?> load() async {
    if (!await _file.exists()) return null;
    final s = await _file.readAsString();
    return json.decode(s) as Map<String, dynamic>;
  }

  @override
  Future<void> save(Map<String, dynamic> jsonMap) async {
    await _file.writeAsString(json.encode(jsonMap), flush: true);
  }

  @override
  Future<String> computeCurrentDataVersion() async => currentDataVersion;
}
