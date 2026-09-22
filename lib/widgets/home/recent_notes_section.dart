import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../models/note.dart';

class RecentNotesSection extends StatelessWidget {
  final List<Note> notes;
  final VoidCallback onCreateNote;
  final ValueChanged<Note>? onOpenNote;

  const RecentNotesSection({
    super.key,
    required this.notes,
    required this.onCreateNote,
    this.onOpenNote,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT NOTES',
          style: AppTypography.uiLabel(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ).copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 14.0),

        if (notes.isEmpty) ...[
          // Calm empty state
          Text(
            'Your notes will appear here.',
            style: AppTypography.title(
              fontSize: 20.0,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14.0),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48.0),
            child: InkWell(
              onTap: onCreateNote,
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    const Icon(Icons.arrow_forward_rounded, size: 16.0, color: AppColors.textPrimary),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          // When notes exist, list recent items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: notes.length > 5 ? 5 : notes.length,
            separatorBuilder: (context, index) => const Divider(
              color: AppColors.borderSubtle,
              height: 20.0,
            ),
            itemBuilder: (context, index) {
              final note = notes[index];
              return InkWell(
                onTap: onOpenNote != null ? () => onOpenNote!(note) : null,
                borderRadius: BorderRadius.circular(8.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: AppTypography.title(
                          fontSize: 17.0,
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
              );
            },
          ),
        ],
      ],
    );
  }
}
