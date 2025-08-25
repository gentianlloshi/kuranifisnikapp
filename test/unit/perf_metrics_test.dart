import 'package:flutter_test/flutter_test.dart';
import 'package:kurani_fisnik_app/core/metrics/perf_metrics.dart';

void main() {
  group('PerfMetrics', () {
    test('indexCoverage and enrichmentCoverage clamp and update', () {
  final m = PerfMetrics.instance; m.resetForTest();
      m.setIndexCoverage(0.25);
      m.setEnrichmentCoverage(0.5);
      var snap = m.currentSnapshot();
      expect(snap.indexCoverage, 0.25);
      expect(snap.enrichmentCoverage, 0.5);
      // Over-clamp
      m.setIndexCoverage(2.0);
      m.setEnrichmentCoverage(-1.0);
      snap = m.currentSnapshot();
      expect(snap.indexCoverage, 1.0);
      expect(snap.enrichmentCoverage, 0.0);
    });

    test('lazyBoxOpens & cache hit counters increment', () {
  final m = PerfMetrics.instance; m.resetForTest();
      final before = m.currentSnapshot();
      m.incLazyBoxOpen();
      m.incTranslationCacheHit();
      m.incTransliterationCacheHit();
      final after = m.currentSnapshot();
      expect(after.lazyBoxOpens, before.lazyBoxOpens + 1);
      expect(after.translationCacheHits, before.translationCacheHits + 1);
      expect(after.transliterationCacheHits, before.transliterationCacheHits + 1);
    });
  });
}
