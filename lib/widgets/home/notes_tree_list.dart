import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../models/note.dart';
import '../../models/note_block.dart';

/// The home list: top-level notes, each expandable to reveal the notes inside
/// it, to any depth. While searching it becomes a flat list of matches.
class NotesTreeList extends StatefulWidget {
  final List<Note> notes;
  final String searchQuery;
  final VoidCallback onCreateNote;
  final ValueChanged<Note> onOpenNote;
  final ValueChanged<Note>? onLongPressNote;
  final void Function(Note note, Offset globalPosition)? onNoteMenu;
  final bool compact;
  final String? selectedNoteId;

  const NotesTreeList({
    super.key,
    required this.notes,
    required this.searchQuery,
    required this.onCreateNote,
    required this.onOpenNote,
    this.onLongPressNote,
    this.onNoteMenu,
    this.compact = false,
    this.selectedNoteId,
  });

  /// Notes matching [query], in the same most-recent-first order as search.
  static List<Note> matchingNotes(List<Note> notes, String query) {
    final byRecent = List<Note>.from(notes)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return byRecent;
    return [
      for (final note in byRecent)
        if (note.title.toLowerCase().contains(normalized) ||
            note.content.toLowerCase().contains(normalized))
          note,
    ];
  }

  @override
  State<NotesTreeList> createState() => _NotesTreeListState();
}

class _NotesTreeListState extends State<NotesTreeList> {
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _expandSelectedAncestors();
  }

  @override
  void didUpdateWidget(covariant NotesTreeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedNoteId != oldWidget.selectedNoteId || widget.notes != oldWidget.notes) {
      _expandSelectedAncestors();
    }
  }

  void _expandSelectedAncestors() {
    final selectedId = widget.selectedNoteId;
    if (selectedId == null) return;
    final byId = {for (final note in widget.notes) note.id: note};
    var parentId = byId[selectedId]?.parentId;
    while (parentId != null) {
      _expandedIds.add(parentId);
      parentId = byId[parentId]?.parentId;
    }
  }

  List<({Note note, int depth, bool hasChildren})> _visibleRows() {
    final byRecent = List<Note>.from(widget.notes)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (widget.searchQuery.trim().isNotEmpty) {
      return [
        for (final note in NotesTreeList.matchingNotes(widget.notes, widget.searchQuery))
          (note: note, depth: 0, hasChildren: false),
      ];
    }

    final ids = {for (final note in byRecent) note.id};
    final childrenByParent = <String, List<Note>>{};
    final roots = <Note>[];
    for (final note in byRecent) {
      final parentId = note.parentId;
      if (parentId != null && ids.contains(parentId)) {
        childrenByParent.putIfAbsent(parentId, () => []).add(note);
      } else {
        roots.add(note);
      }
    }

    final rows = <({Note note, int depth, bool hasChildren})>[];
    void addRow(Note note, int depth) {
      final children = childrenByParent[note.id] ?? const <Note>[];
      rows.add((note: note, depth: depth, hasChildren: children.isNotEmpty));
      if (_expandedIds.contains(note.id)) {
        for (final child in children) {
          addRow(child, depth + 1);
        }
      }
    }

    for (final root in roots) {
      addRow(root, 0);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notes.isEmpty) {
      return _buildEmptyState(context);
    }

    final rows = _visibleRows();
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          'No notes match "${widget.searchQuery.trim()}".',
          style: AppTypography.subtitle(color: context.appTextSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: widget.compact
          ? const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0)
          : const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 96.0),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return widget.compact ? _CompactNoteRow(
          key: ValueKey('note_row_${row.note.id}'),
          note: row.note,
          depth: row.depth,
          hasChildren: row.hasChildren,
          isExpanded: _expandedIds.contains(row.note.id),
          isSelected: row.note.id == widget.selectedNoteId,
          onToggle: () {
            setState(() {
              if (!_expandedIds.remove(row.note.id)) _expandedIds.add(row.note.id);
            });
          },
          onTap: () => widget.onOpenNote(row.note),
          onLongPress: widget.onLongPressNote == null ? null : () => widget.onLongPressNote!(row.note),
          onNoteMenu: widget.onNoteMenu,
        ) : _NoteRow(
          key: ValueKey('note_row_${row.note.id}'),
          note: row.note,
          depth: row.depth,
          hasChildren: row.hasChildren,
          isExpanded: _expandedIds.contains(row.note.id),
          onToggle: () {
            setState(() {
              if (!_expandedIds.remove(row.note.id)) {
                _expandedIds.add(row.note.id);
              }
            });
          },
          onTap: () => widget.onOpenNote(row.note),
          onLongPress: () => widget.onLongPressNote?.call(row.note),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    if (widget.compact) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(8.0, 12.0, 8.0, 8.0),
        child: _CompactEmptyState(),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your notes will appear here.',
            style: AppTypography.subtitle(color: context.appTextSecondary),
          ),
          const SizedBox(height: 4.0),
          TextButton(
            onPressed: widget.onCreateNote,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: context.appTextPrimary,
            ),
            child: Text(
              'Create your first note',
              style: AppTypography.uiHeadline(color: context.appTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactEmptyState extends StatelessWidget {
  const _CompactEmptyState();

  @override
  Widget build(BuildContext context) => Text(
    'Your notes will appear here.',
    style: AppTypography.uiLabel(fontSize: 13.0, fontWeight: FontWeight.w400, color: context.appTextSecondary),
  );
}

class _CompactNoteRow extends StatefulWidget {
  final Note note;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(Note note, Offset globalPosition)? onNoteMenu;

  const _CompactNoteRow({super.key, required this.note, required this.depth, required this.hasChildren, required this.isExpanded, required this.isSelected, required this.onToggle, required this.onTap, this.onLongPress, this.onNoteMenu});

  @override
  State<_CompactNoteRow> createState() => _CompactNoteRowState();
}

class _CompactNoteRowState extends State<_CompactNoteRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.note.title.trim().isEmpty ? 'Untitled' : widget.note.title.trim();
    final showMore = (_hovered || _focused) && widget.onNoteMenu != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onNoteMenu == null
              ? widget.onLongPress
              : () {
                  final renderBox = context.findRenderObject() as RenderBox;
                  widget.onNoteMenu!(
                    widget.note,
                    renderBox.localToGlobal(renderBox.size.center(Offset.zero)),
                  );
                },
          onSecondaryTapUp: widget.onNoteMenu == null
              ? null
              : (details) => widget.onNoteMenu!(widget.note, details.globalPosition),
          child: Container(
            height: 30.0,
            decoration: BoxDecoration(
              color: widget.isSelected ? context.appRowSelected : (_hovered ? context.appRowHover : null),
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Row(children: [
              SizedBox(width: 16.0 * widget.depth),
              SizedBox(
                width: 22.0,
                child: widget.hasChildren ? IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 22.0, height: 30.0),
                  onPressed: widget.onToggle,
                  icon: Icon(widget.isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded, size: 18.0, color: context.appTextSecondary),
                ) : null,
              ),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.uiHeadline(fontSize: 14.0, fontWeight: FontWeight.w500, color: context.appTextPrimary))),
              SizedBox(
                width: 24.0,
                height: 24.0,
                child: showMore ? IconButton(
                  tooltip: 'More', padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 24.0, height: 24.0),
                  onPressed: () {
                    final renderBox = context.findRenderObject() as RenderBox;
                    final position = renderBox.localToGlobal(
                      Offset(0, renderBox.size.height),
                    );
                    widget.onNoteMenu!(widget.note, position);
                  },
                  icon: Icon(Icons.more_horiz_rounded, size: 18.0, color: context.appTextSecondary),
                ) : null,
              ),
              const SizedBox(width: 4.0),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final Note note;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NoteRow({
    super.key,
    required this.note,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    required this.onToggle,
    required this.onTap,
    required this.onLongPress,
  });

  String get _preview {
    for (final line in note.content.split('\n')) {
      final clean = cleanMarkerPrefix(line).trim();
      if (clean.isNotEmpty) return clean;
    }
    return '';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final daysAgo = today.difference(day).inDays;
    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final label = '${date.day} ${months[date.month - 1]}';
    return date.year == now.year ? label : '$label ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = note.title.trim().isEmpty ? 'Untitled' : note.title.trim();
    final preview = _preview;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: EdgeInsets.only(left: 20.0 * depth, top: 9.0, bottom: 9.0, right: 12.0),
        child: Row(
          children: [
            SizedBox(
              width: 32.0,
              height: 32.0,
              child: hasChildren
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: isExpanded ? 'Hide notes inside' : 'Show notes inside',
                      onPressed: onToggle,
                      icon: Icon(
                        isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                        size: 20.0,
                        color: context.appTextSecondary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.uiHeadline(color: context.appTextPrimary),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    preview.isEmpty ? _formatDate(note.updatedAt) : '${_formatDate(note.updatedAt)}   $preview',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.uiLabel(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w400,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
