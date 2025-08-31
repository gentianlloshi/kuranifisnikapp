// Validates that critical assets exist and are non-empty.
// Usage: dart run tool/validate_assets.dart
import 'dart:convert';
import 'dart:io';

Never _fail(String msg) {
  stderr.writeln('ASSET VALIDATION FAILED: $msg');
  exit(2);
}

void main(List<String> args) async {
  final indexFile = File('assets/data/search_index.json');
  if (!indexFile.existsSync()) {
    _fail('assets/data/search_index.json is missing. Run tool/build_search_index.dart');
  }
  final len = await indexFile.length();
  if (len < 1024) {
    _fail('assets/data/search_index.json is too small ($len bytes) — appears empty/corrupt.');
  }
  try {
    final content = await indexFile.readAsString();
    final jsonMap = json.decode(content) as Map<String, dynamic>;
    final index = jsonMap['index'];
    if (index is! Map || index.isEmpty) {
      _fail('search_index.json has no "index" map or it is empty.');
    }
  } catch (e) {
    _fail('Failed to parse search_index.json: $e');
  }
  stdout.writeln('Assets OK: search_index.json present and non-empty.');
}
