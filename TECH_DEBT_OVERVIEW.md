# Technical Debt & Shortcut Decisions

This document captures intentional shortcuts and their implications, plus remediation plan (Sprint oriented) for the Kurani Fisnik Flutter App.

_Last updated: 2025-08-12 (post search refactor phase 1, auto-scroll refinement)_

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

## 15. Heavy JSON Parsing on Main Isolate (Startup Frame Skips)
- Status: PARTIALLY MITIGATED
- Shortcut: Large translation / transliteration JSON decode + merge executed synchronously during initial UI build (initial state).
- Current: Core large JSON parsing moved to isolates; frame skips reduced but still present during search index build surah collection.
- Risk: Residual skipped frames (40–230) during initial index activities; battery/cpu spikes.
- Remediation (Next): Combine verse collection + index build fully off-main; throttle progress notifications; instrumentation of frame timings.

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

## 20. Search Index Persistence Missing
- Shortcut: Index rebuilt every launch; no disk snapshot.
- Risk: Repeated cold cost; battery & startup jank on slower devices.
- Remediation: Serialize index + metadata (version hash) to app documents; load fast path.

## 21. Search Index Partial Off-Main Collection
- Shortcut: Verse collection loop (1..114) still sequential on main before isolate build (pre-refactor plan). Phase 1 introduced manager & debounce but not consolidated build.
- Risk: Frame skips during collection; user perceives sluggishness.
- Remediation: Single compute for collection+build; stream/estimate progress; avoid main isolate awaits.

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

---
## Risk Levels
High: 1,7,8,13,15,20,21
Medium: 3,9,11,12,14,16,22,24
Low: 2,4,5,6,10,17,18,19,23,25,26

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
