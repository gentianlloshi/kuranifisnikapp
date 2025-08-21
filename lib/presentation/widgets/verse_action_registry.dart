import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/verse.dart';
import '../providers/bookmark_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/memorization_provider.dart';
import '../providers/note_provider.dart';
import 'note_editor_dialog.dart';
import 'sheet_header.dart';
import '../theme/theme.dart';

typedef VerseActionHandler = Future<void> Function(BuildContext context, Verse verse);

class VerseAction {
  final String id;
  final String label;
  final IconData icon;
  final VerseActionHandler handler;
  final bool Function(BuildContext context, Verse verse)? visibleIf;
  VerseAction({required this.id, required this.label, required this.icon, required this.handler, this.visibleIf});
}

class VerseActionRegistry extends ChangeNotifier {
  final List<VerseAction> _actions = [];
  List<VerseAction> actionsFor(BuildContext ctx, Verse v) => _actions.where((a) => a.visibleIf?.call(ctx, v) ?? true).toList(growable: false);
  void register(VerseAction action) { if (_actions.any((a) => a.id == action.id)) return; _actions.add(action); notifyListeners(); }
  void registerAll(Iterable<VerseAction> acts) { for (final a in acts) register(a); }
  void clear() { _actions.clear(); notifyListeners(); }
}

class VerseActionsSheet extends StatelessWidget {
  final Verse verse;
  const VerseActionsSheet({super.key, required this.verse});
  @override
  Widget build(BuildContext context) {
    final registry = Provider.of<VerseActionRegistry>(context, listen: false);
    final items = registry.actionsFor(context, verse);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: 'Ajeti ${verse.number}',
            subtitle: 'Sure ${verse.surahNumber}',
            leadingIcon: Icons.menu_book,
            onClose: () => Navigator.of(context).maybePop(),
          ),
          ...items.map((a) => ListTile(
                leading: Icon(a.icon),
                title: Text(a.label),
                onTap: () async {
                  Navigator.pop(context);
                  await a.handler(context, verse);
                },
              )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

List<VerseAction> buildDefaultVerseActions() => [
  VerseAction(
    id: 'play',
    label: 'Luaj Ajetin',
    icon: Icons.play_arrow,
    handler: (ctx, v) async { ctx.read<AudioProvider>().playVerse(v); },
  ),
  VerseAction(
    id: 'bookmark',
    label: 'Shto / Hiq nga Favoritet',
    icon: Icons.bookmark_border,
    handler: (ctx, v) async { await ctx.read<BookmarkProvider>().toggleBookmark(v.verseKey); },
  ),
  VerseAction(
    id: 'memorize',
    label: 'Shto në Memorizim',
    icon: Icons.psychology,
    visibleIf: (c,v) => !c.read<MemorizationProvider>().containsVerse(v.surahNumber, v.number),
    handler: (ctx, v) async { await ctx.read<MemorizationProvider>().addVerse(v.surahNumber, v.number); },
  ),
  VerseAction(
    id: 'remove_memorize',
    label: 'Hiq nga Memorizimi',
    icon: Icons.psychology_alt,
    visibleIf: (c,v) => c.read<MemorizationProvider>().containsVerse(v.surahNumber, v.number),
    handler: (ctx, v) async { await ctx.read<MemorizationProvider>().removeVerse(v.surahNumber, v.number); },
  ),
  VerseAction(
    id: 'note',
    label: 'Shënim',
    icon: Icons.note_add,
    handler: (ctx, v) async { showDialog(context: ctx, builder: (d)=> NoteEditorDialog(verseKey: v.verseKey, onSave: (note){ final np = ctx.read<NoteProvider>(); if (note.id.isEmpty) { np.addNote(note.verseKey, note.content, tags: note.tags); } else { np.updateNote(note); } })); },
  ),
  VerseAction(
    id: 'copy',
    label: 'Kopjo Tekstin',
    icon: Icons.copy,
  handler: (ctx, v) async { final text = v.textArabic; ctx.read<AppStateProvider>().enqueueSnack('U kopjua (${text.length} shkronja)'); },
  ),
];
