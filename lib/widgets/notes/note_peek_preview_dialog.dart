import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../controllers/rich_text_editing_controller.dart';
import '../../models/note.dart';
import 'note_action_menu.dart';

class NotePeekPreviewDialog extends StatelessWidget {
  final Note note;
  final ValueChanged<NoteActionType> onActionSelected;
  final List<NoteActionType> actions;

  const NotePeekPreviewDialog({
    super.key,
    required this.note,
    required this.onActionSelected,
    this.actions = const [
      NoteActionType.open,
      NoteActionType.duplicate,
      NoteActionType.share,
      NoteActionType.archive,
      NoteActionType.delete,
    ],
  });

  static Future<NoteActionType?> show(
    BuildContext context, {
    required Note note,
    List<NoteActionType>? actions,
  }) {
    return showDialog<NoteActionType>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withAlpha(140),
      builder: (context) => NotePeekPreviewDialog(
        note: note,
        actions: actions ?? const [
          NoteActionType.open,
          NoteActionType.duplicate,
          NoteActionType.share,
          NoteActionType.archive,
          NoteActionType.delete,
        ],
        onActionSelected: (action) => Navigator.of(context).pop(action),
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) {
      return 'Updated just now';
    } else if (diff.inMinutes < 60) {
      return 'Updated ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && date.day == now.day) {
      return 'Updated Today';
    } else if (diff.inHours < 48 && date.day == now.subtract(const Duration(days: 1)).day) {
      return 'Updated Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return 'Updated ${date.day} ${months[date.month - 1]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = note.title.trim().isNotEmpty ? note.title.trim() : 'Untitled';
    final contentText = note.content.trim().isNotEmpty
        ? note.content.trim()
        : (note.subtitle ?? 'No additional text.');
    final pageCount = note.childrenIds.length;
    final controller = RichTextEditingController.fromNoteContent(
      content: contentText,
      formatting: note.formatting,
    );

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
          elevation: 0,
          child: GestureDetector(
            onTap: () {}, // Prevent taps on preview card from dismissing dialog
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Floating Peek Preview Card
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 280.0),
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: context.appBorderSubtle, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(76),
                          blurRadius: 20.0,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Card Header: Title + Subpages Tag
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                titleText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.title(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w700,
                                  color: context.appTextPrimary,
                                ),
                              ),
                            ),
                            if (pageCount > 0) ...[
                              const SizedBox(width: 8.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: context.appBg,
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: context.appBorderSubtle, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      size: 12.0,
                                      color: context.appTextSecondary,
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      '$pageCount ${pageCount == 1 ? 'page' : 'pages'}',
                                      style: AppTypography.uiLabel(
                                        fontSize: 11.0,
                                        fontWeight: FontWeight.w600,
                                        color: context.appTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 4.0),
                        Text(
                          _formatRelativeDate(note.updatedAt),
                          style: AppTypography.uiLabel(
                            fontSize: 11.5,
                            color: context.appTextTertiary,
                          ),
                        ),

                        const SizedBox(height: 12.0),
                        Divider(color: context.appBorderSubtle, height: 1.0),
                        const SizedBox(height: 12.0),

                        // Body Snippet Preview
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: SelectableText.rich(
                              controller.buildTextSpan(
                                context: context,
                                style: AppTypography.body(
                                  fontSize: 14.5,
                                  color: context.appTextSecondary,
                                ),
                                withComposing: false,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12.0),

                  // 2. Floating Actions Panel
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: context.appBorderSubtle, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(64),
                          blurRadius: 16.0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < actions.length; i++) ...[
                          if (i > 0)
                            Divider(color: context.appBorderSubtle, height: 1.0),
                          _buildActionTile(context, actions[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, NoteActionType action) {
    final isDestructive = action.isDestructive;
    final color = isDestructive ? Colors.red : context.appTextPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onActionSelected(action),
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 13.0),
          child: Row(
            children: [
              Icon(action.icon, color: color, size: 20.0),
              const SizedBox(width: 14.0),
              Expanded(
                child: Text(
                  action.label,
                  style: AppTypography.uiHeadline(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
