import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/presentation/widgets/dev_perf_overlay.dart';
import 'package:kurani_fisnik_app/core/metrics/perf_metrics.dart';

void main() {
  setUp(() {
    // Ensure clean counters before each test
    PerfMetrics.instance.resetForTest();
  });

  testWidgets('DevPerfOverlay shows metrics and updates over time', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DevPerfOverlay(enabled: true, child: SizedBox.shrink()),
        ),
      ),
    );

    // Initial render should show overlay header and 0% index
    expect(find.text('Perf Overlay'), findsOneWidget);
    expect(find.text('Index: 0%'), findsOneWidget);

    // Update index coverage and highlight metrics
    PerfMetrics.instance.setIndexCoverage(0.42);
    PerfMetrics.instance.recordHighlightDuration(const Duration(milliseconds: 7));

    // Overlay refreshes via a 1s periodic timer
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Index: 42%'), findsOneWidget);
    expect(find.textContaining('last 7ms'), findsOneWidget);
    expect(find.textContaining('count 1'), findsOneWidget);

    // Another highlight to ensure count increments and last updates
    PerfMetrics.instance.recordHighlightDuration(const Duration(milliseconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('last 3ms'), findsOneWidget);
    expect(find.textContaining('count 2'), findsOneWidget);
  });
}
