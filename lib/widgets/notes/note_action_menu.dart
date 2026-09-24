import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../models/note.dart';

enum NoteActionType {
  open('Open & edit', Icons.edit_outlined),
  duplicate('Duplicate', Icons.copy_rounded),
  share('Share note', Icons.ios_share_rounded),
  archive('Archive', Icons.archive_outlined),
  delete('Delete note', Icons.delete_outline_rounded, isDestructive: true),
  pin('Pin note', Icons.push_pin_outlined);

  final String label;
  final IconData icon;
  final bool isDestructive;

  const NoteActionType(this.label, this.icon, {this.isDestructive = false});
}

class NoteActionMenu extends StatelessWidget {
  final Note note;
  final ValueChanged<NoteActionType> onActionSelected;
  final List<NoteActionType> availableActions;

  const NoteActionMenu({
    super.key,
    required this.note,
    required this.onActionSelected,
    this.availableActions = const [
      NoteActionType.delete,
    ],
  });

  static Future<NoteActionType?> show(
    BuildContext context, {
    required Note note,
    List<NoteActionType> availableActions = const [NoteActionType.delete],
  }) {
    return showModalBottomSheet<NoteActionType>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => NoteActionMenu(
        note: note,
        availableActions: availableActions,
        onActionSelected: (action) => Navigator.of(context).pop(action),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noteTitle = note.title.trim().isNotEmpty ? note.title.trim() : 'Untitled';

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
        border: Border(
          top: BorderSide(color: context.appBorderSubtle, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 24.0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Header: Note Title preview
            Text(
              noteTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              'Actions',
              style: AppTypography.uiLabel(
                fontSize: 11.5,
                color: context.appTextTertiary,
              ),
            ),
            const SizedBox(height: 12.0),
            Divider(color: context.appBorderSubtle, height: 1.0),
            const SizedBox(height: 8.0),

            // Action Items
            ...availableActions.map((action) {
              final color = action.isDestructive ? Colors.red : context.appTextPrimary;
              return ListTile(
                leading: Icon(action.icon, color: color, size: 20.0),
                title: Text(
                  action.label,
                  style: AppTypography.uiHeadline(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                onTap: () => onActionSelected(action),
              );
            }),
          ],
        ),
      ),
    );
  }
}
