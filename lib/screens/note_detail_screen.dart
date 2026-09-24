import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';
import '../app/theme/context_theme_extensions.dart';
import '../models/note.dart';
import '../models/note_block.dart';
import '../repositories/note_repository.dart';
import '../services/local_ai_service.dart';
import '../widgets/ai/ai_actions_sheet.dart';
import '../widgets/ai/note_analysis_sheet.dart';
import '../widgets/editor/block_note_editor.dart';
import '../widgets/editor/page_block_picker_sheet.dart';

class NoteDetailScreen extends StatefulWidget {
  final String noteId;
  final Note? initialNote;
  final NoteRepository? noteRepository;
  final List<Note>? navigationAncestors;

  const NoteDetailScreen({
    super.key,
    required this.noteId,
    this.initialNote,
    this.noteRepository,
    this.navigationAncestors,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  static final Set<String> _activeNoteIdsInStack = <String>{};

  Note? _note;
  List<Note> _ancestors = [];
  List<Note> _childNotes = [];
  bool _isLoading = true;

  late final TextEditingController _titleController;
  final FocusNode _titleFocusNode = FocusNode();
  final GlobalKey<State<BlockNoteEditor>> _editorKey = GlobalKey<State<BlockNoteEditor>>();

  List<NoteBlock> _currentBlocks = [];

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
    _titleController.addListener(_onFieldChanged);
    _titleFocusNode.addListener(_onFocusChanged);

    if (_note != null) {
      _currentBlocks = List.from(_note!.blocks);
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _activeNoteIdsInStack.remove(widget.noteId);
    _debounceTimer?.cancel();
    _titleController.removeListener(_onFieldChanged);
    _titleFocusNode.removeListener(_onFocusChanged);

    _saveCurrentChangesSync();

    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    _hasUnsavedChanges = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _saveCurrentChanges();
    });
  }

  void _onBlocksChanged(List<NoteBlock> updatedBlocks) {
    _currentBlocks = List.from(updatedBlocks);
    _onFieldChanged();
  }

  Future<void> _saveCurrentChanges() async {
    if (_note == null || !_hasUnsavedChanges) return;
    final repo = _repo;
    if (repo == null) return;

    final updatedTitle = _titleController.text.trim();
    final blocksJson = jsonEncode(_currentBlocks.map((b) => b.toJson()).toList());
    final plainTextContent = _currentBlocks.map((b) => b.content).join('\n');
    final pageBlockNoteIds = _currentBlocks
        .where((b) => b.type == BlockType.page && b.targetNoteId != null && b.targetNoteId!.isNotEmpty)
        .map((b) => b.targetNoteId!)
        .toSet()
        .toList();

    final updated = _note!.copyWith(
      title: updatedTitle.isNotEmpty ? updatedTitle : 'Untitled',
      content: plainTextContent,
      blocksJson: blocksJson,
      childrenIds: pageBlockNoteIds.isNotEmpty
          ? {..._note!.childrenIds, ...pageBlockNoteIds}.toList()
          : _note!.childrenIds,
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
    final blocksJson = jsonEncode(_currentBlocks.map((b) => b.toJson()).toList());
    final plainTextContent = _currentBlocks.map((b) => b.content).join('\n');
    final pageBlockNoteIds = _currentBlocks
        .where((b) => b.type == BlockType.page && b.targetNoteId != null && b.targetNoteId!.isNotEmpty)
        .map((b) => b.targetNoteId!)
        .toSet()
        .toList();

    final updated = _note!.copyWith(
      title: updatedTitle.isNotEmpty ? updatedTitle : 'Untitled',
      content: plainTextContent,
      blocksJson: blocksJson,
      childrenIds: pageBlockNoteIds.isNotEmpty
          ? {..._note!.childrenIds, ...pageBlockNoteIds}.toList()
          : _note!.childrenIds,
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

    final ancestors = widget.navigationAncestors ?? await repo.getAncestorPath(note.id);
    final rawChildren = await repo.getChildNotes(note.id);

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
        _currentBlocks = List.from(note.blocks);
        for (final child in children) {
          final alreadyPresent = _currentBlocks.any(
            (b) => b.type == BlockType.page && b.targetNoteId == child.id,
          );
          if (!alreadyPresent) {
            if (_currentBlocks.length == 1 &&
                _currentBlocks.first.type == BlockType.text &&
                _currentBlocks.first.content.isEmpty) {
              _currentBlocks = [
                NoteBlock(type: BlockType.page, targetNoteId: child.id),
              ];
            } else {
              _currentBlocks.add(
                NoteBlock(type: BlockType.page, targetNoteId: child.id),
              );
            }
          }
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

  Future<void> _openPageBlockNote(String targetNoteId) async {
    await _saveCurrentChanges();
    if (!mounted) return;

    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: RouteSettings(name: '/note/$targetNoteId'),
        builder: (context) => NoteDetailScreen(
          noteId: targetNoteId,
          noteRepository: _repo,
          navigationAncestors: [..._ancestors, ?_note],
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

  String _getFormattedContent() {
    if (_note == null) return '';
    final formattedBuffer = StringBuffer();
    for (final b in _currentBlocks) {
      final indent = '  ' * b.indentLevel;
      switch (b.type) {
        case BlockType.heading:
          formattedBuffer.writeln('\n$indent# ${b.content}');
          break;
        case BlockType.bullet:
          formattedBuffer.writeln('$indent• ${b.content}');
          break;
        case BlockType.number:
          formattedBuffer.writeln('${indent}1. ${b.content}');
          break;
        case BlockType.page:
          formattedBuffer.writeln('$indent[Subpage: ${b.content}]');
          break;
        case BlockType.divider:
          formattedBuffer.writeln('$indent---');
          break;
        case BlockType.text:
          formattedBuffer.writeln('$indent${b.content}');
          break;
      }
    }
    return formattedBuffer.toString().trim().isNotEmpty
        ? formattedBuffer.toString().trim()
        : _note!.content;
  }

  Future<void> _openUnderstandNote() async {
    if (_note == null) return;
    final aiService = RepositoryScope.maybeOf(context)?.aiService ?? const LocalAiService();
    await _saveCurrentChanges();
    if (!mounted) return;

    await NoteAnalysisSheet.show(
      context,
      noteId: _note!.id,
      noteTitle: _note!.title,
      noteContent: _getFormattedContent(),
      aiService: aiService,
    );
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
      noteContent: _getFormattedContent(),
      aiService: aiService,
    );
  }

  Future<void> _handleBack() async {
    await _saveCurrentChanges();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _showAddBlockPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.notes_rounded),
                  title: const Text('Text'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    final state = _editorKey.currentState;
                    if (state != null) {
                      dynamic dynamicState = state;
                      dynamicState.insertTextBlock(BlockType.text);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.title),
                  title: const Text('Heading'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    final state = _editorKey.currentState;
                    if (state != null) {
                      dynamic dynamicState = state;
                      dynamicState.insertTextBlock(BlockType.heading);
                    }
                  },
                ),
                ListTile(
                  leading: const Text('•', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  title: const Text('Bullet List'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    final state = _editorKey.currentState;
                    if (state != null) {
                      dynamic dynamicState = state;
                      dynamicState.insertTextBlock(BlockType.bullet);
                    }
                  },
                ),
                ListTile(
                  leading: const Text('1.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  title: const Text('Numbered List'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    final state = _editorKey.currentState;
                    if (state != null) {
                      dynamic dynamicState = state;
                      dynamicState.insertTextBlock(BlockType.number);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Page'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final selectedNoteId = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      builder: (sheetCtx) => PageBlockPickerSheet(
                        currentNoteId: widget.noteId,
                        parentStreamId: _note?.parentId,
                        noteRepository: _repo,
                      ),
                    );

                  if (selectedNoteId != null && mounted) {
                    final state = _editorKey.currentState;
                    if (state != null) {
                      dynamic dynamicState = state;
                      dynamicState.insertPageBlock(selectedNoteId);
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.horizontal_rule),
                title: const Text('Divider'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  final state = _editorKey.currentState;
                  if (state != null) {
                    dynamic dynamicState = state;
                    dynamicState.insertDividerBlock();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
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
              key: const Key('understand_note_button'),
              onPressed: _openUnderstandNote,
              style: TextButton.styleFrom(
                foregroundColor: context.appTextPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                minimumSize: const Size(40.0, 36.0),
              ),
              child: Text(
                'UNDERSTAND NOTE',
                style: AppTypography.uiHeadline(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: _openAiActions,
              style: TextButton.styleFrom(
                foregroundColor: context.appTextPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                minimumSize: const Size(40.0, 36.0),
              ),
              child: Text(
                '✦ AI',
                style: AppTypography.uiHeadline(
                  fontSize: 13.0,
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 16.0),

                // Block-based continuous Document Editor
                BlockNoteEditor(
                  key: _editorKey,
                  blocks: _currentBlocks,
                  noteRepository: _repo,
                  onChanged: _onBlocksChanged,
                  onOpenNote: _openPageBlockNote,
                ),

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

  Widget _buildFormattingToolbar() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
              onTap: () {
                final state = _editorKey.currentState;
                if (state != null) {
                  dynamic dynamicState = state;
                  dynamicState.toggleBold();
                }
              },
              tooltip: 'Bold',
            ),
            const SizedBox(width: 4.0),
            _buildToolbarButton(
              label: 'I',
              isItalic: true,
              onTap: () {
                final state = _editorKey.currentState;
                if (state != null) {
                  dynamic dynamicState = state;
                  dynamicState.toggleItalic();
                }
              },
              tooltip: 'Italic',
            ),
            const SizedBox(width: 4.0),
            _buildToolbarButton(
              label: '•',
              onTap: () {
                final state = _editorKey.currentState;
                if (state != null) {
                  dynamic dynamicState = state;
                  dynamicState.setBlockType(BlockType.bullet);
                }
              },
              tooltip: 'Bullet List',
            ),
            const SizedBox(width: 4.0),
            _buildToolbarButton(
              label: '1.',
              onTap: () {
                final state = _editorKey.currentState;
                if (state != null) {
                  dynamic dynamicState = state;
                  dynamicState.setBlockType(BlockType.number);
                }
              },
              tooltip: 'Numbered List',
            ),
            const SizedBox(width: 4.0),
            _buildToolbarButton(
              label: '←',
              onTap: () {
                final state = _editorKey.currentState;
                if (state != null) {
                  dynamic dynamicState = state;
                  dynamicState.decreaseIndent();
                }
              },
              tooltip: 'Decrease Indent',
            ),
            const SizedBox(width: 4.0),
            _buildToolbarButton(
              label: '→',
              onTap: () {
                final state = _editorKey.currentState;
                if (state != null) {
                  dynamic dynamicState = state;
                  dynamicState.increaseIndent();
                }
              },
              tooltip: 'Increase Indent',
            ),
            const SizedBox(width: 4.0),
            _buildToolbarButton(
              label: '+',
              onTap: _showAddBlockPicker,
              tooltip: 'Add Block',
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.keyboard_hide_rounded, size: 20.0, color: context.appTextTertiary),
              onPressed: () {
                FocusScope.of(context).unfocus();
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
    bool isActive = false,
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
          decoration: isActive
              ? BoxDecoration(
                  color: context.appBorderSubtle.withValues(alpha: 0.6),
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
