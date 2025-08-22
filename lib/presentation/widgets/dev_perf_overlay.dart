import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kurani_fisnik_app/core/metrics/perf_metrics.dart';

class DevPerfOverlay extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const DevPerfOverlay({super.key, required this.child, required this.enabled});

  @override
  State<DevPerfOverlay> createState() => _DevPerfOverlayState();
}

class _DevPerfOverlayState extends State<DevPerfOverlay> {
  Timer? _timer;
  PerfMetricsSnapshot _snap = PerfMetrics.instance.currentSnapshot();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() { _snap = PerfMetrics.instance.currentSnapshot(); });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 8,
          top: 8,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontSize: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Perf Overlay'),
                    Text('Index: ${(100*_snap.indexCoverage).toStringAsFixed(0)}%'),
                    Text('Highlight: last ${_snap.highlightRenderMsLast}ms, count ${_snap.highlightRenderCount}'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
