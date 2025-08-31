import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Abstraction over snapshot persistence and dataVersion computation.
abstract class SnapshotStore {
  /// Load the snapshot payload as a decoded map, or null if not present.
  Future<Map<String, dynamic>?> load();

  /// Persist the given snapshot payload.
  Future<void> save(Map<String, dynamic> json);

  /// Compute the current dataVersion for the corpus used by the search index.
  Future<String> computeCurrentDataVersion();
}

/// Default implementation backed by app documents directory.
class DefaultSnapshotStore implements SnapshotStore {
  final String fileName;
  String? _cachedHash;

  DefaultSnapshotStore({this.fileName = 'search_index_v2.json'});

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  @override
  Future<Map<String, dynamic>?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
  // Parse large JSON in an isolate to keep UI thread responsive
  return await compute(_decodeJsonMap, content);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(Map<String, dynamic> jsonMap) async {
    try {
      final file = await _file();
      await file.writeAsString(json.encode(jsonMap), flush: true);
    } catch (_) {
      // ignore IO errors
    }
  }

  @override
  Future<String> computeCurrentDataVersion() async {
    if (_cachedHash != null) return _cachedHash!;
    try {
      const files = <String>[
        'assets/data/suret.json',
        'assets/data/sq_ahmeti.json',
        'assets/data/sq_mehdiu.json',
        'assets/data/sq_nahi.json',
        'assets/data/arabic_quran.json',
        'assets/data/transliterations.json',
      ];
      final sig = StringBuffer('v2:');
      for (final f in files) {
        try {
          final data = await rootBundle.load(f);
          final bytes = data.buffer.asUint8List();
          final len = bytes.length;
          final first = len > 0 ? bytes[0] : 0;
          final last = len > 0 ? bytes[len - 1] : 0;
          sig
            ..write(f)
            ..write('#')
            ..write(len)
            ..write(':')
            ..write(first)
            ..write('-')
            ..write(last)
            ..write('|');
        } catch (_) {
          sig..write(f)..write('#missing|');
        }
      }
      _cachedHash = sig.toString();
      return _cachedHash!;
    } catch (_) {
      return 'v2:fallback';
    }
  }
}

// Top-level function required for compute()
Map<String, dynamic> _decodeJsonMap(String content) => json.decode(content) as Map<String, dynamic>;
