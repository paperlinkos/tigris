import 'package:flutter/material.dart';
import '../../app/theme/app_typography.dart';
import '../../app/theme/context_theme_extensions.dart';
import '../../models/note.dart';

class RecentSquareCards extends StatelessWidget {
  final List<Note> recentNotes;
  final ValueChanged<Note> onOpenNote;

  const RecentSquareCards({
    super.key,
    required this.recentNotes,
    required this.onOpenNote,
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
    if (recentNotes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENTS',
          style: AppTypography.uiLabel(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: context.appTextSecondary,
          ).copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 12.0),
        SizedBox(
          height: 105.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: recentNotes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10.0),
            itemBuilder: (context, index) {
              final note = recentNotes[index];
              return _buildSquareCard(context, note);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSquareCard(BuildContext context, Note note) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onOpenNote(note),
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: 105.0,
          height: 105.0,
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(12.0),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 15.0,
                    color: context.appTextSecondary,
                  ),
                  Flexible(
                    child: Text(
                      _formatRelativeDate(note.updatedAt),
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.uiLabel(
                        fontSize: 10.0,
                        color: context.appTextTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Expanded(
                child: Text(
                  note.title.isNotEmpty ? note.title : 'Untitled',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
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
