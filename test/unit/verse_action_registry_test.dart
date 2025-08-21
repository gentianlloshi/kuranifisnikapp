import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kurani_fisnik_app/presentation/widgets/verse_action_registry.dart';

// Minimal mock providers
class _DummyVerse {
  final int surahNumber; final int number; final String verseKey; final String textArabic; _DummyVerse(this.surahNumber,this.number): verseKey='$surahNumber:$number', textArabic='';
}
class MockMemorizationProvider extends ChangeNotifier { final Set<String> _set={}; bool containsVerse(int s,int v)=>_set.contains('$s:$v'); void add(int s,int v){_set.add('$s:$v'); notifyListeners();} void remove(int s,int v){_set.remove('$s:$v'); notifyListeners();}}

void main(){
  testWidgets('memorize add/remove visibility flips', (tester) async {
    final mem = MockMemorizationProvider();
    final verse = _DummyVerse(1,1);
    await tester.pumpWidget(
      MultiProvider(
        providers:[
          ChangeNotifierProvider<VerseActionRegistry>(create:(_)=>VerseActionRegistry()..registerAll(buildDefaultVerseActions())),
          ChangeNotifierProvider<MockMemorizationProvider>.value(value: mem),
        ],
        child: MaterialApp(home: Builder(builder:(ctx){
          final registry = Provider.of<VerseActionRegistry>(ctx,listen:false);
          final actionsBefore = registry.actionsFor(ctx, Verse(surahId:1, verseNumber:1, arabicText:'', translation:null, transliteration:null, verseKey: verse.verseKey));
          expect(actionsBefore.any((a)=>a.id=='memorize'), true);
          expect(actionsBefore.any((a)=>a.id=='remove_memorize'), false);
          mem.add(1,1);
          final actionsAfter = registry.actionsFor(ctx, Verse(surahId:1, verseNumber:1, arabicText:'', translation:null, transliteration:null, verseKey: verse.verseKey));
          expect(actionsAfter.any((a)=>a.id=='memorize'), false);
          expect(actionsAfter.any((a)=>a.id=='remove_memorize'), true);
          return const SizedBox.shrink();
        })),
    );
  });
}
