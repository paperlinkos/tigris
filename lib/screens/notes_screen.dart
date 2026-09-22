import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../widgets/calm_scaffold.dart';
import '../widgets/notes/note_list_item.dart';
import 'note_detail_screen.dart';

class NotesScreen extends StatefulWidget {
  final NoteRepository? noteRepository;

  const NotesScreen({
    super.key,
    this.noteRepository,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _rootNotes = [];
  List<Note> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  NoteRepository? get _repo =>
      widget.noteRepository ?? RepositoryScope.maybeOf(context)?.noteRepository;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRootNotes();
  }

  Future<void> _loadRootNotes() async {
    final repo = _repo;
    if (repo == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final notes = await repo.getRootNotes();
    if (mounted) {
      setState(() {
        _rootNotes = notes;
        _isLoading = false;
      });
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    } else {
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    final repo = _repo;
    if (repo == null) return;

    final results = await repo.searchNotes(query);
    if (mounted && _searchController.text.trim() == query) {
      setState(() {
        _isSearching = true;
        _searchResults = results;
      });
    }
  }

  Future<void> _createRootNote() async {
    final repo = _repo;
    if (repo == null) return;

    final newNote = Note(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: '',
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repo.saveNote(newNote);

    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: RouteSettings(name: '/note/${newNote.id}'),
          builder: (context) => NoteDetailScreen(
            noteId: newNote.id,
            initialNote: newNote,
            noteRepository: repo,
          ),
        ),
      );
      if (mounted) {
        await _loadRootNotes();
      }
    }
  }

  Future<void> _openNote(Note note) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/note/${note.id}'),
        builder: (context) => NoteDetailScreen(
          noteId: note.id,
          initialNote: note,
          noteRepository: _repo,
        ),
      ),
    );

    if (mounted) {
      await _loadRootNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CalmScaffold(
      title: 'NOTES',
      trailingHeaderAction: InkWell(
        onTap: _createRootNote,
        borderRadius: BorderRadius.circular(6.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 16.0, color: AppColors.textPrimary),
              const SizedBox(width: 4.0),
              Text(
                'New note',
                style: AppTypography.uiHeadline(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Minimal Discovery & Search Bar
                _buildSearchBar(),
                const SizedBox(height: 20.0),

                // Content: Search results or Hierarchy
                if (_isSearching)
                  _buildSearchResults()
                else if (_rootNotes.isEmpty)
                  _buildEmptyState()
                else
                  _buildNotesList(),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 18.0,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: AppTypography.subtitle(
                fontSize: 14.5,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Search notes, titles, or thoughts...',
                hintStyle: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14.0,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12.0),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 16.0),
              color: AppColors.textTertiary,
              splashRadius: 16.0,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No matches found.',
              style: AppTypography.title(
                fontSize: 18.0,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              'No notes match "${_searchController.text.trim()}".',
              style: AppTypography.subtitle(
                fontSize: 14.0,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: Text(
            '${_searchResults.length} ${_searchResults.length == 1 ? 'RESULT' : 'RESULTS'}',
            style: AppTypography.uiLabel(
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ).copyWith(letterSpacing: 1.1),
          ),
        ),
        const SizedBox(height: 8.0),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchResults.length,
          separatorBuilder: (context, index) => const Divider(
            color: AppColors.borderSubtle,
            height: 1.0,
          ),
          itemBuilder: (context, index) {
            final note = _searchResults[index];
            return NoteListItem(
              note: note,
              onTap: () => _openNote(note),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All thoughts start here.',
            style: AppTypography.title(
              fontSize: 22.0,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Create a note to begin.',
            style: AppTypography.body(
              fontSize: 15.0,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24.0),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48.0),
            child: InkWell(
              onTap: _createRootNote,
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 18.0, color: AppColors.textPrimary),
                    const SizedBox(width: 6.0),
                    Flexible(
                      child: Text(
                        'New note',
                        style: AppTypography.uiHeadline(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _rootNotes.length,
      separatorBuilder: (context, index) => const Divider(
        color: AppColors.borderSubtle,
        height: 1.0,
      ),
      itemBuilder: (context, index) {
        final note = _rootNotes[index];
        return NoteListItem(
          note: note,
          onTap: () => _openNote(note),
        );
      },
    );
  }
}
