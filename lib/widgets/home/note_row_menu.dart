import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';

enum NoteRowAction { addPage, rename, duplicate, delete }

Future<NoteRowAction?> showNoteRowMenu(BuildContext context, Offset position) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return showMenu<NoteRowAction>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    color: context.appRaised,
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: context.appBorder),
    ),
    constraints: const BoxConstraints.tightFor(width: 220),
    items: [
      _item(context, 'Add page inside', NoteRowAction.addPage),
      _item(context, 'Rename', NoteRowAction.rename),
      _item(context, 'Duplicate', NoteRowAction.duplicate),
      const PopupMenuDivider(),
      _item(context, 'Delete', NoteRowAction.delete, color: _dangerColor(context)),
    ],
  );
}

PopupMenuItem<NoteRowAction> _item(
  BuildContext context,
  String label,
  NoteRowAction value, {
  Color? color,
}) => PopupMenuItem<NoteRowAction>(
  value: value,
  height: 32,
  child: Text(
    label,
    style: AppTypography.uiHeadline(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: color ?? context.appTextPrimary,
    ),
  ),
);

Color _dangerColor(BuildContext context) => context.isDarkMode
    ? const Color(0xFFF2877E)
    : const Color(0xFFB3261E);
