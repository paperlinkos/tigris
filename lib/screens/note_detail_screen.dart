import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/di/repository_scope.dart';
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
import '../widgets/desktop_panel.dart';
import '../widgets/ideas/ship_to_agent_panel.dart';

class NoteDetailScreen extends StatefulWidget {
  final String noteId;
  final Note? initialNote;
  final NoteRepository? noteRepository;
  final List<Note>? navigationAncestors;
  final ValueChanged<String>? onNavigateToNote;
  final VoidCallback? onDeleted;
  final String? externalTitle;

  /// Each new value moves the cursor to the note's body.
  final int focusBodyRequest;

  /// Left inset of the breadcrumb when embedded, to clear a control over the pane.
  final double embeddedTitleInset;

  const NoteDetailScreen({
    super.key,
    required this.noteId,
    this.initialNote,
    this.noteRepository,
    this.navigationAncestors,
    this.onNavigateToNote,
    this.onDeleted,
    this.externalTitle,
    this.focusBodyRequest = 0,
    this.embeddedTitleInset = 16.0,
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
  bool _hasUnsavedChanges = false;
  bool _isWritingBody = false;

  // Kept from didChangeDependencies so dispose can still save after the
  // widget has been deactivated, when context lookups are no longer allowed.
  NoteRepository? _scopedRepo;
  bool _disposing = false;

  NoteRepository? get _repo =>
      widget.noteRepository ??
      _scopedRepo ??
      (mounted && !_disposing ? RepositoryScope.maybeOf(context)?.noteRepository : null);

  @override
  void initState() {
    super.initState();
    _activeNoteIdsInStack.add(widget.noteId);
    _note = widget.initialNote;

    _titleController = TextEditingController(text: _note?.title ?? '');
    _titleController.addListener(_onFieldChanged);
    _titleFocusNode.addListener(_onFocusChanged);
    FocusManager.instance.addListener(_onPrimaryFocusChanged);

    if (_note != null) {
      _currentBlocks = List.from(_note!.blocks);
    }
  }

  @override
  void didUpdateWidget(covariant NoteDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final title = widget.externalTitle;
    if (title != oldWidget.externalTitle && title != null && title != _titleController.text) {
      _titleController.text = title;
    }
    if (widget.focusBodyRequest != oldWidget.focusBodyRequest) {
      _focusBody();
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onPrimaryFocusChanged() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final isWritingBody =
        focusContext?.findAncestorWidgetOfExactType<BlockNoteEditor>() != null;
    if (mounted && isWritingBody != _isWritingBody) {
      setState(() => _isWritingBody = isWritingBody);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onPrimaryFocusChanged);
    _activeNoteIdsInStack.remove(widget.noteId);
    _debounceTimer?.cancel();
    _titleController.removeListener(_onFieldChanged);
    _titleFocusNode.removeListener(_onFocusChanged);

    _disposing = true;
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

    await repo.saveNote(updated);

    if (mounted) {
      setState(() {
        _note = updated;
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
    _scopedRepo = RepositoryScope.maybeOf(context)?.noteRepository;
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

    if (widget.onNavigateToNote != null) {
      widget.onNavigateToNote!(ancestor.id);
      return;
    }

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

    if (widget.onNavigateToNote != null) {
      widget.onNavigateToNote!(targetNoteId);
      return;
    }

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

  Future<void> _addPageInside() async {
    final repo = _repo;
    if (_note == null || repo == null) return;

    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewPageDialog(),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final now = DateTime.now();
    final child = Note(
      id: 'note_${now.millisecondsSinceEpoch}',
      title: name,
      content: '',
      parentId: _note!.id,
      workspace: _note!.workspace,
      createdAt: now,
      updatedAt: now,
    );
    await repo.saveNote(child);
    if (!mounted) return;

    final state = _editorKey.currentState;
    if (state != null) {
      dynamic dynamicState = state;
      dynamicState.insertPageBlock(child.id);
    }
    await _openPageBlockNote(child.id);
  }

  Future<void> _confirmDelete() async {
    if (_note == null) return;
    final totalChildren = _childNotes.length;

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

    final repo = _repo;
    if (confirmed == true && repo != null && mounted) {
      _hasUnsavedChanges = false;
      await repo.deleteNote(_note!.id);
      if (mounted) {
        if (widget.onDeleted != null) {
          widget.onDeleted!();
        } else {
          Navigator.of(context).pop(true);
        }
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

  Future<void> _setIdeaStatus(String status) async {
    final repo = _repo;
    if (_note == null || repo == null) return;
    final updated = _note!.copyWith(ideaStatus: status, updatedAt: DateTime.now());
    await repo.saveNote(updated);
    if (mounted) setState(() => _note = updated);
  }

  Future<void> _shipToAgent() async {
    final repo = _repo;
    if (_note == null || repo == null) return;
    final all = await repo.getAllNotes();
    var root = _note!;
    final byId = {for (final note in all) note.id: note};
    final seen = <String>{};
    while (root.parentId != null && seen.add(root.id) && byId[root.parentId] != null) { root = byId[root.parentId]!; }
    if (!mounted) return;
    await openScreen(context, (_) => ShipToAgentPanel(root: root, notes: all, repository: repo));
    await _loadNoteData();
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
          automaticallyImplyLeading: widget.onNavigateToNote == null,
          leading: widget.onNavigateToNote == null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18.0),
                  color: context.appTextPrimary,
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
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
          automaticallyImplyLeading: widget.onNavigateToNote == null,
          leading: widget.onNavigateToNote == null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18.0),
                  color: context.appTextPrimary,
                  onPressed: _handleBack,
                )
              : null,
          centerTitle: false,
          toolbarHeight: _isEmbedded ? 44.0 : null,
          titleSpacing: _isEmbedded ? widget.embeddedTitleInset : null,
          title: _isEmbedded ? _buildEmbeddedBreadcrumb() : null,
          actions: [
            if (_note!.isIdea)
              TextButton(onPressed: _shipToAgent, child: const Text('Ship to agent')),
            TextButton(
              onPressed: _openAiActions,
              style: TextButton.styleFrom(
                foregroundColor: context.appTextSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                minimumSize: const Size(40.0, 36.0),
              ),
              child: Text(
                '✦ AI',
                style: AppTypography.uiLabel(
                  fontSize: 14.0,
                  color: context.appTextSecondary,
                ),
              ),
            ),
            PopupMenuButton<String>(
              key: const Key('note_more_menu'),
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
                  case 'add_page':
                    _addPageInside();
                  case 'understand':
                    _openUnderstandNote();
                  case 'delete':
                    _confirmDelete();
                  case 'ship':
                    _shipToAgent();
                }
              },
              itemBuilder: (context) => [
                if (_note!.isIdea) const PopupMenuItem(value: 'ship', child: Text('Ship to agent')),
                PopupMenuItem(value: 'add_page', child: Text('Add page inside')),
                PopupMenuItem(value: 'understand', child: Text('Understand note')),
                PopupMenuItem(value: 'delete', child: Text('Delete note')),
              ],
            ),
            const SizedBox(width: 4.0),
          ],
        ),
        bottomNavigationBar: _isWritingBody && !_isEmbedded ? _buildFormattingToolbar() : null,
        body: SafeArea(
          // Tapping the empty page below the text continues writing there.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focusBody(atEnd: true),
            child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 24.0, top: 12.0, bottom: 12.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720.0),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The editor's drag-handle gutter (26px) sits in the left margin,
                // so its text lines up with the title.
                Padding(
                  padding: const EdgeInsets.only(left: 26.0),
                  child: _buildBreadcrumbs(),
                ),
                if (_note!.isIdea && _note!.parentId == null)
                  Padding(
                    padding: const EdgeInsets.only(left: 26, top: 12),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [for (final status in Note.ideaStatuses) ChoiceChip(label: Text(status), selected: _note!.ideaStatus == status, onSelected: (_) => _setIdeaStatus(status))]),
                  ),
                if (_note!.handedOffTo != null && _note!.handedOffAt != null)
                  Padding(padding: const EdgeInsets.only(left: 26, top: 8), child: Text('Handed off to ${_note!.handedOffTo} on ${_shortDate(_note!.handedOffAt!)}.', style: AppTypography.uiLabel(fontSize: 12, color: context.appTextSecondary))),

                Padding(
                  padding: const EdgeInsets.only(left: 26.0),
                  child: TextField(
                  key: const Key('note_title_field'),
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  autofocus: widget.initialNote?.title.isEmpty ?? false,
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
                  textInputAction: TextInputAction.next,
                  // Replaces the default next-field move, so focus moves only once.
                  onEditingComplete: _focusBody,
                  ),
                ),
                const SizedBox(height: 16.0),

                // Block-based continuous Document Editor
                BlockNoteEditor(
                  key: _editorKey,
                  blocks: _currentBlocks,
                  noteRepository: _repo,
                  onChanged: _onBlocksChanged,
                  onOpenNote: _openPageBlockNote,
                  desktopFormatting: _isEmbedded,
                  onRequestNewPage: _addPageInside,
                ),

                const SizedBox(height: 56.0),
              ],
            ),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }

  void _focusBody({bool atEnd = false}) {
    final state = _editorKey.currentState;
    if (state != null) {
      dynamic dynamicState = state;
      dynamicState.focusBody(atEnd: atEnd);
    }
  }

  String _shortDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }


  bool get _isEmbedded => widget.onNavigateToNote != null;

  /// The path along the top of the pane. Deep paths collapse their middle.
  Widget _buildEmbeddedBreadcrumb() {
    final shown = _ancestors.length > 3
        ? [_ancestors.first, null, ..._ancestors.sublist(_ancestors.length - 2)]
        : _ancestors;
    final style = AppTypography.uiLabel(fontSize: 12.0, fontWeight: FontWeight.w400, color: context.appTextSecondary);
    return Row(
      key: const Key('note_breadcrumb'),
      children: [
        for (final ancestor in shown) ...[
          if (ancestor == null)
            Text('...', style: style)
          else
            Flexible(
              child: InkWell(
                onTap: () => _navigateToAncestor(ancestor),
                borderRadius: BorderRadius.circular(4),
                child: Text(
                  ancestor.title.isEmpty ? 'Untitled' : ancestor.title,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Text('/', style: style),
          ),
        ],
      ],
    );
  }

  Widget _buildBreadcrumbs() {
    if (_ancestors.isEmpty || _isEmbedded) return const SizedBox.shrink();

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
                      color: context.appTextTertiary,
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
                      color: context.appTextSecondary,
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
            if (bottomInset > 0)
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

class _NewPageDialog extends StatefulWidget {
  const _NewPageDialog();

  @override
  State<_NewPageDialog> createState() => _NewPageDialogState();
}

class _NewPageDialogState extends State<_NewPageDialog> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appSurface,
      title: Text(
        'New page inside this note',
        style: AppTypography.title(fontSize: 18.0, color: context.appTextPrimary),
      ),
      content: TextField(
        key: const Key('new_page_name_field'),
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Page name'),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_nameController.text.trim()),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
