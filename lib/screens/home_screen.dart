import 'dart:async';
import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/context_theme_extensions.dart';
import '../models/note.dart';
import '../persistence/app_storage.dart';
import '../services/cloud_sync_service.dart';
import '../services/note_sync_engine.dart';
import '../services/sync_coordinator.dart';
import '../services/backup_service.dart';
import '../services/drive_account.dart';
import '../app/theme/app_typography.dart';
import '../repositories/task_repository.dart';
import '../widgets/home/notes_tree_list.dart';
import '../widgets/notes/note_action_menu.dart';
import '../widgets/notes/note_peek_preview_dialog.dart';
import 'note_detail_screen.dart';
import '../widgets/home/home_more_menu.dart';
import '../widgets/ideas/workspace_switch.dart';
import '../services/idea_brief.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onCreateNote;
  final VoidCallback? onStartReview;
  final ValueChanged<Note>? onOpenNote;
  final CloudSyncService? syncService;
  final NoteSyncEngine? syncEngine;
  final SyncCoordinator? syncCoordinator;
  final BackupService? backupService;
  final DriveAccount? driveAccount;

  const HomeScreen({
    super.key,
    this.onCreateNote,
    this.onStartReview,
    this.onOpenNote,
    this.syncService,
    this.syncEngine,
    this.syncCoordinator,
    this.backupService,
    this.driveAccount,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Note> _allNotes = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  StreamSubscription<List<Note>>? _notesSubscription;
  String _workspace = Note.notesWorkspace;
  final Map<String, String> _queries = {Note.notesWorkspace: '', Note.ideasWorkspace: ''};

  List<Note> get _workspaceNotes => inWorkspace(_allNotes, _workspace);

  @override
  void initState() {
    super.initState();
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
    _notesSubscription = repoScope.noteRepository.watchAllNotes().listen(
      (allNotes) {
        if (!mounted) return;
        setState(() {
          _allNotes = allNotes;
          _isLoading = false;
        });
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
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
    if (_workspace == Note.notesWorkspace && widget.onCreateNote != null) {
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
      workspace: _workspace,
      ideaStatus: _workspace == Note.ideasWorkspace ? 'Spark' : null,
    );

    await repoScope.noteRepository.saveNote(note);
    await _loadData();
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: RouteSettings(name: '/note/${note.id}'),
          builder: (context) =>
              NoteDetailScreen(noteId: note.id, initialNote: note),
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
        builder: (context) =>
            NoteDetailScreen(noteId: note.id, initialNote: note),
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

    final titlePrefix = note.title.isNotEmpty
        ? '${note.title} (Copy)'
        : 'Untitled (Copy)';
    final duplicate = Note(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      parentId: note.parentId,
      title: titlePrefix,
      content: note.content,
      formatting: note.formatting,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      workspace: note.workspace,
      ideaStatus: note.ideaStatus,
      handedOffTo: note.handedOffTo,
      handedOffAt: note.handedOffAt,
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
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ),
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
        body: const Center(child: SizedBox.shrink()),
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
                  padding: const EdgeInsets.only(
                    left: 20.0,
                    right: 8.0,
                    top: 12.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _workspace == Note.ideasWorkspace ? 'Ideas' : 'Notes',
                              style: AppTypography.display(
                                color: context.appTextPrimary,
                              ),
                            ),
                            if (widget.syncService != null)
                              ListenableBuilder(
                                listenable: widget.syncService!,
                                builder: (context, _) => Text(
                                  syncStatusText(widget.syncService!.state),
                                  style: AppTypography.uiLabel(
                                    fontSize: 12.0,
                                    color: context.appTextSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _buildMoreMenu(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 4.0),
                  child: WorkspaceSwitch(
                    workspace: _workspace,
                    onChanged: (workspace) => setState(() {
                      _queries[_workspace] = _searchQuery;
                      _workspace = workspace;
                      _searchQuery = _queries[workspace] ?? '';
                      _searchController.text = _searchQuery;
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 8.0),
                  child: _buildSearchField(),
                ),
                Expanded(
                  child: NotesTreeList(
                    notes: _workspaceNotes,
                    searchQuery: _searchQuery,
                    onCreateNote: _handleCreateNote,
                    onOpenNote: _handleOpenNote,
                    onLongPressNote: _showNoteActionMenu,
                    ideas: _workspace == Note.ideasWorkspace,
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
          Icon(
            Icons.search_rounded,
            size: 18.0,
            color: context.appTextSecondary,
          ),
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
                hintText: _workspace == Note.ideasWorkspace ? 'Search ideas' : 'Search',
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
              child: Icon(
                Icons.cancel_rounded,
                size: 16.0,
                color: context.appTextTertiary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoreMenu() {
    final actions = HomeMoreMenuActions(
      context: context,
      taskRepository: LocalTaskRepository(storage: AppStorage.instance),
      syncService: widget.syncService,
      syncEngine: widget.syncEngine,
      syncCoordinator: widget.syncCoordinator,
      backupService: widget.backupService,
      driveAccount: widget.driveAccount,
      onStartReview: widget.onStartReview,
    );
    return HomeMoreMenu(
      onSignIn: actions.openSignIn,
      onReview: actions.openReview,
      onTasks: actions.openTasks,
      onSync: actions.sync,
      onTheme: actions.toggleTheme,
      onSettings: actions.openSettings,
    );
  }
}
