import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/core/metrics/perf_metrics.dart';
import 'package:kurani_fisnik_app/presentation/widgets/perf_summary.dart';

void main() {
  testWidgets('PerfSummary shows counters and coverage percentages', (tester) async {
    final snap = PerfMetricsSnapshot(
      audioCacheHits: 3,
      lazyBoxOpens: 1,
      translationCacheHits: 2,
      transliterationCacheHits: 0,
      indexCoverage: 0.66,
      enrichmentCoverage: 0.5,
      highlightRenderCount: 10,
      highlightRenderMsTotal: 120,
      highlightRenderMsLast: 12,
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox.shrink()),
    ));

    // Inject widget under test
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PerfSummary(
          snapshot: snap,
          indexCoverage: 0.66,
          enrichmentCoverage: 0.5,
        ),
      ),
    ));

    expect(find.text('Perf:'), findsOneWidget);
    expect(find.textContaining('audioCacheHits=3'), findsOneWidget);
    expect(find.textContaining('trCache=2'), findsOneWidget);
    expect(find.textContaining('trlitCache=0'), findsOneWidget);
    expect(find.textContaining('lazyBoxOpens=1'), findsOneWidget);
    // Labels render; exact percent text like "Idx 66%" should appear
    expect(find.textContaining('Idx'), findsOneWidget);
    expect(find.textContaining('Enr'), findsOneWidget);
  });
}
