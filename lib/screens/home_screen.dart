import 'dart:async';
import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/context_theme_extensions.dart';
import '../models/note.dart';
import '../persistence/preferences_storage.dart';
import '../controllers/theme_controller.dart';
import '../repositories/offline_first_note_repository.dart';
import '../repositories/task_repository.dart';
import '../views/tasks_view.dart';
import '../app/theme/app_typography.dart';
import '../widgets/home/notes_tree_list.dart';
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
  List<Note> _allNotes = [];
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
      setState(() {
        _allNotes = allNotes;
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

    final allNotes = await repoScope.noteRepository.getAllNotes();

    if (mounted) {
      setState(() {
        _allNotes = allNotes;
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

  Future<void> _handleOpenTasks() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: context.appBg,
          appBar: AppBar(
            backgroundColor: context.appBg,
            title: Text('Tasks', style: AppTypography.uiHeadline(color: context.appTextPrimary)),
          ),
          body: TasksView(taskRepository: _taskRepository, searchQuery: ''),
        ),
      ),
    );
  }

  Future<void> _handleSync() async {
    final repo = RepositoryScope.maybeOf(context)?.noteRepository;
    if (repo is OfflineFirstNoteRepository) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syncing notes...')),
      );
      await repo.syncWithCloud();
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

    return Scaffold(
      backgroundColor: context.appBg,
      floatingActionButton: FloatingActionButton(
        key: const Key('new_note_button'),
        onPressed: _handleCreateNote,
        tooltip: 'New note',
        elevation: 1.0,
        backgroundColor: context.appTextPrimary,
        foregroundColor: context.appBg,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit_outlined, size: 22.0),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 8.0, top: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notes',
                          style: AppTypography.display(color: context.appTextPrimary),
                        ),
                      ),
                      _buildMoreMenu(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 8.0),
                  child: _buildSearchField(),
                ),
                Expanded(
                  child: NotesTreeList(
                    notes: _allNotes,
                    searchQuery: _searchQuery,
                    onCreateNote: _handleCreateNote,
                    onOpenNote: _handleOpenNote,
                    onLongPressNote: _showNoteActionMenu,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 38.0,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: context.appSurfaceSubtle,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18.0, color: context.appTextSecondary),
          const SizedBox(width: 8.0),
          Expanded(
            child: TextField(
              key: const Key('notes_search_field'),
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: AppTypography.uiLabel(
                fontSize: 15.0,
                fontWeight: FontWeight.w400,
                color: context.appTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: AppTypography.uiLabel(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w400,
                  color: context.appTextSecondary,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Icon(Icons.cancel_rounded, size: 16.0, color: context.appTextTertiary),
            ),
        ],
      ),
    );
  }

  Widget _buildMoreMenu() {
    final themeController = ThemeControllerScope.maybeOf(context);
    return PopupMenuButton<String>(
      key: const Key('home_more_menu'),
      tooltip: 'More',
      icon: Icon(Icons.more_horiz_rounded, color: context.appTextPrimary),
      color: context.appSurface,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: context.appBorder),
      ),
      onSelected: (value) {
        switch (value) {
          case 'review':
            _handleOpenReview();
          case 'tasks':
            _handleOpenTasks();
          case 'sync':
            _handleSync();
          case 'theme':
            themeController?.toggleDarkMode();
          case 'settings':
            _handleOpenSettings();
        }
      },
      itemBuilder: (context) => [
        _menuItem('review', 'Review'),
        _menuItem('tasks', 'Tasks'),
        _menuItem('sync', 'Sync notes'),
        if (themeController != null)
          _menuItem('theme', context.isDarkMode ? 'Light mode' : 'Dark mode'),
        _menuItem('settings', 'Settings'),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label) {
    return PopupMenuItem<String>(
      value: value,
      height: 42.0,
      child: Text(
        label,
        style: AppTypography.uiLabel(
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
          color: context.appTextPrimary,
        ),
      ),
    );
  }
}
