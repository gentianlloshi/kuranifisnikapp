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

## Incremental Delivery Plan
- Sprint 1 (Foundations): SURAH-LIST-1, MEMO-1, MEMO-2 (baseline), SEARCH-1 scaffolding.
- Sprint 2 (Enhance & Polish): SURAH-LIST-2, VERSE-ACTIONS-1, MEMO-3, MEMO-4.
- Sprint 3 (Data & Advanced): DATA-1, THEMATIC-1, TEXHVID-1, SEARCH-2 (context preview).

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
