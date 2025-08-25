import 'package:flutter/material.dart';
import '../../domain/entities/note.dart';

class NoteEditorDialog extends StatefulWidget {
  final Note? note;
  final String? verseKey;
  final Function(Note) onSave;

  const NoteEditorDialog({
    super.key,
    this.note,
    this.verseKey,
    required this.onSave,
  });

  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  late TextEditingController _contentController;
  late TextEditingController _tagsController;
  final _formKey = GlobalKey<FormState>();
  
  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _tagsController = TextEditingController(
      text: widget.note?.tags.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isEditing ? Icons.edit : Icons.note_add,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Ndrysho shënimin' : 'Shto shënim të ri',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Verse info
            if (widget.verseKey != null || widget.note?.verseKey != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmark,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ajeti: ${widget.verseKey ?? widget.note!.verseKey}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Content field
                    Text(
                      'Përmbajtja e shënimit',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Shkruani shënimin tuaj këtu...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ju lutem shkruani përmbajtjen e shënimit';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Tags field
                    Text(
                      'Etiketat (të ndara me presje)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        hintText: 'p.sh. dua, sabër, namaz',
                        border: OutlineInputBorder(),
                        helperText: 'Ndani etiketat me presje (,)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Anulo'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveNote,
                  child: Text(isEditing ? 'Ruaj ndryshimet' : 'Shto shënimin'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveNote() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final content = _contentController.text.trim();
    final tagsText = _tagsController.text.trim();
    final tags = tagsText.isNotEmpty
        ? tagsText.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList()
        : <String>[];

    final Note noteToSave;
    
    if (isEditing) {
      noteToSave = widget.note!.copyWith(
        content: content,
        tags: tags,
        updatedAt: DateTime.now(),
      );
    } else {
      // For new notes, the provider will handle ID generation and timestamps
      noteToSave = Note(
        id: '', // Will be generated by the use case
        verseKey: widget.verseKey!,
        content: content,
        tags: tags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    widget.onSave(noteToSave);
    Navigator.of(context).pop();
  }
}

