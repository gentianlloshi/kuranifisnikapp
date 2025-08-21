import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/providers/selection_service.dart';

void main() {
  test('selection mode start/toggle/clear', () {
    final s = SelectionService();
    expect(s.mode, SelectionMode.none);
    s.start(SelectionMode.verses);
    expect(s.mode, SelectionMode.verses);
    s.toggle('1:1');
    expect(s.contains('1:1'), true);
    s.toggle('1:1');
    expect(s.mode, SelectionMode.none); // auto exit
  });
}
