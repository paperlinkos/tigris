import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../models/note.dart';
import '../../persistence/app_storage.dart';
import '../../repositories/note_repository.dart';
import '../../repositories/task_repository.dart';
import '../../screens/note_detail_screen.dart';
import '../../services/backup_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/drive_account.dart';
import '../../services/note_sync_engine.dart';
import '../../services/sync_coordinator.dart';
import '../../widgets/home/home_more_menu.dart';
import '../../widgets/home/notes_tree_list.dart';

const double desktopBreakpoint = 900;

class DesktopShell extends StatefulWidget {
  final NoteRepository noteRepository;
  final CloudSyncService? syncService;
  final NoteSyncEngine? syncEngine;
  final SyncCoordinator? syncCoordinator;
  final BackupService? backupService;
  final DriveAccount? driveAccount;
  final VoidCallback? onStartReview;

  const DesktopShell({super.key, required this.noteRepository, this.syncService, this.syncEngine, this.syncCoordinator, this.backupService, this.driveAccount, this.onStartReview});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  List<Note> _notes = [];
  String? _openNoteId;
  String _query = '';
  double _sidebarWidth = 280;
  bool _sidebarHidden = false;
  bool _dividerActive = false;
  bool _openedInitialNote = false;
  String? _openNoteParentId;
  StreamSubscription<List<Note>>? _subscription;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = widget.noteRepository.watchAllNotes().listen(_receiveNotes);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async => _receiveNotes(await widget.noteRepository.getAllNotes());

  void _receiveNotes(List<Note> notes) {
    if (!mounted) return;
    final hasOpen = _openNoteId != null && notes.any((note) => note.id == _openNoteId);
    setState(() {
      _notes = notes;
      if (!_openedInitialNote) {
        _openedInitialNote = true;
        _openNoteId = _mostRecentId(notes);
        _openNoteParentId = _noteById(_openNoteId, notes)?.parentId;
      } else if (_openNoteId != null && !hasOpen) {
        _selectAfterRemoval(notes);
      }
    });
  }

  Note? _noteById(String? id, [List<Note>? notes]) {
    if (id == null) return null;
    for (final note in notes ?? _notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  String? _mostRecentId([List<Note>? notes]) {
    final sorted = [...(notes ?? _notes)]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.isEmpty ? null : sorted.first.id;
  }

  void _selectAfterRemoval(List<Note> notes) {
    final parent = _openNoteParentId;
    _openNoteId = parent != null && notes.any((note) => note.id == parent) ? parent : _mostRecentId(notes);
    _openNoteParentId = _noteById(_openNoteId, notes)?.parentId;
  }

  void _open(String id) {
    final note = _noteById(id);
    setState(() {
      _openNoteId = id;
      _openNoteParentId = note?.parentId;
      _query = '';
      _searchController.clear();
    });
  }

  Future<void> _createNote() async {
    final now = DateTime.now();
    final note = Note(id: 'note_${now.millisecondsSinceEpoch}', title: '', content: '', createdAt: now, updatedAt: now);
    await widget.noteRepository.saveNote(note);
    if (mounted) _open(note.id);
  }

  // The notes stream may have already moved on from the deleted note.
  void _afterDelete(String deletedId) {
    if (_openNoteId != deletedId) return;
    setState(() => _selectAfterRemoval(_notes.where((note) => note.id != _openNoteId).toList()));
  }

  @override
  Widget build(BuildContext context) {
    final note = _noteById(_openNoteId);
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Row(children: [
          if (!_sidebarHidden) _buildSidebar(context),
          if (!_sidebarHidden) _buildDivider(context),
          Expanded(child: _buildPane(context, note)),
        ]),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) => SizedBox(
    key: const Key('desktop_sidebar'),
    width: _sidebarWidth,
    child: ColoredBox(
      color: context.appSidebar,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 44, child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 7),
          child: Row(children: [
            Expanded(child: Text('Tigris', style: AppTypography.uiHeadline(fontSize: 14, fontWeight: FontWeight.w500, color: context.appTextPrimary))),
            IconButton(key: const Key('desktop_new_note'), tooltip: 'New note', iconSize: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 30, height: 30), onPressed: _createNote, icon: const Icon(Icons.add)),
            HomeMoreMenu(
              onSignIn: _menuActions(context).openSignIn, onReview: _menuActions(context).openReview,
              onTasks: _menuActions(context).openTasks, onSync: _menuActions(context).sync,
              onTheme: _menuActions(context).toggleTheme, onSettings: _menuActions(context).openSettings,
            ),
            IconButton(key: const Key('desktop_hide_sidebar'), tooltip: 'Hide sidebar', iconSize: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 30, height: 30), onPressed: () => setState(() => _sidebarHidden = true), icon: const Icon(Icons.view_sidebar_outlined)),
          ]),
        )),
        Container(
          height: 32, margin: const EdgeInsets.symmetric(horizontal: 8), padding: const EdgeInsets.symmetric(horizontal: 8), alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: context.appRowHover, borderRadius: BorderRadius.circular(6)),
          child: TextField(key: const Key('desktop_search'), controller: _searchController, onChanged: (value) => setState(() => _query = value), style: AppTypography.uiLabel(fontSize: 13, fontWeight: FontWeight.w400, color: context.appTextPrimary), decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: 'Search', hintStyle: AppTypography.uiLabel(fontSize: 13, fontWeight: FontWeight.w400, color: context.appTextTertiary))),
        ),
        const SizedBox(height: 8),
        Expanded(child: NotesTreeList(notes: _notes, searchQuery: _query, compact: true, selectedNoteId: _openNoteId, onCreateNote: _createNote, onOpenNote: (note) => _open(note.id))),
        if (widget.syncService != null) Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ListenableBuilder(listenable: widget.syncService!, builder: (context, _) => Text(syncStatusText(widget.syncService!.state), style: AppTypography.uiLabel(fontSize: 12, fontWeight: FontWeight.w400, color: context.appTextSecondary))),
        ),
      ]),
    ),
  );

  HomeMoreMenuActions _menuActions(BuildContext context) => HomeMoreMenuActions(
    context: context, taskRepository: LocalTaskRepository(storage: AppStorage.instance), syncService: widget.syncService,
    syncEngine: widget.syncEngine, syncCoordinator: widget.syncCoordinator, backupService: widget.backupService,
    driveAccount: widget.driveAccount, onStartReview: widget.onStartReview,
  );

  Widget _buildDivider(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    onEnter: (_) => setState(() => _dividerActive = true), onExit: (_) { if (!_dividerActive) return; setState(() => _dividerActive = false); },
    child: GestureDetector(
      key: const Key('desktop_divider'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => setState(() => _dividerActive = true),
      onHorizontalDragUpdate: (details) => setState(() => _sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(220.0, 420.0)),
      onHorizontalDragEnd: (_) => setState(() => _dividerActive = false),
      child: SizedBox(width: 9, child: Center(child: Container(width: _dividerActive ? 2 : 1, color: _dividerActive ? context.appLineStrong : context.appBorder))),
    ),
  );

  Widget _buildPane(BuildContext context, Note? note) => Stack(children: [
    if (note != null)
      NoteDetailScreen(key: ValueKey(_openNoteId), noteId: note.id, initialNote: note, noteRepository: widget.noteRepository, onNavigateToNote: _open, onDeleted: () => _afterDelete(note.id), embeddedTitleInset: _sidebarHidden ? 56 : 16)
    else
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Your notes will appear here.', style: AppTypography.uiLabel(fontSize: 13, fontWeight: FontWeight.w400, color: context.appTextSecondary)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _createNote, style: ElevatedButton.styleFrom(backgroundColor: context.appTextPrimary, foregroundColor: context.appBg, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))), child: const Text('Create your first note')),
      ])),
    if (_sidebarHidden) Positioned(top: 7, left: 7, child: IconButton(key: const Key('desktop_show_sidebar'), tooltip: 'Show sidebar', iconSize: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 30, height: 30), onPressed: () => setState(() => _sidebarHidden = false), icon: const Icon(Icons.view_sidebar_outlined))),
  ]);
}
