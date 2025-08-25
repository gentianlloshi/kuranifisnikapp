import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';

// Providers
import '../providers/quran_provider.dart';
import '../providers/note_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/texhvid_provider.dart';
import '../providers/memorization_provider.dart';
import '../providers/bookmark_provider.dart';

// Widgets
import '../widgets/quran_view_widget.dart';
import '../widgets/search_widget.dart';
import '../widgets/bookmarks_widget.dart';
import '../widgets/notes_widget.dart';
import '../widgets/memorization_tab.dart'; // new MEMO-1 implementation
import '../widgets/audio_player_widget.dart';
import '../widgets/mini_player_widget.dart';
import '../widgets/texhvid_widget.dart';
import '../widgets/thematic_index_widget.dart';
import '../widgets/image_generator_widget.dart';
import '../widgets/settings_drawer.dart';
import '../providers/reading_progress_provider.dart';
import '../../domain/entities/verse.dart';
import '../../domain/repositories/quran_repository.dart';
import '../widgets/notifications_widget.dart';
import 'help_page.dart'; // Import the new HelpPage
import '../../core/metrics/perf_metrics.dart';
import '../widgets/perf_summary.dart';
import '../providers/app_state_provider.dart';

class EnhancedHomePage extends StatefulWidget {
  const EnhancedHomePage({super.key});

  @override
  State<EnhancedHomePage> createState() => _EnhancedHomePageState();
}

class _EnhancedHomePageState extends State<EnhancedHomePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  bool _showPerfPanel = false;

  final List<TabInfo> _tabs = [
    TabInfo(
      title: 'Kurani',
      icon: Icons.book,
      widget: const QuranViewWidget(),
    ),
    TabInfo(
      title: 'Kërko',
      icon: Icons.search,
      widget: const SearchWidget(),
    ),
    TabInfo(
      title: 'Favoritet',
      icon: Icons.bookmark,
      widget: const BookmarksWidget(),
    ),
    TabInfo(
      title: 'Shënimet',
      icon: Icons.note,
      widget: const NotesWidget(),
    ),
    TabInfo(
      title: 'Memorizo',
      icon: Icons.psychology,
      widget: const MemorizationTab(),
    ),
    TabInfo(
      title: 'Texhvid',
      icon: Icons.school,
      widget: const TexhvidWidget(),
    ),
    TabInfo(
      title: 'Temat',
      icon: Icons.category,
      widget: const ThematicIndexWidget(),
    ),
    TabInfo(
      title: 'Njoftimet',
      icon: Icons.notifications,
      widget: const NotificationsWidget(),
    ),
    TabInfo(
      title: 'Ndihmë',
      icon: Icons.help,
      widget: const HelpPage(),
    ), // Add the new HelpPage
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final quranProvider = context.read<QuranProvider>();
        if (quranProvider.currentSurah != null) {
          quranProvider.exitCurrentSurah();
        }
      },
  child: Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_currentIndex].title),
        actions: [
          if (_currentIndex == 0) _QuranOverflowMenu(),
          IconButton(
            tooltip: 'Perf',
            icon: Icon(_showPerfPanel ? Icons.speed : Icons.speed_outlined),
            onPressed: () => setState(()=> _showPerfPanel = !_showPerfPanel),
          ),
          // Image Generator Button
          IconButton(
            onPressed: () => _showImageGenerator(context),
            icon: const Icon(Icons.image),
            tooltip: 'Gjenerues Imazhesh',
          ),
          // Audio Player Toggle
          Consumer<AudioProvider>(
            builder: (context, audioProvider, child) {
              if (audioProvider.isPlaying || audioProvider.currentTrack != null) {
                return IconButton(
                  onPressed: () => _showAudioPlayer(context),
                  icon: const Icon(Icons.music_note),
                  tooltip: 'Audio Player',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Settings (open end drawer)
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.settings),
              tooltip: 'Cilësimet',
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          onTap: (index) {
            if (index == 0 && _currentIndex == 0) {
              // If already on Quran tab and user taps again, exit current surah to show list
              context.read<QuranProvider>().exitCurrentSurah();
            }
            _tabController.animateTo(index);
          },
          tabs: _tabs.map((tab) => Tab(
                icon: Icon(tab.icon),
                text: tab.title,
              )).toList(),
        ),
      ),
      endDrawer: const SettingsDrawer(),
      body: Stack(
        children: [
          Column(
            children: [
              if (_showPerfPanel) const _PerfPanel(),
              // Main Content (tabs)
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabs.map((tab) => tab.widget).toList(),
                ),
              ),
              // Global Mini Player (persistent at bottom)
              const MiniPlayerWidget(),
            ],
          ),
          const _SnackHost(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    ));
  }

  Widget? _buildFloatingActionButton() {
    switch (_currentIndex) {
      case 0: // Quran
        return FloatingActionButton(
          onPressed: () => _showQuickNavigation(context),
          tooltip: 'Navigim i Shpejtë',
          child: const Icon(Icons.navigation),
        );
      case 1: // Search
        return null; // Search has its own input
      case 2: // Bookmarks
        return FloatingActionButton(
          onPressed: () => _addCurrentVerseToBookmarks(),
          tooltip: 'Shto në Favoritet',
          child: const Icon(Icons.bookmark_add),
        );
      case 3: // Notes
        return FloatingActionButton(
          onPressed: () => _createNewNote(),
          tooltip: 'Shënim i Ri',
          child: const Icon(Icons.add),
        );
      case 4: // Memorization
        return FloatingActionButton(
          onPressed: () => _addToMemorization(),
          tooltip: 'Shto për Memorizim',
          child: const Icon(Icons.add),
        );
      case 5: // Texhvid
        return FloatingActionButton(
          onPressed: () => _startTexhvidQuiz(),
          tooltip: 'Fillo Kuizin',
          child: const Icon(Icons.quiz),
        );
      case 6: // Thematic Index
        return null; // Has its own search
      case 7: // Notifications
        return FloatingActionButton(
          onPressed: () => _createReminder(),
          tooltip: 'Krijo Kujtesë',
          child: const Icon(Icons.alarm_add),
        );
      default:
        return null;
    }
  }

  void _showImageGenerator(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ImageGeneratorWidget(),
      ),
    );
  }

  void _showAudioPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AudioPlayerWidget(mini: false),
    );
  }

  void _showQuickNavigation(BuildContext context) {
    final surahController = TextEditingController();
    final verseController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navigim i Shpejtë'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: surahController,
              decoration: const InputDecoration(
                labelText: 'Numri i Sures (1-114)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: verseController,
              decoration: const InputDecoration(
                labelText: 'Numri i Ajetit (opsional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulo'),
          ),
            ElevatedButton(
              onPressed: () {
                final surahNumber = int.tryParse(surahController.text.trim());
                final verseNumber = int.tryParse(verseController.text.trim());
                if (surahNumber == null || surahNumber < 1 || surahNumber > 114) {
                  context.read<AppStateProvider>().enqueueSnack('Numër sureje i pavlefshëm');
                  return;
                }
                Navigator.pop(context);
                if (verseNumber != null && verseNumber > 0) {
                  context.read<QuranProvider>().openSurahAtVerse(surahNumber, verseNumber);
                } else {
                  context.read<QuranProvider>().navigateToSurah(surahNumber);
                }
                _tabController.animateTo(0); // switch to Quran tab
              },
              child: const Text('Shko'),
            ),
        ],
      ),
    );
  }

  void _addCurrentVerseToBookmarks() {
    final quranProvider = context.read<QuranProvider>();
    if (quranProvider.currentSurah != null) {
      final verses = quranProvider.currentVerses;
      if (verses.isNotEmpty) {
        final currentVerse = verses.first; // Improvement: track currently viewed/selected verse
        final key = '${currentVerse.surahNumber}:${currentVerse.number}';
        final bookmarkProvider = context.read<BookmarkProvider>();
        bookmarkProvider.toggleBookmark(key);
        context.read<AppStateProvider>().enqueueSnack(
          bookmarkProvider.isBookmarkedSync(key)
              ? 'Ajeti u shtua në favoritë'
              : 'Ajeti u hoq nga favoritët',
        );
      }
    }
  }

  void _createNewNote() {
    final noteProvider = context.read<NoteProvider>();
  // For now create a placeholder note (improvement: show dialog)
  noteProvider.createNewNote(verseKey: '1:1', content: '');
  }

  void _addToMemorization() {
    final surahController = TextEditingController();
    final verseController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shto për Memorizim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: surahController,
              decoration: const InputDecoration(
                labelText: 'Sure (1-114)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: verseController,
              decoration: const InputDecoration(
                labelText: 'Ajeti',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulo')),
          ElevatedButton(
            onPressed: () {
              final surah = int.tryParse(surahController.text.trim());
              final verse = int.tryParse(verseController.text.trim());
              if (surah == null || surah < 1 || surah > 114 || verse == null || verse < 1) {
                context.read<AppStateProvider>().enqueueSnack('Të dhëna të pavlefshme');
                return;
              }
              final key = '$surah:$verse';
              context.read<MemorizationProvider>().toggleVerseMemorization(key);
              Navigator.pop(context);
              context.read<AppStateProvider>().enqueueSnack('Ajeti $key u shtua/ndryshua');
            },
            child: const Text('Ruaj'),
          ),
        ],
      ),
    );
  }

  void _startTexhvidQuiz() {
    final texhvidProvider = context.read<TexhvidProvider>();
    texhvidProvider.startQuiz();
  }

  void _createReminder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Krijo Kujtesë'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Titulli i Kujtesës',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Përshkrimi',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulo'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AppStateProvider>().enqueueSnack('Kujtesa u krijua');
            },
            child: const Text('Krijo'),
          ),
        ],
      ),
    );
  }
}

class _QuranOverflowMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
  return PopupMenuButton<String>(
  onSelected: (value) async {
        if (value == 'resume') {
          final audio = context.read<AudioProvider>();
          final quran = context.read<QuranProvider>();
          // ReadingProgressProvider may not be globally provided yet; guard lookup.
          ReadingResumePoint? resume;
          try {
            final rp = Provider.of<ReadingProgressProvider?>(context, listen: false);
            if (rp != null) {
              resume = await rp.getMostRecent();
            }
          } catch (_) {}
          if (resume == null) {
    if (!context.mounted) return;
    context.read<AppStateProvider>().enqueueSnack('Asnjë pikë leximi e fundit.');
            return;
          }
      await quran.ensureSurahLoaded(resume.surah);
          final verse = quran.findVerse(resume.surah, resume.verse) ?? Verse(
            surahId: resume.surah,
            verseNumber: resume.verse,
            arabicText: '',
            translation: null,
            transliteration: null,
            verseKey: '${resume.surah}:${resume.verse}',
          );
      if (!context.mounted) return;
      await audio.playVerse(verse);
        }
      },
      itemBuilder: (ctx) => const [
        PopupMenuItem(
          value: 'resume',
          child: Text('Vazhdo nga leximi i fundit'),
        ),
      ],
    );
  }
}

class _PerfPanel extends StatefulWidget {
  const _PerfPanel();
  @override
  State<_PerfPanel> createState() => _PerfPanelState();
}

class _PerfPanelState extends State<_PerfPanel> {
  StreamSubscription<double>? _enrSub;
  StreamSubscription<Map<String,double>>? _trSub;
  Map<String,double>? _latestTrCov;
  double? _latestEnr;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachStreams();
  }

  void _attachStreams() {
    final repo = _findQuranRepository(context);
    if (repo == null) return;
    _enrSub ??= repo.enrichmentCoverageStream.listen((v) {
      _latestEnr = v;
      setState(() {});
    });
    _trSub ??= repo.translationCoverageStream.listen((m) {
      _latestTrCov = m;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _enrSub?.cancel();
    _trSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = PerfMetrics.instance;
    final snap = metrics.currentSnapshot();
    final enrichment = _latestEnr ?? snap.enrichmentCoverage;
    return AnimatedBuilder(
      animation: metrics,
      builder: (_, __) {
        final updatedSnap = metrics.currentSnapshot();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: Border(bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.2))),
          ),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodySmall!,
            child: Row(children: [
              Expanded(child: PerfSummary(
                snapshot: updatedSnap,
                indexCoverage: updatedSnap.indexCoverage,
                enrichmentCoverage: enrichment,
              )),
              _TranslationCoverageButton(liveCoverage: _latestTrCov),
            ]),
          ),
        );
      },
    );
  }
}

class _TranslationCoverageButton extends StatelessWidget {
  final Map<String,double>? liveCoverage;
  const _TranslationCoverageButton({this.liveCoverage});
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Translation coverage',
      icon: const Icon(Icons.language, size: 18),
      onPressed: () => _showDialog(context),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog(context: context, builder: (c) {
      final repo = _findQuranRepository(context);
      final data = liveCoverage ?? repo?.translationCoverageByKey() ?? const {};
      return AlertDialog(
        title: const Text('Translation Coverage'),
        content: data.isEmpty ? const Text('No data yet') : SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: (data.length * 36).clamp(80, 300).toDouble(),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemBuilder: (ctx2, i) {
                    final entry = data.entries.elementAt(i);
                    final pct = (entry.value*100).clamp(0,100).toStringAsFixed(0);
                    return Row(
                      children: [
                        Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                        SizedBox(
                          width: 110,
                          child: LinearProgressIndicator(value: entry.value.clamp(0,1)),
                        ),
                        const SizedBox(width: 8),
                        Text('$pct%'),
                      ],
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: data.length,
                ),
              ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: Text('${data.length} translations', style: Theme.of(context).textTheme.labelSmall)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.of(c).pop(), child: const Text('Mbyll')),
        ],
      );
    });
  }
}

QuranRepository? _findQuranRepository(BuildContext context) {
  try { return Provider.of<QuranProvider>(context, listen:false).repository; } catch(_) { return null; }
}

// CoverageBar moved to presentation/widgets/perf_summary.dart

class TabInfo {
  final String title;
  final IconData icon;
  final Widget widget;

  TabInfo({
    required this.title,
    required this.icon,
    required this.widget,
  });
}

/// Overlay widget that listens to AppStateProvider snack queue and displays SnackBars sequentially.
class _SnackHost extends StatefulWidget {
  const _SnackHost();
  @override
  State<_SnackHost> createState() => _SnackHostState();
}

class _SnackHostState extends State<_SnackHost> {
  AppStateProvider? _last;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = Provider.of<AppStateProvider>(context);
    if (_last != app) {
      _last = app;
      // Trigger attempt to show if pending
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow(app));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow(app));
    }
  }

  void _maybeShow(AppStateProvider app) {
    if (!mounted) return;
    final current = app.currentSnack;
    if (current == null) return;
  // If a snack is already being displayed (provider flag), don't show again.
  if (app.isSnackDisplaying) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    app.markSnackDisplayed();
    messenger.showSnackBar(
      SnackBar(
        content: Text(current.text),
        duration: current.duration,
        behavior: SnackBarBehavior.floating,
      ),
    ).closed.whenComplete(() {
      if (mounted) {
        app.onSnackCompleted();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Invisible widget; listens to provider changes.
    return const SizedBox.shrink();
  }
}


