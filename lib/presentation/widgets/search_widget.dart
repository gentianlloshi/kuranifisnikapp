import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../providers/bookmark_provider.dart';
import '../providers/quran_provider.dart';
import '../providers/app_state_provider.dart';
import '../../domain/entities/verse.dart';
import '../theme/theme.dart';
import 'sheet_header.dart';

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
      final appState = context.read<AppStateProvider>();
      setState(() {
        _filterArabic = appState.searchInArabic;
        _filterTranslation = appState.searchInTranslation;
  _selectedJuz = appState.searchJuz;
  _filterTransliteration = appState.searchInTransliteration;
      });
      context.read<QuranProvider>().setJuzFilter(_selectedJuz);
      context.read<QuranProvider>().setFieldFilters(
        translation: _filterTranslation,
        arabic: _filterArabic,
  transliteration: _filterTransliteration,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<QuranProvider, AppStateProvider>(
      builder: (context, quranProvider, appState, child) {
        final double p = quranProvider.indexProgress;
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
        return Column(
          children: [
            // Search input and filters
            Container(
              padding: EdgeInsets.all(context.spaceLg),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceElevated(1),
                borderRadius: BorderRadius.circular(context.radiusCard.x),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  // Index progress (shown while building)
                  if (quranProvider.isBuildingIndex && quranProvider.indexProgress < 0.999)
                    Padding(
                      padding: EdgeInsets.only(bottom: context.spaceMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(value: quranProvider.indexProgress <= 0 ? null : quranProvider.indexProgress),
                          SizedBox(height: context.spaceXs),
                          Text(
                            'Indeximi i Kërkimit... ${(quranProvider.indexProgress * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  // Search field
                  TextField(
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
                      suffix: Consumer<QuranProvider>(
                        builder: (ctx, qp, _) => qp.isBuildingIndex
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
                                quranProvider.clearSearch();
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
                            qp.ensureIndexBuild();
                          }
                        }
                      }
                      if (query.trim().isEmpty) {
                        quranProvider.clearSearch();
                        _indexKickIssued = false; // reset when cleared
                      } else {
                        if (!gatingActive) {
                          // Debounce at the widget level to minimize rapid provider churn
                          quranProvider.searchVersesDebounced(query.trim());
                        }
                      }
                    },
                    onSubmitted: (query) {
                      if (!gatingActive) quranProvider.searchVerses(query.trim());
                    },
                  ),
                  SizedBox(height: context.spaceMd),
                  
                  // Filters row (translation selection + Juz + field toggles)
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
                            // (Future) tie translation filter weighting
                            if (_searchController.text.trim().isNotEmpty) {
                              _performSearch(quranProvider, _searchController.text.trim());
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
                            quranProvider.setJuzFilter(v);
                            if (_searchController.text.trim().isNotEmpty) {
                              _performSearch(quranProvider, _searchController.text.trim());
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
                          quranProvider.setFieldFilters(translation: sel);
                          if (_searchController.text.trim().isNotEmpty) {
                            _performSearch(quranProvider, _searchController.text.trim());
                          }
                        },
                      ),
                      FilterChip(
                        label: const Text('Arabisht'),
                        selected: _filterArabic,
                        onSelected: (sel) {
                          setState(() => _filterArabic = sel);
                          context.read<AppStateProvider>().updateSearchFilters(inArabic: sel);
                          quranProvider.setFieldFilters(arabic: sel);
                          if (_searchController.text.trim().isNotEmpty) {
                            _performSearch(quranProvider, _searchController.text.trim());
                          }
                        },
                      ),
                      FilterChip(
                        label: const Text('Transliterim'),
                        selected: _filterTransliteration,
                        onSelected: (sel) {
                          setState(() => _filterTransliteration = sel);
                          context.read<AppStateProvider>().updateTransliterationFilter(sel);
                          quranProvider.setFieldFilters(transliteration: sel);
                          if (_searchController.text.trim().isNotEmpty) {
                            _performSearch(quranProvider, _searchController.text.trim());
                          }
                        },
                      ),
                    ],
                  ),
                  // Future: Advanced filters button triggers bottom sheet
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.tune),
                      label: const Text('Filtrat'),
                      onPressed: () => _showFiltersSheet(context),
                    ),
                  ),
                ],
              ),
            ),
            
            // Search results
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is UserScrollNotification || n is ScrollUpdateNotification) {
                    // inform provider for adaptive throttling
                    quranProvider.notifyUserScrollActivity();
                  }
                  return false;
                },
        child: gatingActive
          ? _GatingNotice(progress: p)
          : _buildSearchResults(quranProvider, appState),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFiltersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return BottomSheetWrapper(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                title: 'Filtrat e Kërkimit',
                leadingIcon: Icons.tune,
                onClose: () => Navigator.of(ctx).maybePop(),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: context.spaceSm,
                  runSpacing: context.spaceXs,
                  children: [
                    FilterChip(
                      label: const Text('Përkthimi'),
                      selected: _filterTranslation,
                      onSelected: (sel) {
                        setState(() => _filterTranslation = sel);
                        context.read<AppStateProvider>().updateSearchFilters(inTranslation: sel);
                        context.read<QuranProvider>().setFieldFilters(translation: sel);
                      },
                    ),
                    FilterChip(
                      label: const Text('Arabisht'),
                      selected: _filterArabic,
                      onSelected: (sel) {
                        setState(() => _filterArabic = sel);
                        context.read<AppStateProvider>().updateSearchFilters(inArabic: sel);
                        context.read<QuranProvider>().setFieldFilters(arabic: sel);
                      },
                    ),
                    FilterChip(
                      label: const Text('Transliterim'),
                      selected: _filterTransliteration,
                      onSelected: (sel) {
                        setState(() => _filterTransliteration = sel);
                        context.read<AppStateProvider>().updateTransliterationFilter(sel);
                        context.read<QuranProvider>().setFieldFilters(transliteration: sel);
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.spaceLg),
            ],
          ),
        );
      },
    );
  }

  void _performSearch(QuranProvider quranProvider, String query) {
    quranProvider.searchVerses(query);
  }

  Widget _buildSearchResults(QuranProvider quranProvider, AppStateProvider appState) {
    // isSearching not implemented; rely on isLoading
    if (quranProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (quranProvider.error != null) {
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
              quranProvider.error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final searchResults = quranProvider.searchResults;
    
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final verse = searchResults[index];
        return SearchResultItem(
          verse: verse,
          searchQuery: _searchController.text,
          settings: appState.settings,
        );
      },
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
    if (mounted) setState(() { _loadingCtx = false; });
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
        ? Color.alphaBlend(scheme.primary.withOpacity(0.06), surface)
        : Color.alphaBlend(scheme.primary.withOpacity(0.03), surface);

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
                  Consumer<BookmarkProvider>(
                    builder: (context, bookmarkProvider, _) {
                      final key = '${verse.surahNumber}:${verse.number}';
                      final isMarked = bookmarkProvider.isBookmarkedSync(key);
                      return IconButton(
                        icon: Icon(isMarked ? Icons.bookmark : Icons.bookmark_border),
                        color: isMarked ? theme.colorScheme.primary : theme.iconTheme.color,
                        tooltip: isMarked ? 'Hiq nga favoritët' : 'Shto në favoritë',
                        onPressed: () async {
                          await bookmarkProvider.toggleBookmark(key);
                          final locale = Localizations.localeOf(context);
                          final strings = Strings(Strings.resolve(locale));
                          context.read<AppStateProvider>().enqueueSnack(
                            isMarked ? strings.t('bookmark_removed') : strings.t('bookmark_added'),
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
                RichText(
                  text: _buildHighlightedText(
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

  final List<InlineSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    
    int start = 0;
    int index = lowerText.indexOf(lowerQuery);
    
    while (index != -1) {
      // Add text before the match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: (widget.settings.fontSizeTranslation - 2).toDouble(),
            height: 1.4,
          ),
        ));
      }
      
      // Add highlighted match (Option A refined: soft yellow background, bold dark text)
      final bool isDark = theme.brightness == Brightness.dark;
      final highlightBg = isDark
          ? theme.colorScheme.tertiary.withOpacity(0.28)
          : theme.colorScheme.tertiaryContainer; // reuse tertiaryContainer as semantic highlight
      final highlightColor = isDark
          ? theme.colorScheme.onTertiaryContainer
          : theme.colorScheme.onTertiaryContainer;
      final matchText = text.substring(index, index + query.length);
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
            matchText,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: (widget.settings.fontSizeTranslation - 2).toDouble(),
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: highlightColor,
            ),
          ),
        ),
      ));
      
      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }
    
    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: (widget.settings.fontSizeTranslation - 2).toDouble(),
          height: 1.4,
        ),
      ));
    }
    
  return TextSpan(children: spans);
  }

  void _navigateToVerse(BuildContext context) {
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
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
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

class _IndexBadge extends StatelessWidget {
  final String label; final Color color; const _IndexBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
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

