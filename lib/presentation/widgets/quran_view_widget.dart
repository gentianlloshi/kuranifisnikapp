import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quran_provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/word_by_word_provider.dart';
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
            final verses = quranProvider.currentVerses;
            final index = verses.indexWhere((v) => v.verseKey == currentPlayingKey);
            if (index >= 0 && _scrollController.hasClients) {
              _scrollController.animateTo(
                index * 220.0, // approximate card height
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            }
          });
        }
        if (quranProvider.currentSurah == null) {
          // Show list of surahs directly so user can choose
          return const SurahListWidget();
        }

        final surah = quranProvider.currentSurah!;
        final verses = quranProvider.currentVerses;

        return Column(
          children: [
            // Surah header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8,8,8,8),
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
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            surah.nameArabic,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'AmiriQuran',
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
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
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
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
                          return VerseWidget(
                            key: key,
                            verse: verse,
                            settings: appState.settings,
                            isBookmarked: isBm,
                            onBookmarkToggle: () => bookmarkProvider.toggleBookmark(verse.verseKey),
                            // Use verseKey directly instead of legacy 'tag'
                            currentPlayingVerseKey: Provider.of<AudioProvider>(context).currentTrack?.verseKey,
                    currentWordIndex: Provider.of<AudioProvider>(context).currentWordIndex, // Pass current word index
                    wordByWordData: Provider.of<WordByWordProvider>(context).currentWordByWordVerses.firstWhere(
                      (element) => element.verseNumber == verse.number, orElse: () => WordByWordVerse(verseNumber: verse.number, words: []), // Provide a default empty list
                    ),
                          );
                        },
                      );
                },
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
  final int? currentWordIndex;
  final WordByWordVerse? wordByWordData;

  const VerseWidget({
    super.key,
    required this.verse,
    required this.settings,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    this.currentPlayingVerseKey,
    this.currentWordIndex,
    this.wordByWordData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isCurrentVersePlaying = currentPlayingVerseKey == verse.verseKey;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse number and actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    verse.number.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked ? theme.primaryColor : null,
                  ),
                  onPressed: onBookmarkToggle,
                ),
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _playVerse(context, verse),
                ),
                VerseNotesIndicator(verseKey: '${verse.surahNumber}:${verse.number}'),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => _shareVerse(context, verse),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showVerseOptions(context, verse),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Arabic text
            if (settings.showArabic)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: settings.showWordByWord && wordByWordData != null && wordByWordData!.words.isNotEmpty
                    ? Wrap(
                        alignment: WrapAlignment.end,
                        textDirection: TextDirection.rtl,
                        children: List.generate(wordByWordData!.words.length, (index) {
                          final word = wordByWordData!.words[index];
                          final isHighlighted = isCurrentVersePlaying && currentWordIndex == index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
                            child: Text(
                              word.arabic,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'AmiriQuran',
                                fontSize: settings.fontSizeArabic.toDouble(),
                                height: 1.8,
                                color: isHighlighted ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
                                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }),
                      )
                    : Text(
                        verse.textArabic,
                        style: TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: settings.fontSizeArabic.toDouble(),
                          height: 1.8,
                        ),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                      ),
              ),
            
            // Translation
            if (settings.showTranslation && verse.textTranslation != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  verse.textTranslation!,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: settings.fontSizeTranslation.toDouble(),
                    height: 1.6,
                  ),
                ),
              ),
            
            // Transliteration
            if (settings.showTransliteration && verse.textTransliteration != null)
              Text(
                verse.textTransliteration!,
                style: TextStyle(
                  fontSize: settings.fontSizeTranslation.toDouble() - 2,
                  fontStyle: FontStyle.italic,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
          ],
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
      context.read<AudioProvider>().playSurah(verses, startIndex: startIndex);
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


