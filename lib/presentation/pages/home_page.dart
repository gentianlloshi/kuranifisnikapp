import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/quran_provider.dart';
import '../providers/bookmark_provider.dart';
import '../widgets/surah_list_widget.dart';
import '../widgets/quran_view_widget.dart';
import '../widgets/search_widget.dart';
import '../widgets/bookmarks_widget.dart';
import '../widgets/notifications_widget.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/notes_widget.dart';
import '../widgets/settings_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AppStateProvider, QuranProvider, BookmarkProvider>(
      builder: (context, appState, quranProvider, bookmarkProvider, child) {
        if (appState.isLoading || quranProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Kurani Fisnik'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.list), text: 'Suret'),
                Tab(icon: Icon(Icons.book), text: 'Leximi'),
                Tab(icon: Icon(Icons.search), text: 'Kërko'),
                Tab(icon: Icon(Icons.bookmark), text: 'Favoritet'),
                Tab(icon: Icon(Icons.note), text: 'Shënimet'),
                Tab(icon: Icon(Icons.notifications), text: 'Njoftime'),
              ],
            ),
          ),
          drawer: const SettingsDrawer(),
          body: Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    SurahListWidget(),
                    QuranViewWidget(),
                    SearchWidget(),
                    BookmarksWidget(),
                    NotesWidget(),
                    NotificationsWidget(),
                  ],
                ),
              ),
              const AudioPlayerWidget(),
            ],
          ),
          floatingActionButton: _buildFloatingActionButton(),
        );
      },
    );
  }

  Widget? _buildFloatingActionButton() {
    switch (_currentIndex) {
      case 1: // Quran View
        return FloatingActionButton(
          onPressed: () {
            // TODO: Implement jump to verse functionality
            _showJumpToVerseDialog();
          },
          child: const Icon(Icons.navigation),
        );
      case 2: // Search
        return FloatingActionButton(
          onPressed: () {
            // TODO: Clear search results
            context.read<QuranProvider>().clearSearch();
          },
          child: const Icon(Icons.clear),
        );
      default:
        return null;
    }
  }

  void _showJumpToVerseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shko te ajeti'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Numri i sures',
                hintText: 'p.sh. 2',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Numri i ajetit',
                hintText: 'p.sh. 255',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anulo'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement navigation to verse
              Navigator.of(context).pop();
            },
            child: const Text('Shko'),
          ),
        ],
      ),
    );
  }
}

