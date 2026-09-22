import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../models/note.dart';

class ContinueLearningSection extends StatelessWidget {
  final Note? continueNote;
  final ValueChanged<Note>? onOpenNote;

  const ContinueLearningSection({
    super.key,
    this.continueNote,
    this.onOpenNote,
  });

  @override
  Widget build(BuildContext context) {
    // When no continue-learning note exists, omit cleanly without clutter
    if (continueNote == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTINUE LEARNING',
          style: AppTypography.uiLabel(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ).copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 14.0),
        InkWell(
          onTap: onOpenNote != null ? () => onOpenNote!(continueNote!) : null,
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: AppColors.border, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  continueNote!.title,
                  style: AppTypography.title(
                    fontSize: 18.0,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (continueNote!.subtitle != null && continueNote!.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    continueNote!.subtitle!,
                    style: AppTypography.subtitle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
