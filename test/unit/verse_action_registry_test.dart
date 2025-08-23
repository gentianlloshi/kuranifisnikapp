import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kurani_fisnik_app/presentation/widgets/verse_action_registry.dart';
import 'package:kurani_fisnik_app/domain/entities/verse.dart';
import 'package:kurani_fisnik_app/presentation/providers/memorization_provider.dart';

// Minimal fake that matches MemorizationProvider API expected by registry
class FakeMemorizationProvider extends MemorizationProvider {
  final Set<String> _set = {};
  @override
  bool containsVerse(int s, int v) => _set.contains('$s:$v');
  // Bypass any Hive calls in base class by shadowing behavior
  @override
  Future<void> addVerse(int surah, int verse) async { _set.add('$surah:$verse'); notifyListeners(); }
  @override
  Future<void> removeVerse(int surah, int verse) async { _set.remove('$surah:$verse'); notifyListeners(); }
  void add(int s, int v) { _set.add('$s:$v'); notifyListeners(); }
  void remove(int s, int v) { _set.remove('$s:$v'); notifyListeners(); }
}

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('memorize add/remove visibility flips', (tester) async {
  final mem = FakeMemorizationProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers:[
          ChangeNotifierProvider<VerseActionRegistry>(create:(_)=>VerseActionRegistry()..registerAll(buildDefaultVerseActions())),
          ChangeNotifierProvider<MemorizationProvider>.value(value: mem),
        ],
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    // Obtain a context by pumping a Builder
    late BuildContext captured;
    await tester.pumpWidget(
      MultiProvider(
        providers:[
          ChangeNotifierProvider<VerseActionRegistry>(create:(_)=>VerseActionRegistry()..registerAll(buildDefaultVerseActions())),
          ChangeNotifierProvider<MemorizationProvider>.value(value: mem),
        ],
        child: MaterialApp(home: Builder(builder:(ctx){ captured = ctx; return const SizedBox.shrink(); })),
      ),
    );
    final registry = Provider.of<VerseActionRegistry>(captured, listen: false);
    final verse = const Verse(surahId:1, verseNumber:1, arabicText:'', translation:null, transliteration:null, verseKey:'1:1');
    final before = registry.actionsFor(captured, verse);
    expect(before.any((a)=>a.id=='memorize'), true);
    expect(before.any((a)=>a.id=='remove_memorize'), false);
    mem.add(1,1);
    await tester.pump();
    final after = registry.actionsFor(captured, verse);
    expect(after.any((a)=>a.id=='memorize'), false);
    expect(after.any((a)=>a.id=='remove_memorize'), true);
  });
}
