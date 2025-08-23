import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/quran_provider.dart';
import '../theme/theme.dart';
import '../providers/note_provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/word_by_word_provider.dart';
import '../providers/memorization_provider.dart';
import '../providers/selection_service.dart';
import '../providers/reading_progress_provider.dart';
import '../widgets/verse_notes_indicator.dart';
import '../widgets/surah_list_widget.dart';
import '../../domain/entities/verse.dart';
import '../../domain/entities/word_by_word.dart';
import '../../core/services/share_service.dart';
import '../widgets/note_editor_dialog.dart';
import 'verse_action_registry.dart';
class QuranViewWidget extends StatefulWidget {
  const QuranViewWidget({super.key});

  @override
  State<QuranViewWidget> createState() => _QuranViewWidgetState();
}

class _QuranViewWidgetState extends State<QuranViewWidget> {
  final ScrollController _scrollController = ScrollController();
  String? _lastPlayingVerseKey;
  final Map<String, GlobalKey> _verseKeys = {}; // verseKey -> GlobalKey
  final Map<String, double> _verseHeights = {}; // verseKey -> measured height
  final Map<String, double> _cumulativeOffsets = {}; // verseKey -> cumulative offset before this verse
  bool _layoutReady = false;
  DateTime _lastAutoScroll = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _autoScrollThrottle = Duration(milliseconds: 350);
  DateTime _lastUserScroll = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _manualScrollSuppressionWindow = Duration(seconds: 5); // pause auto-scroll 5s after user interacts (spec)
  // Accurate progress tracking cadence
  DateTime _lastAccurateProgressCalc = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _progressCalcThrottle = Duration(milliseconds: 120);
  static const bool kUseNewVerseHighlight = true; // feature flag for new highlight spec
  final TextEditingController _jumpSurahCtrl = TextEditingController();
  final TextEditingController _jumpVerseCtrl = TextEditingController();
  // Selection mode state
  bool get _selectionMode => context.read<SelectionService>().mode == SelectionMode.verses;
  // Persist arrival highlight range briefly so it survives rebuilds
  int? _arrivalRangeStart;
  int? _arrivalRangeEnd;
  Timer? _arrivalRangeClearTimer;
  int _pendingScrollRetries = 0;
  static const int _maxPendingScrollRetries = 8;

  // Centralized highlight decoration builder (verse-level)
  BoxDecoration _buildVerseHighlightDecoration(BuildContext context, {required bool isActive}) {
    final scheme = Theme.of(context).colorScheme;
    if (!isActive) return const BoxDecoration();
    final bool dark = scheme.brightness == Brightness.dark;
    // Layer base elevated surface then blend a primary tint for active verse.
    final baseSurface = scheme.surfaceElevated(2);
    final tint = dark ? scheme.primary.withOpacity(0.18) : scheme.primary.withOpacity(0.10);
    final blended = Color.alphaBlend(tint, baseSurface);
    final accent = dark ? scheme.primaryContainer : scheme.primary;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: blended,
      border: Border(left: BorderSide(color: accent.withOpacity(dark ? 0.9 : 1.0), width: 3)),
      boxShadow: dark
          ? [
              BoxShadow(
                color: scheme.primary.withOpacity(0.25),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ]
          : [
              BoxShadow(
                color: scheme.primary.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
    );
  }

  // Secondary decoration for soft range highlight (lighter than active verse)
  BoxDecoration _buildRangeHighlightDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool dark = scheme.brightness == Brightness.dark;
    final baseSurface = scheme.surfaceElevated(1);
    final tint = dark ? scheme.tertiary.withOpacity(0.14) : scheme.tertiary.withOpacity(0.10);
    final blended = Color.alphaBlend(tint, baseSurface);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: blended,
      border: Border(left: BorderSide(color: scheme.tertiary.withOpacity(dark ? 0.7 : 0.9), width: 2)),
    );
  }

  void _openAddNote(BuildContext context, Verse verse) {
    showDialog(
      context: context,
      builder: (ctx) => NoteEditorDialog(
        verseKey: verse.verseKey,
        onSave: (note) {
          final provider = context.read<NoteProvider>();
          if (note.id.isEmpty) {
            provider.addNote(note.verseKey, note.content, tags: note.tags);
          } else {
            provider.updateNote(note);
          }
        },
      ),
    );
  }

  void _showVerseOptions(BuildContext context, Verse verse) {
    // Delegate to VerseWidget's modal for consistency
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => BottomSheetWrapper(
              child: VerseActionsSheet(
                verse: verse,
              ),
      ),
    );
  }

  BoxDecoration _mergeSelectionDecoration(BuildContext context, {required BoxDecoration base, required bool isSelected}) {
    if (!isSelected) return base;
    final scheme = Theme.of(context).colorScheme;
    // Layer selection indication (adaptive overlay)
    final bool dark = scheme.brightness == Brightness.dark;
    final selectionColor = (dark ? scheme.primary.withOpacity(0.22) : scheme.primaryContainer.withOpacity(0.35));
    return base.copyWith(
      color: base.color == null ? selectionColor : Color.alphaBlend(selectionColor, base.color!),
      border: base.border ?? Border.all(color: scheme.primary.withOpacity(dark ? 0.5 : 0.6), width: 2),
    );
  }

  void _toggleSelection(String verseKey) {
    final sel = context.read<SelectionService>();
    if (sel.mode != SelectionMode.verses) {
      sel.start(SelectionMode.verses);
    }
    sel.toggle(verseKey);
    setState(() {});
  }

  void _clearSelection() { final sel = context.read<SelectionService>(); sel.clear(); setState(() {}); }

  Future<void> _bookmarkSelected() async {
    final bookmarkProvider = context.read<BookmarkProvider>();
  final sel = context.read<SelectionService>();
  for (final key in sel.selected) {
      await bookmarkProvider.toggleBookmark(key);
    }
    if (mounted) {
      context.read<AppStateProvider>().enqueueSnack('U aplikuan shënjimet për ${sel.selected.length} ajete');
    }
    _clearSelection();
  }

  void _shareSelected() {
  final sel = context.read<SelectionService>();
  context.read<AppStateProvider>().enqueueSnack('Do të ndahet ${sel.selected.length} ajete (së shpejti)');
  }

  // Removed word style builder (moved into VerseWidget for direct reuse)

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Register default verse actions once (idempotent)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reg = context.read<VerseActionRegistry?>();
      if (reg != null && reg.actionsFor != null) { // existence guard
        if (reg.actionsFor(context, const Verse(surahId: 1, verseNumber: 1, arabicText: '', translation: null, transliteration: null, verseKey: '1:1')).isEmpty) {
          reg.registerAll(buildDefaultVerseActions());
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
  _jumpSurahCtrl.dispose();
  _jumpVerseCtrl.dispose();
  _arrivalRangeClearTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // User has scrolled to the end, load more verses
          Provider.of<QuranProvider>(context, listen: false).loadMoreVerses();
    }
    // Mark user scroll interaction (ignore if programmatic overscroll not triggered by user - heuristic: userScrollDirection not idle)
    final dir = _scrollController.position.userScrollDirection;
    if (dir != ScrollDirection.idle) {
      _lastUserScroll = DateTime.now();
      _updateAccurateProgress();
    }
  }

  void _updateAccurateProgress() {
    final now = DateTime.now();
    if (now.difference(_lastAccurateProgressCalc) < _progressCalcThrottle) return; // throttle
    _lastAccurateProgressCalc = now;
    if (!_scrollController.hasClients) return;
    final q = Provider.of<QuranProvider>(context, listen: false);
    if (q.currentSurahId == null || q.currentVerses.isEmpty) return;
    final verses = q.currentVerses;
    final viewportTop = _scrollController.offset;
    final viewportBottom = viewportTop + _scrollController.position.viewportDimension;
    double bestVisible = 0;
    Verse? bestVerse;
    // Evaluate visible fraction using RenderBox geometry of each verse card if available.
    for (final v in verses) {
      final key = _verseKeys[v.verseKey];
      final ctx = key?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox) continue;
      final position = box.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
      // position.dy is global relative to screen; convert to scroll space by adding scroll offset baseline (approx by using scroll metrics pixels relative to first paint).
      final topGlobal = position.dy + _scrollController.offset; // approximate mapping back into scroll coordinates
      final height = box.size.height;
      final bottomGlobal = topGlobal + height;
      final overlapTop = math.max(viewportTop, topGlobal);
      final overlapBottom = math.min(viewportBottom, bottomGlobal);
      final visible = math.max(0, overlapBottom - overlapTop);
      if (visible <= 0) continue;
      final fraction = visible / height;
      if (fraction > bestVisible) {
        bestVisible = fraction;
        bestVerse = v;
      }
    }
    if (bestVerse != null) {
      try {
        Provider.of<ReadingProgressProvider>(context, listen: false)
            .updateProgress(bestVerse.surahNumber, bestVerse.number);
      } catch (_) {}
    }
  }

  double _computeScrollOffsetForIndex(int targetIndex, List<Verse> verses) {
    if (targetIndex <= 0) return 0;
    final prevVerseKey = verses[targetIndex - 1].verseKey;
    final cached = _cumulativeOffsets[prevVerseKey];
    if (cached != null) return cached;
    // fallback compute once then cache along iteration
    double running = 0;
    for (int i = 0; i < verses.length; i++) {
      final v = verses[i];
      final h = _verseHeights[v.verseKey] ?? 220;
      if (i == 0) {
        _cumulativeOffsets[v.verseKey] = h + 16; // after first card
      } else {
        final prevKey = verses[i - 1].verseKey;
        _cumulativeOffsets[v.verseKey] = (_cumulativeOffsets[prevKey] ?? running) + h + 16;
      }
      running = _cumulativeOffsets[v.verseKey]!;
      if (i == targetIndex - 1) return running;
    }
    return running;
  }

  void _scheduleMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bool updated = false;
      _verseKeys.forEach((vk, key) {
        final ctx = key.currentContext;
        if (ctx != null) {
          final box = ctx.findRenderObject();
          if (box is RenderBox) {
            final h = box.size.height;
            if (h > 0 && (_verseHeights[vk] == null || (_verseHeights[vk]! - h).abs() > 1)) {
              _verseHeights[vk] = h;
              updated = true;
            }
          }
        }
      });
      if (updated && mounted) {
  _cumulativeOffsets.clear(); // recompute on demand next time
  setState(() {}); // trigger potential more accurate future scrolls
      }
    });
  }

  bool _isVerseRoughlyVisible(int index, List<Verse> verses) {
    if (!_scrollController.hasClients) return false;
    final scrollOffset = _scrollController.offset;
    final viewport = _scrollController.position.viewportDimension;
    // Approximate position using measured heights if available, else fallback fixed height
    double top = 0;
    for (int i = 0; i < index; i++) {
      final v = verses[i];
      top += (_verseHeights[v.verseKey] ?? 220) + 16; // card + spacing
      if (top > scrollOffset + viewport) break; // early exit
    }
    final v = verses[index];
    final height = (_verseHeights[v.verseKey] ?? 220) + 16;
    final bottom = top + height;
    return (bottom >= scrollOffset) && (top <= scrollOffset + viewport * 0.95);
  }

  Future<void> _autoScrollToVerse(String verseKey, List<Verse> verses) async {
    final appState = context.read<AppStateProvider>();
    if (!appState.autoScrollEnabled) return;
    final now = DateTime.now();
    if (now.difference(_lastAutoScroll) < _autoScrollThrottle) return; // throttle
  // Suppress if user manually scrolled recently to respect user control
  if (now.difference(_lastUserScroll) < _manualScrollSuppressionWindow) return;
    final index = verses.indexWhere((v) => v.verseKey == verseKey);
    if (index < 0) return;
    if (_isVerseRoughlyVisible(index, verses)) return; // already visible enough
    _lastAutoScroll = now;
    await Future.delayed(const Duration(milliseconds: 10)); // allow build/layout settle
    if (!mounted) return;
    final key = _verseKeys[verseKey];
    final ctx = key?.currentContext;
    if (ctx != null) {
      try {
  double alignment = 0.5; // center by default per spec
  if (appState.adaptiveAutoScroll) {
          // Use measured height to adjust alignment: taller verses align nearer top
          final h = _verseHeights[verseKey] ?? 260;
          if (h > 600) {
            alignment = 0.02;
          } else if (h > 400) {
            alignment = 0.05;
          } else if (h > 300) {
            alignment = 0.08;
          }
        }
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 420),
          alignment: alignment,
          curve: Curves.easeInOutCubic,
        );
        return;
      } catch (_) {/* fallback below */}
    }
    // Fallback approximate scroll
    if (_scrollController.hasClients) {
      final raw = _computeScrollOffsetForIndex(index, verses).toDouble();
      final maxExtent = _scrollController.position.maxScrollExtent;
      final targetOffset = math.min(math.max(0.0, raw), maxExtent);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<QuranProvider, AppStateProvider, BookmarkProvider>(
      builder: (context, quranProvider, appState, bookmarkProvider, child) {
  // Handle pending scroll target (e.g., after navigating from search/bookmark)
  int? pendingTarget = quranProvider.pendingScrollTarget;
  // Handle pending arrival highlight range
  final pendingRange = quranProvider.consumePendingHighlightRange();
        if (pendingRange != null) {
          // Persist in local state and clear after a short delay
          _arrivalRangeStart = pendingRange[0];
          _arrivalRangeEnd = pendingRange[1];
          _arrivalRangeClearTimer?.cancel();
          _arrivalRangeClearTimer = Timer(const Duration(seconds: 6), () {
            if (!mounted) return;
            setState(() {
              _arrivalRangeStart = null;
              _arrivalRangeEnd = null;
            });
          });
        }
        if (pendingTarget != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final verses = quranProvider.currentVerses;
            final idx = verses.indexWhere((v) => v.number == pendingTarget);
            if (idx >= 0 && _scrollController.hasClients) {
              // Prefer precise ensureVisible using the GlobalKey if available
              final key = _verseKeys['${quranProvider.currentSurah!.number}:$pendingTarget'];
              final ctx = key?.currentContext;
              if (ctx != null) {
                try {
                  await Scrollable.ensureVisible(
                    ctx,
                    duration: const Duration(milliseconds: 480),
                    alignment: 0.08,
                    curve: Curves.easeInOutCubic,
                  );
                  quranProvider.consumePendingScrollTarget();
                  _pendingScrollRetries = 0;
                  return;
                } catch (_) {/* fallback below */}
              }
              // Fallback to computed offset if key context not ready
              final position = _computeScrollOffsetForIndex(idx, verses).clamp(0.0, _scrollController.position.maxScrollExtent);
              _scrollController.animateTo(
                position as double,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
              );
              quranProvider.consumePendingScrollTarget();
              _pendingScrollRetries = 0;
            } else {
              // Not yet visible in paged list; retry bounded times
              if (_pendingScrollRetries < _maxPendingScrollRetries) {
                _pendingScrollRetries++;
                setState(() {});
              } else {
                _pendingScrollRetries = 0;
              }
            }
          });
        }
        // Auto-scroll when current playing verse changes
        final currentPlayingKey = context.watch<AudioProvider>().currentTrack?.verseKey;
        if (currentPlayingKey != null && currentPlayingKey != _lastPlayingVerseKey) {
          _lastPlayingVerseKey = currentPlayingKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _autoScrollToVerse(currentPlayingKey, quranProvider.currentVerses);
          });
        }
  if (quranProvider.currentSurah == null) {
          // Show list of surahs directly so user can choose
          return const SurahListWidget();
        }

        final surah = quranProvider.currentSurah!;
        final verses = quranProvider.currentVerses;
        // Build a quick lookup for pending range
  final int? rangeStart = _arrivalRangeStart;
  final int? rangeEnd = _arrivalRangeEnd;
        // Load real word-by-word + timestamps if feature enabled
        if (context.read<AppStateProvider>().showWordByWord) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final wbw = context.read<WordByWordProvider>();
            // Fire-and-forget; provider vetë publikon state
            // ignore: discarded_futures
            wbw.ensureLoaded(surah.number);
          });
        }

  // Schedule measurement after this frame to record verse heights
  _scheduleMeasurement();

  // Compute values that shouldn't cause every row to subscribe independently
  final playingKey = context.select<AudioProvider, String?>((a) => a.currentTrack?.verseKey);

  return Column(
          children: [
            if (_selectionMode)
              _SelectionBar(
                count: context.watch<SelectionService>().selected.length,
                onCancel: _clearSelection,
                onBookmark: _bookmarkSelected,
                onShare: _shareSelected,
              ),
            // Surah header (reconstructed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Theme.of(context).colorScheme.surfaceElevated(1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    children: [
                      Text(
                        '${surah.nameTranslation} • ${surah.nameTransliteration}',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${surah.revelation} • ${surah.versesCount} ajete',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Verses list
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is UserScrollNotification || (notification is ScrollUpdateNotification && notification.dragDetails != null)) {
                    // Mark manual user interaction to pause auto-scroll window
                    _lastUserScroll = DateTime.now();
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  padding: EdgeInsets.only(
                    left: context.spaceLg,
                    right: context.spaceLg,
                    top: context.spaceLg,
                    bottom: context.spaceLg + 80, // space for chaining banner
                  ),
                  itemCount: verses.length + 1, // extra sentinel row for loader / next surah card
                  itemBuilder: (context, index) {
                    if (index == verses.length) {
                      // Sentinel row
                      if (quranProvider.hasMoreVerses) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: quranProvider.isLoading
                                ? const CircularProgressIndicator()
                                : ElevatedButton.icon(
                                    onPressed: () => quranProvider.loadMoreVerses(),
                                    icon: const Icon(Icons.unfold_more),
                                    label: const Text('Ngarko më shumë'),
                                  ),
                          ),
                        );
                      } else {
                        // End of surah; offer next surah chaining if not last.
                        final current = quranProvider.currentSurah;
                        if (current != null && current.number < 114) {
                          final nextNum = current.number + 1;
                          final prefetched = quranProvider.hasPrefetched(nextNum);
                          return Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Card(
                              color: Theme.of(context).colorScheme.surfaceElevated(1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(Icons.play_circle_outline, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        prefetched
                                            ? 'Sura $nextNum gati. Vazhdo leximin?'
                                            : 'Fundi i sures. Vazhdo me Sura $nextNum',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await quranProvider.navigateToSurah(nextNum);
                                        if (mounted) {
                                          _scrollController.jumpTo(0);
                                        }
                                      },
                                      child: const Text('Vazhdo'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox(height: 24);
                      }
                    }
                  final verse = verses[index];
                  final key = _verseKeys.putIfAbsent(verse.verseKey, () => GlobalKey());
                      return FutureBuilder<bool>(
                        future: bookmarkProvider.isBookmarked(verse.verseKey),
                        builder: (context, snapshot) {
                          final isBm = snapshot.data ?? false;
                          // Use fine-grained selects to avoid rebuilding all items on provider changes
                          final isCurrent = playingKey == verse.verseKey;
                          var wbw = context.select<WordByWordProvider, WordByWordVerse?>((p) => p.getVerseWordData(verse.number));
                          if (wbw == null) {
                            final hasError = context.select<WordByWordProvider, bool>((p) => p.error != null);
                            if (hasError) {
                              wbw = context.read<WordByWordProvider>().buildNaiveFromVerse(verse);
                            }
                          }
              final isSelected = context.watch<SelectionService>().selected.contains(verse.verseKey);
              // Arrival range soft highlight (verse number within range)
              final inArrivalRange = rangeStart != null && rangeEnd != null && verse.number >= rangeStart! && verse.number <= rangeEnd!;
              final baseDecoration = isCurrent
                ? _buildVerseHighlightDecoration(context, isActive: true)
                : (inArrivalRange ? _buildRangeHighlightDecoration(context) : const BoxDecoration());
              final decoration = _mergeSelectionDecoration(context, base: baseDecoration, isSelected: isSelected);
                          final reduceMotion = appState.reduceMotion;
                          final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 300);
                          return RepaintBoundary(
                            child: GestureDetector(
                            key: key,
                            onLongPress: () => _toggleSelection(verse.verseKey),
                            onTap: () {
                              if (_selectionMode) {
                                _toggleSelection(verse.verseKey);
                              } else {
                                // default tap: open options bottom sheet
                                _showVerseOptions(context, verse);
                              }
                            },
                            child: AnimatedContainer(
                              duration: duration,
                              curve: Curves.easeInOut,
                              decoration: decoration,
                              child: VerseWidget(
                                verse: verse,
                                settings: appState.settings,
                                isBookmarked: isBm,
                                onBookmarkToggle: () => bookmarkProvider.toggleBookmark(verse.verseKey),
                                currentPlayingVerseKey: playingKey,
                                wordByWordData: wbw,
                              ),
                            ),
                            ),
                          );
                        }
                      );
                  },
                ),
              ),
            ),
          ],
  );
      },
    );
  }
}

class VerseWidget extends StatelessWidget {
  final Verse verse;
  final dynamic settings; // AppSettings
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final String? currentPlayingVerseKey;
  final WordByWordVerse? wordByWordData;

  const VerseWidget({
    super.key,
    required this.verse,
    required this.settings,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    this.currentPlayingVerseKey,
    this.wordByWordData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isCurrentVersePlaying = currentPlayingVerseKey == verse.verseKey;
    TextStyle _buildWordArabicStyle(BuildContext context, {required bool isHighlighted, required double baseSize}) {
      final t = Theme.of(context).textTheme.bodyArabic.copyWith(fontSize: baseSize, height: 1.65);
      if (!isHighlighted) return t;
      return t.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold);
    }
    
    return Padding(
      padding: EdgeInsets.only(bottom: context.spaceMd),
      child: Material(
        color: isCurrentVersePlaying
            ? theme.colorScheme.surfaceElevated(2)
            : theme.colorScheme.surfaceElevated(1),
        borderRadius: BorderRadius.circular(10),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.spaceMd, context.spaceMd, context.spaceMd, context.spaceSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: ShapeDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.07),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        verse.number.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary.withOpacity(0.9),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Wrap(
                          spacing: context.spaceXs,
                          runSpacing: -context.spaceXs,
                          alignment: WrapAlignment.end,
                          children: [
                            IconButton(
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(minWidth: 36, minHeight: 32 + context.spaceXs),
                              icon: Icon(
                                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                color: isBookmarked ? theme.colorScheme.primary : null,
                                size: 20,
                              ),
                              tooltip: isBookmarked ? 'Hiq shenjën' : 'Shëno',
                              onPressed: onBookmarkToggle,
                            ),
              Consumer<WordByWordProvider>(
                              builder: (context, wbwProv, _) => IconButton(
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 36, minHeight: 32 + context.spaceXs),
                                icon: const Icon(Icons.play_arrow, size: 20),
                                tooltip: 'Luaj ajetin me highlight',
                                onPressed: () async {
                                  await wbwProv.ensureLoaded(verse.surahNumber);
                                  if (!context.mounted) return;
                                  final data = wbwProv.getVerseWordData(verse.number);
                                  final ts = wbwProv.getVerseTimestamps(verse.number);
                                  context.read<AudioProvider>().playVerseWithWordData(verse, data, timestamps: ts);
                                },
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              height: 32 + context.spaceXs,
                              child: Center(
                                child: VerseNotesIndicator(
                                  verseKey: '${verse.surahNumber}:${verse.number}',
                                ),
                              ),
                            ),
                            IconButton(
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(minWidth: 36, minHeight: 32 + context.spaceXs),
                              icon: const Icon(Icons.share, size: 18),
                              tooltip: 'Ndaj',
                              onPressed: () => _shareVerse(context, verse),
                            ),
                            Consumer<MemorizationProvider>(
                              builder: (context, mem, _) {
                                final key = '${verse.surahNumber}:${verse.number}';
                                final isMem = mem.isVerseMemorized(key);
                                return IconButton(
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(minWidth: 36, minHeight: 32 + context.spaceXs),
                                  icon: Icon(
                                    isMem ? Icons.psychology : Icons.psychology_outlined,
                                    color: isMem ? theme.colorScheme.primary : null,
                                    size: 20,
                                  ),
                                  tooltip: 'Memorizim',
                                  onPressed: () => mem.toggleVerseMemorization(key),
                                );
                              },
                            ),
                            IconButton(
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(minWidth: 36, minHeight: 32 + context.spaceXs),
                              icon: const Icon(Icons.more_vert, size: 20),
                              tooltip: 'Opsione',
                              onPressed: () => _showVerseOptions(context, verse),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.spaceSm),
                
                // Arabic text
            if (settings.showArabic)
              Padding(
                padding: EdgeInsets.only(bottom: context.spaceMd),
                child: settings.showWordByWord && wordByWordData != null && wordByWordData!.words.isNotEmpty
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: _WordByWordLine(
                          verseKey: verse.verseKey,
                          words: wordByWordData!.words,
                          baseSize: settings.fontSizeArabic.toDouble(),
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerRight,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            verse.textArabic,
                            style: Theme.of(context).textTheme.bodyArabic.copyWith(
                                  fontSize: settings.fontSizeArabic.toDouble(),
                                  height: 1.65,
                                ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
              ),
            
            // Translation
            if (settings.showTranslation && verse.textTranslation != null)
              Padding(
                padding: EdgeInsets.only(bottom: context.spaceSm),
                child: Text(
                  verse.textTranslation!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: settings.fontSizeTranslation.toDouble(),
                        height: 1.55,
                      ),
                ),
              ),
            
                // Transliteration
                if (settings.showTransliteration && verse.textTransliteration != null)
                  Text(
                    verse.textTransliteration!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: (settings.fontSizeTranslation.toDouble() - 2).clamp(10, 100),
                          fontStyle: FontStyle.italic,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                          height: 1.4,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Local add note helper (mirrors QuranViewWidget implementation) to allow bottom sheet action inside VerseWidget
  void _openAddNote(BuildContext context, Verse verse) {
    showDialog(
      context: context,
      builder: (ctx) => NoteEditorDialog(
        verseKey: verse.verseKey,
        onSave: (note) {
          final provider = context.read<NoteProvider>();
          if (note.id.isEmpty) {
            provider.addNote(note.verseKey, note.content, tags: note.tags);
          } else {
            provider.updateNote(note);
          }
        },
      ),
    );
  }

  void _playVerse(BuildContext context, Verse verse) {
    context.read<AudioProvider>().playVerse(verse);
  }

  void _playFromVerse(BuildContext context, Verse verse) {
    final quranProvider = context.read<QuranProvider>();
    final verses = quranProvider.currentVerses;
    final startIndex = verses.indexWhere((v) => v.number == verse.number);
    
    if (startIndex != -1) {
  final wbwProv = context.read<WordByWordProvider>();
  context.read<AudioProvider>().playSurah(verses, startIndex: startIndex, wbwProvider: wbwProv);
    }
  }

  void _shareVerse(BuildContext context, Verse verse) {
    ShareService.shareVerse(
      arabic: verse.textArabic,
      translation: verse.textTranslation,
      reference: '(${verse.surahNumber}:${verse.number})',
    );
  }

  void _showVerseOptions(BuildContext context, Verse verse) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => BottomSheetWrapper(
  child: VerseActionsSheet(verse: verse),
      ),
    );
  }
}

class _WordByWordLine extends StatelessWidget {
  final String verseKey;
  final List<WordData> words;
  final double baseSize;
  const _WordByWordLine({required this.verseKey, required this.words, required this.baseSize});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Selector<AudioProvider, _VerseWordState>(
        selector: (_, audio) => _VerseWordState(audio.currentTrack?.verseKey, audio.currentWordIndex),
        shouldRebuild: (prev, next) => (prev.verseKey == verseKey || next.verseKey == verseKey) && prev != next,
        builder: (context, state, _) {
          final bool isActiveVerse = state.verseKey == verseKey;
          final activeIndex = isActiveVerse ? state.wordIndex : null;
          final appState = context.read<AppStateProvider>();
          final glow = appState.wordHighlightGlow && !appState.reduceMotion;
          final baseStyle = theme.textTheme.bodyArabic.copyWith(fontSize: baseSize, height: 1.6);
          final useSpan = appState.useSpanWordRendering;
          if (useSpan) {
            final bool dark = theme.colorScheme.brightness == Brightness.dark;
            final Color baseHighlightBg = dark
                ? theme.colorScheme.primary.withOpacity(0.28)
                : theme.colorScheme.primary.withOpacity(0.15);
            // Build pure TextSpan list with minimal objects; reuse recognizers if desired (omitted now for simplicity).
            final List<TextSpan> wordSpans = List.generate(words.length, (i) {
              final w = words[i];
              final highlighted = activeIndex == i;
              TextStyle style = baseStyle;
              if (highlighted) {
                style = style.copyWith(
                  fontWeight: FontWeight.w600,
                  background: Paint()..color = baseHighlightBg,
                  shadows: glow
                      ? [
                          Shadow(
                            color: theme.colorScheme.primary.withOpacity(dark ? 0.55 : 0.45),
                            blurRadius: 12,
                          )
                        ]
                      : null,
                );
              }
              return TextSpan(text: w.arabic + (i == words.length - 1 ? '' : ' '), style: style);
            });
            return Directionality(
              textDirection: TextDirection.rtl,
              child: RichText(
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                text: TextSpan(children: wordSpans),
              ),
            );
          } else {
            // Fallback to legacy widget-per-word path (kept for safety / feature flag rollback)
            final List<InlineSpan> spans = [];
            final animDuration = appState.reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
            for (int i = 0; i < words.length; i++) {
              final w = words[i];
              final highlighted = activeIndex == i;
              final bool dark = theme.colorScheme.brightness == Brightness.dark;
              final highlightBg = dark
                  ? theme.colorScheme.primary.withOpacity(0.28)
                  : theme.colorScheme.primary.withOpacity(0.15);
              spans.add(
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: AnimatedContainer(
                    duration: animDuration,
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: highlighted
                        ? BoxDecoration(
                            color: highlightBg,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: glow
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withOpacity(dark ? 0.55 : 0.45),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          )
                        : null,
                    child: Text(
                      w.arabic,
                      style: highlighted
                          ? baseStyle.copyWith(fontWeight: FontWeight.w600, color: baseStyle.color)
                          : baseStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              );
              if (i != words.length - 1) {
                spans.add(const WidgetSpan(child: SizedBox(width: 4)));
              }
            }
            return Directionality(
                textDirection: TextDirection.rtl,
                child: RichText(
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  text: TextSpan(children: spans),
                ));
          }
        });
  }
}

@immutable
class _VerseWordState {
  final String? verseKey;
  final int? wordIndex;
  const _VerseWordState(this.verseKey, this.wordIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _VerseWordState && runtimeType == other.runtimeType && verseKey == other.verseKey && wordIndex == other.wordIndex;
  @override
  int get hashCode => Object.hash(verseKey, wordIndex);
}

// _WordToken removed in RichText refactor (spans used instead)

class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onCancel;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  const _SelectionBar({required this.count, required this.onCancel, required this.onBookmark, required this.onShare});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Anulo',
                onPressed: onCancel,
              ),
              Text('$count të përzgjedhura', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: 'Shëno',
                onPressed: onBookmark,
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Ndaj',
                onPressed: onShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Verse action registry appended below (old _VerseOptionsSheet removed)



