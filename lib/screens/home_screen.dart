import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/context_theme_extensions.dart';
import '../models/note.dart';
import '../persistence/preferences_storage.dart';
import '../repositories/task_repository.dart';
import '../views/tasks_view.dart';
import '../widgets/home/app_sidebar_drawer.dart';
import '../widgets/home/bottom_control_bar.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/recent_notes_section.dart';
import '../widgets/home/recent_square_cards.dart';

import 'note_detail_screen.dart';
import 'review_session_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onCreateNote;
  final VoidCallback? onStartReview;
  final ValueChanged<Note>? onOpenNote;

  const HomeScreen({
    super.key,
    this.onCreateNote,
    this.onStartReview,
    this.onOpenNote,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  HomeViewMode _viewMode = HomeViewMode.notes;
  List<Note> _recentNotes = [];
  List<Note> _streamNotes = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late final TaskRepository _taskRepository;

  @override
  void initState() {
    super.initState();
    _taskRepository = LocalTaskRepository(storage: PreferencesStorage());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> reload() => _loadData();

  Future<void> _loadData() async {
    final repoScope = RepositoryScope.maybeOf(context);
    if (repoScope == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final recents = await repoScope.noteRepository.getRecentNotes(limit: 10);
    final roots = await repoScope.noteRepository.getRootNotes();
    final streams = roots.where((n) => n.childrenIds.isNotEmpty || n.isRoot).toList();

    if (mounted) {
      setState(() {
        _recentNotes = recents;
        _streamNotes = streams;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCreateNote() async {
    if (widget.onCreateNote != null) {
      widget.onCreateNote!();
      return;
    }

    final repoScope = RepositoryScope.maybeOf(context);
    if (repoScope == null) return;

    final note = Note(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      title: '',
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repoScope.noteRepository.saveNote(note);
    await _loadData();
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: RouteSettings(name: '/note/${note.id}'),
          builder: (context) => NoteDetailScreen(
            noteId: note.id,
            initialNote: note,
          ),
        ),
      );
      if (mounted) {
        await _loadData();
      }
    }
  }

  Future<void> _handleOpenNote(Note note) async {
    if (widget.onOpenNote != null) {
      widget.onOpenNote!(note);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/note/${note.id}'),
        builder: (context) => NoteDetailScreen(
          noteId: note.id,
          initialNote: note,
        ),
      ),
    );
    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _handleOpenSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  Future<void> _handleOpenReview() async {
    if (widget.onStartReview != null) {
      widget.onStartReview!();
      return;
    }

    final repoScope = RepositoryScope.maybeOf(context);
    if (repoScope == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RepositoryScope(
          noteRepository: repoScope.noteRepository,
          reviewRepository: repoScope.reviewRepository,
          flashcardRepository: repoScope.flashcardRepository,
          quizRepository: repoScope.quizRepository,
          child: const ReviewSessionScreen(),
        ),
      ),
    );
    if (mounted) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: const Center(
          child: SizedBox.shrink(),
        ),
      );
    }

    final filteredNotes = _searchQuery.isEmpty
        ? _recentNotes
        : _recentNotes.where((n) {
            final q = _searchQuery.toLowerCase();
            return n.title.toLowerCase().contains(q) ||
                n.content.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: context.appBg,
      drawer: AppSidebarDrawer(
        streams: _streamNotes,
        onOpenNote: _handleOpenNote,
        onOpenSettings: _handleOpenSettings,
        onOpenReview: _handleOpenReview,
      ),
      bottomNavigationBar: BottomControlBar(
        searchController: _searchController,
        onSearchChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        onCreateNote: _handleCreateNote,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: HomeHeader(
                viewMode: _viewMode,
                onViewModeChanged: (mode) {
                  setState(() {
                    _viewMode = mode;
                  });
                },
              ),
            ),

            Expanded(
              child: _viewMode == HomeViewMode.tasks
                  ? TasksView(
                      taskRepository: _taskRepository,
                      searchQuery: _searchQuery,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_searchQuery.isEmpty && _recentNotes.isNotEmpty) ...[
                            RecentSquareCards(
                              recentNotes: _recentNotes,
                              onOpenNote: _handleOpenNote,
                            ),
                            const SizedBox(height: 28.0),
                          ],

                          RecentNotesSection(
                            notes: filteredNotes,
                            onCreateNote: _handleCreateNote,
                            onOpenNote: _handleOpenNote,
                          ),
                          const SizedBox(height: 36.0),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
