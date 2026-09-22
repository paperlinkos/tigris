import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_typography.dart';

class EmptyPlaceholder extends StatelessWidget {
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyPlaceholder({
    super.key,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.display(
                fontSize: 30.0,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14.0),
            Text(
              description,
              style: AppTypography.subtitle(
                fontSize: 16.0,
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 36.0),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52.0),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: AppTypography.uiHeadline(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
