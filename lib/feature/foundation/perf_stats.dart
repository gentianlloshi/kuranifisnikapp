import 'dart:async';

/// Lightweight performance & usage counters; not a profiler substitute.
/// Collects cumulative counts + last sample timestamps for quick diagnostic overlay.
class PerfStats {
  static final PerfStats I = PerfStats._();
  PerfStats._();

  final _counters = <String,int>{};
  final _gauges = <String,num>{};
  final _timestamps = <String,DateTime>{};
  final _streams = <String,StreamController<num>>{}; // optional live feeds

  void inc(String key, [int by = 1]) { _counters.update(key, (v)=> v+by, ifAbsent: ()=> by); }
  void add(String key, int value) { inc(key, value); }
  void setGauge(String key, num value) { _gauges[key] = value; _timestamps[key] = DateTime.now(); }
  void mark(String key) { _timestamps[key] = DateTime.now(); }
  Stream<num> live(String key) => _streams.putIfAbsent(key, ()=> StreamController<num>.broadcast()).stream;
  void pushLive(String key, num value) { _streams.putIfAbsent(key, ()=> StreamController<num>.broadcast()).add(value); }

  Map<String,dynamic> snapshot() => {
    'counters': Map<String,int>.from(_counters),
    'gauges': Map<String,num>.from(_gauges),
    'timestamps': _timestamps.map((k,v)=> MapEntry(k, v.toIso8601String())),
  };

  String pretty() {
    final s = snapshot();
    final buf = StringBuffer();
    buf.writeln('PerfStats:');
    (s['counters'] as Map<String,int>).forEach((k,v)=> buf.writeln('  [C] $k = $v'));
    (s['gauges'] as Map<String,num>).forEach((k,v)=> buf.writeln('  [G] $k = $v'));
    (s['timestamps'] as Map<String,dynamic>).forEach((k,v)=> buf.writeln('  [T] $k @ $v'));
    return buf.toString();
  }
}
