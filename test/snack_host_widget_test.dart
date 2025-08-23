import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/app_state_provider.dart';
import 'package:kurani_fisnik_app/domain/usecases/settings_usecases.dart';
import 'package:kurani_fisnik_app/domain/repositories/storage_repository.dart';
import 'package:kurani_fisnik_app/domain/entities/app_settings.dart';
import 'package:kurani_fisnik_app/domain/entities/bookmark.dart';
import 'package:kurani_fisnik_app/domain/entities/note.dart';

// Minimal SnackHost used only for testing; mirrors production behavior closely.
class TestSnackHost extends StatefulWidget {
  const TestSnackHost({super.key});
  @override
  State<TestSnackHost> createState() => _TestSnackHostState();
}

class _TestSnackHostState extends State<TestSnackHost> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = Provider.of<AppStateProvider>(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow(app));
  }

  void _maybeShow(AppStateProvider app) {
    if (!mounted) return;
    final current = app.currentSnack;
    if (current == null || app.isSnackDisplaying) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    app.markSnackDisplayed();
    messenger
        .showSnackBar(SnackBar(
          content: Text(current.text),
          duration: current.duration,
          behavior: SnackBarBehavior.floating,
        ))
        .closed
        .whenComplete(() {
      if (mounted) app.onSnackCompleted();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _DummyGetSettings extends GetSettingsUseCase {
  _DummyGetSettings() : super(_DummyStorage());
}

class _DummySaveSettings extends SaveSettingsUseCase {
  _DummySaveSettings() : super(_DummyStorage());
}

class _DummyStorage implements StorageRepository {
  AppSettings _settings = const AppSettings();
  @override
  Future<AppSettings?> getSettings() async => _settings;
  @override
  Future<void> saveSettings(AppSettings settings) async { _settings = settings; }
  @override
  Future<List<Bookmark>> getBookmarks() async => [];
  @override
  Future<void> saveBookmarks(List<Bookmark> bookmarks) async {}
  @override
  Future<void> addBookmark(Bookmark bookmark) async {}
  @override
  Future<void> removeBookmark(String verseKey) async {}
  @override
  Future<bool> isBookmarked(String verseKey) async => false;
  @override
  Future<void> saveNote(Note note) async {}
  @override
  Future<void> deleteNote(String noteId) async {}
  @override
  Future<List<Note>> getNotes() async => [];
  @override
  Future<Note?> getNoteForVerse(String verseKey) async => null;
  @override
  Future<void> saveLastReadPosition(int surahNumber, int verseNumber) async {}
  @override
  Future<Map<String, int>> getLastReadPosition() async => {'surah':1,'verse':1};
  @override
  Future<Map<String, int>> getLastReadTimestamps() async => {};
  @override
  Future<void> addVerseToMemorization(String verseKey) async {}
  @override
  Future<void> removeVerseFromMemorization(String verseKey) async {}
  @override
  Future<List<String>> getMemorizationList() async => [];
  @override
  Future<bool> isVerseMemorized(String verseKey) async => false;
}

void main() {
  testWidgets('SnackHost shows queued SnackBars sequentially', (tester) async {
    final appState = AppStateProvider(
      getSettingsUseCase: _DummyGetSettings(),
      saveSettingsUseCase: _DummySaveSettings(),
      simple: true,
    );

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>.value(value: appState),
      ],
      child: const MaterialApp(home: Scaffold(body: TestSnackHost())),
    ));

    // Enqueue two snacks
    appState.enqueueSnack('First', duration: const Duration(milliseconds: 20));
    appState.enqueueSnack('Second', duration: const Duration(milliseconds: 20));

  // Let the frame settle and first SnackBar appear
  await tester.pump();
  // The show logic is scheduled in a post-frame callback; pump again
  await tester.pump();
    // The SnackBar shows within a MaterialBanner-like semantics; check by text
    expect(find.text('First'), findsOneWidget);

  // Wait for the first SnackBar to close (Snackbar display + hide animations)
  await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // Now the second should appear
    expect(find.text('Second'), findsOneWidget);

    // Let it close as well
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // No SnackBars left
    expect(find.byType(SnackBar), findsNothing);
  });
}
