# Technical Debt & Shortcut Decisions

This document captures intentional shortcuts and their implications, plus remediation plan (Sprint oriented) for the Kurani Fisnik Flutter App.

_Last updated: 2025-08-12 (updated with performance & auto-scroll UX analysis)_

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
- Shortcut: Large translation / transliteration JSON decode + merge executed synchronously during initial UI build.
- Risk: Skipped 80–190 frames; degraded first impression; battery/cpu spikes.
- Remediation: Phase loading (core metadata first), defer heavy assets, move decoding to compute isolates, lazy load on demand.

## 16. Missing Auto-Scroll for Currently Playing Verse (Critical UX Gap)
- Shortcut: Audio index change not bound to scroll position; no automatic alignment of active verse in reader view.
- Risk: Breaks “hands-free” listening; users lose context; perceived unpolished.
- Remediation: Verse widgets keyed (GlobalKey or index-based itemPositions via ScrollablePositionedList); subscribe to currentIndexStream; invoke ensureVisible with smooth alignment & throttle; configurable auto-scroll toggle.

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

---
## Risk Levels
High: 1,7,8,13,16
Medium: 3,9,11,12,14,15
Low: 2,4,5,6,10,17,18,19

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
