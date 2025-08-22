# Use Case Integration Roadmap

Branch: feature/use-case-integration
Source Spec Version: 1.0 (Detailed Use Cases Document, 26 Korrik 2024)

## Guiding Principles
- Incremental vertical slices per module (Navigation, Reading, Memorization, Audio, Index, Personal Tools, Settings).
- Maintain startup performance constraints (no regression to prior jank > 200ms main thread stalls).
- Reuse existing providers where practical; introduce domain use cases only when adding non-trivial logic.
- Defer heavy/lazy data loads consistent with current performance strategy.

## Cross-Cutting Technical Debt & Enhancements
| Theme | Actions |
|-------|---------|
| State Consistency | Migrate ad-hoc provider logic (e.g., memorization legacy flags) to unified domain models; introduce typed status enums (done for memorization). |
| Persistence Versioning | Introduce version keys for new stored structures (memorization v1 already). Plan: favorites v2, notes tags indexing v1, reading progress v2. |
| Search Index | Add partial snapshot checkpoints (20/50/80%) & surface readiness states to search UI. |
| Performance Instrumentation | Extend perf summary with: indexCoverage%, enrichmentCoverage%, audioCacheHits, lazyBoxOpens. |
| Modularization | Separate core UI widgets vs feature modules; create `feature/` folder for Memorization, Thematic Index, Texhvid. |
| Error Handling | Centralize user-facing error surfaces (snackbars) via AppStateProvider messenger queue. |
| Accessibility | Larger tap targets (48dp), semantic labels for screen readers on icons (play, memorize, note). |

## Mapping Use Cases to Tasks (High-Level)

### Module: Navigation & Discovery
- UC-01: Surah list enhancements (progress bar, continue button) -> tasks SURAH-LIST-1..4
- UC-02: Search filters (Arabic/Albanian/juz) + context preview -> SEARCH-1..5

### Module: Reading & Interaction
- UC-03: Infinite scroll chaining + quick jump -> READING-1..3
- UC-04: Audio recitation enhancements (start from current, mini-player persistence) -> AUDIO-1..6
- UC-05: Verse action sheet consolidation -> VERSE-ACTIONS-1..2
- UC-06: Multi-select operations (already partial) unify with memorization & bookmark bulk -> MULTI-1..3

### Module: Study & Personal Tools
- UC-07: Thematic index hierarchical expand/collapse virtual list -> THEMATIC-1..4
- UC-08: Texhvid rule exploration + quiz mode -> TEXHVID-1..6
- UC-09: Personal collections hub (favorites, notes, memorization, bookmarks) unified nav -> PERSONAL-1..5

### Module: Settings & Data Management
- UC-10: Live theming & font scaling persistence -> SETTINGS-1..3
- UC-11: Import/Export JSON domain serializer + merge strategy -> DATA-1..4

### Module: Memorization (Spec Already Added)
- MEMO-1: Dedicated Tab UI (sticky controls, stats header)
- MEMO-2: Audio repeat integration & auto-scroll smoothing
- MEMO-3: Hide text (blur & tap-to-peek) with per-verse ephemeral reveal
- MEMO-4: Status cycling UI element (chip / pill) + animated transitions
- MEMO-5: Session persistence (selected vs ephemeral) & idle auto-save
- MEMO-6: Migration script from legacy boolean storage

## Detailed Task Breakdown (Initial Sprint Candidates)

1. SURAH-LIST-1: Add reading progress model (verses read / total). Persist as map surah->lastReadVerse & derived percentage.
2. SURAH-LIST-2: "Continue where you left off" button logic (most recent activity) with debounce.
3. SEARCH-1: Extend search UI with filter panel (chips) -> gating index queries.
4. MEMO-1: Implement Memorization tab scaffold + sticky header (SliverPersistentHeader).
5. MEMO-2: Integrate session selection with AudioProvider (repeat cycles) and gentle scroll.
6. VERSE-ACTIONS-1: Refactor verse options sheet into configurable action registry.
7. DATA-1: Draft domain export model (favorites, notes, memorization, settings) -> JSON.

## Progress Summary (Aug 2025)

| ID | Task | Status | Notes |
|----|------|--------|-------|
| SURAH-LIST-1 | Reading progress model & persistence | Done | `ReadingProgressProvider` + continue card implemented. |
| SURAH-LIST-2 | Continue button debounce | Done | Resume logic via most recent verse + popup menu. |
| SEARCH-1 | Search UI filters & gating | Done | Chips + field filters + index readiness gating at 20/50/80%. |
| VERSE-ACTIONS-1 | Configurable action registry | Done | `VerseActionRegistry` + dynamic sheet. |
| MEMO-1 | Memorization tab scaffold | Done | New tab with sticky header & stats. |
| MEMO-2 | Audio repeat & auto-scroll smoothing | Partial | Basic repeat (playlist duplication) + auto-scroll; refine loop controls & word-level sync later. |
| MEMO-3 | Hide text & tap-to-peek | Done | Blur/peek (5s auto-hide) implemented. |
| MEMO-4 | Status cycling UI with animation | Done | Outlined animated button. |
| MEMO-5 | Session persistence & idle save | Done | Debounced session selection persistence. |
| MEMO-6 | Legacy migration | Done | Migration executed on load (verses boolean/list -> structured). |
| DATA-1 | Export JSON (v2 model) | Done | Export + hash + domain toggles. |
| DATA-2 | Import dry-run diff + merge strategy | Done | Diff + conflict resolver + settings merge/overwrite. |
| THEMATIC-1 | Hierarchical thematic index scaffold | Done | Lazy node tree + persisted expansion. |
| THEMATIC-2 | Virtualized subtheme rendering | Done | Height clamp + builder list. |
| THEMATIC-3 | Deep‑link references to Quran view | Done | Tap on refs opens Quran at ajeti/range start via QuranProvider. |
| TEXHVID-1 | Texhvid rules basic viewer | Done | Viewer stable; content sanitized to strip HTML-like tags. |
| TEXHVID-2 | Texhvid quiz mode | Partial | Start dialog (category/limit) + session flow implemented; stats persistence pending. |
| SEARCH-2 | Context preview lines | Done | Prev/next verse context expansion. |
| PERF-1 | Perf panel metrics (index/enrichment/cache) | Done | Panel with coverage bars & translation dialog. |
| PERF-2 | Reactive translation & enrichment coverage | Done | Repository streams drive the perf panel live; no manual refresh. |
| A11Y-1 | Larger tap targets (key icons) | Partial | Many icons sized 20; audit pass needed. |
| ERR-1 | Centralized snackbar queue | Done | AppStateProvider queue + overlay host; major widgets migrated to enqueueSnack. |

## Updated Next Immediate Actions

1. PERF-2: Make translation coverage & enrichment coverage reactive (stream or ChangeNotifier from repository) + mini summary in panel. (Completed)
2. TEXHVID-2: Extend quiz mode with scoring summary and persist history (accuracy, streak) in Hive.
3. MEMO-2b: Persist A‑B range across session and show repeat counters; smooth index-based seeks already in place. (Completed; persistence via SharedPreferences, counters visible in player chips.)
4. SEARCH-3: Add fuzzy / partial matching optimization & highlight performance profiling (avoid widget span inflation on long results).
5. ERR-1: Introduce AppStateProvider snackbar queue + unified error dispatch API; refactor existing SnackBars.
6. TEST-1: Add widget tests (thematic index expansion, memorization hide/peek, verse action registry dynamic filtering).
7. A11Y-1b: Accessibility audit (semantics labels on action icons, minimum 48dp interactive areas) & doc checklist. (Partial; added Semantics to mini player and Texhvid quiz.)
8. DATA-3: Add incremental import preview for large JSON (streamed parsing) & progress updates.
9. TEXHVID-3: Persist quiz performance stats (streak, accuracy) in Hive with version key.
10. PERF-3: Add frame build timing sampler + optional overlay (dev mode toggle) for hotspots.

### Recently Completed (Aug 22)
- PERF‑2: Reactive coverage streams wired to performance panel (live updates).
- ERR‑1: Centralized snackbar queue; migrated key surfaces.
- AUDIO: A‑B loop index‑based seek within playlist + status chip in full player.
- TEXHVID: Start Quiz dialog (category/limit), HTML sanitization at model layer.
- ANDROID UX: Predictive back enabled; updated back handling in player sheet.
- STABILITY: WBW cache map cast fix; mounted checks added in Quran view async flows.

## Deferred / Nice-To-Have Backlog
| Idea | Rationale |
|------|-----------|
| Multi-reciter LRU cache | Reduce storage & memory for audio assets. |
| Offline first translation diff sync | Future content update mechanism. |
| Advanced search ranking (BM25-lite) | Better relevance ordering when multiple terms (flagged). |
| Animated list diffing for memorization changes | Smoother UX when cycling statuses. |

> Roadmap auto-updated after resolving initial compilation errors & integrating Perf + Memorization features (commit batch Aug 2025). Adjust IDs if new domains added.

## Incremental Delivery Plan
- Sprint 1 (Foundations) ✅: SURAH-LIST-1, MEMO-1, MEMO-2 (baseline), SEARCH-1 scaffolding.
- Sprint 2 (Enhance & Polish) ✅: SURAH-LIST-2, VERSE-ACTIONS-1, MEMO-3, MEMO-4.
- Sprint 3 (Data & Advanced) ✅: DATA-1, THEMATIC-1, TEXHVID-1 (base), SEARCH-2 (context preview).

### Proposed Upcoming Sprints (Draft)

- Sprint 4 (Performance & Error Handling Core)
	- PERF-2: Reactive translation & enrichment coverage.
	- ERR-1: Snackbar queue + unified error dispatch API.
	- MEMO-2b: Per-verse repeat count / A-B loop controls.
	- TEST-1 (subset): Unit/widget tests for PERF panel reactivity & error queue.

- Sprint 5 (Learning & Quiz Expansion)
	- TEXHVID-2: Quiz mode logic (random rule, answer set, scoring, persistence skeleton).
	- TEXHVID-3: Persist quiz performance stats (streak, accuracy) Hive v1.
	- DATA-3: Incremental import preview (streamed parsing progress UI).
	- TEST-1 (subset): Texhvid quiz logic tests + streamed import diff tests.

- Sprint 6 (Search & Accessibility Hardening)
	- SEARCH-3: Fuzzy / partial matching optimization + highlight perf profiling.
	- A11Y-1b: Accessibility audit & semantic labels rollout.
	- PERF-3: Frame build timing sampler + optional dev overlay.
	- TEST-1 (subset): Search highlight performance guard, semantics presence tests.

- Sprint 7 (Refinement & Nice-To-Have Candidates)
	- Multi-reciter LRU cache (prototype) OR Animated list diffing (choose based on perf findings).
	- Advanced search ranking (BM25-lite) spike behind feature flag.
	- Polish: Remaining a11y gaps, documentation updates, backlog triage.

### Sprint Objective Narratives
| Sprint | Objective | Success Indicators |
|--------|-----------|--------------------|
| 4 | Make performance & error telemetry actionable while refining memorization audio loops | Live updating perf panel (<1s latency), centralized snackbars adopted by 80% of former ad-hoc sites, stable A-B looping without dropped frames |
| 5 | Introduce engaging learning loop for Texhvid + resilient data import UX | Quiz session completion tracked, accuracy stats persisted, streamed import handles >1MB file without main thread jank >32ms |
| 6 | Improve discoverability & inclusivity; harden search scalability | Fuzzy search median query <120ms @ 5k verses, all critical icons have semantics labels, dev overlay identifies >1 hotspot if exists |
| 7 | Strategic enhancements preparing for future content & ranking | Feature flags for reciter cache / ranking, measured audio cache hit improvement, reduced rebuilds in memorization list |

### Dependency / Sequencing Notes
- PERF-2 precedes PERF-3 (need reactive sources before sampling overlay value).
- ERR-1 precedes wider adoption tests (TEST-1 subsets staged across sprints for incremental coverage).
- TEXHVID-2 before TEXHVID-3 (stats schema depends on quiz interaction model).
- SEARCH-3 ideally after performance instrumentation to leverage overlays for profiling.

### Capacity / Load Assumptions (Adjust Per Velocity)
- Each sprint targets ~4 primary tasks (mix of feature + infra) + layered test items to avoid late testing crunch.
- TEST-1 subdivided to ensure earlier coverage for newly introduced domains.

### Exit Criteria Additions For Upcoming Sprints
- Sprint 4: No persistent SnackBar usages outside queue (lint grep check passes).
- Sprint 5: Quiz accuracy persisted across restart; import progress UI never blocks scrolling.
- Sprint 6: Accessibility audit checklist artifact committed; search fuzzy ranking passes basic relevance test cases.
- Sprint 7: Chosen nice-to-have behind feature flag with toggle doc & perf baseline comparison recorded.

## Risk & Mitigation
| Risk | Mitigation |
|------|------------|
| Performance regression from new widgets | Profile builds, leverage list virtualization, avoid sync heavy ops on build. |
| Data migration errors | Add migration version keys & dry-run validation before commit. |
| Audio sync drift with repeat cycles | Pre-buffer durations & throttle scroll animation window. |
| Complex state coupling (multi-select vs session) | Shared selection service with mode discriminators. |

## Open Questions
- Should import merge or overwrite? (Proposed: Offer both with dry-run diff preview.)
- Multi-reciter caching strategy? (Consider LRU per reciter limited to N surahs.)
- Thematic index lazy expansion persistence? (Store expanded node IDs.)

## Definition of Done (Per Task)
- Code + tests (if logic heavy)
- No analyzer errors / new warnings
- Performance smoke (frame build <16ms average for target list views)
- Updated CHANGELOG section in roadmap or separate changelog file

## Next Immediate Actions
1. Implement MEMO-1 tab UI skeleton.
2. Hook audio repeat (MEMO-2) using existing AudioProvider.
3. Add migration for legacy memorization map to new list format (MEMO-6) to avoid orphan data.

---

(Generated automatically as starting roadmap; adjust typeIds if future Hive adapters introduced.)
