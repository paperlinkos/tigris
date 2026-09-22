import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class HomeHeader extends StatelessWidget {
  final VoidCallback onCreateNote;

  const HomeHeader({
    super.key,
    required this.onCreateNote,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning.';
    } else if (hour < 17) {
      return 'Good afternoon.';
    } else {
      return 'Good evening.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting with full editorial width
        Text(
          _getGreeting(),
          style: AppTypography.display(
            fontSize: 32.0,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20.0),
        // Primary Action: "+ New note"
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48.0),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            onPressed: onCreateNote,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 18.0, color: AppColors.textPrimary),
                const SizedBox(width: 8.0),
                Text(
                  'New note',
                  style: AppTypography.uiHeadline(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
