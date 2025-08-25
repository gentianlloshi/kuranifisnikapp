# Word By Word Audio Highlight Implementation

> This document explains, end-to-end, how to design and implement a **Word‑By‑Word (WBW) audio playback with real‑time text highlighting** in a Flutter app (as realized in this project). It is structured so you could rebuild the entire feature from scratch: data formats, models, services, synchronization logic, UI rendering, performance tuning, extensibility, and testing.

---
## 1. Goals & User Experience
**Primary Goal**: While recitation audio plays, each Arabic word of the current verse is highlighted in sync so the user can visually follow and optionally tap words for memorization or repetition.

**Secondary Goals**:
- Smooth scrolling & zero layout jitter while the highlight moves.
- Fast initial load (lazy / staged parsing, cached assets).
- Offline operation (all assets local / Hive cached).
- Extensible to phrase segments, memorization statistics, and multi‑translation overlays.

---
## 2. Functional Requirements
| ID | Requirement |
|----|-------------|
| F1 | Load per‑verse word lists (Arabic + optional transliteration + translation). |
| F2 | Load per‑verse audio timestamps mapping audio time to words (or phrase segments). |
| F3 | Play a single verse or a playlist (full surah) with continuous highlighting. |
| F4 | Start highlight immediately at word 0 when playback begins. |
| F5 | Update active word as audio position crosses word time boundaries. |
| F6 | Provide fallback synthetic timestamps if real timestamps missing. |
| F7 | Support caching to avoid reparsing on subsequent launches. |
| F8 | Avoid UI jitter (no width shifts when highlight changes). |

---
## 3. Non‑Functional Requirements
- **Performance**: Avoid blocking UI thread; parsing offloaded to isolates (`compute`).
- **Scalability**: Handle all 114 surahs without memory blowup (lazy load).
- **Robustness**: Graceful handling of malformed or partial timestamp data.
- **Testability**: Deterministic parser & sync logic testable without UI.
- **Maintainability**: Clear layering (Data Source → Repository → Use Case → Provider → Service → Widgets).

---
## 4. Data Assets Design
### 4.1 Words JSON (per surah)
Example (`assets/data/word/1.json`):
```json
{
  "1": { "total_words": 4, "words": ["بِسْمِ", "اللّٰهِ", "الرَّحْمٰنِ", "الرَّحِيْمِ"] },
  "2": { "total_words": 4, "words": ["الْحَمْدُ", "لِلّٰهِ", "رَبِّ", "الْعَالَمِينَ"] }
}
```
(Translations / transliterations can be added later.)

### 4.2 Timestamp JSON (per surah)
Real-world variation accepted. Implement supports two schemas:
1. **Legacy Map**:
```json
{ "1": [ {"start":10,"end":450}, {"start":451,"end":900} ] }
```
2. **Segment Array** (phrase spans):
```json
[
  {"ayah":1, "segments":[ [0,2,0,800], [2,4,801,1600] ]},
  {"ayah":2, "segments":[ [0,4,1601,3000] ] }
]
```
Where a segment format is `[startWordIndex, nextWordIndex, startMs, endMs]` and must be *expanded* per word to unify rendering logic.

---
## 5. Domain Models (Hive Types)
File: `lib/domain/entities/word_by_word.dart`
```dart
class WordByWordVerse { int verseNumber; List<WordData> words; }
class WordData { String arabic; String translation; String transliteration; int charStart; int charEnd; }
class TimestampData { int verseNumber; List<WordTimestamp> wordTimestamps; }
class WordTimestamp { int start; int end; }
```
Design Notes:
- `charStart/charEnd`: reserved for potential text selection / partial highlighting.
- Keep models minimal; enrich via separate tables if needed.

---
## 6. Layered Architecture Overview
```
Assets (.json) → Local Data Source (parsing + cache) → Repository → Use Cases (optional) → Provider (state) → AudioService (playback + sync) → Widgets (RichText highlight)
```
- **Data Source**: Knows asset paths & parsing intricacies.
- **Repository**: Abstracts data source (prepare for remote / updates -> future).
- **Provider**: Aggregates loaded per-surah data; exposes maps keyed by verse.
- **AudioService**: Controls player, listens to position changes, emits active word index stream.
- **UI Widgets**: Subscribe (via `Selector` / `Consumer`) to only necessary slices to minimize rebuild cost.

---
## 7. Local Data Source Implementation
File: `lib/data/datasources/local/word_by_word_local_data_source.dart`
Responsibilities:
- Versioned cache keys (e.g., `word_by_word_surah_{n}_v2`).
- Isolate parsing using `compute`.
- Expanding phrase segments into per‑word timestamps.
- Logging & mismatch warnings.

Key Steps:
1. Check Hive box (cache hit). If found → deserialize models.
2. Else load asset → parse → (for timestamps) expand if needed → store to Hive → return.
3. Maintain `_cacheVersion` constant; bump when format changes.

Pseudo-snippet (expansion core):
```dart
for (final seg in segments) {
  final ws = seg[0]; final wn = seg[1]; final start = seg[2]; final end = seg[3];
  final span = wn - ws; final dur = end - start;
  for (int k = 0; k < span; k++) {
    final wStart = start + (dur * k / span).round();
    final wEnd   = start + (dur * (k+1) / span).round();
    perWord[ws + k] = {'start': wStart, 'end': wEnd};
  }
}
```

---
## 8. Repository Layer
Interface example (`lib/domain/repositories/quran_repository.dart` style analogue):
```dart
abstract class WordByWordRepository {
  Future<List<WordByWordVerse>> getSurahWords(int surah);
  Future<List<TimestampData>> getSurahTimestamps(int surah);
}
```
Implementation simply delegates to data source. This indirection allows later remote sync or differential updates.

---
## 9. Provider (State Management)
File (conceptual): `lib/presentation/providers/word_by_word_provider.dart`
Responsibilities:
- Ensure data for a surah is loaded once (`ensureLoaded(int surah)`).
- Maintain maps: `Map<int, WordByWordVerse> verses`, `Map<int, List<WordTimestamp>> timestamps`.
- Provide `allTimestamps` for playlist playback (a flattened map keyed by verseNumber).
- Integrity check: if `words.length != wordTimestamps.length` log and attempt expansion or fallback.

API Outline:
```dart
class WordByWordProvider extends ChangeNotifier {
  Future<void> ensureLoaded(int surah);
  WordByWordVerse? verse(int verseNumber);
  List<WordTimestamp>? verseTimestamps(int verseNumber);
  Map<int,List<WordTimestamp>> get allTimestamps;
}
```

---
## 10. Audio Service Integration
File: `lib/core/services/audio_service.dart`
Core Functions:
- Build playlist (e.g., concatenating verse audio sources).
- Maintain `_currentWordTimestamps` (list for active verse) & `_currentWordIndexController` (StreamController<int>). 
- On `currentIndexStream` change (verse advanced): swap `_currentWordTimestamps`, push index 0.
- Listen to `positionStream` (sampled / throttled) → update word index via incremental scan or binary search.

Pseudo:
```dart
void _onPosition(Duration p) {
  final ms = p.inMilliseconds;
  final ts = _currentWordTimestamps;
  // advance pointer only forward
  while (_ptr+1 < ts.length && ms >= ts[_ptr+1].start) _ptr++;
  if (_ptr != _lastEmitted) _wordIndexCtrl.add(_ptr);
}
```

Streams Exposed:
- `Stream<int> get currentVerseStream` (optional).
- `Stream<int> get currentWordIndexStream`.
- `Stream<PlayerState>` for UI controls.

---
## 11. Synchronization Logic Details
1. Load surah data before playback (pre-warm).
2. Start audio player.
3. Emit initial word index (0) immediately → ensures immediate highlight.
4. Subscribe to position updates (throttle ~60–80ms) to avoid UI flood.
5. Use monotonic pointer advancement (O(1) amortized) instead of rescanning from start each tick.
6. When track index changes, reset pointer and timestamps.

Edge Cases:
- Position overshoot (seek forward): perform localized binary search from pointer to end.
- Seek backward: perform binary search across entire list.

---
## 12. UI Rendering Strategy
Goals: Minimize rebuilds & avoid layout shift.
- Render verse line as a single `RichText` (or `Text.rich`) with `TextSpan` children.
- Apply highlight via background paint, not changing font weight/size.
- Wrap widget with `Selector<AudioProvider, (int activeVerse, int activeWord)>` so only this subtree rebuilds when indices change.
- Keep each verse's spans prebuilt? Optionally cache spans and only rebuild when active changes (micro-optimization).

Example Span Builder:
```dart
List<TextSpan> buildSpans(WordByWordVerse verse, int activeWord) => [
  for (int i=0; i<verse.words.length; i++) TextSpan(
    text: '${verse.words[i].arabic} ',
    style: i == activeWord ? highlighted : normal,
  )
];
```

Highlight Style:
```dart
final highlighted = normal.copyWith(background: Paint()..color = accentColor.withOpacity(.35));
```
Reason: background paint avoids text width change (no bold weight jitter).

---
## 13. Performance Considerations
| Concern | Mitigation |
|---------|-----------|
| JSON parsing jank | `compute()` isolate parsing; versioned caching (v2). |
| Too many rebuilds | `Selector` to target only word line; single RichText. |
| Frequent position updates | Throttle (≈55ms) + early exit if still inside current word. |
| Linear scan for index | Incremental forward pointer (amortized O(1)) + binary search only on backward seek. |
| Initial asset load spike | Lazy load non-critical translations post first frame. |
| Large memory footprint | Load only requested surah; dispose rarely used caches if needed. |

---
## 14. Fallback & Error Handling
Scenarios:
- Missing timestamp file ⇒ generate synthetic evenly spaced timestamps using verse audio duration estimate.
- Fewer timestamps than words ⇒ expand segments (already done) or append synthetic tail with default gap.
- Overlapping / unsorted timestamps ⇒ sort by `start`, clamp non-monotonic entries.
- Division by zero on identical start/end ⇒ mark minimal range (e.g., +40ms).

Diagnostics Logging (examples):
```
[WBW] expanded verse=5 words=19 expected=19
[WBW] expand warn verse=3 words=7 expected=9
[WBW] synthetic verse=12 words=15 reason=missing_timestamps
```

---
## 15. Logging & Instrumentation
Key log points:
- Cache hits vs asset loads.
- Expansion warnings.
- Playlist verse advance (`advance playlist verse=1:3 ts=12`).
- Word index changes (only first few for debug). Optionally disable in release.

Use simple `debugPrint` with prefixes; later can swap with a logging package (e.g., `logger`).

---
## 16. Extensibility Ideas
Feature | Approach
--------|---------
Tap a word to replay from it | Seek audio to word.start and reset pointer. 
Loop current word / phrase | Add repeat mode controlling position listener gating. 
Memorization tracking | Increment counters when word index transitions. Persist in Hive. 
Multi-reciter sync | Store multiple timestamp sets keyed by reciter ID. 
Animations | Fade background color with implicit animations (avoid heavy controllers). 
Accessibility | Expose current word via semantics label. 

---
## 17. Testing Strategy
Test Type | What to Verify
----------|---------------
Unit (Parser) | Phrase segment expansion yields expected per-word count & monotonic times.
Unit (Pointer Logic) | Given sequence of timestamps & positions, emitted indices correct.
Unit (Fallback) | Missing / dirty data triggers synthetic generation.
Widget | RichText highlights correct span without layout shift (golden test). 
Integration | Play mock audio (simulated position stream) and assert index progression. 

Example Parser Test Pseudocode:
```dart
final segments = [ [0,3,0,900] ]; // 3 words
final expanded = expandSegments(segments);
expect(expanded.length, 3);
expect(expanded.first.start, 0);
expect(expanded.last.end, 900);
```

---
## 18. Step-by-Step Implementation Sequence (From Zero)
1. Prepare assets (words & timestamps JSON). Validate schemas early.
2. Create domain models + Hive adapters (run build_runner if needed).
3. Initialize Hive boxes in app startup (`main.dart`).
4. Implement Local Data Source w/ versioned keys + isolate parsers.
5. Implement Repository interface & concrete class.
6. Add Provider for WBW (ensureLoaded & maps).
7. Implement AudioService wrapper over `just_audio` with playlist & sync logic.
8. Expose streams (word index) via Provider (`AudioProvider`).
9. Build UI verse widget using `RichText` + `Selector`.
10. Add highlight style & initial index emission.
11. Add expansion logic for segment timestamps.
12. Add logging & fallback synthetic generation.
13. Optimize performance (throttling, pointer scanning).
14. Add tests for parser + sync.
15. Polish UX (scroll into view active verse, subtle animation).

---
## 19. Minimal Code Skeleton (Condensed)
```dart
// audio_service.dart
class AudioService { /* singleton */
  final _player = AudioPlayer();
  final _wordIndexCtrl = StreamController<int>.broadcast();
  List<WordTimestamp> _current = []; int _ptr = 0; int _last = -1;
  Stream<int> get wordIndexStream => _wordIndexCtrl.stream;
  void playPlaylist(List<AudioSource> sources, Map<int,List<WordTimestamp>> tsMap) { /* build ConcatenatingAudioSource */ }
  void _onPosition(Duration d) { final ms = d.inMilliseconds; while (_ptr+1<_current.length && ms>=_current[_ptr+1].start) _ptr++; if (_ptr!=_last){_last=_ptr; _wordIndexCtrl.add(_ptr);} }
}
```
```dart
// word_by_word_provider.dart
class WordByWordProvider extends ChangeNotifier {
  final WordByWordRepository repo; Map<int,WordByWordVerse> _verses={}; Map<int,List<WordTimestamp>> _ts={};
  Future<void> ensureLoaded(int surah) async { if(!_surahLoaded(surah)){ /* load, store */ } }
  List<WordTimestamp>? verseTs(int verse)=>_ts[verse];
  Map<int,List<WordTimestamp>> get allTimestamps=>_ts;
}
```
```dart
// verse_widget.dart (excerpt)
class VerseWordLine extends StatelessWidget { /* build RichText with highlight */ }
```

---
## 20. Troubleshooting Guide
Issue | Likely Cause | Fix
------|--------------|----
No highlight | Word index stream never emits | Ensure initial emit (index 0) & timestamps not empty. 
Highlight jumps late | Position sampling too sparse | Reduce throttle interval. 
Jitter / layout shift | Font weight/style changes on highlight | Use background paint only. 
Wrong word highlighted | Timestamp expansion misaligned | Log per verse words vs timestamps lengths. 
High CPU | Linear scan each tick | Use pointer forward scan + binary search on seek. 
Cache not updating | Old schema persisted | Bump `_cacheVersion`. 

---
## 21. Security & Offline Notes
- All assets are local: zero network dependencies → safer & predictable.
- If remote updates are added later: validate checksums & schema before replacing cached data.

---
## 22. Future Enhancements
- Adaptive sync refinement using pitch detection (advanced).
- Animated cursor overlay (Canvas) instead of background fill.
- Per-user pacing analytics.
- Cloud-synced memorization progress.

---
## 23. Summary
This WBW system cleanly separates concerns: **data ingestion**, **caching**, **synchronization**, and **presentation**. Expansion of segment timestamps into per-word granularity unifies the rendering and reduces complexity in the UI layer. Performance optimizations (isolate parsing, pointer advancement, throttled position sampling) ensure smooth playback and visual alignment.

---
---
## 24. Recent UX Refinements (Post v1.1)
Addition | Description | Rationale
---------|-------------|----------
Adaptive Auto-Scroll Alignment | Dynamically chooses scroll alignment (0.02–0.10) based on measured verse height. | Long verses need to start nearer top to keep more content in view; short verses feel better slightly lower.
Glow Word Highlight (optional) | Soft dual-shadow + translucent background behind active word. Toggle `wordHighlightGlow` & respects `reduceMotion`. | Improves visual focus without harsh color blocks; accessible (can be disabled for motion sensitivity/performance).
Settings Toggles | `adaptiveAutoScroll`, `wordHighlightGlow` exposed in settings drawer. | User control & experimentation.

Technical Notes:
- Alignment thresholds currently heuristic: >600px → 0.02, >400px → 0.05, >300px → 0.08 else 0.10. Can be externalized to a config map if future tuning needed.
- Glow skips when `reduceMotion` true to avoid visual noise & extra layer compositing.
- Shadows add negligible cost (single RichText rebuild) due to span-level style only on active word.

Potential Next Steps:
- Cache verse height class after first measurement to avoid repeated threshold checks.
- Provide alternative emphasis style (underline pulse) for users who dislike glow.
- Expose alignment thresholds in an advanced debug/settings panel.

---
*Document version: 1.2 | Cache schema version: 2 (added adaptive auto-scroll + glow option)*

---
## 25. Maintenance Updates (Aug 22, 2025)
Fixes:
- Cache read type safety: Coerce cached Hive values `Map<dynamic,dynamic>` → `Map<String,dynamic>` before `fromJson` to prevent runtime cast exceptions on WBW/timestamps.
- Lifecycle safety: Added `mounted` checks around post-frame callbacks and async UI interactions in Quran view to avoid unsafe ancestor lookups while WBW auto-scroll/highlight callbacks run.

Notes:
- No schema change required; only read-path coercion. Keep `_cacheVersion` as-is unless data format changes.
