import 'dart:async';
import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../services/local_ai_service.dart';
import '../widgets/ai/ai_actions_sheet.dart';

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
  // Track active note IDs currently in the navigator stack for logical hierarchy pops
  static final Set<String> _activeNoteIdsInStack = <String>{};

  Note? _note;
  List<Note> _ancestors = [];
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
    _activeNoteIdsInStack.add(widget.noteId);
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
    _activeNoteIdsInStack.remove(widget.noteId);
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

    final ancestors = await repo.getAncestorPath(note.id);
    final children = await repo.getChildNotes(note.id);

    if (mounted) {
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
        _ancestors = ancestors;
        _childNotes = children;
        _isLoading = false;
      });
    }
  }

  Future<void> _addChildPage() async {
    if (_note == null) return;
    await _saveCurrentChanges();
    final repo = _repo;
    if (repo == null || !mounted) return;

    final newChild = Note(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      parentId: _note!.id,
      title: '',
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repo.saveNote(newChild);

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/note/${newChild.id}'),
        builder: (context) => NoteDetailScreen(
          noteId: newChild.id,
          initialNote: newChild,
          noteRepository: repo,
        ),
      ),
    );

    if (mounted) {
      await _loadNoteData();
    }
  }

  Future<void> _navigateToAncestor(Note ancestor) async {
    await _saveCurrentChanges();
    if (!mounted) return;

    if (_activeNoteIdsInStack.contains(ancestor.id)) {
      Navigator.of(context).popUntil((route) => route.settings.name == '/note/${ancestor.id}');
    } else {
      final updated = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          settings: RouteSettings(name: '/note/${ancestor.id}'),
          builder: (context) => NoteDetailScreen(
            noteId: ancestor.id,
            initialNote: ancestor,
            noteRepository: _repo,
          ),
        ),
      );
      if (updated == true && mounted) {
        await _loadNoteData();
      }
    }
  }

  Future<void> _openChildNote(Note child) async {
    await _saveCurrentChanges();
    if (!mounted) return;

    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: RouteSettings(name: '/note/${child.id}'),
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
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breadcrumbs navigation (if note has ancestors)
                _buildBreadcrumbs(),

                // Digital Page Title Editor
                TextField(
                  controller: _titleController,
                  style: AppTypography.display(
                    fontSize: 30.0,
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

                const SizedBox(height: 20.0),
                const Divider(color: AppColors.borderSubtle, height: 1.0),
                const SizedBox(height: 24.0),

                // Digital Page Body Content Editor
                TextField(
                  controller: _contentController,
                  style: AppTypography.body(
                    fontSize: 17.0,
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

                // Child notes section
                _buildChildNotesSection(),

                const SizedBox(height: 56.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    if (_ancestors.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _ancestors.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Text(
                    '/',
                    style: AppTypography.uiLabel(
                      fontSize: 13.0,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              InkWell(
                onTap: () => _navigateToAncestor(_ancestors[i]),
                borderRadius: BorderRadius.circular(4.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                  child: Text(
                    _ancestors[i].title.isEmpty ? 'Untitled' : _ancestors[i].title,
                    style: AppTypography.uiLabel(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CHILD NOTES',
              style: AppTypography.uiLabel(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ).copyWith(letterSpacing: 1.2),
            ),
            InkWell(
              onTap: _addChildPage,
              borderRadius: BorderRadius.circular(4.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 15.0, color: AppColors.textPrimary),
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
        if (_childNotes.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              'No child notes yet. Tap "+ Add page" to nest a note inside this page.',
              style: AppTypography.subtitle(
                fontSize: 13.5,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ] else ...[
          for (final child in _childNotes)
            InkWell(
              onTap: () => _openChildNote(child),
              borderRadius: BorderRadius.circular(6.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.title.isEmpty ? 'Untitled' : child.title,
                            style: AppTypography.subtitle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (child.subtitle != null && child.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2.0),
                            Text(
                              child.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                fontSize: 13.0,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13.0,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
