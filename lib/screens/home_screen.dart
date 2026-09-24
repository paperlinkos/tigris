import 'dart:async';
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

import '../app/theme/app_typography.dart';
import '../widgets/notes/note_action_menu.dart';
import '../widgets/notes/note_peek_preview_dialog.dart';
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
  List<Note> _standaloneNotes = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late final TaskRepository _taskRepository;
  StreamSubscription<List<Note>>? _notesSubscription;

  @override
  void initState() {
    super.initState();
    _taskRepository = LocalTaskRepository(storage: PreferencesStorage());
  }

  @override
  void dispose() {
    _notesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToNotes();
  }

  Future<void> reload() => _loadData();

  void _subscribeToNotes() {
    final repoScope = RepositoryScope.maybeOf(context);
    if (repoScope == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    _notesSubscription?.cancel();
    _notesSubscription = repoScope.noteRepository.watchAllNotes().listen((allNotes) {
      if (!mounted) return;
      final recents = List<Note>.from(allNotes)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final rootNotes = allNotes.where((n) => n.parentId == null || n.isRoot).toList();
      final streams = rootNotes.where((n) => n.childrenIds.isNotEmpty).toList();
      final standalone = rootNotes.where((n) => n.childrenIds.isEmpty).toList();

      setState(() {
        _recentNotes = recents.take(10).toList();
        _streamNotes = streams;
        _standaloneNotes = standalone;
        _isLoading = false;
      });
    }, onError: (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

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
    final streams = roots.where((n) => n.childrenIds.isNotEmpty).toList();
    final standalone = roots.where((n) => n.childrenIds.isEmpty).toList();

    if (mounted) {
      setState(() {
        _recentNotes = recents;
        _streamNotes = streams;
        _standaloneNotes = standalone;
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

  Future<void> _showNoteActionMenu(Note note) async {
    final action = await NotePeekPreviewDialog.show(context, note: note);
    if (action == null || !mounted) return;

    switch (action) {
      case NoteActionType.open:
        await _handleOpenNote(note);
        break;
      case NoteActionType.delete:
        await _confirmAndDeleteNote(note);
        break;
      case NoteActionType.duplicate:
        await _handleDuplicateNote(note);
        break;
      case NoteActionType.pin:
      case NoteActionType.archive:
      case NoteActionType.share:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${action.label} completed'),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
    }
  }

  Future<void> _handleDuplicateNote(Note note) async {
    final repoScope = RepositoryScope.maybeOf(context);
    if (repoScope == null) return;

    final titlePrefix = note.title.isNotEmpty ? '${note.title} (Copy)' : 'Untitled (Copy)';
    final duplicate = Note(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      parentId: note.parentId,
      title: titlePrefix,
      content: note.content,
      formatting: note.formatting,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repoScope.noteRepository.saveNote(duplicate);
  }

  Future<void> _confirmAndDeleteNote(Note note) async {
    final totalChildren = note.childrenIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: context.appBorderSubtle),
        ),
        title: Text(
          'Delete Note',
          style: AppTypography.title(
            fontSize: 20.0,
            color: context.appTextPrimary,
          ),
        ),
        content: Text(
          totalChildren > 0
              ? 'This note has $totalChildren ${totalChildren == 1 ? 'subpage' : 'subpages'}. Deleting it will permanently delete this note and all nested descendants.'
              : 'Are you sure you want to delete this note?',
          style: AppTypography.body(
            fontSize: 14.5,
            color: context.appTextSecondary,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.uiLabel(
                fontSize: 14.0,
                color: context.appTextSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTextPrimary,
              foregroundColor: context.appBg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.0),
              ),
            ),
            child: Text(
              'Delete',
              style: AppTypography.uiHeadline(
                fontSize: 14.0,
                color: context.appBg,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repoScope = RepositoryScope.maybeOf(context);
      if (repoScope != null) {
        await repoScope.noteRepository.deleteNote(note.id);
      }
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
        notes: _standaloneNotes,
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
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                              onLongPressNote: _showNoteActionMenu,
                            ),
                            const SizedBox(height: 28.0),
                          ],

                          RecentNotesSection(
                            notes: filteredNotes,
                            onCreateNote: _handleCreateNote,
                            onOpenNote: _handleOpenNote,
                            onLongPressNote: _showNoteActionMenu,
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
