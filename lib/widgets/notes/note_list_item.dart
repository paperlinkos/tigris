import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../models/note.dart';

class NoteListItem extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const NoteListItem({
    super.key,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final childCount = note.childrenIds.length;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isNotEmpty ? note.title : 'Untitled',
                      style: AppTypography.title(
                        fontSize: 18.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (note.subtitle != null && note.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3.0),
                      Text(
                        note.subtitle!,
                        style: AppTypography.subtitle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (childCount > 0) ...[
                const SizedBox(width: 12.0),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '$childCount ${childCount == 1 ? 'page' : 'pages'}',
                    style: AppTypography.uiLabel(
                      fontSize: 12.0,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8.0),
              const Padding(
                padding: EdgeInsets.only(top: 5.0),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11.0,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
