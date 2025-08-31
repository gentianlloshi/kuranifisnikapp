import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../providers/bookmark_provider.dart';
import '../providers/quran_provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/note_provider.dart';
import '../../domain/entities/verse.dart';
import '../../domain/entities/note.dart';
import 'package:kurani_fisnik_app/core/metrics/perf_metrics.dart';
import '../theme/theme.dart';
import 'sheet_header.dart';
import '../search/unified_ranking.dart';

// Lightweight snapshots for Selector-based rebuild scoping
class _IndexState {
  final bool building;
  final double progress;
  const _IndexState(this.building, this.progress);
}

class _ResultsSnapshot {
  final List<Verse> results;
  final bool isLoading;
  final String? error;
  const _ResultsSnapshot(this.results, this.isLoading, this.error);
}

class SearchWidget extends StatefulWidget {
  const SearchWidget({super.key});

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  bool _indexKickIssued = false; // prevent repeated ensureIndexBuild bursts per non-empty session
  String _selectedTranslation = 'sq_ahmeti';
  int? _selectedJuz; // 1..30
  bool _filterTranslation = true;
  bool _filterArabic = true;
  bool _filterTransliteration = true; // now persisted

  @override
  void initState() {
    super.initState();
    // Hydrate from persisted settings after first frame to ensure provider ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // avoid setState/context usage after dispose
      final appState = context.read<AppStateProvider>();
      setState(() {
        _filterArabic = appState.searchInArabic;
        _filterTranslation = appState.searchInTranslation;
        _selectedJuz = appState.searchJuz;
        _filterTransliteration = appState.searchInTransliteration;
      });
      if (!mounted) return;
      // Prepare references synchronously, then defer mutations to a microtask (no context used inside async).
      final qpRef = context.read<QuranProvider>();
      final bool bgEnabled = context.read<AppStateProvider>().backgroundIndexingEnabled;
      scheduleMicrotask(() async {
        if (!mounted) return;
        final qp = qpRef;
        qp.setJuzFilter(_selectedJuz);
        qp.setFieldFilters(
          translation: _filterTranslation,
          arabic: _filterArabic,
          transliteration: _filterTransliteration,
        );
        // Ensure the search index is hot-loaded from the prebuilt asset/snapshot
        // so first queries don't run against an empty index.
        await qp.ensureSearchIndexReady();
        // After attempting fast-path load, optionally start incremental build to refresh snapshots
        // only if not yet complete and background indexing is enabled.
        if (bgEnabled && qp.indexProgress < 1.0 && !_indexKickIssued) {
          _indexKickIssued = true; // prevent duplicate kicks in this session
          qp.startIndexBuild();
        }
      });
      // Removed immediate startIndexBuild here to avoid racing with ensureSearchIndexReady()
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search input and filters
        Container(
          padding: EdgeInsets.all(context.spaceLg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceElevated(1),
            borderRadius: BorderRadius.circular(context.radiusCard.x),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              // Index progress (shown while building)
              Selector<QuranProvider, _IndexState>(
                selector: (_, qp) => _IndexState(qp.isBuildingIndex, qp.indexProgress),
                builder: (ctx, s, __) {
                  if (!(s.building) || s.progress >= 0.999) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.only(bottom: context.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: s.progress <= 0 ? null : s.progress),
                        SizedBox(height: context.spaceXs),
                        Text(
                          'Indeximi i Kërkimit... ${(s.progress * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Search field
              Selector<QuranProvider, double>(
                selector: (_, qp) => qp.indexProgress,
                builder: (ctx, p, __) {
                  String readinessLabel;
                  Color readinessColor;
                  if (p >= 1.0) {
                    readinessLabel = 'Index i Plotë'; readinessColor = Colors.green;
                  } else if (p >= 0.8) {
                    readinessLabel = '80%'; readinessColor = Colors.lightGreen;
                  } else if (p >= 0.5) {
                    readinessLabel = '50%'; readinessColor = Colors.orange;
                  } else if (p >= 0.2) {
                    readinessLabel = '20%'; readinessColor = Colors.deepOrange;
                  } else if (p > 0) {
                    readinessLabel = '…'; readinessColor = Colors.grey;
                  } else {
                    readinessLabel = '0%'; readinessColor = Colors.grey;
                  }
                  final bool gatingActive = p < 0.2 && _searchController.text.trim().isNotEmpty;
                  return TextField(
                    controller: _searchController,
                    enabled: !gatingActive,
                    decoration: InputDecoration(
                      hintText: 'Kërko në Kuran...',
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(horizontal: context.spaceMd, vertical: context.spaceSm),
                      prefix: Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: _IndexBadge(label: readinessLabel, color: readinessColor),
                      ),
                      suffix: Selector<QuranProvider, bool>(
                        selector: (_, qp) => qp.isBuildingIndex,
                        builder: (ctx, building, _) => building
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const SizedBox.shrink(),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                context.read<QuranProvider>().clearSearch();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (query) {
                      setState(() {}); // Update clear icon state
                      if (query.isNotEmpty) {
                        if (gatingActive) return; // block queries early readiness
                        final app = context.read<AppStateProvider>();
                        if (app.backgroundIndexingEnabled && !_indexKickIssued) {
                          final qp = context.read<QuranProvider>();
                          if (qp.indexProgress < 1.0) {
                            _indexKickIssued = true;
                            qp.startIndexBuild();
                          }
                        }
                      }
                      if (query.trim().isEmpty) {
                        context.read<QuranProvider>().clearSearch();
                        _indexKickIssued = false; // reset when cleared
                      } else {
                        if (!gatingActive) {
                          // Debounce at the widget level to minimize rapid provider churn
                          context.read<QuranProvider>().searchVersesDebounced(query.trim());
                        }
                      }
                    },
                    onSubmitted: (query) {
                      if (!gatingActive) context.read<QuranProvider>().searchVerses(query.trim());
                    },
                  );
                },
              ),
              SizedBox(height: context.spaceMd),
              // Filters row (translation selection + Juz)
              Row(
                children: [
                  // Translation dropdown
                  Expanded(
                    flex: 2,
                    child: DropdownButton<String>(
                      value: _selectedTranslation,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'sq_ahmeti', child: Text('Ahmeti')),
                        DropdownMenuItem(value: 'sq_mehdiu', child: Text('Mehdiu')),
                        DropdownMenuItem(value: 'sq_nahi', child: Text('Nahi')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedTranslation = v);
                        if (_searchController.text.trim().isNotEmpty) {
                          context.read<QuranProvider>().searchVerses(_searchController.text.trim());
                        }
                      },
                    ),
                  ),
                  SizedBox(width: context.spaceSm),
                  // Juz selector
                  Expanded(
                    child: DropdownButton<int?>(
                      value: _selectedJuz,
                      isExpanded: true,
                      hint: const Text('Juz'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Të gjithë')),
                        ...List.generate(30, (i) => DropdownMenuItem<int?>(value: i + 1, child: Text('Juz ${i + 1}'))),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedJuz = v);
                        context.read<AppStateProvider>().updateSearchFilters(juz: v);
                        final qp = context.read<QuranProvider>();
                        qp.setJuzFilter(v);
                        if (_searchController.text.trim().isNotEmpty) {
                          qp.searchVerses(_searchController.text.trim());
                        }
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spaceSm),
              // Field toggles
              Wrap(
                spacing: context.spaceSm,
                runSpacing: -context.spaceXs,
                children: [
                  FilterChip(
                    label: const Text('Përkthimi'),
                    selected: _filterTranslation,
                    onSelected: (sel) {
                      setState(() => _filterTranslation = sel);
                      context.read<AppStateProvider>().updateSearchFilters(inTranslation: sel);
                      context.read<QuranProvider>().setFieldFilters(translation: sel);
                      if (_searchController.text.trim().isNotEmpty) {
                        context.read<QuranProvider>().searchVerses(_searchController.text.trim());
                      }
                    },
                  ),
                  FilterChip(
                    label: const Text('Arabisht'),
                    selected: _filterArabic,
                    onSelected: (sel) {
                      setState(() => _filterArabic = sel);
                      context.read<AppStateProvider>().updateSearchFilters(inArabic: sel);
                      context.read<QuranProvider>().setFieldFilters(arabic: sel);
                      if (_searchController.text.trim().isNotEmpty) {
                        context.read<QuranProvider>().searchVerses(_searchController.text.trim());
                      }
                    },
                  ),
                  FilterChip(
                    label: const Text('Transliterim'),
                    selected: _filterTransliteration,
                    onSelected: (sel) {
                      setState(() => _filterTransliteration = sel);
                      context.read<AppStateProvider>().updateTransliterationFilter(sel);
                      context.read<QuranProvider>().setFieldFilters(transliteration: sel);
                      if (_searchController.text.trim().isNotEmpty) {
                        context.read<QuranProvider>().searchVerses(_searchController.text.trim());
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        // Search results
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is UserScrollNotification || n is ScrollUpdateNotification) {
                context.read<QuranProvider>().notifyUserScrollActivity();
              }
              return false;
            },
            child: Selector<QuranProvider, _ResultsSnapshot>(
              selector: (_, qp) => _ResultsSnapshot(qp.searchResults, qp.isLoading, qp.error),
              builder: (ctx, snap, __) {
                final p = ctx.select<QuranProvider, double>((qp) => qp.indexProgress);
                final gatingActive = p < 0.2 && _searchController.text.trim().isNotEmpty;
                if (gatingActive) return _GatingNotice(progress: p);
                final settings = ctx.select<AppStateProvider, dynamic>((a) => a.settings);
                return _buildSearchResults(snap.results, snap.isLoading, snap.error, settings);
              },
            ),
          ),
        ),
      ],
    );
  }

  // Filters bottom sheet removed to avoid duplicate controls and reduce vertical space.

  // Show a modal with the full list of note hits
  void _showAllNoteHits(List<Note> notes, String query) {
  if (!mounted) return; // widget might have been disposed (e.g., fast tab switch)
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return BottomSheetWrapper(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHeader(title: 'Të gjitha shënimet e gjetura', leadingIcon: Icons.note),
              SizedBox(
                height: 420,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, i) => _NoteHitCard(note: notes[i], query: query),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: notes.length,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }


  Widget _buildSearchResults(List<Verse> searchResults, bool isLoading, String? error, dynamic settings) {
    // isSearching not implemented; rely on isLoading
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Gabim në kërkim',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

  final noteProvider = context.read<NoteProvider>();
  // Get a larger set for unified ranking and for the bottom-sheet "show all"
  final allNoteHits = _searchController.text.trim().isNotEmpty
    ? noteProvider.quickSearchNotes(_searchController.text.trim(), limit: 50)
    : const <Note>[];
  // Keep a small preview strip (legacy UI) while also computing unified top picks
  final noteHitsPreview = allNoteHits.length > 5 ? allNoteHits.sublist(0, 5) : allNoteHits;
    
    if (_searchController.text.trim().isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Shkruani një fjalë për të kërkuar',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nuk u gjetën rezultate',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

  // Build unified top results (combined verse + note) limited to 5 items
  final unifiedTop = computeUnifiedTop(
      verses: searchResults.length > 50 ? searchResults.sublist(0, 50) : searchResults,
      notes: allNoteHits,
      query: _searchController.text.trim(),
      limit: 5,
    );
    final count = searchResults.length;
    final label = count == 1 ? 'U gjet 1 rezultat' : 'U gjetën $count rezultate';
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Always show the total results label at the very top
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (unifiedTop.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 16),
                  const SizedBox(width: 6),
                  Text('Top rezultate (të kombinuara)', style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final it = unifiedTop[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: it.note != null
                      ? _NoteHitCard(note: it.note!, query: _searchController.text.trim())
                      : SearchResultItem(
                          verse: it.verse!,
                          searchQuery: _searchController.text,
                          settings: settings,
                        ),
                );
              },
              childCount: unifiedTop.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        if (noteHitsPreview.isNotEmpty && unifiedTop.every((it) => it.note == null)) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.note, size: 16),
                  const SizedBox(width: 6),
                  Text('Shënime të gjetura (${allNoteHits.length})', style: Theme.of(context).textTheme.labelMedium),
                  const Spacer(),
                  if (allNoteHits.length > noteHitsPreview.length)
                    TextButton(
                      onPressed: () => _showAllNoteHits(allNoteHits, _searchController.text.trim()),
                      child: const Text('Shfaq të gjitha'),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (_, i) {
                  final n = noteHitsPreview[i];
                  return _NoteHitCard(note: n, query: _searchController.text.trim());
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: noteHitsPreview.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final verse = searchResults[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchResultItem(
                  verse: verse,
                  searchQuery: _searchController.text,
                  settings: settings,
                ),
              );
            },
            childCount: searchResults.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

class SearchResultItem extends StatefulWidget {
  final Verse verse;
  final String searchQuery;
  final dynamic settings; // AppSettings

  const SearchResultItem({
    super.key,
    required this.verse,
    required this.searchQuery,
    required this.settings,
  });

  @override
  State<SearchResultItem> createState() => _SearchResultItemState();
}

class _SearchResultItemState extends State<SearchResultItem> {
  bool _expanded = false;
  Verse? _prev;
  Verse? _next;
  bool _loadingCtx = false;

  Future<void> _loadContext(BuildContext context) async {
    if (_expanded) return; // already loaded or in process
    setState(() { _expanded = true; _loadingCtx = true; });
    try {
      final q = context.read<QuranProvider>();
      // Ensure surah verses loaded (lightweight if cached)
      await q.ensureSurahLoaded(widget.verse.surahNumber);
      final all = q.fullCurrentSurahVerses;
      final idx = all.indexWhere((v) => v.number == widget.verse.number);
      if (idx != -1) {
        if (idx > 0) _prev = all[idx - 1];
        if (idx + 1 < all.length) _next = all[idx + 1];
      }
    } catch (_) {}
  if (!mounted) return;
  setState(() { _loadingCtx = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = widget.settings;
    final searchQuery = widget.searchQuery;
    final verse = widget.verse;

    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final surface = scheme.surfaceElevated(isDark ? 1 : 0);
    final baseBlend = isDark
  ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.06), surface)
  : Color.alphaBlend(scheme.primary.withValues(alpha: 0.03), surface);

    return Card(
      color: baseBlend,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToVerse(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(context.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verse reference
        Row(
                children: [
                  _RefChip('${verse.surahNumber}:${verse.number}'),
                  const Spacer(),
          if (searchQuery.isNotEmpty) _MatchCountBadge(text: verse.textTranslation ?? '', query: searchQuery),
                  Consumer<BookmarkProvider>(
                    builder: (context, bookmarkProvider, _) {
                      final key = '${verse.surahNumber}:${verse.number}';
                      final isMarked = bookmarkProvider.isBookmarkedSync(key);
                      return IconButton(
                        icon: Icon(isMarked ? Icons.bookmark : Icons.bookmark_border),
                        color: isMarked ? theme.colorScheme.primary : theme.iconTheme.color,
                        tooltip: isMarked ? 'Hiq nga favoritët' : 'Shto në favoritë',
                        onPressed: () async {
                          final wasMarked = isMarked;
                          await bookmarkProvider.toggleBookmark(key);
                          if (!context.mounted) return;
                          final locale = Localizations.localeOf(context);
                          final strings = Strings(Strings.resolve(locale));
                          if (!context.mounted) return;
                          context.read<AppStateProvider>().enqueueSnack(
                            wasMarked ? strings.t('bookmark_removed') : strings.t('bookmark_added'),
                            duration: const Duration(seconds: 2),
                          );
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(_expanded ? Icons.unfold_less : Icons.unfold_more),
                    tooltip: _expanded ? 'Mbyll kontekstin' : 'Kontekst',
                    onPressed: () => _loadContext(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Arabic text (if enabled)
      if (settings.showArabic)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
        verse.textArabic,
                    style: theme.textTheme.bodyArabic.copyWith(
                      fontSize: (settings.fontSizeArabic - 4).toDouble(),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              
              // Translation with highlighting
              if (settings.showTranslation && verse.textTranslation != null)
                _ProfilingRichText(
                  buildSpan: () => _buildHighlightedText(
                    verse.textTranslation!,
                    searchQuery,
                    theme,
                  ),
                ),
              if (_expanded)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _loadingCtx
                      ? Padding(
                          key: const ValueKey('loading'),
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text('Duke marrë kontekstin...', style: theme.textTheme.bodySmall),
                            ],
                          ),
                        )
                      : Column(
                          key: const ValueKey('ctx'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_prev != null) ...[
                              const SizedBox(height: 12),
                              Opacity(
                                opacity: 0.75,
                                child: Text(
                                  '${_prev!.number}. ${_prev!.textTranslation ?? ''}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                            if (_next != null) ...[
                              const SizedBox(height: 8),
                              Opacity(
                                opacity: 0.75,
                                child: Text(
                                  '${_next!.number}. ${_next!.textTranslation ?? ''}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _buildHighlightedText(String text, String query, ThemeData theme) {
    if (query.isEmpty) {
      return TextSpan(
        text: text,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: (widget.settings.fontSizeTranslation - 2).toDouble(),
          height: 1.4,
        ),
      );
    }
    // Diacritic-insensitive, token-based partial highlighting
    final bool isDark = theme.brightness == Brightness.dark;
    final highlightBg = isDark
  ? theme.colorScheme.tertiary.withValues(alpha: 0.28)
        : theme.colorScheme.tertiaryContainer;
    final highlightColor = theme.colorScheme.onTertiaryContainer;

    // Normalization helper for Albanian and common Latin accents
    String norm(String s) {
      s = s.toLowerCase();
      s = s.replaceAll('ç', 'c').replaceAll('ë', 'e');
      const mapping = {
        'á':'a','à':'a','ä':'a','â':'a','ã':'a','å':'a','ā':'a','ă':'a','ą':'a',
        'é':'e','è':'e','ë':'e','ê':'e','ě':'e','ē':'e','ę':'e','ė':'e',
        'í':'i','ì':'i','ï':'i','î':'i','ī':'i','į':'i','ı':'i',
        'ó':'o','ò':'o','ö':'o','ô':'o','õ':'o','ø':'o','ō':'o','ő':'o',
        'ú':'u','ù':'u','ü':'u','û':'u','ū':'u','ů':'u','ű':'u','ť':'t','š':'s','ž':'z','ñ':'n'
      };
      final sb = StringBuffer();
      for (final ch in s.split('')) {
        sb.write(mapping[ch] ?? ch);
      }
      return sb.toString();
    }

    final baseStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: (widget.settings.fontSizeTranslation - 2).toDouble(),
      height: 1.4,
    );

    final textNorm = norm(text);
    // Split query into tokens, filter short empties
    final queryTokens = query
        .split(RegExp(r"[^\p{L}\p{N}]+", unicode: true))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .map(norm)
        .toSet();
    if (queryTokens.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    // Build match intervals merging overlaps across tokens
    final intervals = <List<int>>[]; // [start,end)
    for (final tok in queryTokens) {
      int start = 0;
      while (true) {
        final idx = textNorm.indexOf(tok, start);
        if (idx == -1) break;
        intervals.add([idx, idx + tok.length]);
        start = idx + tok.length;
      }
    }
    if (intervals.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    intervals.sort((a, b) => a[0].compareTo(b[0]));
    // Merge overlaps
    final merged = <List<int>>[];
    for (final iv in intervals) {
      if (merged.isEmpty || iv[0] > merged.last[1]) {
        merged.add([iv[0], iv[1]]);
      } else {
        if (iv[1] > merged.last[1]) merged.last[1] = iv[1];
      }
    }

    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final iv in merged) {
      final a = iv[0], b = iv[1];
      if (a > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, a), style: baseStyle));
      }
      final original = text.substring(a, b);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            color: highlightBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            original,
            style: baseStyle?.copyWith(
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: highlightColor,
            ),
          ),
        ),
      ));
      cursor = b;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return TextSpan(children: spans);
  }

  void _navigateToVerse(BuildContext context) {
  if (!context.mounted) return;
  final q = context.read<QuranProvider>();
  q.openSurahAtVerse(widget.verse.surahNumber, widget.verse.number);
    // If there's a higher-level tab controller, rely on parent logic (avoid crashing if none)
    try {
      final controller = DefaultTabController.maybeOf(context);
      controller?.animateTo(0); // ensure we are on reading tab (adjust index if needed)
    } catch (_) {/* ignore */}
  }
}

class _RefChip extends StatelessWidget {
  final String label;
  const _RefChip(this.label);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0,2),
          )
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MatchCountBadge extends StatelessWidget {
  final String text;
  final String query;
  const _MatchCountBadge({required this.text, required this.query});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = _countMatches(text, query);
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$count', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.w700)),
    );
  }

  static int _countMatches(String text, String query) {
    String norm(String s) {
      s = s.toLowerCase();
      s = s.replaceAll('ç', 'c').replaceAll('ë', 'e');
      const mapping = {
        'á':'a','à':'a','ä':'a','â':'a','ã':'a','å':'a','ā':'a','ă':'a','ą':'a',
        'é':'e','è':'e','ë':'e','ê':'e','ě':'e','ē':'e','ę':'e','ė':'e',
        'í':'i','ì':'i','ï':'i','î':'i','ī':'i','į':'i','ı':'i',
        'ó':'o','ò':'o','ö':'o','ô':'o','õ':'o','ø':'o','ō':'o','ő':'o',
        'ú':'u','ù':'u','ü':'u','û':'u','ū':'u','ů':'u','ű':'u','ť':'t','š':'s','ž':'z','ñ':'n'
      };
      final sb = StringBuffer();
      for (final ch in s.split('')) { sb.write(mapping[ch] ?? ch); }
      return sb.toString();
    }
    final tn = norm(text);
    final tokens = query
        .split(RegExp(r"[^\p{L}\p{N}]+", unicode: true))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .map(norm)
        .toSet();
    if (tokens.isEmpty) return 0;
    int total = 0;
    for (final tok in tokens) {
      int start = 0;
      while (true) {
        final i = tn.indexOf(tok, start);
        if (i == -1) break;
        total++;
        start = i + tok.length;
      }
    }
    return total;
  }
}

class _IndexBadge extends StatelessWidget {
  final String label; final Color color; const _IndexBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
  color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
  border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _GatingNotice extends StatelessWidget {
  final double progress; const _GatingNotice({required this.progress});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_bottom, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Indeksi po ndërtohet (${(progress*100).toStringAsFixed(0)}%).', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Kërkimi do të aktivizohet pas 20% për rezultate të kuptueshme.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            LinearProgressIndicator(value: progress <= 0 ? null : progress),
          ],
        ),
      ),
    );
  }
}

class _ProfilingRichText extends StatelessWidget {
  final TextSpan Function() buildSpan;
  const _ProfilingRichText({required this.buildSpan});
  @override
  Widget build(BuildContext context) {
    final sw = Stopwatch()..start();
    final span = buildSpan();
    sw.stop();
    PerfMetrics.instance.recordHighlightDuration(sw.elapsed);
    return Semantics(
      label: 'Tekst me theksim të rezultateve',
      child: RichText(text: span),
    );
  }
}

class _NoteHitCard extends StatelessWidget {
  final Note note;
  final String query;
  const _NoteHitCard({required this.note, required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = note.verseKey.split(':');
    final ref = parts.length == 2 ? '${parts[0]}:${parts[1]}' : note.verseKey;
    return InkWell(
      onTap: () {
        final s = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 1;
        final v = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  if (!context.mounted) return;
  context.read<QuranProvider>().openSurahAtVerse(s, v);
        final controller = DefaultTabController.maybeOf(context);
        controller?.animateTo(0);
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceElevated(1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Ajeti: $ref',
                  style: theme.textTheme.labelSmall,
                ),
                const Spacer(),
                Text(
                  _formatDate(note.updatedAt),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _HighlightedSnippet(text: note.content, query: query),
            ),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 26,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) => Chip(label: Text(note.tags[i]), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemCount: note.tags.length,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _HighlightedSnippet extends StatelessWidget {
  final String text;
  final String query;
  const _HighlightedSnippet({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (query.isEmpty) return Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium);
    String norm(String s) {
      s = s.toLowerCase();
      s = s.replaceAll('ç', 'c').replaceAll('ë', 'e');
      const mapping = {
        'á':'a','à':'a','ä':'a','â':'a','ã':'a','å':'a','ā':'a','ă':'a','ą':'a',
        'é':'e','è':'e','ë':'e','ê':'e','ě':'e','ē':'e','ę':'e','ė':'e',
        'í':'i','ì':'i','ï':'i','î':'i','ī':'i','į':'i','ı':'i',
        'ó':'o','ò':'o','ö':'o','ô':'o','õ':'o','ø':'o','ō':'o','ő':'o',
        'ú':'u','ù':'u','ü':'u','û':'u','ū':'u','ů':'u','ű':'u','ť':'t','š':'s','ž':'z','ñ':'n'
      };
      final sb = StringBuffer();
      for (final ch in s.split('')) { sb.write(mapping[ch] ?? ch); }
      return sb.toString();
    }
    final base = theme.textTheme.bodyMedium;
    final tn = norm(text);
    final qTokens = query
        .split(RegExp(r"[^\p{L}\p{N}]+", unicode: true))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .map(norm)
        .toSet();
    final intervals = <List<int>>[];
    for (final tok in qTokens) {
      int start = 0;
      while (true) {
        final i = tn.indexOf(tok, start);
        if (i == -1) break;
        intervals.add([i, i + tok.length]);
        start = i + tok.length;
      }
    }
    if (intervals.isEmpty) return Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: base);
    intervals.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<int>>[];
    for (final iv in intervals) {
      if (merged.isEmpty || iv[0] > merged.last[1]) { merged.add([iv[0], iv[1]]); }
      else if (iv[1] > merged.last[1]) { merged.last[1] = iv[1]; }
    }
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final iv in merged) {
      final a = iv[0], b = iv[1];
      if (a > cursor) spans.add(TextSpan(text: text.substring(cursor, a), style: base));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(text.substring(a, b), style: base?.copyWith(fontWeight: FontWeight.w700, height: 1.2, color: theme.colorScheme.onSecondaryContainer)),
        ),
      ));
      cursor = b;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor), style: base));
    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}

