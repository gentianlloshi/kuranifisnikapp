import 'package:flutter/scheduler.dart';
import 'package:kurani_fisnik_app/core/utils/logger.dart';

class PerformanceMonitor {
  static PerformanceMonitor? _instance;
  final List<FrameTiming> _recent = [];
  PerformanceMonitor._() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }
  static void ensureStarted() {
    _instance ??= PerformanceMonitor._();
  }
  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _recent.add(t);
      final totalMicros = t.totalSpan.inMicroseconds;
      if (totalMicros > 32000) {
        Logger.w('Slow frame ${totalMicros / 1000.0}ms (build=${t.buildDuration.inMilliseconds}ms layout=${t.rasterDuration.inMilliseconds}ms)', tag: 'Perf');
      }
      if (_recent.length > 120) _recent.removeAt(0);
    }
  }
}
