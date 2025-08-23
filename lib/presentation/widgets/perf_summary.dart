import 'package:flutter/material.dart';
import 'package:kurani_fisnik_app/core/metrics/perf_metrics.dart';

/// Small, reusable summary of perf counters and coverage bars.
/// Pure-render widget to keep it easy to unit-test.
class PerfSummary extends StatelessWidget {
  final PerfMetricsSnapshot snapshot;
  final double indexCoverage;
  final double enrichmentCoverage;

  const PerfSummary({
    super.key,
    required this.snapshot,
    required this.indexCoverage,
    required this.enrichmentCoverage,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Perf:'),
        Text('audioCacheHits=${snapshot.audioCacheHits}'),
        Text('trCache=${snapshot.translationCacheHits}'),
        Text('trlitCache=${snapshot.transliterationCacheHits}'),
        Text('lazyBoxOpens=${snapshot.lazyBoxOpens}'),
        CoverageBar(label: 'Idx', value: indexCoverage),
        CoverageBar(label: 'Enr', value: enrichmentCoverage),
      ],
    );
  }
}

class CoverageBar extends StatelessWidget {
  final String label;
  final double value; // 0..1
  const CoverageBar({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).clamp(0, 100).toStringAsFixed(0);
    final color = value >= 0.99
        ? Colors.green
        : value >= 0.75
            ? Colors.lightGreen
            : value >= 0.5
                ? Colors.orange
                : Colors.redAccent;
    return Tooltip(
      message: '$label coverage $pct%',
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label $pct%', style: const TextStyle(fontSize: 10)),
            SizedBox(
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: value.clamp(0, 1),
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
