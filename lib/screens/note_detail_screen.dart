import 'dart:async';
import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../app/theme/context_theme_extensions.dart';
import '../controllers/rich_text_editing_controller.dart';
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
  late final SmartListController _contentController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();

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

    final initialContent = (_note?.content != null && _note!.content.isNotEmpty)
        ? _note!.content
        : (_note?.subtitle ?? '');

    _titleController = TextEditingController(text: _note?.title ?? '');
    _contentController = SmartListController(text: initialContent);

    _titleController.addListener(_onFieldChanged);
    _contentController.addListener(_onFieldChanged);

    _titleFocusNode.addListener(_onFocusChanged);
    _contentFocusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _activeNoteIdsInStack.remove(widget.noteId);
    _debounceTimer?.cancel();
    _titleController.removeListener(_onFieldChanged);
    _contentController.removeListener(_onFieldChanged);
    _titleFocusNode.removeListener(_onFocusChanged);
    _contentFocusNode.removeListener(_onFocusChanged);

    _saveCurrentChangesSync();

    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
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
    final updatedContent = _contentController.text;

    final updated = _note!.copyWith(
      title: updatedTitle.isNotEmpty ? updatedTitle : 'Untitled',
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
    final updatedContent = _contentController.text;

    final updated = _note!.copyWith(
      title: updatedTitle.isNotEmpty ? updatedTitle : 'Untitled',
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
    final rawChildren = await repo.getChildNotes(note.id);

    // Filter out abandoned empty drafts
    final children = <Note>[];
    for (final child in rawChildren) {
      final isAbandoned = (child.title.trim().isEmpty || child.title == 'Untitled') &&
          child.content.trim().isEmpty &&
          child.childrenIds.isEmpty;
      if (isAbandoned) {
        await repo.deleteNote(child.id);
      } else {
        children.add(child);
      }
    }

    if (mounted) {
      if (!_hasUnsavedChanges) {
        if (_titleController.text != note.title) {
          _titleController.text = note.title;
        }
        final noteBody = note.content.isNotEmpty ? note.content : (note.subtitle ?? '');
        if (_contentController.text != noteBody) {
          _contentController.text = noteBody;
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
      // Discard empty draft if user popped back without writing anything
      final savedChild = await repo.getNote(newChild.id);
      if (savedChild != null &&
          (savedChild.title.trim().isEmpty || savedChild.title == 'Untitled') &&
          savedChild.content.trim().isEmpty &&
          savedChild.childrenIds.isEmpty) {
        await repo.deleteNote(newChild.id);
      }
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
      return Scaffold(
        backgroundColor: context.appBg,
        body: const Center(child: SizedBox.shrink()),
      );
    }

    if (_note == null) {
      return Scaffold(
        backgroundColor: context.appBg,
        appBar: AppBar(
          backgroundColor: context.appBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18.0),
            color: context.appTextPrimary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Note not found.',
            style: AppTypography.body(fontSize: 16.0, color: context.appTextSecondary),
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
        backgroundColor: context.appBg,
        appBar: AppBar(
          backgroundColor: context.appBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18.0),
            color: context.appTextPrimary,
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
                      color: context.appTextTertiary,
                    ),
                  ),
                ),
              ),
            TextButton(
              onPressed: _openAiActions,
              style: TextButton.styleFrom(
                foregroundColor: context.appTextPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                minimumSize: const Size(44.0, 36.0),
              ),
              child: Text(
                '✦ AI',
                style: AppTypography.uiHeadline(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20.0),
              color: context.appTextSecondary,
              tooltip: 'Delete note',
            ),
            const SizedBox(width: 4.0),
          ],
        ),
        bottomNavigationBar: _buildFormattingToolbar(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Title Section (Breadcrumbs + Title + Date Stamp)
                _buildBreadcrumbs(),

                TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  style: AppTypography.display(
                    fontSize: 32.0,
                    color: context.appTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Untitled',
                    hintStyle: TextStyle(
                      color: context.appTextTertiary,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 6.0),

                if (_note != null) ...[
                  Text(
                    _formatDateStamp(_note!.updatedAt),
                    style: AppTypography.uiLabel(
                      fontSize: 12.0,
                      color: context.appTextTertiary,
                    ),
                  ),
                  const SizedBox(height: 18.0),
                ] else ...[
                  const SizedBox(height: 20.0),
                ],

                // 2. Body Section (The Notes)
                TextField(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  style: AppTypography.body(
                    fontSize: 17.0,
                    color: context.appTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Start writing...',
                    hintStyle: TextStyle(
                      color: context.appTextTertiary,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 36.0),

                // 3. Child Notes Section
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
    if (_childNotes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: InkWell(
          onTap: _addChildPage,
          borderRadius: BorderRadius.circular(6.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_rounded,
                  size: 18.0,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6.0),
                Text(
                  'Add page',
                  style: AppTypography.uiLabel(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
            child: Text(
              'Pages',
              style: AppTypography.uiLabel(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ).copyWith(letterSpacing: 0.8),
            ),
          ),
          const SizedBox(height: 6.0),
          for (final child in _childNotes)
            InkWell(
              onTap: () => _openChildNote(child),
              borderRadius: BorderRadius.circular(6.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 2.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 16.0,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        child.title.isEmpty ? 'Untitled' : child.title,
                        style: AppTypography.body(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12.0,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10.0),
          InkWell(
            onTap: _addChildPage,
            borderRadius: BorderRadius.circular(6.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 2.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 16.0,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    'Add page',
                    style: AppTypography.uiLabel(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateStamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) {
      return 'Updated just now';
    } else if (diff.inMinutes < 60) {
      return 'Updated ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && date.day == now.day) {
      return 'Updated ${diff.inHours}h ago';
    } else if (diff.inHours < 48 && date.day == now.subtract(const Duration(days: 1)).day) {
      return 'Updated yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return 'Updated ${date.day} ${months[date.month - 1]}';
    }
  }

  void _applyBold() {
    _contentController.toggleFormat('**');
  }

  void _applyItalic() {
    _contentController.toggleFormat('*');
  }

  void _applyHighlight() {
    _contentController.toggleFormat('==');
  }

  void _applyBulletList() {
    final val = _contentController.value;
    final selection = val.selection;
    final text = val.text;
    if (!selection.isValid) return;

    final cursor = selection.start;
    final lineStart = text.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    final actualLineStart = lineStart == -1 ? 0 : lineStart + 1;
    final currentLine = text.substring(actualLineStart, cursor);

    if (currentLine.startsWith('• ')) {
      final newText = text.replaceRange(actualLineStart, actualLineStart + 2, '');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: (selection.start - 2).clamp(0, newText.length)),
      );
    } else {
      final newText = text.replaceRange(actualLineStart, actualLineStart, '• ');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + 2),
      );
    }
  }

  void _applyNumberedList() {
    final val = _contentController.value;
    final selection = val.selection;
    final text = val.text;
    if (!selection.isValid) return;

    final cursor = selection.start;
    final lineStart = text.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
    final actualLineStart = lineStart == -1 ? 0 : lineStart + 1;
    final currentLine = text.substring(actualLineStart, cursor);

    final numMatch = RegExp(r'^(\d+)\.\s*').firstMatch(currentLine);
    if (numMatch != null) {
      final len = numMatch.group(0)!.length;
      final newText = text.replaceRange(actualLineStart, actualLineStart + len, '');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: (selection.start - len).clamp(0, newText.length)),
      );
    } else {
      int nextNum = 1;
      if (actualLineStart > 0) {
        final prevLineStart = text.lastIndexOf('\n', actualLineStart - 2);
        final actualPrevStart = prevLineStart == -1 ? 0 : prevLineStart + 1;
        final prevLine = text.substring(actualPrevStart, actualLineStart - 1);
        final prevNumMatch = RegExp(r'^(\d+)\.\s*').firstMatch(prevLine);
        if (prevNumMatch != null) {
          nextNum = int.parse(prevNumMatch.group(1)!) + 1;
        }
      }
      final prefix = '$nextNum. ';
      final newText = text.replaceRange(actualLineStart, actualLineStart, prefix);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length),
      );
    }
  }

  Widget _buildFormattingToolbar() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isContentFocused = _contentFocusNode.hasFocus;
    final isTitleFocused = _titleFocusNode.hasFocus;

    if (bottomInset == 0 && !isContentFocused && !isTitleFocused) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: 48.0,
        decoration: BoxDecoration(
          color: context.appSurface,
          border: Border(
            top: BorderSide(color: context.appBorderSubtle, width: 0.8),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _buildToolbarButton(
            label: 'B',
            isBold: true,
            onTap: _applyBold,
            tooltip: 'Bold',
          ),
          const SizedBox(width: 4.0),
          _buildToolbarButton(
            label: 'I',
            isItalic: true,
            onTap: _applyItalic,
            tooltip: 'Italic',
          ),
          const SizedBox(width: 4.0),
          _buildToolbarButton(
            label: 'H',
            isHighlight: true,
            onTap: _applyHighlight,
            tooltip: 'Highlight',
          ),
          const SizedBox(width: 4.0),
          VerticalDivider(
            color: context.appBorderSubtle,
            indent: 10,
            endIndent: 10,
            width: 16,
          ),
          _buildToolbarButton(
            label: '•',
            onTap: _applyBulletList,
            tooltip: 'Bullet List',
          ),
          const SizedBox(width: 4.0),
          _buildToolbarButton(
            label: '1.',
            onTap: _applyNumberedList,
            tooltip: 'Numbered List',
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.keyboard_hide_rounded, size: 20.0, color: context.appTextTertiary),
            onPressed: () {
              _contentFocusNode.unfocus();
              _titleFocusNode.unfocus();
            },
            tooltip: 'Hide keyboard',
          ),
        ],
      ),
    ),
  );
}

  Widget _buildToolbarButton({
    required String label,
    required VoidCallback onTap,
    bool isBold = false,
    bool isItalic = false,
    bool isHighlight = false,
    required String tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6.0),
        child: Container(
          width: 36.0,
          height: 32.0,
          alignment: Alignment.center,
          decoration: isHighlight
              ? BoxDecoration(
                  color: context.isDarkMode ? const Color(0xFF665C00) : const Color(0xFFFFF1A8),
                  borderRadius: BorderRadius.circular(4.0),
                )
              : null,
          child: Text(
            label,
            style: AppTypography.uiHeadline(
              fontSize: 15.0,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: context.appTextPrimary,
            ).copyWith(
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class SmartListController extends RichTextEditingController {
  SmartListController({super.text});

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final oldSel = selection;

    // Intercept single newline insertion
    if (newValue.text.length == oldText.length + 1 &&
        oldSel.isCollapsed &&
        oldSel.start >= 0 &&
        oldSel.start <= oldText.length &&
        newValue.text.length > oldSel.start &&
        newValue.text[oldSel.start] == '\n') {
      
      final cursor = oldSel.start;
      final lineStart = oldText.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
      final actualLineStart = lineStart == -1 ? 0 : lineStart + 1;
      final lineBeforeEnter = oldText.substring(actualLineStart, cursor);

      // 1. Check Bullet list (•, -, *)
      final bulletMatch = RegExp(r'^(\s*)([•\-\*])\s*(.*)$').firstMatch(lineBeforeEnter);
      if (bulletMatch != null) {
        final indent = bulletMatch.group(1)!;
        final symbol = bulletMatch.group(2)!;
        final content = bulletMatch.group(3)!;

        if (content.trim().isEmpty) {
          // Double enter on empty bullet -> Exit list mode
          final newText = oldText.substring(0, actualLineStart) + oldText.substring(cursor);
          super.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: actualLineStart),
          );
          return;
        } else {
          // Continue bullet list
          final prefix = '\n$indent$symbol ';
          final newText = oldText.substring(0, cursor) + prefix + oldText.substring(cursor);
          super.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: cursor + prefix.length),
          );
          return;
        }
      }

      // 2. Check Numbered list (1., 2., etc)
      final numMatch = RegExp(r'^(\s*)(\d+)\.\s*(.*)$').firstMatch(lineBeforeEnter);
      if (numMatch != null) {
        final indent = numMatch.group(1)!;
        final numVal = int.parse(numMatch.group(2)!);
        final content = numMatch.group(3)!;

        if (content.trim().isEmpty) {
          // Double enter on empty number -> Exit list mode
          final newText = oldText.substring(0, actualLineStart) + oldText.substring(cursor);
          super.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: actualLineStart),
          );
          return;
        } else {
          // Continue numbered list
          final prefix = '\n$indent${numVal + 1}. ';
          final newText = oldText.substring(0, cursor) + prefix + oldText.substring(cursor);
          super.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: cursor + prefix.length),
          );
          return;
        }
      }
    }

    super.value = newValue;
  }
}
