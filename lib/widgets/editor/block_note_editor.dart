import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/di/repository_scope.dart';
import '../../models/note.dart';
import '../../models/note_block.dart';
import '../../repositories/note_repository.dart';
import 'page_block_picker_sheet.dart';

class BlockDragData {
  final int sourceIndex;
  final String blockId;
  final int subtreeCount;
  final List<NoteBlock> subtreeBlocks;

  BlockDragData({
    required this.sourceIndex,
    required this.blockId,
    required this.subtreeCount,
    required this.subtreeBlocks,
  });
}

class RichTextEditingController extends TextEditingController {
  List<InlineAttribute> attributes;

  RichTextEditingController({
    super.text,
    List<InlineAttribute>? attributes,
  }) : attributes = attributes != null ? List.from(attributes) : [];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final currentText = text;

    if (attributes.isEmpty || currentText.isEmpty) {
      return TextSpan(style: baseStyle, text: currentText);
    }

    final len = currentText.length;
    final validAttrs = attributes.where((a) => a.start < len && a.end > 0 && a.start < a.end).toList();
    if (validAttrs.isEmpty) {
      return TextSpan(style: baseStyle, text: currentText);
    }

    final boundaries = <int>{0, len};
    for (final attr in validAttrs) {
      final s = attr.start.clamp(0, len);
      final e = attr.end.clamp(0, len);
      if (s < e) {
        boundaries.add(s);
        boundaries.add(e);
      }
    }

    final sortedPoints = boundaries.toList()..sort();
    final spans = <TextSpan>[];

    for (int i = 0; i < sortedPoints.length - 1; i++) {
      final segStart = sortedPoints[i];
      final segEnd = sortedPoints[i + 1];
      if (segEnd <= segStart) continue;

      final segText = currentText.substring(segStart, segEnd);
      bool isBold = false;
      bool isItalic = false;

      for (final attr in validAttrs) {
        final s = attr.start.clamp(0, len);
        final e = attr.end.clamp(0, len);
        if (s <= segStart && e >= segEnd) {
          if (attr.type == 'bold') isBold = true;
          if (attr.type == 'italic') isItalic = true;
        }
      }

      TextStyle charStyle = baseStyle;
      if (isBold) charStyle = charStyle.copyWith(fontWeight: FontWeight.bold);
      if (isItalic) charStyle = charStyle.copyWith(fontStyle: FontStyle.italic);

      spans.add(TextSpan(text: segText, style: charStyle));
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}


class BlockNoteEditor extends StatefulWidget {
  final List<NoteBlock> blocks;
  final NoteRepository? noteRepository;
  final ValueChanged<List<NoteBlock>> onChanged;
  final Function(String targetNoteId)? onOpenNote;

  const BlockNoteEditor({
    super.key,
    required this.blocks,
    this.noteRepository,
    required this.onChanged,
    this.onOpenNote,
  });

  @override
  State<BlockNoteEditor> createState() => BlockNoteEditorState();
}

class BlockNoteEditorState extends State<BlockNoteEditor> {
  NoteRepository? get _effectiveRepo =>
      widget.noteRepository ?? RepositoryScope.maybeOf(context)?.noteRepository;

  late List<NoteBlock> _blocks;
  final List<RichTextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  int _activeBlockIndex = 0;

  // Drag state
  int? _dropTargetIndex;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _initBlocks(widget.blocks);
  }

  @override
  void didUpdateWidget(BlockNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final externalIds = widget.blocks.map((b) => b.id).toList();
    final internalIds = _blocks.map((b) => b.id).toList();
    if (!listEquals(externalIds, internalIds)) {
      _initBlocks(widget.blocks);
    }
  }

  void _setActiveIndex(int index) {
    if (_activeBlockIndex != index && index >= 0 && index < _blocks.length) {
      setState(() => _activeBlockIndex = index);
    }
  }

  void _initBlocks(List<NoteBlock> initialBlocks) {
    _clearControllers();
    _blocks = initialBlocks.isEmpty
        ? [NoteBlock(type: BlockType.text, content: '')]
        : List.from(initialBlocks);

    for (int i = 0; i < _blocks.length; i++) {
      var block = _blocks[i];
      if (block.type == BlockType.bullet || block.type == BlockType.number) {
        final cleaned = cleanMarkerPrefix(block.content);
        if (cleaned != block.content) {
          block = block.copyWith(content: cleaned);
          _blocks[i] = block;
        }
      }
      final controller = RichTextEditingController(
        text: block.content,
        attributes: block.inlineAttributes,
      );
      final focusNode = FocusNode();

      _controllers.add(controller);
      _focusNodes.add(focusNode);
    }
  }

  void _clearControllers() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _controllers.clear();
    _focusNodes.clear();
  }

  @override
  void dispose() {
    _clearControllers();
    super.dispose();
  }

  void _notifyChanged() {
    for (int i = 0; i < _blocks.length; i++) {
      if (_blocks[i].type != BlockType.divider && _blocks[i].type != BlockType.page) {
        _blocks[i] = _blocks[i].copyWith(
          content: _controllers[i].text,
          inlineAttributes: _controllers[i].attributes,
        );
      }
    }
    widget.onChanged(List.unmodifiable(_blocks));
  }

  int get activeBlockIndex => _activeBlockIndex;

  NoteBlock get activeBlock =>
      _blocks.isNotEmpty && _activeBlockIndex < _blocks.length
          ? _blocks[_activeBlockIndex]
          : _blocks.first;

  List<NoteBlock> get blocks => List.unmodifiable(_blocks);

  List<int> getSubtreeIndices(int startIndex) {
    if (startIndex < 0 || startIndex >= _blocks.length) return [];
    final parentLevel = _blocks[startIndex].indentLevel;
    final indices = <int>[startIndex];
    for (int i = startIndex + 1; i < _blocks.length; i++) {
      if (_blocks[i].indentLevel > parentLevel) {
        indices.add(i);
      } else {
        break;
      }
    }
    return indices;
  }

  void moveSubtree({required int sourceIndex, required int targetIndex, int? newIndentLevel}) {
    final count = getSubtreeIndices(sourceIndex).length;
    final targetLevel = newIndentLevel ?? _blocks[sourceIndex].indentLevel;
    _moveSubtree(
      sourceStartIndex: sourceIndex,
      subtreeCount: count,
      targetInsertIndex: targetIndex,
      newIndentLevel: targetLevel,
    );
  }

  void _moveSubtree({
    required int sourceStartIndex,
    required int subtreeCount,
    required int targetInsertIndex,
    required int newIndentLevel,
  }) {
    if (sourceStartIndex < 0 || sourceStartIndex >= _blocks.length) return;
    if (targetInsertIndex < 0 || targetInsertIndex > _blocks.length) return;

    final movedBlocks = _blocks.sublist(sourceStartIndex, sourceStartIndex + subtreeCount);
    final movedControllers = _controllers.sublist(sourceStartIndex, sourceStartIndex + subtreeCount);
    final movedFocusNodes = _focusNodes.sublist(sourceStartIndex, sourceStartIndex + subtreeCount);

    final oldRootIndent = movedBlocks.first.indentLevel;
    final deltaIndent = newIndentLevel - oldRootIndent;

    final updatedSubtree = movedBlocks.map((b) {
      final updatedLevel = (b.indentLevel + deltaIndent).clamp(0, 5);
      return b.copyWith(indentLevel: updatedLevel);
    }).toList();

    _blocks.removeRange(sourceStartIndex, sourceStartIndex + subtreeCount);
    _controllers.removeRange(sourceStartIndex, sourceStartIndex + subtreeCount);
    _focusNodes.removeRange(sourceStartIndex, sourceStartIndex + subtreeCount);

    int insertPos = targetInsertIndex;
    if (targetInsertIndex > sourceStartIndex) {
      insertPos = (targetInsertIndex - subtreeCount).clamp(0, _blocks.length);
    } else {
      insertPos = targetInsertIndex.clamp(0, _blocks.length);
    }

    _blocks.insertAll(insertPos, updatedSubtree);
    _controllers.insertAll(insertPos, movedControllers);
    _focusNodes.insertAll(insertPos, movedFocusNodes);

    _activeBlockIndex = insertPos;
    setState(() {});
    _notifyChanged();
  }

  void toggleBold() => _toggleAttribute('bold');
  void toggleItalic() => _toggleAttribute('italic');

  void _toggleAttribute(String type) {
    if (_activeBlockIndex >= _controllers.length) return;
    final controller = _controllers[_activeBlockIndex];
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final start = selection.start;
    final end = selection.end;
    final currentAttrs = List<InlineAttribute>.from(controller.attributes);
    final existingIndex = currentAttrs.indexWhere(
      (a) => a.type == type && a.start == start && a.end == end,
    );

    if (existingIndex >= 0) {
      currentAttrs.removeAt(existingIndex);
    } else {
      currentAttrs.add(InlineAttribute(start: start, end: end, type: type));
    }

    setState(() {
      controller.attributes = currentAttrs;
      _blocks[_activeBlockIndex] = _blocks[_activeBlockIndex].copyWith(inlineAttributes: currentAttrs);
    });
    _notifyChanged();
  }

  void setBlockType(BlockType type) {
    if (_activeBlockIndex >= _blocks.length) return;
    final currentBlock = _blocks[_activeBlockIndex];
    final cleaned = cleanMarkerPrefix(_controllers[_activeBlockIndex].text);
    _controllers[_activeBlockIndex].text = cleaned;
    final newType = currentBlock.type == type ? BlockType.text : type;
    setState(() {
      _blocks[_activeBlockIndex] = currentBlock.copyWith(type: newType, content: cleaned);
    });
    _notifyChanged();
  }

  void transformBlock(int index, BlockType newType, {String? targetNoteId}) {
    if (index < 0 || index >= _blocks.length) return;
    final currentBlock = _blocks[index];
    final cleaned = cleanMarkerPrefix(_controllers[index].text);
    _controllers[index].text = cleaned;
    setState(() {
      _blocks[index] = currentBlock.copyWith(
        type: newType,
        content: cleaned,
        targetNoteId: targetNoteId ?? currentBlock.targetNoteId,
      );
    });
    _notifyChanged();
  }

  void increaseIndent() {
    if (_activeBlockIndex >= _blocks.length) return;
    final block = _blocks[_activeBlockIndex];
    setState(() {
      _blocks[_activeBlockIndex] = block.copyWith(indentLevel: (block.indentLevel + 1).clamp(0, 5));
    });
    _notifyChanged();
  }

  void decreaseIndent() {
    if (_activeBlockIndex >= _blocks.length) return;
    final block = _blocks[_activeBlockIndex];
    setState(() {
      _blocks[_activeBlockIndex] = block.copyWith(indentLevel: (block.indentLevel - 1).clamp(0, 5));
    });
    _notifyChanged();
  }

  void insertTextBlock(BlockType type, {bool replaceIfEmpty = true}) {
    if (_activeBlockIndex >= 0 && _activeBlockIndex < _blocks.length) {
      final current = _blocks[_activeBlockIndex];
      final currentText = _controllers[_activeBlockIndex].text.trim();
      if (replaceIfEmpty && current.type == BlockType.text && currentText.isEmpty) {
        setBlockType(type);
        return;
      }
    }

    final insertIndex = (_activeBlockIndex + 1).clamp(0, _blocks.length);
    final newBlock = NoteBlock(
      type: type,
      content: '',
      indentLevel: _activeBlockIndex >= 0 && _activeBlockIndex < _blocks.length
          ? _blocks[_activeBlockIndex].indentLevel
          : 0,
    );

    setState(() {
      _blocks.insert(insertIndex, newBlock);
      final controller = RichTextEditingController(text: '');
      final fNode = FocusNode();
      final targetIdx = insertIndex;
      fNode.addListener(() {
        if (fNode.hasFocus) setState(() => _activeBlockIndex = targetIdx);
      });
      _controllers.insert(insertIndex, controller);
      _focusNodes.insert(insertIndex, fNode);
      _activeBlockIndex = insertIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) => fNode.requestFocus());
    });
    _notifyChanged();
  }

  void insertPageBlock(String targetNoteId, {bool replaceIfEmpty = true}) {
    final newBlock = NoteBlock(
      type: BlockType.page,
      targetNoteId: targetNoteId,
      indentLevel: _activeBlockIndex >= 0 && _activeBlockIndex < _blocks.length
          ? _blocks[_activeBlockIndex].indentLevel
          : 0,
    );

    if (_activeBlockIndex >= 0 && _activeBlockIndex < _blocks.length) {
      final current = _blocks[_activeBlockIndex];
      final currentText = _controllers[_activeBlockIndex].text.trim();
      if (replaceIfEmpty && current.type == BlockType.text && currentText.isEmpty) {
        setState(() {
          _blocks[_activeBlockIndex] = newBlock;
          _controllers[_activeBlockIndex].text = '';
          final textBlockIndex = _activeBlockIndex + 1;
          final trailingText = NoteBlock(type: BlockType.text, content: '');
          _blocks.insert(textBlockIndex, trailingText);
          final controller = RichTextEditingController(text: '');
          final fNode = FocusNode();
          final nextIdx = textBlockIndex;
          fNode.addListener(() {
            if (fNode.hasFocus) setState(() => _activeBlockIndex = nextIdx);
          });
          _controllers.insert(textBlockIndex, controller);
          _focusNodes.insert(textBlockIndex, fNode);
          _activeBlockIndex = textBlockIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) => fNode.requestFocus());
        });
        _notifyChanged();
        return;
      }
    }
    _insertBlockAtActive(newBlock);
  }

  void insertDividerBlock({bool replaceIfEmpty = true}) {
    final newBlock = NoteBlock(
      type: BlockType.divider,
      indentLevel: _activeBlockIndex >= 0 && _activeBlockIndex < _blocks.length
          ? _blocks[_activeBlockIndex].indentLevel
          : 0,
    );

    if (_activeBlockIndex >= 0 && _activeBlockIndex < _blocks.length) {
      final current = _blocks[_activeBlockIndex];
      final currentText = _controllers[_activeBlockIndex].text.trim();
      if (replaceIfEmpty && current.type == BlockType.text && currentText.isEmpty) {
        setState(() {
          _blocks[_activeBlockIndex] = newBlock;
          _controllers[_activeBlockIndex].text = '';
          final textBlockIndex = _activeBlockIndex + 1;
          final trailingText = NoteBlock(type: BlockType.text, content: '');
          _blocks.insert(textBlockIndex, trailingText);
          final controller = RichTextEditingController(text: '');
          final fNode = FocusNode();
          final nextIdx = textBlockIndex;
          fNode.addListener(() {
            if (fNode.hasFocus) setState(() => _activeBlockIndex = nextIdx);
          });
          _controllers.insert(textBlockIndex, controller);
          _focusNodes.insert(textBlockIndex, fNode);
          _activeBlockIndex = textBlockIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) => fNode.requestFocus());
        });
        _notifyChanged();
        return;
      }
    }
    _insertBlockAtActive(newBlock);
  }

  void deleteBlock(int index) {
    if (index < 0 || index >= _blocks.length) return;
    if (_blocks.length <= 1) {
      setState(() {
        _blocks[0] = NoteBlock(type: BlockType.text, content: '');
        _controllers[0].text = '';
      });
      _notifyChanged();
      return;
    }

    setState(() {
      _blocks.removeAt(index);
      _controllers[index].dispose();
      _focusNodes[index].dispose();
      _controllers.removeAt(index);
      _focusNodes.removeAt(index);
      final newActive = (index > 0 ? index - 1 : 0).clamp(0, _blocks.length - 1);
      _activeBlockIndex = newActive;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (newActive < _focusNodes.length) _focusNodes[newActive].requestFocus();
      });
    });
    _notifyChanged();
  }

  void _insertBlockAtActive(NoteBlock block) {
    final insertIndex = _activeBlockIndex + 1;
    setState(() {
      _blocks.insert(insertIndex, block);
      final controller = RichTextEditingController(
        text: block.content,
        attributes: block.inlineAttributes,
      );
      final focusNode = FocusNode();
      _controllers.insert(insertIndex, controller);
      _focusNodes.insert(insertIndex, focusNode);
      _activeBlockIndex = insertIndex;
    });
    _notifyChanged();

    final textBlockIndex = insertIndex + 1;
    final trailingText = NoteBlock(type: BlockType.text, content: '');
    setState(() {
      _blocks.insert(textBlockIndex, trailingText);
      _controllers.insert(textBlockIndex, RichTextEditingController(text: ''));
      final fNode = FocusNode();
      _focusNodes.insert(textBlockIndex, fNode);
      _activeBlockIndex = textBlockIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) => fNode.requestFocus());
    });
    _notifyChanged();
  }

  void insertBlockAfter(int index, String content) {
    if (index < 0 || index >= _blocks.length) return;
    final currentBlock = _blocks[index];

    BlockType newType = BlockType.text;
    if (currentBlock.type == BlockType.bullet) newType = BlockType.bullet;
    else if (currentBlock.type == BlockType.number) newType = BlockType.number;

    final newBlock = NoteBlock(
      type: newType,
      content: content,
      indentLevel: currentBlock.indentLevel,
    );
    final insertIndex = index + 1;

    final controller = RichTextEditingController(text: content);
    final focusNode = FocusNode();

    setState(() {
      _blocks.insert(insertIndex, newBlock);
      _controllers.insert(insertIndex, controller);
      _focusNodes.insert(insertIndex, focusNode);
      _activeBlockIndex = insertIndex;
    });
    _notifyChanged();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (insertIndex < _focusNodes.length) {
        _focusNodes[insertIndex].requestFocus();
        controller.selection = const TextSelection.collapsed(offset: 0);
      }
    });
  }

  void _handleEnter(int index) {
    final currentBlock = _blocks[index];
    final controller = _controllers[index];
    final text = controller.text;

    if ((currentBlock.type == BlockType.bullet || currentBlock.type == BlockType.number) &&
        text.trim().isEmpty) {
      setState(() {
        _blocks[index] = currentBlock.copyWith(type: BlockType.text, content: '', indentLevel: 0);
        controller.text = '';
      });
      _notifyChanged();
      return;
    }

    insertBlockAfter(index, '');
  }

  void _handleBackspace(int index) {
    final currentBlock = _blocks[index];
    final controller = _controllers[index];

    if (controller.selection.isCollapsed && controller.selection.start == 0) {
      if (currentBlock.indentLevel > 0) {
        decreaseIndent();
        return;
      } else if (currentBlock.type != BlockType.text) {
        setState(() => _blocks[index] = currentBlock.copyWith(type: BlockType.text));
        _notifyChanged();
        return;
      } else if (_blocks.length > 1 && index > 0) {
        final prevIndex = index - 1;
        final prevController = _controllers[prevIndex];
        final prevText = prevController.text;
        final currentText = controller.text;
        final mergedText = prevText + currentText;

        setState(() {
          _blocks.removeAt(index);
          controller.dispose();
          _focusNodes[index].dispose();
          _controllers.removeAt(index);
          _focusNodes.removeAt(index);

          _blocks[prevIndex] = _blocks[prevIndex].copyWith(content: mergedText);
          prevController.value = TextEditingValue(
            text: mergedText,
            selection: TextSelection.collapsed(offset: prevText.length),
          );

          _activeBlockIndex = prevIndex;
        });
        _notifyChanged();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (prevIndex < _focusNodes.length) {
            _focusNodes[prevIndex].requestFocus();
          }
        });
        return;
      }
    }
  }

  int _calculateNumberSequence(int index) {
    final targetLevel = _blocks[index].indentLevel;
    int count = 1;
    for (int i = index - 1; i >= 0; i--) {
      final b = _blocks[i];
      if (b.type == BlockType.number) {
        if (b.indentLevel == targetLevel) count++;
        else if (b.indentLevel < targetLevel) break;
      } else {
        break;
      }
    }
    return count;
  }

  // ── Drag coordination ───────────────────────────────────────────────────────

  void _onDragStarted(int index) {
    HapticFeedback.selectionClick();
    setState(() => _isDragging = true);
  }

  void _onDragEnd() {
    setState(() {
      _isDragging = false;
      _dropTargetIndex = null;
    });
  }

  void _updateDropTarget(int index, Offset localPos, double rowHeight) {
    final newTarget = localPos.dy > rowHeight / 2 ? index + 1 : index;
    if (_dropTargetIndex != newTarget) setState(() => _dropTargetIndex = newTarget);
  }

  void _acceptDrop(BlockDragData data) {
    final targetIdx = _dropTargetIndex ?? data.sourceIndex;
    final targetLevel = data.sourceIndex < _blocks.length
        ? _blocks[data.sourceIndex].indentLevel
        : 0;
    _moveSubtree(
      sourceStartIndex: data.sourceIndex,
      subtreeCount: data.subtreeCount,
      targetInsertIndex: targetIdx,
      newIndentLevel: targetLevel,
    );
    setState(() {
      _isDragging = false;
      _dropTargetIndex = null;
    });
    _notifyChanged();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _blocks.length; i++) ...[
          if (_isDragging && _dropTargetIndex == i)
            _buildDropIndicator(context, _blocks[i].indentLevel),
          _BlockRow(
            key: ValueKey(_blocks[i].id),
            index: i,
            block: _blocks[i],
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            isDragging: _isDragging,
            editorState: this,
          ),
        ],
        if (_isDragging && _dropTargetIndex == _blocks.length)
          _buildDropIndicator(context, 0),

        // Dedicated bottom drop target so dragging down anywhere past/below
        // the existing blocks reliably places the item at the bottom of the note.
        DragTarget<BlockDragData>(
          onWillAcceptWithDetails: (details) {
            if (_dropTargetIndex != _blocks.length) {
              setState(() => _dropTargetIndex = _blocks.length);
            }
            return true;
          },
          onMove: (details) {
            if (_dropTargetIndex != _blocks.length) {
              setState(() => _dropTargetIndex = _blocks.length);
            }
          },
          onAcceptWithDetails: (details) {
            _dropTargetIndex = _blocks.length;
            _acceptDrop(details.data);
          },
          builder: (context, candidateData, rejectedData) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_focusNodes.isNotEmpty) {
                  _focusNodes.last.requestFocus();
                }
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: double.infinity,
                  minHeight: _isDragging ? 320.0 : 64.0,
                ),
                child: const ColoredBox(color: Colors.transparent),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDropIndicator(BuildContext context, int level) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white70 : const Color(0xFF2563EB);
    return Padding(
      padding: EdgeInsets.only(left: 28.0 + (20.0 * level), top: 1, bottom: 1, right: 16),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          Expanded(child: Container(height: 2, color: color)),
        ],
      ),
    );
  }

  // ── Block actions sheet ─────────────────────────────────────────────────────

  void showBlockActionsSheet(BuildContext context, int index) {
    final block = _blocks[index];
    final currentType = block.type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sheetLabel('TURN INTO', isDark),
                  _sheetTile(ctx, 'Text', Icons.notes_rounded, currentType == BlockType.text,
                      () => transformBlock(index, BlockType.text)),
                  _sheetTile(ctx, 'Heading', Icons.title_rounded, currentType == BlockType.heading,
                      () => transformBlock(index, BlockType.heading)),
                  ListTile(
                    dense: true,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text('•', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    title: const Text('Bulleted list'),
                    trailing: currentType == BlockType.bullet ? const Icon(Icons.check, size: 18) : null,
                    onTap: () { Navigator.of(ctx).pop(); transformBlock(index, BlockType.bullet); },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                      child: Text('1.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    title: const Text('Numbered list'),
                    trailing: currentType == BlockType.number ? const Icon(Icons.check, size: 18) : null,
                    onTap: () { Navigator.of(ctx).pop(); transformBlock(index, BlockType.number); },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.description_outlined, size: 20),
                    title: const Text('Page'),
                    trailing: currentType == BlockType.page ? const Icon(Icons.check, size: 18) : null,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final selectedNoteId = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        builder: (sheetCtx) => PageBlockPickerSheet(
                          currentNoteId: '',
                          noteRepository: _effectiveRepo,
                        ),
                      );
                      if (selectedNoteId != null) {
                        transformBlock(index, BlockType.page, targetNoteId: selectedNoteId);
                      }
                    },
                  ),
                  _sheetTile(ctx, 'Divider', Icons.horizontal_rule_rounded,
                      currentType == BlockType.divider, () => transformBlock(index, BlockType.divider)),
                  const Divider(height: 16),
                  _sheetLabel('ACTIONS', isDark),
                  _sheetTile(ctx, 'Indent', Icons.format_indent_increase_rounded, false, () {
                    _activeBlockIndex = index; increaseIndent();
                  }),
                  _sheetTile(ctx, 'Outdent', Icons.format_indent_decrease_rounded, false, () {
                    _activeBlockIndex = index; decreaseIndent();
                  }),
                  if (index > 0)
                    _sheetTile(ctx, 'Move up', Icons.arrow_upward_rounded, false,
                        () => moveSubtree(sourceIndex: index, targetIndex: index - 1)),
                  if (index < _blocks.length - 1)
                    _sheetTile(ctx, 'Move down', Icons.arrow_downward_rounded, false,
                        () => moveSubtree(sourceIndex: index, targetIndex: index + 2)),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                    title: const Text('Delete block', style: TextStyle(color: Colors.redAccent)),
                    onTap: () { Navigator.of(ctx).pop(); deleteBlock(index); },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sheetLabel(String text, bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.0, fontWeight: FontWeight.w700, letterSpacing: 0.8,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
    ),
  );

  Widget _sheetTile(BuildContext ctx, String title, IconData icon, bool isSelected, VoidCallback action) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(title),
      trailing: isSelected ? const Icon(Icons.check, size: 18) : null,
      onTap: () { Navigator.of(ctx).pop(); action(); },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BlockRow — self-contained stateful row managing its own hover state.
// The drag handle is invisible by default, fading in on hover.
// ─────────────────────────────────────────────────────────────────────────────

class _BlockRow extends StatefulWidget {
  final int index;
  final NoteBlock block;
  final RichTextEditingController controller;
  final FocusNode focusNode;
  final bool isDragging;
  final BlockNoteEditorState editorState;

  const _BlockRow({
    super.key,
    required this.index,
    required this.block,
    required this.controller,
    required this.focusNode,
    required this.isDragging,
    required this.editorState,
  });

  @override
  State<_BlockRow> createState() => _BlockRowState();
}

class _BlockRowState extends State<_BlockRow> {
  bool _isHovered = false;
  bool _isDragActive = false;

  BlockNoteEditorState get _editor => widget.editorState;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(_BlockRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (widget.focusNode.hasFocus) {
      _editor._setActiveIndex(widget.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final index = widget.index;
    final indentPadding = EdgeInsets.only(left: 20.0 * block.indentLevel);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // On mobile there is no hover, so always show the handle (at reduced opacity
    // when idle) so users can see where to press-and-hold to drag.
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
    final isActive = _editor.activeBlockIndex == index;
    final handleOpacity = _isDragActive || (isMobile && isActive)
        ? 1.0
        : isMobile
            ? 0.35          // always faintly visible on mobile
            : _isHovered
                ? 1.0
                : 0.0;      // hidden on desktop until hover

    final subtreeCount = _editor.getSubtreeIndices(index).length;
    final dragData = BlockDragData(
      sourceIndex: index,
      blockId: block.id,
      subtreeCount: subtreeCount,
      subtreeBlocks: _editor.blocks.sublist(index, index + subtreeCount),
    );

    final handleChild = InkWell(
      onTap: () => _editor.showBlockActionsSheet(context, index),
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 26,
        child: Padding(
          padding: const EdgeInsets.only(right: 6, top: 4, left: 2, bottom: 4),
          child: AnimatedOpacity(
            opacity: handleOpacity,
            duration: const Duration(milliseconds: 150),
            child: Icon(
              Icons.drag_indicator_rounded,
              size: 18,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );

    final dragHandle = LongPressDraggable<BlockDragData>(
      data: dragData,
      delay: const Duration(milliseconds: 200),
      hapticFeedbackOnStart: true,
      onDragStarted: () {
        setState(() => _isDragActive = true);
        _editor._onDragStarted(index);
      },
      onDragEnd: (_) {
        setState(() => _isDragActive = false);
        _editor._onDragEnd();
      },
      onDraggableCanceled: (_, __) {
        setState(() => _isDragActive = false);
        _editor._onDragEnd();
      },
      feedback: _DragFeedbackCard(block: block, subtreeCount: subtreeCount, isDark: isDark),
      childWhenDragging: SizedBox(
        width: 26,
        child: Padding(
          padding: const EdgeInsets.only(right: 6, top: 4, left: 2, bottom: 4),
          child: Opacity(
            opacity: 0.2,
            child: Icon(Icons.drag_indicator_rounded, size: 18,
                color: isDark ? Colors.white : Colors.black),
          ),
        ),
      ),
      child: handleChild,
    );

    final rowContent = _buildContent(context, block, index, dragHandle, indentPadding);

    final dragTarget = DragTarget<BlockDragData>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        final willAccept = !(data.sourceIndex <= index && index < data.sourceIndex + data.subtreeCount);
        if (willAccept) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final localPos = renderBox.globalToLocal(details.offset);
            _editor._updateDropTarget(index, localPos, renderBox.size.height);
          }
        }
        return willAccept;
      },
      onMove: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final localPos = renderBox.globalToLocal(details.offset);
          _editor._updateDropTarget(index, localPos, renderBox.size.height);
        }
      },
      onLeave: (_) {/* intentionally keep last target — _dropTargetIndex preserved for onAccept */},
      onAcceptWithDetails: (details) => _editor._acceptDrop(details.data),
      builder: (_, __, ___) => rowContent,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: dragTarget,
    );
  }

  Widget _buildContent(
    BuildContext context,
    NoteBlock block,
    int index,
    Widget dragHandle,
    EdgeInsets indentPadding,
  ) {
    if (block.type == BlockType.divider) {
      return Padding(
        padding: indentPadding.add(const EdgeInsets.symmetric(vertical: 4.0)),
        child: Row(
          children: [dragHandle, const Expanded(child: Divider(thickness: 1.5))],
        ),
      );
    }

    if (block.type == BlockType.page) {
      return Padding(
        padding: indentPadding.add(const EdgeInsets.symmetric(vertical: 2.0)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            dragHandle,
            Expanded(child: _buildPageLineWidget(context, block.targetNoteId, block.content)),
          ],
        ),
      );
    }

    Widget prefixWidget = const SizedBox.shrink();
    TextStyle textStyle = const TextStyle(fontSize: 16, height: 1.4);

    if (block.type == BlockType.heading) {
      textStyle = const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3);
    } else if (block.type == BlockType.bullet) {
      prefixWidget = const Padding(
        padding: EdgeInsets.only(right: 8.0, top: 2.0),
        child: Text('•', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );
    } else if (block.type == BlockType.number) {
      final seq = _editor._calculateNumberSequence(index);
      prefixWidget = Padding(
        padding: const EdgeInsets.only(right: 8.0, top: 2.0),
        child: Text('$seq.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }

    final controller = widget.controller;
    final focusNode = widget.focusNode;

    return Padding(
      padding: indentPadding.add(const EdgeInsets.symmetric(vertical: 2.0)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dragHandle,
          prefixWidget,
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): () => _editor._handleEnter(index),
                const SingleActivator(LogicalKeyboardKey.backspace): () {
                  if (controller.selection.isCollapsed && controller.selection.start == 0) {
                    _editor._handleBackspace(index);
                  }
                },
              },
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: textStyle,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 4.0),
                ),
                onChanged: (val) {
                  if (val.contains('\n')) {
                    final lines = val.split('\n');
                    final firstLine = lines.first;

                    var targetType = widget.block.type;
                    var cleanedFirst = firstLine;
                    if (targetType == BlockType.text) {
                      if (firstLine.startsWith('• ') || firstLine.startsWith('- ') || firstLine.startsWith('* ')) {
                        targetType = BlockType.bullet;
                        cleanedFirst = cleanMarkerPrefix(firstLine);
                      } else if (RegExp(r'^\d+\.\s+').hasMatch(firstLine)) {
                        targetType = BlockType.number;
                        cleanedFirst = cleanMarkerPrefix(firstLine);
                      }
                    }

                    controller.value = TextEditingValue(
                      text: cleanedFirst,
                      selection: TextSelection.collapsed(offset: cleanedFirst.length),
                    );
                    _editor._blocks[index] = _editor._blocks[index].copyWith(
                      type: targetType,
                      content: cleanedFirst,
                    );
                    _editor._notifyChanged();

                    int currentInsertIdx = index;
                    for (int i = 1; i < lines.length; i++) {
                      _editor.insertBlockAfter(currentInsertIdx, lines[i]);
                      currentInsertIdx++;
                    }
                    return;
                  }

                  var updatedText = val;
                  BlockType targetType = widget.block.type;

                  if (targetType == BlockType.text) {
                    if (val.startsWith('• ') || val.startsWith('- ') || val.startsWith('* ')) {
                      targetType = BlockType.bullet;
                      updatedText = cleanMarkerPrefix(val);
                      controller.value = TextEditingValue(
                        text: updatedText,
                        selection: TextSelection.collapsed(offset: updatedText.length),
                      );
                    } else if (RegExp(r'^\d+\.\s+').hasMatch(val)) {
                      targetType = BlockType.number;
                      updatedText = cleanMarkerPrefix(val);
                      controller.value = TextEditingValue(
                        text: updatedText,
                        selection: TextSelection.collapsed(offset: updatedText.length),
                      );
                    }
                  } else if (targetType == BlockType.bullet || targetType == BlockType.number) {
                    if (val.startsWith('• ') || val.startsWith('- ') ||
                        val.startsWith('* ') || RegExp(r'^\d+\.\s+').hasMatch(val)) {
                      updatedText = cleanMarkerPrefix(val);
                      controller.value = TextEditingValue(
                        text: updatedText,
                        selection: TextSelection.collapsed(offset: updatedText.length),
                      );
                    }
                  }

                  _editor._blocks[index] = _editor._blocks[index].copyWith(
                    type: targetType,
                    content: updatedText,
                  );
                  _editor._notifyChanged();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageLineWidget(BuildContext context, String? targetNoteId, String fallbackTitle) {
    final repo = _editor._effectiveRepo;

    if (targetNoteId == null || repo == null) {
      final title = fallbackTitle.trim().isNotEmpty ? fallbackTitle.trim() : 'Untitled Page';
      return _pageLineContent(context, title: title, isAvailable: false, onTap: null);
    }

    return StreamBuilder<List<Note>>(
      stream: repo.watchAllNotes(),
      builder: (context, snapshot) {
        final targetNote = snapshot.data?.where((n) => n.id == targetNoteId).firstOrNull;
        
        String title;
        if (targetNote != null && targetNote.title.trim().isNotEmpty) {
          title = targetNote.title.trim();
        } else if (fallbackTitle.trim().isNotEmpty) {
          title = fallbackTitle.trim();
        } else if (snapshot.hasData) {
          title = targetNote != null ? 'Untitled' : 'Deleted Page Reference';
        } else {
          title = 'Loading...';
        }

        final isAvailable = targetNote != null || !snapshot.hasData;
        return _pageLineContent(
          context,
          title: title,
          isAvailable: isAvailable,
          onTap: () {
            if (widget.editorState.widget.onOpenNote != null && targetNote != null) {
              widget.editorState.widget.onOpenNote!(targetNoteId);
            }
          },
        );
      },
    );
  }

  Widget _pageLineContent(
    BuildContext context, {
    required String title,
    required bool isAvailable,
    required VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isAvailable
        ? (isDark ? Colors.white : Colors.black87)
        : (isDark ? Colors.white38 : Colors.black38);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        child: Row(
          children: [
            Icon(Icons.description_outlined, size: 15.0,
                color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280)),
            const SizedBox(width: 6.0),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16.0, height: 1.4, fontWeight: FontWeight.w500, color: textColor,
                  decoration: isAvailable ? TextDecoration.underline : TextDecoration.lineThrough,
                  decorationStyle: TextDecorationStyle.dotted,
                  decorationColor: isDark ? Colors.white38 : Colors.black38,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DragFeedbackCard
// ─────────────────────────────────────────────────────────────────────────────

class _DragFeedbackCard extends StatelessWidget {
  final NoteBlock block;
  final int subtreeCount;
  final bool isDark;

  const _DragFeedbackCard({
    required this.block,
    required this.subtreeCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final text = block.content.isEmpty
        ? (block.type == BlockType.page ? 'Page Link' : 'Empty line')
        : block.content;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_indicator_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (subtreeCount > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${subtreeCount - 1}',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
