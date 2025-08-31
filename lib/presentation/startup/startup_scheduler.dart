import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/quran_provider.dart';
import 'package:kurani_fisnik_app/core/utils/logger.dart';
// Unused heavy providers removed from startup scheduler imports to reduce load.

/// Lightweight phased startup coordinator to reduce main-isolate burst load.
/// Phases (relative to first frame):
///  - Phase 1 (Frame 0): UI shell only (nothing here, just construction)
///  - Phase 2 (~+200ms): Load surah metadata (QuranProvider.loadSurahs)
///  - Phase 3: REMOVED (no search index work at startup to avoid jank)
///  - Phase 4 (~+1200ms): Warm minor providers (word-by-word ensure minimal) / optional translation prewarm placeholder
/// All delays are adaptive. Search index build is now triggered lazily when the user opens the Search tab.
class StartupScheduler {
  final BuildContext context;
  bool _started = false;
  Timer? _phase2Timer;
  Timer? _phase4Timer;

  StartupScheduler(this.context);

  void start() {
    if (_started) return;
    _started = true;
    // Schedule phases using timers so we don't block first frame.
    _phase2Timer = Timer(const Duration(milliseconds: 200), () {
      Logger.d('Phase2 start', tag: 'StartupPhase');
      _phase2();
      Logger.d('Phase2 end', tag: 'StartupPhase');
    });
    // Phase 3 intentionally not scheduled to avoid any search index work at startup.
    _phase4Timer = Timer(const Duration(milliseconds: 1200), () {
      Logger.d('Phase4 start', tag: 'StartupPhase');
      _phase4();
      Logger.d('Phase4 end', tag: 'StartupPhase');
    });
  }

  void accelerateIndexBuild() {
    if (!_started) return;
    // No-op: search index build is lazily triggered by the Search tab itself.
  }

  void _phase2() {
    final quran = context.read<QuranProvider>();
    if (quran.surahs.isEmpty) {
      quran.loadSurahs();
    }
  }

  void _phase4() {
  // Light warmups only; heavy Hive warmups removed (large assets now in-memory cached on demand).
  // Keep hook here for future minor prewarms if needed.
  }

  void dispose() {
    _phase2Timer?.cancel();
    _phase4Timer?.cancel();
  }
}
