import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../models/note.dart';
import 'notebook_card_item.dart';

enum NoteSortOption {
  recent('Recently updated', Icons.access_time_rounded),
  title('Alphabetical (A-Z)', Icons.sort_by_alpha_rounded),
  created('Date created', Icons.calendar_today_rounded);

  final String label;
  final IconData icon;
  const NoteSortOption(this.label, this.icon);
}

class RecentNotesSection extends StatefulWidget {
  final List<Note> notes;
  final VoidCallback onCreateNote;
  final ValueChanged<Note>? onOpenNote;
  final ValueChanged<Note>? onLongPressNote;

  const RecentNotesSection({
    super.key,
    required this.notes,
    required this.onCreateNote,
    this.onOpenNote,
    this.onLongPressNote,
  });

  @override
  State<RecentNotesSection> createState() => _RecentNotesSectionState();
}

class _RecentNotesSectionState extends State<RecentNotesSection> {
  NoteSortOption _currentSort = NoteSortOption.recent;

  List<Note> get _sortedNotes {
    final list = List<Note>.from(widget.notes);
    switch (_currentSort) {
      case NoteSortOption.recent:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case NoteSortOption.title:
        list.sort((a, b) {
          final titleA = a.title.trim().isEmpty ? 'Untitled' : a.title.trim();
          final titleB = b.title.trim().isEmpty ? 'Untitled' : b.title.trim();
          return titleA.toLowerCase().compareTo(titleB.toLowerCase());
        });
        break;
      case NoteSortOption.created:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sortedList = _sortedNotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'NOTES',
              style: AppTypography.uiLabel(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
              ).copyWith(letterSpacing: 1.2),
            ),
            if (widget.notes.isNotEmpty)
              PopupMenuButton<NoteSortOption>(
                key: const Key('notes_sort_button'),
                offset: const Offset(0, 30),
                elevation: 4,
                color: context.appSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  side: BorderSide(color: context.appBorderSubtle, width: 1.0),
                ),
                onSelected: (option) {
                  setState(() {
                    _currentSort = option;
                  });
                },
                itemBuilder: (context) => NoteSortOption.values.map((opt) {
                  final isSelected = opt == _currentSort;
                  return PopupMenuItem<NoteSortOption>(
                    value: opt,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          opt.icon,
                          size: 16.0,
                          color: isSelected ? context.appTextPrimary : context.appTextSecondary,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          opt.label,
                          style: AppTypography.uiLabel(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? context.appTextPrimary : context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_vert_rounded,
                        size: 15.0,
                        color: context.appTextSecondary,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        _currentSort.label,
                        style: AppTypography.uiLabel(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14.0),

        if (sortedList.isEmpty) ...[
          Text(
            'Your notes will appear here.',
            style: AppTypography.title(
              fontSize: 18.0,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 14.0),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48.0),
            child: InkWell(
              onTap: widget.onCreateNote,
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Create your first note',
                        style: AppTypography.uiHeadline(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Icon(Icons.arrow_forward_rounded, size: 16.0, color: context.appTextPrimary),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedList.length > 6 ? 6 : sortedList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12.0),
            itemBuilder: (context, index) {
              final note = sortedList[index];
              return NotebookCardItem(
                note: note,
                onTap: () {
                  if (widget.onOpenNote != null) widget.onOpenNote!(note);
                },
                onLongPress: widget.onLongPressNote != null ? () => widget.onLongPressNote!(note) : null,
                onOptionsTap: widget.onLongPressNote != null ? () => widget.onLongPressNote!(note) : null,
              );
            },
          ),
        ],
      ],
    );
  }
}
