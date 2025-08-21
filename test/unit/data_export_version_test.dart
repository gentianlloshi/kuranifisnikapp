import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/core/services/data_export_service.dart';

void main() {
  test('export version bumped to 2', () {
    expect(DataExportService.exportVersion, 2);
  });
}
