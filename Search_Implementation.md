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
2. Provider ensures the inverted index exists.
   - Attempts to load a persisted snapshot (v2) from app documents for a fast path.
   - If not built or partial, starts incremental background build: for each surah, collects raw rows, offloads per‑surah tokenization with `compute(buildInvertedIndex, raw)`, then merges the partial index.
3. When index ready: `_searchIndexQuery(query)` executes.
4. Results (ranked `List<Verse>`) assigned to `_searchResults` and `notifyListeners()` triggers UI update.
5. If index build failed: falls back to `_searchVersesUseCase` (legacy direct search).

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
| Index Build | O(N * T) where N=verses, T=tokens per verse | Incremental; per‑surah tokenization offloaded to isolate; merged on main. |
| Query | O(sum(len(postingList(token)))) + sort(candidates) | Candidate set small vs full corpus due to prefix pruning. |
| Memory | ~ (tokens * avgKeyRefs * pointer) | Controlled by prefix cap & normalization. |

Warm Index Expected Query Latency: ~1–10 ms typical (device-dependent).

---
## 8. Fallback Path
If index build fails (exception or isolate error): `_invertedIndex` may remain partial → provider searches the available subset or falls back to `_searchVersesUseCase`.

---
## 9. Threading & Concurrency
- Heavy build uses `compute` (spawns a short-lived isolate). Raw verse list transferred via serialization.
- No locking required inside index builder isolate.
- Main isolate only mutates `_invertedIndex` post await; race avoided by `_isBuildingIndex` guard.

Edge Case: Multiple simultaneous search calls while build in progress: first call triggers build, others await finishing (no explicit await but they exit early until index ready and later re-trigger search).

---
## 10. Error Handling
- Silent continue on per-surah failure while collecting verses (skips broken surah).
- Entire build wrapped in try/finally; failure resets state & notifies UI to allow fallback.
- Improvements suggested: capture exception details to a diagnostic log buffer.

---
## 11. Caching & Persistence Strategy
- Verse objects cached in `_verseCache` keyed by verseKey for quick retrieval after ranking.
- Index snapshot persistence implemented (v2): JSON `{version, index, verses, createdAt, nextSurah}` stored in app documents; fast‑path load and partial resume.

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
1. Persisted index with versioning (asset hash).
2. Weighted multi-field scoring + optional BM25-lite variant (flag scaffolded).
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
Primary root cause of perceived freezes / potential ANR:
- Heavy synchronous work on the main isolate prior to (and separate from) the isolate index build: sequential loading of all surah verses (1..114) inside `_ensureSearchIndex` before handing raw list to `compute`.
- Immediate, un-debounced execution of `_searchIndexQuery` on each keystroke (high frequency invocations; short queries produce very broad prefix candidate sets early).
- Rebuilding the index every app launch (no persistence) → repeated cold-start cost.

Secondary quality issues:
- Ranking heuristic simplistic (translation-only bonus, no field weighting / proximity).
- False negatives for some inflected forms (e.g. morphological endings) and reported example ("faraonit") likely due to token normalization mismatch vs query form.
- No debounce → wasted cycles & UI jitter while user still typing.

### 21.2 Prioritized Action Phases

#### Phase 1 (Immediate – Blockers)
1. Full Off-Main Index Build: Move BOTH verse collection + index construction into a single top-level `buildFullIndex()` run via `compute`. Only minimal progress signaling on main isolate.
2. Debounce Search Input: 300–400 ms timer reset on `onChanged`; ignore stale queries. Cancel running scoring if a new debounce cycle starts.
3. Guard Re-Entrancy: If index build in progress, queue latest pending query; execute once ready.

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

### 21.3 Implementation Sketches

Full off-main build (pseudo):
```dart
// top_level for compute
Future<IndexPayload> buildFullIndex(_IndexBuildRequest req) async {
   final verses = <RawVerse>[];
   for (final id in req.surahIds) {
      final vs = await loadSurahVersesSync(id); // NOTE: in isolate (pure parsing / map)
      verses.addAll(vs);
   }
   final index = createInvertedIndex(verses);
   final version = computeCorpusHash(verses);
   return IndexPayload(index, version, verses.length);
}
```

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

