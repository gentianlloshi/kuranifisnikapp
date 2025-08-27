# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2025-08-27

### Highlights
- Massive performance improvements: strict lazy-loading enforced (metas-only startup), per-surah verse hydration, background parsing, and search index prebuild with incremental progress.
- Search experience revamped: debounced input, rebuild scoping with Provider `context.select`/`Selector`, index-readiness gating, and a unified results list.
- Stability: resolved build-time errors in `search_widget.dart`, fixed duplicate provider method and invalid identifiers, and eliminated interaction-time rebuild storms.
- Memory: verified zero Verse instances at cold start; reduced churn during search.
- Developer experience: added progress metrics and throttled provider notifications to avoid UI jank.

### Added
- SearchIndexManager incremental build trigger and progress stream with snapshot persistence.
- UI indicators for index coverage and readiness.

### Changed
- `search_widget.dart` refactor to use `context.read`/`context.select`, remove unused helpers, and fix syntax/bracing issues.
- Provider API: replaced `ensureIndexBuild` with `startIndexBuild`.
- Rebuild control across Search UI with scoped widgets and const usage.

### Fixed
- Duplicate method definition in provider.
- Syntax and undefined identifier errors in Search UI.
- Startup eager loading that created many Verse instances.

### Tests/Quality
- Test suite green (≈60 tests).
- Analyzer reports only info-level lints (to be cleaned in a follow-up).

### Notes
- No breaking changes expected for users. Internal provider API rename only affects app code.

---

## [1.0.0] - 2025-07-xx
- Initial public release.