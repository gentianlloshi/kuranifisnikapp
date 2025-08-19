import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/quran_provider.dart';
import '../theme/theme.dart';
import '../theme/theme.dart';
import '../providers/app_state_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/word_by_word_provider.dart';
import '../providers/memorization_provider.dart';
import '../widgets/verse_notes_indicator.dart';
import '../widgets/surah_list_widget.dart';
import '../../domain/entities/verse.dart';
import '../../domain/entities/word_by_word.dart';

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
  static const bool kUseNewVerseHighlight = true; // feature flag for new highlight spec
  // Selection mode state
  bool _selectionMode = false;
  final Set<String> _selectedVerseKeys = <String>{};

  // Centralized highlight decoration builder (verse-level)
  BoxDecoration _buildVerseHighlightDecoration(BuildContext context, {required bool isActive}) {
    final scheme = Theme.of(context).colorScheme;
    if (!isActive) return const BoxDecoration();
    // Refined spec: subtle fill + left accent bar
    final accent = scheme.primary;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: accent.withOpacity(0.12),
      border: Border(left: BorderSide(color: accent, width: 3)),
    );
  }

  void _showVerseOptions(BuildContext context, Verse verse) {
    // Delegate to VerseWidget's modal for consistency
    showModalBottomSheet(
      context: context,
      builder: (context) => _VerseOptionsSheet(
        verse: verse,
        onPlay: () => context.read<AudioProvider>().playVerse(verse),
        onPlayFromHere: () {
          final q = context.read<QuranProvider>();
          final verses = q.currentVerses;
          final startIndex = verses.indexWhere((v) => v.number == verse.number);
          if (startIndex != -1) {
            final wbwProv = context.read<WordByWordProvider>();
            context.read<AudioProvider>().playSurah(verses, startIndex: startIndex, wbwProvider: wbwProv);
          }
        },
        onToggleMemorization: () {
          final mem = context.read<MemorizationProvider>();
          final key = '${verse.surahNumber}:${verse.number}';
          mem.toggleVerseMemorization(key);
          Navigator.pop(context);
        },
      ),
    );
  }

  BoxDecoration _mergeSelectionDecoration(BuildContext context, {required BoxDecoration base, required bool isSelected}) {
    if (!isSelected) return base;
    final scheme = Theme.of(context).colorScheme;
    // Layer selection indication (semi-transparent primaryContainer + border)
    final selectionColor = scheme.primaryContainer.withOpacity(0.35);
    return base.copyWith(
      color: base.color == null ? selectionColor : Color.alphaBlend(selectionColor, base.color!),
      border: base.border ?? Border.all(color: scheme.primary.withOpacity(0.6), width: 2),
    );
  }

  void _enterSelection(String verseKey) {
    setState(() {
      _selectionMode = true;
      _selectedVerseKeys.add(verseKey);
    });
  }

  void _toggleSelection(String verseKey) {
    if (!_selectionMode) {
      _enterSelection(verseKey);
      return;
    }
    setState(() {
      if (_selectedVerseKeys.contains(verseKey)) {
        _selectedVerseKeys.remove(verseKey);
        if (_selectedVerseKeys.isEmpty) _selectionMode = false;
      } else {
        _selectedVerseKeys.add(verseKey);
      }
    });
  }

  void _clearSelection() {
    if (!_selectionMode) return;
    setState(() {
      _selectedVerseKeys.clear();
      _selectionMode = false;
    });
  }

  Future<void> _bookmarkSelected() async {
    final bookmarkProvider = context.read<BookmarkProvider>();
    for (final key in _selectedVerseKeys) {
      await bookmarkProvider.toggleBookmark(key);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('U aplikuan shënjimet për ${_selectedVerseKeys.length} ajete')), // localization later
      );
    }
    _clearSelection();
  }

  void _shareSelected() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Do të ndahet ${_selectedVerseKeys.length} ajete (së shpejti)')),
    );
  }

  // Removed word style builder (moved into VerseWidget for direct reuse)

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
        final pendingTarget = quranProvider.consumePendingScrollTarget();
        if (pendingTarget != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final verses = quranProvider.currentVerses;
            final index = verses.indexWhere((v) => v.number == pendingTarget);
            if (index >= 0 && _scrollController.hasClients) {
              final position = _computeScrollOffsetForIndex(index, verses);
              _scrollController.animateTo(
                position.clamp(0, _scrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
              );
            }
          });
        }
        // Auto-scroll when current playing verse changes
        final currentPlayingKey = context.watch<AudioProvider>().currentTrack?.verseKey;
        if (currentPlayingKey != null && currentPlayingKey != _lastPlayingVerseKey) {
          _lastPlayingVerseKey = currentPlayingKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _autoScrollToVerse(currentPlayingKey, quranProvider.currentVerses);
          });
        }
  if (quranProvider.currentSurah == null) {
          // Show list of surahs directly so user can choose
          return const SurahListWidget();
        }

        final surah = quranProvider.currentSurah!;
        final verses = quranProvider.currentVerses;
        // Load real word-by-word + timestamps if feature enabled
        if (context.read<AppStateProvider>().showWordByWord) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<WordByWordProvider>().ensureLoaded(surah.number);
          });
        }

        return Column(
          children: [
            if (_selectionMode)
              _SelectionBar(
                count: _selectedVerseKeys.length,
                onCancel: _clearSelection,
                onBookmark: _bookmarkSelected,
                onShare: _shareSelected,
              ),
            // Surah header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(context.spaceSm, context.spaceSm, context.spaceSm, context.spaceSm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.4),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Kthehu',
                    onPressed: () => context.read<QuranProvider>().exitCurrentSurah(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              surah.nameArabic,
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.bodyArabic.copyWith(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height:4),
                        Text(
                          '${surah.nameTranslation} • ${surah.nameTransliteration}',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${surah.revelation} • ${surah.versesCount} ajete',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  padding: EdgeInsets.all(context.spaceLg),
                  itemCount: verses.length + (quranProvider.hasMoreVerses ? 1 : 0), // Add 1 for loading indicator
                  itemBuilder: (context, index) {
                    if (index == verses.length) {
                      // Last item, show loading indicator if more verses are available
                      return quranProvider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : const SizedBox.shrink();
                    }
                  final verse = verses[index];
                  final key = _verseKeys.putIfAbsent(verse.verseKey, () => GlobalKey());
                      return FutureBuilder<bool>(
                        future: bookmarkProvider.isBookmarked(verse.verseKey),
                        builder: (context, snapshot) {
                          final isBm = snapshot.data ?? false;
                          final currentPlaying = Provider.of<AudioProvider>(context).currentTrack?.verseKey; // only verse-level listening here (no word index)
                          final wbwProvider = Provider.of<WordByWordProvider>(context);
                          var wbw = wbwProvider.getVerseWordData(verse.number);
                          wbw ??= wbwProvider.error != null ? wbwProvider.buildNaiveFromVerse(verse) : null;
                          final isCurrent = currentPlaying == verse.verseKey;
                          final isSelected = _selectedVerseKeys.contains(verse.verseKey);
                          final baseDecoration = _buildVerseHighlightDecoration(context, isActive: isCurrent);
                          final decoration = _mergeSelectionDecoration(context, base: baseDecoration, isSelected: isSelected);
                          final reduceMotion = appState.reduceMotion;
                          final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 300);
                          return GestureDetector(
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
                                currentPlayingVerseKey: currentPlaying,
                                wordByWordData: wbw,
                              ),
                            ),
                          );
                        },
                      );
                  },
                ),
              ),
            ),
          ],
        );
  // Schedule measurement after rendering
  _scheduleMeasurement();
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
        color: theme.colorScheme.surface,
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
                          spacing: 0,
                          runSpacing: -4,
                          alignment: WrapAlignment.end,
                          children: [
                            IconButton(
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
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
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                                icon: const Icon(Icons.play_arrow, size: 20),
                                tooltip: 'Luaj ajetin me highlight',
                                onPressed: () async {
                                  await wbwProv.ensureLoaded(verse.surahNumber);
                                  final data = wbwProv.getVerseWordData(verse.number);
                                  final ts = wbwProv.getVerseTimestamps(verse.number);
                                  context.read<AudioProvider>().playVerseWithWordData(verse, data, timestamps: ts);
                                },
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              height: 32,
                              child: Center(
                                child: VerseNotesIndicator(
                                  verseKey: '${verse.surahNumber}:${verse.number}',
                                ),
                              ),
                            ),
                            IconButton(
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
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
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
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
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
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
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funksioni i ndarjes do të implementohet së shpejti')),
    );
  }

  void _showVerseOptions(BuildContext context, Verse verse) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Luaj këtë ajet'),
            onTap: () {
              Navigator.pop(context);
              _playVerse(context, verse);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: const Text('Luaj nga ky ajet'),
            onTap: () {
              Navigator.pop(context);
              _playFromVerse(context, verse);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Kopjo'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement copy functionality
            },
          ),
          ListTile(
            leading: const Icon(Icons.note_add),
            title: const Text('Shto shënim'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement add note functionality
            },
          ),
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text('Shto në memorim'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement add to memorization functionality
            },
          ),
        ],
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
          final List<InlineSpan> spans = [];
          final animDuration = appState.reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
          for (int i = 0; i < words.length; i++) {
            final w = words[i];
            final highlighted = activeIndex == i;
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AnimatedContainer(
                  duration: animDuration,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: highlighted
                      ? BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: glow
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.5),
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

class _VerseOptionsSheet extends StatelessWidget {
  final Verse verse;
  final VoidCallback onPlay;
  final VoidCallback onPlayFromHere;
  final VoidCallback onToggleMemorization;
  const _VerseOptionsSheet({required this.verse, required this.onPlay, required this.onPlayFromHere, required this.onToggleMemorization});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Luaj këtë ajet'),
            onTap: () {
              Navigator.pop(context);
              onPlay();
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: const Text('Luaj nga ky ajet'),
            onTap: () {
              Navigator.pop(context);
              onPlayFromHere();
            },
          ),
          ListTile(
            leading: const Icon(Icons.psychology),
            title: const Text('Ndrysho Status Memorizimi'),
            onTap: onToggleMemorization,
          ),
        ],
      ),
    );
  }
}


