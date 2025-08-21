import 'package:flutter/foundation.dart';
import 'dart:async';

class PerfMetricsSnapshot {
  final int audioCacheHits;
  final int lazyBoxOpens; // number of deferred Hive box opens
  final int translationCacheHits; // shared prefs translation cache
  final int transliterationCacheHits; // (if later cached externally)
  final double indexCoverage; // 0..1 fraction of search index built
  final double enrichmentCoverage; // 0..1 fraction of surahs enriched (translation+transliteration)
  const PerfMetricsSnapshot({
    required this.audioCacheHits,
    required this.lazyBoxOpens,
    required this.translationCacheHits,
    required this.transliterationCacheHits,
    required this.indexCoverage,
    required this.enrichmentCoverage,
  });
}

class PerfMetrics extends ChangeNotifier {
  PerfMetrics._();
  static final PerfMetrics instance = PerfMetrics._();
  int _audioCacheHits = 0;
  int _lazyBoxOpens = 0;
  int _translationCacheHits = 0;
  int _transliterationCacheHits = 0;
  double _indexCoverage = 0.0;
  double _enrichmentCoverage = 0.0;

  void incAudioCacheHit() { _audioCacheHits++; _notify(); }
  void incLazyBoxOpen() { _lazyBoxOpens++; _notify(); }
  void incTranslationCacheHit() { _translationCacheHits++; _notify(); }
  void incTransliterationCacheHit() { _transliterationCacheHits++; _notify(); }
  void setIndexCoverage(double v) { final nv = v.clamp(0.0,1.0); if (nv != _indexCoverage) { _indexCoverage = nv; _notify(); } }
  void setEnrichmentCoverage(double v) { final nv = v.clamp(0.0,1.0); if (nv != _enrichmentCoverage) { _enrichmentCoverage = nv; _notify(); } }
  // Bulk update helper to avoid double notifications when both change together
  void updateCoverage({double? index, double? enrichment}) {
    bool changed = false;
    if (index != null) { final nv = index.clamp(0.0,1.0); if (nv != _indexCoverage) { _indexCoverage = nv; changed = true; } }
    if (enrichment != null) { final nv = enrichment.clamp(0.0,1.0); if (nv != _enrichmentCoverage) { _enrichmentCoverage = nv; changed = true; } }
    if (changed) { _notify(); }
  }

  PerfMetricsSnapshot currentSnapshot() => PerfMetricsSnapshot(
    audioCacheHits: _audioCacheHits,
    lazyBoxOpens: _lazyBoxOpens,
  translationCacheHits: _translationCacheHits,
  transliterationCacheHits: _transliterationCacheHits,
    indexCoverage: _indexCoverage,
    enrichmentCoverage: _enrichmentCoverage,
  );

  // Test support – reset internal counters (not for production runtime use)
  void resetForTest() {
    _audioCacheHits = 0;
    _lazyBoxOpens = 0;
    _translationCacheHits = 0;
    _transliterationCacheHits = 0;
    _indexCoverage = 0.0;
    _enrichmentCoverage = 0.0;
    _notify();
  }

  void _notify() {
    // Batch notifications using microtask to coalesce rapid updates.
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() { _scheduled = false; notifyListeners(); });
  }

  bool _scheduled = false;
}
