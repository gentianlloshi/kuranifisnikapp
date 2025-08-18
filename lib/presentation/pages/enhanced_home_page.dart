import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../providers/quran_provider.dart';
import '../providers/note_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/texhvid_provider.dart';
import '../providers/memorization_provider.dart';

// Widgets
import '../widgets/quran_view_widget.dart';
import '../widgets/search_widget.dart';
import '../widgets/bookmarks_widget.dart';
import '../widgets/notes_widget.dart';
import '../widgets/memorization_widget.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/texhvid_widget.dart';
import '../widgets/thematic_index_widget.dart';
import '../widgets/image_generator_widget.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/notifications_widget.dart';
import 'help_page.dart'; // Import the new HelpPage

class EnhancedHomePage extends StatefulWidget {
  const EnhancedHomePage({super.key});

  @override
  State<EnhancedHomePage> createState() => _EnhancedHomePageState();
}

class _EnhancedHomePageState extends State<EnhancedHomePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

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
      widget: const MemorizationWidget(),
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
          // Settings
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
      body: Column(
        children: [
          // Audio Player Mini Widget
          Consumer<AudioProvider>(
            builder: (context, audioProvider, child) {
              if (audioProvider.currentTrack != null && 
                  !audioProvider.isPlayerExpanded) {
                return const AudioPlayerWidget(mini: true);
              }
              return const SizedBox.shrink();
            },
          ),
          
          // Main Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) => tab.widget).toList(),
            ),
          ),
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
          child: const Icon(Icons.navigation),
          tooltip: 'Navigim i Shpejtë',
        );
      case 1: // Search
        return null; // Search has its own input
      case 2: // Bookmarks
        return FloatingActionButton(
          onPressed: () => _addCurrentVerseToBookmarks(),
          child: const Icon(Icons.bookmark_add),
          tooltip: 'Shto në Favoritet',
        );
      case 3: // Notes
        return FloatingActionButton(
          onPressed: () => _createNewNote(),
          child: const Icon(Icons.add),
          tooltip: 'Shënim i Ri',
        );
      case 4: // Memorization
        return FloatingActionButton(
          onPressed: () => _addToMemorization(),
          child: const Icon(Icons.add),
          tooltip: 'Shto për Memorizim',
        );
      case 5: // Texhvid
        return FloatingActionButton(
          onPressed: () => _startTexhvidQuiz(),
          child: const Icon(Icons.quiz),
          tooltip: 'Fillo Kuizin',
        );
      case 6: // Thematic Index
        return null; // Has its own search
      case 7: // Notifications
        return FloatingActionButton(
          onPressed: () => _createReminder(),
          child: const Icon(Icons.alarm_add),
          tooltip: 'Krijo Kujtesë',
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Numër sureje i pavlefshëm')));
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
      // TODO integrate real bookmark logic
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('U shtua në favoritet (placeholder)')),
      );
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Të dhëna të pavlefshme')));
                return;
              }
              final key = '$surah:$verse';
              context.read<MemorizationProvider>().toggleVerseMemorization(key);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ajeti $key u shtua/ndryshua')));
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Titulli i Kujtesës',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kujtesa u krijua')),
              );
            },
            child: const Text('Krijo'),
          ),
        ],
      ),
    );
  }
}

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


