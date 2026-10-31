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
  final ValueChanged<Note> onLongPressNote;

  const NotesTreeList({
    super.key,
    required this.notes,
    required this.searchQuery,
    required this.onCreateNote,
    required this.onOpenNote,
    required this.onLongPressNote,
  });

  @override
  State<NotesTreeList> createState() => _NotesTreeListState();
}

class _NotesTreeListState extends State<NotesTreeList> {
  final Set<String> _expandedIds = {};

  List<({Note note, int depth, bool hasChildren})> _visibleRows() {
    final byRecent = List<Note>.from(widget.notes)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final query = widget.searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      return [
        for (final note in byRecent)
          if (note.title.toLowerCase().contains(query) ||
              note.content.toLowerCase().contains(query))
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
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 96.0),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return _NoteRow(
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
          onLongPress: () => widget.onLongPressNote(row.note),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
