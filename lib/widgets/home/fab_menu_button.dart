import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class FabMenuButton extends StatelessWidget {
  final VoidCallback onCreateNote;

  const FabMenuButton({
    super.key,
    required this.onCreateNote,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('home_fab_menu'),
      offset: const Offset(0, -70), // Opens drop-up menu ABOVE the FAB
      elevation: 6,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
      ),
      onSelected: (value) {
        if (value == 'new_note') {
          onCreateNote();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'new_note',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.edit_note_rounded,
                size: 20.0,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 12.0),
              Text(
                'New note',
                style: AppTypography.uiHeadline(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Material(
        elevation: 4.0,
        shape: const CircleBorder(),
        color: AppColors.textPrimary,
        child: const SizedBox(
          width: 56.0,
          height: 56.0,
          child: Center(
            child: Icon(
              Icons.add_rounded,
              color: AppColors.surface,
              size: 28.0,
            ),
          ),
        ),
      ),
    );
  }
}
