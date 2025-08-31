import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search_index.json exists and has a non-empty index', () async {
    final f = File('assets/data/search_index.json');
    expect(await f.exists(), isTrue, reason: 'search_index.json missing');
    final size = await f.length();
    expect(size, greaterThan(1024), reason: 'search_index.json looks empty');
    final map = json.decode(await f.readAsString()) as Map<String, dynamic>;
    expect(map['index'], isA<Map>());
    expect((map['index'] as Map).isNotEmpty, isTrue);
  });
}
