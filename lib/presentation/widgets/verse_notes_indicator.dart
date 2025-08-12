import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../../domain/entities/note.dart';
import 'note_editor_dialog.dart';

class VerseNotesIndicator extends StatelessWidget {
  final String verseKey;

  const VerseNotesIndicator({
    super.key,
    required this.verseKey,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final notesCount = noteProvider.getNotesCountForVerse(verseKey);
        final hasNotes = notesCount > 0;

        return IconButton(
          icon: Badge(
            isLabelVisible: hasNotes,
            label: Text(notesCount.toString()),
            child: Icon(
              hasNotes ? Icons.note : Icons.note_add,
              color: hasNotes ? Theme.of(context).primaryColor : null,
            ),
          ),
          onPressed: () => _showNotesBottomSheet(context, noteProvider),
          tooltip: hasNotes ? 'Shiko shënimet ($notesCount)' : 'Shto shënim',
        );
      },
    );
  }

  void _showNotesBottomSheet(BuildContext context, NoteProvider noteProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => VerseNotesBottomSheet(
        verseKey: verseKey,
        noteProvider: noteProvider,
      ),
    );
  }
}

class VerseNotesBottomSheet extends StatelessWidget {
  final String verseKey;
  final NoteProvider noteProvider;

  const VerseNotesBottomSheet({
    super.key,
    required this.verseKey,
    required this.noteProvider,
  });

  @override
  Widget build(BuildContext context) {
    final notes = noteProvider.getNotesForVerseSync(verseKey);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.note,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shënimet për ajeti $verseKey',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (notes.isNotEmpty)
                            Text(
                              '${notes.length} shënim${notes.length > 1 ? 'e' : ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _addNote(context),
                      icon: const Icon(Icons.add),
                      tooltip: 'Shto shënim të ri',
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Notes list
              Expanded(
                child: notes.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return _buildNoteItem(context, note);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Nuk ka shënime për këtë ajet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Shtoni shënimin e parë duke klikuar butonin +',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _addNote(context),
              icon: const Icon(Icons.add),
              label: const Text('Shto shënim'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(BuildContext context, Note note) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(
          note.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Krijuar: ${_formatDate(note.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: note.tags.map((tag) => Chip(
                  label: Text(
                    tag,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editNote(context, note);
                break;
              case 'delete':
                _deleteNote(context, note);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Ndrysho'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Fshi', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => _editNote(context, note),
      ),
    );
  }

  void _addNote(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => NoteEditorDialog(
        verseKey: verseKey,
        onSave: (note) {
          noteProvider.addNote(verseKey, note.content, tags: note.tags);
        },
      ),
    );
  }

  void _editNote(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (context) => NoteEditorDialog(
        note: note,
        onSave: (updatedNote) {
          noteProvider.updateNote(updatedNote);
        },
      ),
    );
  }

  void _deleteNote(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fshi shënimin'),
        content: const Text('A jeni të sigurt që dëshironi të fshini këtë shënim?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anulo'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              noteProvider.deleteNote(note.id);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Fshi'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

