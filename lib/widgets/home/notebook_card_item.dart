import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../models/note.dart';
import '../../models/note_block.dart';

class NotebookCardItem extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOptionsTap;

  const NotebookCardItem({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.onOptionsTap,
  });

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && date.day == now.day) {
      return 'Today';
    } else if (diff.inHours < 48 && date.day == now.subtract(const Duration(days: 1)).day) {
      return 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstBlock = note.blocks.firstWhere(
      (b) => b.content.trim().isNotEmpty || b.type == BlockType.page,
      orElse: () => note.blocks.first,
    );
    String previewContent = '';
    if (firstBlock.type == BlockType.page) {
      previewContent = '→ Subpage';
    } else if (firstBlock.type == BlockType.bullet) {
      final clean = cleanMarkerPrefix(firstBlock.content);
      previewContent = clean.isNotEmpty ? '• $clean' : '';
    } else if (firstBlock.type == BlockType.number) {
      final clean = cleanMarkerPrefix(firstBlock.content);
      previewContent = clean.isNotEmpty ? '1. $clean' : '';
    } else {
      previewContent = cleanMarkerPrefix(firstBlock.content);
    }
    if (previewContent.isEmpty) {
      previewContent = note.subtitle ?? '';
    }
    final inlinePageIds = note.blocks
        .where((b) => b.type == BlockType.page && (b.targetNoteId?.isNotEmpty ?? false))
        .map((b) => b.targetNoteId!);
    final pageCount = {...note.childrenIds, ...inlinePageIds}.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress ?? onOptionsTap,
        borderRadius: BorderRadius.circular(14.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: context.appBorderSubtle, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(context.isDarkMode ? 30 : 12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Title + Options Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      note.title.isNotEmpty ? note.title : 'Untitled',
                      style: AppTypography.title(
                        fontSize: 17.0,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  GestureDetector(
                    onTap: onOptionsTap ?? onLongPress,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 18.0,
                        color: context.appTextTertiary,
                      ),
                    ),
                  ),
                ],
              ),

              // Snippet Preview
              if (previewContent.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Text(
                  previewContent,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subtitle(
                    fontSize: 13.5,
                    color: context.appTextSecondary,
                  ),
                ),
              ],

              const SizedBox(height: 14.0),

              // Bottom Row: Tag Badge (left) + Date Stamp (right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (pageCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        color: context.appBg,
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: context.appBorderSubtle, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 11.0,
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
                    )
                  else
                    const SizedBox.shrink(),
                  Text(
                    _formatRelativeDate(note.updatedAt),
                    style: AppTypography.uiLabel(
                      fontSize: 11.5,
                      color: context.appTextTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
