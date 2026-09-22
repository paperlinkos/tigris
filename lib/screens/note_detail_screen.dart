import 'dart:async';
import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../services/local_ai_service.dart';
import '../widgets/ai/ai_actions_sheet.dart';
import '../widgets/notes/create_note_sheet.dart';
import '../widgets/notes/note_list_item.dart';

class NoteDetailScreen extends StatefulWidget {
  final String noteId;
  final Note? initialNote;
  final NoteRepository? noteRepository;

  const NoteDetailScreen({
    super.key,
    required this.noteId,
    this.initialNote,
    this.noteRepository,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  Note? _note;
  Note? _parentNote;
  List<Note> _childNotes = [];
  bool _isLoading = true;

  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _contentController;

  Timer? _debounceTimer;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  NoteRepository? get _repo =>
      widget.noteRepository ?? RepositoryScope.maybeOf(context)?.noteRepository;

  @override
  void initState() {
    super.initState();
    _note = widget.initialNote;
    _titleController = TextEditingController(text: _note?.title ?? '');
    _subtitleController = TextEditingController(text: _note?.subtitle ?? '');
    _contentController = TextEditingController(text: _note?.content ?? '');

    _titleController.addListener(_onFieldChanged);
    _subtitleController.addListener(_onFieldChanged);
    _contentController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.removeListener(_onFieldChanged);
    _subtitleController.removeListener(_onFieldChanged);
    _contentController.removeListener(_onFieldChanged);

    _saveCurrentChangesSync();

    _titleController.dispose();
    _subtitleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    _hasUnsavedChanges = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _saveCurrentChanges();
    });
  }

  Future<void> _saveCurrentChanges() async {
    if (_note == null || !_hasUnsavedChanges) return;
    final repo = _repo;
    if (repo == null) return;

    final updatedTitle = _titleController.text.trim();
    final updatedSubtitle = _subtitleController.text.trim();
    final updatedContent = _contentController.text;

    final updated = _note!.copyWith(
      title: updatedTitle.isNotEmpty ? updatedTitle : 'Untitled',
      subtitle: updatedSubtitle.isNotEmpty ? updatedSubtitle : null,
      content: updatedContent,
      updatedAt: DateTime.now(),
    );

    if (mounted) {
      setState(() => _isSaving = true);
    }

    await repo.saveNote(updated);

    if (mounted) {
      setState(() {
        _note = updated;
        _isSaving = false;
        _hasUnsavedChanges = false;
      });
    }
  }

  void _saveCurrentChangesSync() {
    if (_note == null || !_hasUnsavedChanges) return;
    final repo = _repo;
    if (repo == null) return;

    final updatedTitle = _titleController.text.trim();
    final updatedSubtitle = _subtitleController.text.trim();
    final updatedContent = _contentController.text;

    final updated = _note!.copyWith(
      title: updatedTitle.isNotEmpty ? updatedTitle : 'Untitled',
      subtitle: updatedSubtitle.isNotEmpty ? updatedSubtitle : null,
      content: updatedContent,
      updatedAt: DateTime.now(),
    );

    repo.saveNote(updated);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadNoteData();
  }

  Future<void> _loadNoteData() async {
    final repo = _repo;
    if (repo == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final note = await repo.getNote(widget.noteId);
    if (!mounted) return;

    if (note == null) {
      setState(() {
        _note = null;
        _isLoading = false;
      });
      return;
    }

    Note? parent;
    if (note.parentId != null) {
      parent = await repo.getNote(note.parentId!);
    }

    final children = await repo.getChildNotes(note.id);

    if (mounted) {
      // If there are no local unsaved edits, sync controllers with loaded note
      if (!_hasUnsavedChanges) {
        if (_titleController.text != note.title) {
          _titleController.text = note.title;
        }
        final sub = note.subtitle ?? '';
        if (_subtitleController.text != sub) {
          _subtitleController.text = sub;
        }
        if (_contentController.text != note.content) {
          _contentController.text = note.content;
        }
      }

      setState(() {
        _note = note;
        _parentNote = parent;
        _childNotes = children;
        _isLoading = false;
      });
    }
  }

  Future<void> _addChildPage() async {
    if (_note == null) return;
    await _saveCurrentChanges();

    if (!mounted) return;
    final created = await CreateNoteSheet.show(
      context,
      parentId: _note!.id,
      parentTitle: _note!.title,
    );

    final repo = _repo;
    if (created != null && repo != null && mounted) {
      await repo.saveNote(created);
      await _loadNoteData();
    }
  }

  Future<void> _confirmDelete() async {
    if (_note == null) return;
    final totalChildren = _childNotes.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: Text(
          'Delete Note',
          style: AppTypography.title(
            fontSize: 20.0,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          totalChildren > 0
              ? 'This note has $totalChildren ${totalChildren == 1 ? 'subpage' : 'subpages'}. Deleting it will permanently delete this note and all nested descendants.'
              : 'Are you sure you want to delete this note?',
          style: AppTypography.body(
            fontSize: 14.5,
            color: AppColors.textSecondary,
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
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.background,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.0),
              ),
            ),
            child: Text(
              'Delete',
              style: AppTypography.uiHeadline(
                fontSize: 14.0,
                color: AppColors.background,
              ),
            ),
          ),
        ],
      ),
    );

    final repo = _repo;
    if (confirmed == true && repo != null && mounted) {
      _hasUnsavedChanges = false;
      await repo.deleteNote(_note!.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _openChildNote(Note child) async {
    await _saveCurrentChanges();
    if (!mounted) return;

    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(
          noteId: child.id,
          initialNote: child,
          noteRepository: _repo,
        ),
      ),
    );

    if (deleted == true && mounted) {
      await _loadNoteData();
    }
  }

  Future<void> _openAiActions() async {
    if (_note == null) return;
    final aiService = RepositoryScope.maybeOf(context)?.aiService ?? const LocalAiService();
    await _saveCurrentChanges();
    if (!mounted) return;

    await AiActionsSheet.show(
      context,
      noteId: _note!.id,
      noteTitle: _note!.title,
      noteContent: _contentController.text,
      aiService: aiService,
    );
  }

  Future<void> _handleBack() async {
    await _saveCurrentChanges();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: SizedBox.shrink()),
      );
    }

    if (_note == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18.0),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Note not found.',
            style: AppTypography.body(fontSize: 16.0, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _saveCurrentChangesSync();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18.0),
            color: AppColors.textPrimary,
            onPressed: _handleBack,
          ),
          title: _parentNote != null
              ? Text(
                  _parentNote!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.uiLabel(
                    fontSize: 13.0,
                    color: AppColors.textTertiary,
                  ),
                )
              : null,
          centerTitle: false,
          actions: [
            if (_isSaving)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Text(
                    'Saving...',
                    style: AppTypography.uiLabel(
                      fontSize: 12.0,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            TextButton(
              onPressed: _openAiActions,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                minimumSize: const Size(44.0, 36.0),
              ),
              child: Text(
                '✦ AI',
                style: AppTypography.uiHeadline(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20.0),
              color: AppColors.textSecondary,
              tooltip: 'Delete note',
            ),
            const SizedBox(width: 4.0),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Digital Page Title Editor
                TextField(
                  controller: _titleController,
                  style: AppTypography.display(
                    fontSize: 28.0,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Untitled',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 10.0),

                // Digital Page Subtitle Editor
                TextField(
                  controller: _subtitleController,
                  style: AppTypography.subtitle(
                    fontSize: 16.0,
                    color: AppColors.textSecondary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Add a subtitle (optional)...',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 24.0),
                const Divider(color: AppColors.borderSubtle, height: 1.0),
                const SizedBox(height: 24.0),

                // Digital Page Body Content Editor
                TextField(
                  controller: _contentController,
                  style: AppTypography.body(
                    fontSize: 16.0,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Start writing your reflections...',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 48.0),

                // Child subpages section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SUBPAGES',
                      style: AppTypography.uiLabel(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ).copyWith(letterSpacing: 1.2),
                    ),
                    InkWell(
                      onTap: _addChildPage,
                      borderRadius: BorderRadius.circular(6.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 16.0, color: AppColors.textPrimary),
                            const SizedBox(width: 4.0),
                            Text(
                              'Add page',
                              style: AppTypography.uiHeadline(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),

                // Child pages list or calm empty state
                if (_childNotes.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'No subpages yet. Tap "Add page" to nest notes inside this one.',
                      style: AppTypography.subtitle(
                        fontSize: 13.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ] else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _childNotes.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: AppColors.borderSubtle,
                      height: 1.0,
                    ),
                    itemBuilder: (context, index) {
                      final child = _childNotes[index];
                      return NoteListItem(
                        note: child,
                        onTap: () => _openChildNote(child),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 56.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
