import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/quran_provider.dart';
import 'package:kurani_fisnik_app/core/utils/logger.dart';
import '../providers/app_state_provider.dart';
// Unused heavy providers removed from startup scheduler imports to reduce load.

/// Lightweight phased startup coordinator to reduce main-isolate burst load.
/// Phases (relative to first frame):
///  - Phase 1 (Frame 0): UI shell only (nothing here, just construction)
///  - Phase 2 (~+200ms): Load surah metadata (QuranProvider.loadSurahs)
///  - Phase 3 (~+700ms): Resume / start search index incremental build
///  - Phase 4 (~+1200ms): Warm minor providers (word-by-word ensure minimal) / optional translation prewarm placeholder
/// All delays are adaptive: if user initiates a search early, we accelerate index phase.
class StartupScheduler {
  final BuildContext context;
  bool _started = false;
  Timer? _phase2Timer;
  Timer? _phase3Timer; // may be disabled if background indexing off
  Timer? _phase4Timer;

  StartupScheduler(this.context);

  void start() {
    if (_started) return;
    _started = true;
    // Schedule phases using timers so we don't block first frame.
  _phase2Timer = Timer(const Duration(milliseconds: 200), () { Logger.d('Phase2 start', tag: 'StartupPhase'); _phase2(); Logger.d('Phase2 end', tag: 'StartupPhase');});
  // Only schedule phase3 (index build consideration) if background indexing is currently enabled in settings at startup.
  final app = context.read<AppStateProvider>();
  if (app.backgroundIndexingEnabled) {
    _phase3Timer = Timer(const Duration(milliseconds: 700), () { Logger.d('Phase3 start', tag: 'StartupPhase'); _phase3(); Logger.d('Phase3 end', tag: 'StartupPhase');});
  }
  _phase4Timer = Timer(const Duration(milliseconds: 1200), () { Logger.d('Phase4 start', tag: 'StartupPhase'); _phase4(); Logger.d('Phase4 end', tag: 'StartupPhase');});
  }

  void accelerateIndexBuild() {
    if (!_started) return;
    if (_phase3Timer?.isActive ?? false) {
      _phase3Timer!.cancel();
      _phase3();
    }
  }

  void _phase2() {
    final quran = context.read<QuranProvider>();
    if (quran.surahs.isEmpty) {
      quran.loadSurahs();
    }
  }

  void _phase3() {
    // Try loading a snapshot or prebuilt index cheaply; if present, this is fast and avoids heavy CPU.
    // This keeps startup light (no verse allocations), but primes search so it's usable immediately.
    unawaited(() async {
      try {
        final q = context.read<QuranProvider>();
        if (!q.isSearchIndexReady) {
          await q.ensureSearchIndexReady();
          Logger.d('Search index ensured (snapshot/prebuilt) in Phase 3', tag: 'StartupPhase');
        }
      } catch (_) {}
    }());
  }

  void _phase4() {
  // Light warmups only; heavy Hive warmups removed (large assets now in-memory cached on demand).
  // Keep hook here for future minor prewarms if needed.
  }

  void dispose() {
    _phase2Timer?.cancel();
    _phase3Timer?.cancel();
    _phase4Timer?.cancel();
  }
}
