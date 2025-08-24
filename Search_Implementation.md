# Qur'an Search Implementation

_Last updated: 2025-08-23_

This document provides a deep dive into the current search architecture in the Kurani Fisnik Flutter app: data flow, indexing strategy, tokenization & normalization, ranking, fallback paths, performance characteristics, limitations, and recommended enhancements.

---
## 1. High-Level Goals
The search feature must:
- Be fast (sub‑100 ms typical query latency after warmup)
- Support partial / incremental typing (prefix search)
- Handle multilingual content (Arabic, Albanian translation & transliteration)
- Tolerate diacritic / orthographic variance (ç→c, ë→e, Arabic diacritics removed)
- Provide relevant ranking rather than raw occurrence order
- Degrade gracefully if the index build fails (fallback to domain use case)
 - UI highlights partial matches (diacritic‑insensitive) and shows total results count

---
## 2. Data Sources & Entities
Each verse record contributes multiple textual surfaces:
- Arabic: `Verse.textArabic`
- Translation (Albanian): `Verse.textTranslation`
- Transliteration: `Verse.textTransliteration`

A verse is uniquely identified by a composite key `surahNumber:verseNumber` (e.g., `2:255`).

---
## 3. Control Flow Overview
1. UI calls `QuranProvider.searchVerses(query)`.
2. Provider ensures the inverted index exists via `SearchIndexManager.ensureBuilt()`.
   - First tries to load a persisted snapshot (v2) from app documents using a corpus-hash fast path.
   - If not available, it performs a single full off-main isolate build by parsing asset JSONs and constructing the index entirely in an isolate (see `search_index_isolate.dart`).
3. When index is ready: the manager executes the in-memory query and returns ranked `List<Verse>`.
4. Results are assigned to `_searchResults` and `notifyListeners()` triggers UI updates.
5. If index build fails: the provider can still fall back to `_searchVersesUseCase` (legacy direct search), though in practice the snapshot fast-path or isolate build should cover normal operation.

---
## 4. Inverted Index Structure
```
Map<String, List<String>> invertedIndex : token -> list of verseKeys
```
Characteristics:
- Each token list preserves insertion order (effectively surah traversal order) but final ranking overrides order.
- Distinct token harvesting across Arabic (normalized), transliteration, translation.
- Duplicate verseKey prevented per token by local `seen` set.

Memory Consideration:
- Token explosion controlled by: prefix length min=2, max prefix length per base token capped at 10 chars, diacritic folding reduces variants.

---
## 5. Tokenization & Normalization
### 5.1 Latin / Albanian Tokenization
Regex: `[^a-zçëšžáéíóúâêîôûäöü0-9]+` splits on non-alphanumeric (extended). Lowercased early.

### 5.2 Arabic Normalization
Operations:
- Remove tashkeel (harakat & Quranic marks)
- Normalize Alef variants (آ, أ, إ, ٱ → ا)
- Normalize dotless ya (ى → ي)
- Remove tatweel (ـــ)

### 5.3 Latin Diacritic Folding
Mapping reduces e.g. `ç→c`, `ë→e`, plus broad vowel/accent normalization (see `_normalizeLatin`).

### 5.4 Prefix Indexing
For each normalized Latin token (length ≥3):
- Generate prefixes of length 3..min(len-1, 10)
- Enables incremental suggestions while user types.
- Arabic tokens are effectively normalized then tokenized; prefixes generated the same way because after normalization they are plain letters.

### 5.5 Query Expansion
`_expandQueryTokens(query)` adds:
- Original tokens
- Diacritic‑stripped variants (ç, ë → c, e)
- Light Albanian stems (e.g., -ave, -eve, -uar, -shme, -isht, -it, -in, -ve)
Result deduplicated via `toSet()`.

---
## 6. Ranking & Scoring
Given candidate verse keys (union of posting lists for expanded tokens):
- Base score: `hitCount * 10` (one hit per token list membership)
- Bonus: +25 for each full token string containment inside the verse translation (current heuristic target field)
- Secondary tie-breakers: surahNumber ASC, verseNumber ASC

Rationale: Simple, computationally cheap O(k) where k = candidate count. Avoids heavy TF-IDF; acceptable since corpus is small (6236 verses) & largely static.

Filtering & Fuzzy Gate:
- After candidate generation, we require at least one diacritic‑folded substring hit in selected fields (e.g., translation) to keep a verse. This eliminates spurious fuzzy matches (e.g., far tokens matching by edit distance only).
- Fuzzy fallback uses bounded Levenshtein with a first‑letter match filter.

Limitations:
- Does not weight Arabic vs translation differently.
- No position or proximity scoring.
- Multi-field weighting absent (only translation used for bonus).

---
## 7. Performance Characteristics
| Phase | Complexity | Notes |
|-------|------------|-------|
| Index Build | O(N * T) where N=verses, T=tokens per verse | Full build runs in a single isolate using raw asset JSONs (Arabic, translation, transliterations). Main isolate stays responsive. |
| Snapshot Load | O(S) where S=size of snapshot JSON | Fast-path on startup; validated via corpus hash assembled from asset bytes. |
| Query | O(sum(len(postingList(token)))) + sort(candidates) | Candidate set small vs full corpus due to prefix pruning. |
| Memory | ~ (tokens * avgKeyRefs * pointer) | Controlled by prefix cap & normalization. |

Warm Index Expected Query Latency: ~1–10 ms typical (device-dependent).

---
## 8. Fallback Path
If index build fails (exception or isolate error): `_invertedIndex` may remain partial → provider searches the available subset or falls back to `_searchVersesUseCase`.

---
## 9. Threading & Concurrency
- Heavy build uses `compute` with a single entry point `buildFullIndexFromAssets(payload)` which parses asset JSONs and builds the inverted index off the main isolate.
- No locking required inside the index builder isolate. The result is a `{ index, verses }` map transferred back to the main isolate.
- Main isolate only hydrates caches after the compute returns; races are avoided via internal `_building` guard and a build completer.

Edge Case: Multiple simultaneous search calls while build in progress: first call ensures a build starts; subsequent calls search the available subset or wait for completion depending on UI logic. Live `progressStream` allows UI to show progress.

---
## 10. Error Handling
- Silent continue on per-surah failure while collecting verses (skips broken surah).
- Entire build wrapped in try/finally; failure resets state & notifies UI to allow fallback.
- Improvements suggested: capture exception details to a diagnostic log buffer.

---
## 11. Caching & Persistence Strategy
- Verse objects cached in `_verseCache` keyed by verseKey for quick retrieval after ranking.
- Index snapshot persistence implemented (v2): JSON `{version, dataVersion, index, verses, createdAt, nextSurah}` stored in app documents. `dataVersion` is a lightweight corpus hash derived from asset bytes. On startup we attempt a fast-path load; if the hash mismatches, we rebuild off-main and overwrite the snapshot.

---
## 12. Pagination Interaction
Search results currently ignore pagination; entire candidate result set stored in `_searchResults` (acceptable due to limited size). Could paginate if future memory concerns or if combined with global ranking across fields.

---
## 13. Known Limitations & Debt
| Category | Issue | Impact | Proposed Fix |
|----------|-------|--------|--------------|
| Ranking | Lacks Arabic weighting | Mixed-language queries suboptimal | Multi-field weight vector (e.g. translation=1.0, arabic=0.8, translit=0.6) |
| Ranking | No proximity scoring | Multi-token semantic grouping ignored | Track token positions list per verse for ordered / window scoring |
| Accuracy | Prefix bias may inflate noise | Short prefixes (2 chars) yield many candidates | Increase min prefix to 3 or dynamic threshold after corpus stats |
| Perf | Full index build every launch | Startup overhead | Persist index JSON + quick checksum validation |
| UX | No incremental async suggestions gating | Rapid typing may trigger redundant query cycles | Debounce queries (e.g. 120 ms) & show loading chip only during build |
| Memory | Duplicate verseKey references across prefixes | Larger posting lists | Compress postings (delta encode ints after mapping verseKey→int) |
| Intl | Arabic normalization minimal | Some search forms missed | Add more folds (teh marbuta mapping, remove kasheeda variants) |
| Fault | Silent surah load failures | Hidden data gaps | Collect skipped surah IDs & surface warning banner |

---
## 14. Extension Roadmap
1. Weighted multi-field scoring + optional BM25-lite variant (flag scaffolded).
3. Highlight matched tokens in UI (store match spans during scoring pass).
4. Incremental index updates (if adding notes / annotations in future).
5. Advanced phonetic matching (soundex-like for transliteration) for mis-typed queries.

---
## 15. Example Walkthrough
Query: `rahmet Allah`
1. Tokenize → ["rahmet", "allah"]
2. Expand → ["rahmet", "rahmet" (norm same), "allah"]
3. Lookup posting lists for each token and their prefixes if user typed partially (e.g. `rahm`, `alla`).
4. Union & score: verse keys with both tokens receive base 2*10 + bonuses if full tokens appear exactly in translation.
5. Sort → present results.

---
## 16. Code Artifacts
- Provider: `lib/presentation/providers/quran_provider.dart`
- Index builder isolate: `lib/presentation/providers/inverted_index_builder.dart`
- Use cases: `search_verses_usecase.dart`, `get_surah_verses_usecase.dart`

---
## 17. Testing Suggestions
| Test | Description |
|------|-------------|
| Index Build Smoke | Ensure index builds without exceptions with full corpus |
| Query Exact | Query a known unique phrase; expect containing verse rank #1 |
| Query Prefix | Type incremental prefixes; verify result set grows logically |
| Diacritic Fold | Query with and without ç/ë; ensure identical results |
| Arabic Normalization | Include token with removed diacritics; ensure match |
| Fallback Mode | Simulate index build failure; verify fallback path returns results |

---
## 18. Proposed Enhancements (Implementation Sketch)
### 18.1 Persist Index
- Serialize: `{ 'version': <hash>, 'index': <Map<String,List<String>>> }` to app documents.
- On startup compute hash of verse corpus (e.g., SHA256 of concatenated translation file + metadata).
- Load if version matches; else rebuild.

### 18.2 Multi-Field Weighted Score
```
score = sum(tokenHits * 10) + sum(fieldWeights[field]*fullTokenMatches[field])
fieldWeights = {translation:1.0, arabic:0.8, translit:0.5}
```
Would require capturing which field produced each token (store field-id bitmask in postings).

### 18.3 Proximity Boost
Store ordered token positions per verse (Map<verseKey, List<int>> per token). During scoring, for multi-token queries compute minimal span window; add inverse span bonus.

---
## 19. Security & Privacy Considerations
- All processing local; no network calls initiated by search indexing.
- Memory footprint only includes verse texts already bundled with app assets.

---
## 20. Summary
The current search solution balances implementation complexity and performance using a single in-memory inverted index with normalized, prefix-extended tokens. It meets responsiveness goals; a fuzzy-but-gated layer improves relevance. Next steps are persisted index tuning and multi-field ranking sophistication.

---
## 21. Unified Executive Summary & Final Action Plan (From Field Analysis)

This section consolidates live testing observations (UI freezes, sporadic ANR risk, indexing latency, missed matches) into a prioritized remediation program.

### 21.1 Unified Diagnosis
Primary root cause of perceived freezes / potential ANR (previous state):
- Heavy synchronous work on the main isolate prior to the index build (collecting verses per surah) and lack of persistence.

Applied fixes in current implementation:
- Full off-main isolate build that performs both data parsing and index construction from asset JSONs.
- Snapshot persistence with corpus-hash validation for fast startup.

Secondary quality issues:
- Ranking heuristic simplistic (translation-only bonus, no field weighting / proximity).
- False negatives for some inflected forms (e.g. morphological endings) and reported example ("faraonit") likely due to token normalization mismatch vs query form.
- No debounce → wasted cycles & UI jitter while user still typing.

### 21.2 Prioritized Action Phases

#### Phase 1 (Done)
1. Full Off-Main Index Build: Combined data parsing and index construction in `search_index_isolate.buildFullIndexFromAssets` executed via `compute`.
2. Debounce Search Input: Implemented 350 ms debounce in `QuranProvider.searchVersesDebounced`.
3. Guard Re-Entrancy: Build guarded by internal completer and state; UI shows progress via `progressStream`.

#### Phase 2 (Performance & UX Hardening)
4. Persistent Cache: Serialize `{versionHash, index, metadata}` to file; fast path load if hash matches asset corpus.
5. Incremental Warmup: Lazy-load surahs in batches (e.g. 10 at a time) while allowing early partial index usage.
6. Field-Weighted Scoring: Introduce per-field weights (translation 1.0, arabic 0.8, transliteration 0.6) with additive bonuses.

#### Phase 3 (Stability & Accuracy)
7. Crash / Tombstone Verification: After Phase 1 deploy, run soak test (continuous random queries 5 min) & monitor `adb logcat -b crash`.
8. Morphological Normalization: Add light suffix stripping for Albanian (e.g., -it, -in, -i, -ve) configurable; apply to both corpus tokens & query tokens.
9. Prefix Minimum Adjustment: Raise minimum stored prefix length from 2 → 3 (configurable) to reduce massive candidate sets for very short queries.

#### Phase 4 (Quality & Advanced Features)
10. Proximity Boost: Track token positions; reward tight windows for multi-token queries.
11. Highlight Matches: Return span metadata for UI emphasis (improves perceived relevance transparency).
12. Adaptive Debounce: Shorten debounce after index warmed (<50 ms) when user pauses long enough (predictive typing).

### 21.3 Implementation Notes

Full off-main build entry point: `lib/presentation/providers/search_index_isolate.dart` → `buildFullIndexFromAssets(Map<String,String>)`.
- Inputs: JSON strings loaded from assets on main isolate (arabic, translation, transliterations).
- Output: `{ 'index': Map<String,List<String>>, 'verses': Map<String,Map> }`.
- The manager (`search_index_manager.dart`) hydrates `_invertedIndex` and `_verseCache`, emits progress, and persists a snapshot.

Debounce pattern:
```dart
Timer? _debounce;
void onQueryChanged(String q) {
   _debounce?.cancel();
   _debounce = Timer(const Duration(milliseconds: 350), () => provider.searchVerses(q));
}
```

Persistence (simplified):
```dart
Future<void> persistIndex(Map<String,List<String>> idx, String version) async {
   final f = File(pathJoin(appDir, 'search_index.json'));
   await f.writeAsString(jsonEncode({'v':version,'i':idx}));
}
```

Morphological light stem (example for Albanian endings):
```dart
String stem(String token){
   for (final suf in ['ve','it','in','i']) {
      if (token.endsWith(suf) && token.length - suf.length >= 3) {
         return token.substring(0, token.length - suf.length);
      }
   }
   return token;
}
```

### 21.4 Success Metrics
| Metric | Target |
|--------|--------|
| First search responsiveness (cold) | < 150 ms UI block (no visible freeze) |
| Warm search latency | < 20 ms median |
| Index rebuild frequency | Only on corpus hash change |
| Memory overhead | < 25 MB incremental vs baseline |
| Crash / ANR occurrences | 0 in 30 min stress test |

### 21.5 Risk Mitigation
- Large Serialized Index: Use gzip compression if size >2MB.
- Version Drift: Include list of reciter/data asset timestamps in version hash.
- Morphological Over-Stemming: Keep suffix list short; add telemetry counter for unmatched queries.

### 21.6 Immediate Next Steps (Actionable Backlog Entries)
1. Refactor `_ensureSearchIndex` → thin gate delegating to new `SearchIndexManager`.
2. Implement combined isolate build (Phase 1.1) + progress callback channel (optional).
3. Introduce debounce layer in search UI widget.
4. Add persistence load/save (feature-flag initially).
5. Add light stemming & adjust prefix minimum behind config.

### 21.7 Tracking & Telemetry (Optional)
Log structured events: `search.build.start`, `search.build.complete {duration_ms,size_bytes}`, `search.query {q,len,latency_ms,candidates}` to assist tuning.

---
End of unified action plan.

## 22. Performance Phase 2 Implementation Plan (Post Phase 1 Commit)

This extends Section 21 with concrete execution details for the next sprint focused on eliminating main-thread jank (40–230 skipped frames observed).

### 22.1 Instrumentation Tasks
- Add lightweight timing helper (Stopwatch wrapper) in a new `performance_metrics.dart` under `core/utils`.
- Hook spans into: index ensure start, per 10-surah batch (when still on main), isolate build start/complete, first query, each query (length + candidate count).
- Use `SchedulerBinding.instance.addTimingsCallback` (debug only) to log long frame (>32ms) occurrences correlated with active phase.

### 22.2 Combined Off-Main Collection & Build
Replace sequential verse collection loop with a single compute function that:
1. Loads/parses all surah JSON slices (pure data) inside isolate.
2. Builds inverted index directly (no intermediate raw list transferred back beyond final index map).
3. Returns: { index, versesMeta (count), versionHash }.
Progress: since streaming progress from compute is non-trivial, show an indeterminate progress or estimated percentage based on elapsed time vs historical median (persist last build duration to preferences).

### 22.3 Progress Throttling
Provide a throttled setter in provider that only notifies when (now - lastNotify) >120ms OR progressDelta >0.02.

### 22.4 Persistence Outline
File: `search_index_v1.json` in app documents.
Schema: {"v": "<hash>", "bMillis": <int>, "count": <int>, "i": { token: ["s:v", ...] }}.
Hash inputs: app build version + size & modified timestamp of translation assets.
Load flow: attempt read+decode+validate (basic sanity: count>6000, i.size>50). If fail, delete and rebuild.
Write strategy: write to temp file then atomic rename to avoid corruption.

### 22.5 Query Micro-Optimizations
- Pre-store lowercase translation in verse cache to avoid toLowerCase per query.
- Short-circuit candidate accumulation if all full tokens already reached a theoretical max (e.g., all tokens found in some verses) — skip extra work.

### 22.6 Optional Cancel Support
Maintain a cancellation token in manager; if user clears search while building, set flag; isolate result ignored if canceled (still allow persistence unless canceled).

### 22.7 Validation & Metrics Targets
After implementation run a scripted stress test (random 2–12 char queries at 150ms interval for 5 minutes) and record:
- Average query latency.
- 95th percentile latency.
- Max frame time spikes (expect elimination of >500ms stalls).

### 22.8 Rollout Plan
Phase behind debug flag `enableSearchIndexPersistence` for first release; collect crash/user feedback; then default to on.

### 22.9 Task Checklist
1. Timing helper & logging.
2. Combined compute build.
3. Throttled progress updates.
4. Persistence load/save.
5. Lowercase translation cache & micro opts.
6. Stress test script (dev-only) + log analysis.
7. (Optional) cancellation.

---
End Section 22.

## 23. Profiling Playbook (Cold Start & Search)

This section captures how to verify performance characteristics locally and what “good” looks like after moving to the prebuilt asset index and removing heavy Hive startup.

Targets (typical mid‑range Android):
- Cold app start to first interactive frame: < 1.2 s visual; no >250 ms jank on main thread
- Search readiness (index available): instant via asset load (< 50 ms to hydrate)
- First query time (warm): < 30 ms median; < 80 ms p95
- Skipped frames in first 2 seconds: ideally < 10 total

How to measure:
1) Enable Performance Overlay (already wired via DevPerfOverlay in debug). Observe frame bars on cold start; look for tall red bars (>16 ms). Count skipped frames in the first 2 seconds.
2) Run Flutter DevTools (Performance tab):
   - Record from app launch to first search.
   - Verify absence of large asset/Hive I/O blocks on main isolate.
   - Confirm SearchIndexManager emits progress immediately to 100% when asset index is present.
3) Micro-benchmark query:
   - In the Search screen, issue 10 representative queries (e.g., “rahmet”, “Fatiha”, “Allahu i mëshirshëm”).
   - Check PerfMetrics logs for highlight build and query durations; median should be < 20 ms.

Before vs After (expected):
- Before: heavy Hive opens (8–9 s cumulative) and many skipped frames (>200) during early init.
- After: no heavy box opens for static data; search index loaded from assets; skipped frames near zero during idle cold start.

Troubleshooting:
- If index progress stays below 1.0 on cold start, ensure assets/data/search_index.json exists in the bundle and pubspec includes assets/data/.
- If query latency spikes, check for debug-mode overhead (hot reload active). Try profile mode.

