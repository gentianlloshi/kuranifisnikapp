import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../../domain/entities/note.dart';
import 'note_editor_dialog.dart';

class NotesWidget extends StatefulWidget {
  const NotesWidget({super.key});

  @override
  State<NotesWidget> createState() => _NotesWidgetState();
}

class _NotesWidgetState extends State<NotesWidget> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        return Column(
          children: [
            // Search and filter bar
            _buildSearchAndFilterBar(context, noteProvider),
            
            // Notes list
            Expanded(
              child: _buildNotesList(context, noteProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilterBar(BuildContext context, NoteProvider noteProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Kërko në shënime...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        noteProvider.searchNotes('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              noteProvider.searchNotes(value);
            },
          ),
          
          const SizedBox(height: 12),
          
          // Tags filter
          if (noteProvider.tags.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: noteProvider.tags.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Të gjitha'),
                        selected: noteProvider.selectedTag == null,
                        onSelected: (_) => noteProvider.filterByTag(null),
                      ),
                    );
                  }
                  
                  final tag = noteProvider.tags[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(tag),
                      selected: noteProvider.selectedTag == tag,
                      onSelected: (_) => noteProvider.filterByTag(tag),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesList(BuildContext context, NoteProvider noteProvider) {
    if (noteProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (noteProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Gabim në ngarkimin e shënimeve',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              noteProvider.error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => noteProvider.loadNotes(),
              child: const Text('Provo përsëri'),
            ),
          ],
        ),
      );
    }

    final notes = noteProvider.filteredNotes;
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              noteProvider.searchQuery.isNotEmpty || noteProvider.selectedTag != null
                  ? 'Nuk u gjetën shënime'
                  : 'Nuk keni shënime ende',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              noteProvider.searchQuery.isNotEmpty || noteProvider.selectedTag != null
                  ? 'Provoni të ndryshoni kriteret e kërkimit'
                  : 'Shtoni shënime duke klikuar në një ajet',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (noteProvider.searchQuery.isNotEmpty || noteProvider.selectedTag != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => noteProvider.clearFilters(),
                child: const Text('Pastro filtrat'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return NoteListItem(
          note: note,
          onTap: () => _editNote(context, note),
          onDelete: () => _deleteNote(context, noteProvider, note),
        );
      },
    );
  }

  void _editNote(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (context) => NoteEditorDialog(
        note: note,
        onSave: (updatedNote) {
          context.read<NoteProvider>().updateNote(updatedNote);
        },
      ),
    );
  }

  void _deleteNote(BuildContext context, NoteProvider noteProvider, Note note) {
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
}

class NoteListItem extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteListItem({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(
          note.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Ajeti: ${note.verseKey}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
      Text(
              'Krijuar: ${_formatDate(note.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: note.tags.map((tag) => Chip(
                  label: Text(
                    tag,
                    style: theme.textTheme.bodySmall,
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
                onTap();
                break;
              case 'delete':
                onDelete();
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
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

