# Technical Debt & Shortcut Decisions

This document captures intentional shortcuts and their implications, plus remediation plan (Sprint oriented) for the Kurani Fisnik Flutter App.

_Last updated: 2025-08-12_

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

---
## Risk Levels
High: 1,7,8,13
Medium: 3,9,11,12,14
Low: 2,4,5,6,10

---
## Sprint 1 (Proposed Targets)
1. Logger abstraction + replace prints.
2. Reintroduce bookmark & memorization stubs (feature-flagged) + action pattern.
3. Texhvid raw examples preservation (dual field) + minimal test.
4. AudioService segmentation plan (skeleton interfaces only this sprint).
5. Failure / Error hierarchy base + migrate 1–2 use cases.
6. Initial contract tests: Texhvid load, Audio url fallback (mock http), Repository categories.
7. Warning budget gate script (simple Dart or bash counter).

Definition of Done: Warnings <= 70, logger in core, tests green with new suites, feature flags hiding incomplete UI.

---
## Future (Sprint 2+)
- Full AudioService refactor.
- Advanced memorization (SRS) engine scaffold.
- Widget & integration test expansion.
- Performance profiling & index snapshot persistence.

---
Document owner: (assign)
