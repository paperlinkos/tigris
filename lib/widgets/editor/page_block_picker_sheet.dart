import 'package:flutter/material.dart';
import '../../app/di/repository_scope.dart';
import '../../models/note.dart';
import '../../repositories/note_repository.dart';

class PageBlockPickerSheet extends StatefulWidget {
  final String currentNoteId;
  final String? parentStreamId;
  final NoteRepository? noteRepository;

  const PageBlockPickerSheet({
    super.key,
    required this.currentNoteId,
    this.parentStreamId,
    this.noteRepository,
  });

  @override
  State<PageBlockPickerSheet> createState() => _PageBlockPickerSheetState();
}

class _PageBlockPickerSheetState extends State<PageBlockPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  NoteRepository? get _effectiveRepo =>
      widget.noteRepository ?? RepositoryScope.maybeOf(context)?.noteRepository;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createNewNoteAndSelect() async {
    final titleController = TextEditingController();
    final repo = _effectiveRepo;
    if (repo == null) return;

    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: const Text('Create New Page Note'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter note title...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(titleController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (title != null && title.isNotEmpty && mounted) {
      final now = DateTime.now();
      final newNote = Note(
        id: 'note_${now.millisecondsSinceEpoch}',
        title: title,
        content: '',
        parentId: widget.currentNoteId.isNotEmpty
            ? widget.currentNoteId
            : widget.parentStreamId,
        createdAt: now,
        updatedAt: now,
      );
      await repo.saveNote(newNote);
      if (mounted) {
        Navigator.of(context).pop(newNote.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = _effectiveRepo;

    return SafeArea(
      child: AnimatedPadding(
        padding: MediaQuery.of(context).viewInsets,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Row(
                children: [
                  Text(
                    'Link to Page',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search existing notes...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_circle_outline, size: 20),
                title: const Text(
                  'Create New Page Note',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: _createNewNoteAndSelect,
              ),
              const Divider(height: 1),
              const SizedBox(height: 4),
              Expanded(
                child: repo == null
                    ? const Center(child: Text('Repository unavailable'))
                    : StreamBuilder<List<Note>>(
                        stream: repo.watchAllNotes(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final notes = snapshot.data!
                              .where((n) => n.id != widget.currentNoteId)
                              .where((n) =>
                                  _searchQuery.isEmpty ||
                                  n.title.toLowerCase().contains(_searchQuery) ||
                                  n.content.toLowerCase().contains(_searchQuery))
                              .toList();

                          if (notes.isEmpty) {
                            return const Center(
                              child: Text('No existing notes found.'),
                            );
                          }

                      return ListView.separated(
                        itemCount: notes.length,
                        separatorBuilder: (ctx, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(
                              note.title.isEmpty ? 'Untitled Note' : note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              note.content.replaceAll('\n', ' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.of(context).pop(note.id),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
