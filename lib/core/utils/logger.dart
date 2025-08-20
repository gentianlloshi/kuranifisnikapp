import 'dart:developer' as developer;

const bool _isRelease = bool.fromEnvironment('dart.vm.product');

enum LogLevel { debug, info, warn, error }

class Logger {
  Logger._();
  static LogLevel _minLevel = LogLevel.debug;
  static bool _useDeveloperLog = true;
  static Set<String>? _suppressTags; // if set, skip logs for these tags

  static void configure({LogLevel? minLevel, bool? useDeveloperLog, Set<String>? suppressTags}) {
    if (minLevel != null) _minLevel = minLevel;
    if (useDeveloperLog != null) _useDeveloperLog = useDeveloperLog;
    if (suppressTags != null) _suppressTags = suppressTags.isEmpty ? null : suppressTags;
  }

  static void d(String message, {String tag = 'APP'}) {
    if (_isRelease) return; // drop debug logs in release
    _log(LogLevel.debug, tag, message);
  }
  static void i(String message, {String tag = 'APP'}) => _log(LogLevel.info, tag, message);
  static void w(String message, {String tag = 'APP'}) => _log(LogLevel.warn, tag, message);
  static void e(String message, Object? error, StackTrace? stackTrace, {String tag = 'APP'}) {
    final buf = StringBuffer(message);
    if (error != null) buf.write(' | error=$error');
    if (stackTrace != null && !_isRelease) buf.write('\n$stackTrace');
    _log(LogLevel.error, tag, buf.toString());
  }

  static void _log(LogLevel level, String tag, String line) {
    if (level.index < _minLevel.index) return;
    if (_suppressTags != null && _suppressTags!.contains(tag)) return;
    final ts = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(5);
    final msg = '[$ts][$levelStr][$tag] $line';
    if (_useDeveloperLog) {
      developer.log(msg, name: tag, level: level.index * 1000);
    } else {
      // ignore: avoid_print
      print(msg);
    }
  }
}
