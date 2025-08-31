import 'package:flutter_test/flutter_test.dart';

// Placeholder regression test for the intermittent Search tab crash (#4).
// Skipped for now due to environment flakiness with compact reporter and
// the need for a fuller provider scaffold. This will be enabled in the PR
// once we land a stable harness around SearchWidget.

void main() {
  testWidgets(
    '[SKIPPED] Search tab opens and typing does not crash',
    (tester) async {
      // TODO: Implement a stable harness with providers and SearchWidget,
      // reproduce rapid typing + filter toggles, assert no exceptions.
    },
    skip: true,
  );
}
