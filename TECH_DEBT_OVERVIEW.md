# Technical Debt & Shortcut Decisions

This document captures intentional shortcuts and their implications, plus remediation plan (Sprint oriented) for the Kurani Fisnik Flutter App.

_Last updated: 2025-08-22 (A‑B loop index seek, Texhvid HTML sanitization, predictive back, WBW cache cast fix)_

## 1. Removed Providers (Bookmark / Memorization) – Placeholder UI
- Shortcut: Removed provider usages; left FAB actions with SnackBars.
- Risk: User confusion; future re‑integration friction.
- Remediation: Reintroduce via thin service interfaces + feature flag.

## 2. Placeholder FAB Actions
- Shortcut: Actions do not mutate state.
- Risk: Tests may pass while features inert.
- Remediation: Introduce Action classes; map to stubs now, real logic later.

## 3. Consolidated Texhvid Use Cases
- Shortcut: Single `TexhvidUseCases` aggregator.
- Risk: Violates SRP; harder fine-grained tests.
- Remediation: Split into focused use cases when expanding.

## 4. Ignored Style / Deprecation Warnings
- Shortcut: Deferred `withOpacity`, `sort_child_properties_last`, etc.
- Risk: Potential future breakage; noise hides new warnings.
- Remediation: Lint budget; batch fixes.

## 5. Residual Null-Safety Noise (some cleaned)
- Shortcut: Left non-critical null assertions / dead expressions earlier.
- Risk: Misleading readability.
- Remediation: Complete purge; enforce stricter analyzer rules.

## 6. Unstructured TODOs
- Shortcut: Plain TODOs without tags.
- Risk: Hard to prioritize; risk of rot.
- Remediation: Standardize `// TODO(<area>/<id>): description` & monthly audit.

## 7. Flattened Texhvid Examples
- Shortcut: Loss of semantic richness.
- Risk: Harder advanced rendering later.
- Remediation: Store raw example objects alongside flattened view.

## 8. Monolithic AudioService
- Shortcut: All concerns (resolve, cache, prefetch, retry) in one class.
- Risk: Higher complexity, harder testing.
- Remediation: Extract: Resolver, PrefetchCoordinator, CacheManager, Controller.

## 9. Ad-hoc Logging (_log only in audio)
- Shortcut: No unified logger interface.
- Risk: Inconsistent diagnostics.
- Remediation: Introduce Logger abstraction (levels, toggle, route to console/file).

## 10. Conversion Tool Prints & While Style
- Shortcut: Left `print` and single-line while loops.
- Risk: CI noise / potential future bug.
- Remediation: Replace with logger + braces + optional --verbose flag.

## 11. No Feature Flags for Incomplete Features
- Shortcut: UI shows inactive capabilities.
- Risk: Perceived broken features.
- Remediation: Central feature flag registry; hide unfinished items.

## 12. Generic Exception Wrapping in Use Cases
- Shortcut: `throw Exception('Failed ...')` losing original error type.
- Risk: Poor error handling differentiation.
- Remediation: Domain Failure hierarchy + mapping layer.

## 13. Missing Tests (Audio, Texhvid)
- Shortcut: Limited test scope.
- Risk: Regression risk in core behaviors.
- Remediation: Add contract tests (load rules, audio fallback, caching path).

## 14. Lack of Warning Trend Tracking
- Shortcut: Manual observation only.
- Risk: Drift of code quality.
- Remediation: Script to count & categorize warnings per commit.

## 15. Heavy Startup Work Still Clustered (Residual Frame Skips / ANR Risk)
- Status: PARTIALLY MITIGATED / REGRESSED (post new features)
- Improvement So Far: Major JSON (translations, transliterations, WBW, thematic index) offloaded to isolates.
- Current Problem: Surah full object materialization + provider inits + early incremental index start + Hive box opens overlap in first 1–1.5s → large frame bursts (>1000 skipped frames in traces on low-end devices).
- Risk: Perceived freeze; potential OS ANR dialog on very low spec devices; battery spike.
- Remediation (Next):
	1. Phased StartupScheduler (Frame 1 shell → +200ms surah metadata only → +700ms index resume/build → +1200ms translation prewarm).
	2. Lazy verse loading (metadata list first; hydrate verses on demand).
	3. Stagger Hive openings (microtask gaps) & instrument each phase.
	4. Dynamic batch pacing for index using frame timing callbacks.

## 16. Missing Auto-Scroll for Currently Playing Verse (Critical UX Gap)
 - Status: ADDRESSED (PHASE 1) / REFINEMENTS PENDING
- Implemented: GlobalKey measurement + ensureVisible alignment=0.1 + throttle + suppression after recent manual scroll (3s window) + animated highlight of current verse.
- Remaining Gaps: User preference toggle, improved precision for large dynamic font changes, accessibility (reduce motion) mode, scroll easing adaptation when distance large.
- Follow-up: Expose toggle in settings; pre-measure heuristic average line height to reduce fallback offset variance.

## 17. MediaCodec / Dead Thread Legacy Logs
- Shortcut: Historical recreate/dispose pattern produced handler-on-dead-thread warnings; some vendor MediaCodec noise left unfiltered.
- Risk: Diagnostic noise may hide real playback failures.
- Remediation: Confirm absence post-singleton refactor; add filtered logger category (media.noise) and escalate only genuine initialization failures.

## 18. Hidden API Access Warnings
- Shortcut: Rely on upstream player libraries that reflectively probe hidden methods.
- Risk: Potential future OS restriction (low probability); warning clutter.
- Remediation: Keep dependencies updated; no in-house reflection; document acceptance.

## 19. MP3 Xing Data Size Mismatch Logs
- Shortcut: Accept upstream asset variance without pre-validation.
- Risk: Minor duration estimation drift; negligible UX impact.
- Remediation: (Optional) Offline integrity validation + ignore at runtime.

## 20. Search Index Persistence
 - Status: IMPLEMENTED (Snapshot v2: terms map + postings + progress pointer)
- Remaining Debt: No compaction/size guard; legacy snapshot versions not purged; checksum/version mismatch detection minimal.
- Risk: Silent bloat over time; rebuild on subtle schema mismatch.
- Remediation (Next): Add size threshold, legacy file cleanup, strong hash on source asset manifest.

## 21. Search Index Incremental Build CPU Scheduling
- Status: PARTIAL (incremental build + progress stream + adaptive throttle implemented)
- Shortcut: Adaptive throttle uses coarse sleep; frame budget awareness absent; indexing may coincide with other heavy tasks.
- Risk: Jank during simultaneous scroll + build; wasted potential idle frame exploitation.
- Remediation: Frame-time aware pacing (SchedulerBinding timings); pause during sustained fast scroll; merge small batches when idle budget high.

## 22. Insufficient Performance Instrumentation
- Shortcut: Limited coarse Stopwatch logs only for JSON parsing.
- Risk: Hard to correlate frame skips with phases; blind optimization.
- Remediation: Timing spans (build start/end, batches, query latency) + SchedulerBinding frame timing logs (debug only).

## 23. Missing Index Query Micro-Optimizations
- Shortcut: Lowercase conversion & token scanning repeated per query.
- Risk: Unnecessary per-keystroke CPU.
- Remediation: Precompute lowercase translation, early candidate short-circuiting, intersection pruning, deferred highlight span generation.

## 24. Morphological Normalization (Albanian) Absent
- Shortcut: Exact surface tokens only (with diacritic folding), no stemming.
- Risk: Misses inflected forms (e.g., -it, -in) reducing recall.
- Remediation: Light suffix stripping list (configurable) applied symmetrically to corpus & queries; feature-flag.

## 25. Debounce Centralization Done; Legacy Local Debounce Leftovers
- Status: CLEANED (SearchWidget local Timer removed) – keep for audit trail.
- Risk: Divergent future reintroductions.
- Remediation: Document provider-level debounce contract (350ms) & enforce single entry point.

## 26. Verse Highlight Styling Accessibility Review Pending

## 27. Word-by-Word Timestamp Engine Initial Implementation
- Status: NEWLY IMPLEMENTED
- Implemented: Segment expansion (phrase → per-word), cache versioning (v2), pointer-based incremental advancement with throttle (55ms), duplicate log suppression for verse advancement.
- Risk: Frame skips still present early (unrelated residual parsing); potential drift if future timestamp formats vary; synthetic allocation for missing tail words simplistic linear distribution.
- Remediation: Add formal tests (parser expansion correctness, pointer seek backwards), introduce adaptive throttle (reduce when device under load), optional binary search path for backward seeks (already partially implemented).

## 28. Log Volume & Performance Instrumentation Gaps (Audio / WBW)
- Status: NEW
- Shortcut: High-frequency playlist advancement logs (partially reduced), no timing metrics around word index update cost or throttle hit ratio.
- Risk: Hard to reason about remaining frame skips; noisy logs hamper issue triage.
- Remediation: Introduce lightweight metrics aggregator (counts: updates processed vs skipped, avg loop time), gated by debug flag; rate-limit advancement logs (500ms window) globally.
- Shortcut: High-contrast background color chosen without WCAG contrast measurement for dark mode edge cases.
- Risk: Potential low readability for users with contrast sensitivity.
- Remediation: Add contrast check utility & optional outline focus ring; provide user setting to switch highlight style (underline only / background).

## 29. Word-by-Word Rendering Architecture (WidgetSpan Per Word)
- Status: NEW / HIGH PRIORITY
- Issue: `WidgetSpan` + container per word increases render objects & broke Arabic ordering edge cases; impacts shaping & layout cost.
- Remediation: Single `RichText` with `TextSpan` children + per-word recognizers; highlight via style (non-layout) change.

## 30. Highlight State Artifact Accumulation
- Status: NEW
- Issue: Prior layering risked stale highlight widgets remaining.
- Remediation: Centralize active word index; assert exactly one highlight style applied; diff-only rebuild.

## 31. Lazy Surah Metadata Mode Missing
- Status: NEW / HIGH PRIORITY
- Issue: All verse objects instantiated at startup.
- Remediation: Introduce lightweight `SurahMeta` list (id, arabicName, translationName, versesCount); hydrate verses lazily.

## 32. Startup Task Orchestration Absent
- Status: NEW / HIGH PRIORITY
- Issue: No scheduler; tasks fire concurrently causing contention.
- Remediation: Implement `StartupScheduler` phases + cancellation + metrics.

## 33. Frame Timing & Instrumentation Gap
- Status: NEW / HIGH PRIORITY
- Issue: No automated capture of frame durations, first paint, index batch timing.
- Remediation: Add debug-only `PerformanceMonitor` (TTFP, >32ms frames, max contiguous skips, batch duration histogram).

## 34. Verse Paging Aggressiveness
- Status: NEW
- Issue: Static page size may exceed frame budget on large fonts / slower devices.
- Remediation: Adaptive page size targeting <12ms build time.

## 35. Audio & WBW Concurrency Policy
- Status: NEW
- Issue: Heavy background isolate tasks contend with real-time audio UI updates.
- Remediation: Cooperative token / priority escalation (audio over indexing) + yield hooks.

## 36. Translation Prewarm Strategy
- Status: NEW
- Issue: Potential to decode multiple translations up front.
- Remediation: Prewarm only active; lazy others; track usage for idle prefetch.

## 37. Memory Footprint Awareness
- Status: NEW
- Issue: No tracking of verse object counts or cache size.
- Remediation: Counters + debug panel + future LRU if threshold exceeded.

## 38. Gesture Recognizer Allocation Per Word
- Status: NEW
- Issue: One recognizer per word may be heavy for long verses.
- Remediation: Recognizer pool or manual hit-test mapping on pointer up.

## 39. Adaptive Highlight Frequency
- Status: NEW
- Issue: Rebuild for every rapid word transition even < frame budget.
- Remediation: Coalesce rapid transitions; skip intermediate frames.

## 40. Legacy Documentation Drift
- Status: NEW
- Issue: WordByWordImpl doc out-of-sync with planned TextSpan architecture.
- Remediation: Update doc + add ADR after migration.

---flutter run --debug
## Risk Levels
High: 1,7,8,13,15,20,21,29,31,32,33
Medium: 3,9,11,12,14,16,22,24,34,35,37,39,40
Low: 2,4,5,6,10,17,18,19,23,25,26,28,30,36,38

Note: 20 (Persistence) mostly complete; residual items kept High until compaction & checksum added.

### Newly Added/Addressed (Aug 22)
Addressed:
- ERR‑1 Centralized SnackBar queue adopted by major surfaces.
- PERF‑2 Reactive coverage streams wired to perf panel.
- TEXHVID: Sanitized HTML‑like tags from rule content & quiz text at model layer.
- ANDROID: Predictive back enabled; Pop/Back handling modernized in full‑player.
- WBW: Cache cast fix for Hive Map<dynamic,dynamic> to Map<String,dynamic> on read.

New High Priority:
1. (29) WBW TextSpan rendering migration
2. (31) Surah metadata lazy loading
3. (32) Startup scheduler
4. (33) Frame timing instrumentation
5. (21) Dynamic index pacing refinement

### Proposed Sprint Focus (Next)
Area | Tasks
-----|------
Startup Smoothness | 15,31,32,21 (pacing),34
WBW Reliability & Performance | 29,30,38,39
Search Efficiency | 20 (remaining),21
Instrumentation | 22,28 (metrics),33
Memory | 37 (counters),31 (lazy load)

Definition of Done (Sprint):
- TTFP < 700ms (mid-tier, warm start profile).
- No frame >120ms in first 2s (excluding first paint) during profile run.
- WBW migration: zero RTL ordering defects & highlight rebuild <1 per frame.
- Index resume: batches <8ms main isolate time average.
- Surah open (cached) median build <40ms across sample.

---
## Appendix A: Help Page Feature Coverage Audit (2025-08-12)
Derived from `help_page.dart` descriptive sections; status reflects actual implementation or current placeholder.

| Area | Feature (Help Label) | Status | Notes / Debt |
|------|----------------------|--------|--------------|
| Search Panel | Kërkimi Inteligjent (term, surah name/number, verse ref 2:255, Arabic) | PARTIAL | Core index + term search ok; direct pattern `2:255` navigation implemented via openSurahAtVerse; Arabic diacritics normalized; need explicit surah name alias mapping robustness |
| Search Panel | Filtrat e Kërkimit (choose Albanian vs Arabic or specific Juz) | MISSING | No UI filter toggles or Juz constraint currently in search widget |
| Search Panel | Zgjedhja e Përkthimit (multi translation compare) | PARTIAL | Dropdown exists; search ranking only uses active translation; multi-field weighting pending |
| Search Panel | Lundrim i Shpejtë (Go to Juz) | MISSING | No 'Go to Juz' quick menu in current UI; requires Juz index & mapping |
| Reader Controls | Shko te Ajeti (jump within surah) | PARTIAL | Indirect: openSurahAtVerse from external; in-surah drop-down not present (needs verse picker) |
| Reader Controls | Modaliteti i Përzgjedhjes (multi-select verses) | MISSING | No selection state / action bar implemented |
| Reader Controls | Lexim pa Shpërqendrime (fullscreen) | MISSING | No fullscreen toggle hiding chrome |
| Reader Controls | Luaj Gjithë Suren (play entire surah) | PARTIAL | playSurah exists; verify continuous playback & UI control state; stop button unified? |
| Verse Actions | Dëgjo (single verse play) | IMPLEMENTED | Per-verse play button + highlight current verse |
| Verse Actions | Shto te të Preferuarat (favorites) | PARTIAL | Bookmark provider integrated; favorite vs bookmark terminology mismatch |
| Verse Actions | Kopjo | MISSING | UI button placeholder / TODO |
| Verse Actions | Ndaj (share) | MISSING | Snackbar placeholder only |
| Verse Actions | Shenjo (bookmark reading position) | PARTIAL | Bookmark concept present; dedicated 'last position' marker absent |
| Verse Actions | Shënim (notes) | PARTIAL | Notes system exists; per-verse quick add from verse card not yet wired (TODO) |
| Verse Actions | Memorizo | PARTIAL | Memorization provider scaffold + toggle; advanced tools (hide text, spaced repetition) missing |
| Verse Actions | Gjenero Imazh | MISSING | Feature described; implementation not located in code tree |
| Tabs | Kurani | IMPLEMENTED | Surah list + reader view present |
| Tabs | Indeksi Tematik | IMPLEMENTED | Thematic index provider & UI present |
| Tabs | Texhvid | IMPLEMENTED | Rules & quiz content integrated |
| Tabs | Të Preferuarat | PARTIAL | Favorites/bookmarks accessible; UX polish & filtering pending |
| Tabs | Memorizim | PARTIAL | Basic list & provider; lacking progression tools |
| Tabs | Shenjuesit (bookmarks / last position) | PARTIAL | Bookmark list exists; distinct last-read marker logic missing |
| Tabs | Shënimet | PARTIAL | Notes infrastructure; enhanced search/filter UI may be limited |
| Settings | Tema (themes) | IMPLEMENTED | Multiple themes available |
| Settings | Madhësia e shkronjave | IMPLEMENTED | Font size settings applied in widgets |
| Settings | Përkthimi | IMPLEMENTED | Switchable via dropdown; search weighting pending |
| Settings | Opsionet e shfaqjes (toggle arabic, translation, transliteration, word-by-word) | IMPLEMENTED | AppSettings manages toggles |

### Coverage Summary
- Implemented: 11
- Partial: 13
- Missing: 7

### Actionable Debt Additions (Grouped)
1. Search Filters & Juz Navigation: Add translation scope toggles (arabic / translation), Juz selector, surah alias map.
2. Reader UX: Verse jump dropdown, fullscreen toggle, multi-select with action bar.
3. Verse Actions Completion: Copy, Share, Image generation, last-read marker, quick note add wiring.
4. Memorization Enhancements: Practice modes (hide text, spaced repetition scheduling), stats persistence.
5. Favorites vs Bookmarks Terminology: Unify naming & UI labels.
6. Index Ranking: Incorporate multi-translation weighting once filters added.
7. Accessibility: Fullscreen & selection modes should respect system UI overlays; add reduce-motion consideration for auto-scroll.


---
## Sprint 1 (Proposed Targets)
1. Logger abstraction + replace prints.
2. Reintroduce bookmark & memorization stubs (feature-flagged) + action pattern.
3. Texhvid raw examples preservation (dual field) + minimal test.
4. AudioService segmentation plan (skeleton interfaces only this sprint).
5. Failure / Error hierarchy base + migrate 1–2 use cases.
6. Initial contract tests: Texhvid load, Audio url fallback (mock http), Repository categories.
7. Warning budget gate script (simple Dart or bash counter).

Added (post-audio stabilization):
8. Instrument JSON parsing durations (Stopwatch logs) & isolate offload plan doc.
9. Auto-scroll design spike (pick implementation: GlobalKey + ensureVisible vs ScrollablePositionedList) & prototype for one sure.

Definition of Done: Warnings <= 70, logger in core, tests green with new suites, feature flags hiding incomplete UI.

---
## Future (Sprint 2+)
- Full AudioService refactor.
- Advanced memorization (SRS) engine scaffold.
- Widget & integration test expansion.
- Performance profiling & index snapshot persistence.
- Download-then-Play audio prefetch pipeline.
- Auto-scroll production hardening (edge cases: user manual scroll suppression, accessibility settings).
- Word-level timing ingestion & highlight engine (bounded CPU diffing).

---
Document owner: (assign)
