import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../models/review_item.dart';

class MemoryReviewSection extends StatelessWidget {
  final List<ReviewItem> dueReviews;
  final VoidCallback? onStartReview;

  const MemoryReviewSection({
    super.key,
    required this.dueReviews,
    this.onStartReview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Label
        Text(
          'YOUR MEMORY',
          style: AppTypography.uiLabel(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ).copyWith(letterSpacing: 1.2),
        ),
        const SizedBox(height: 14.0),

        if (dueReviews.isEmpty) ...[
          // Calm empty state
          Text(
            'Nothing due for review.',
            style: AppTypography.title(
              fontSize: 22.0,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            'Ideas scheduled for active recall will surface here.',
            style: AppTypography.subtitle(
              fontSize: 14.5,
              color: AppColors.textSecondary,
            ),
          ),
        ] else ...[
          // When reviews exist
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dueReviews.length} ${dueReviews.length == 1 ? "item" : "items"} due today',
                      style: AppTypography.title(
                        fontSize: 20.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Estimated ~${dueReviews.length * 2} minutes',
                      style: AppTypography.subtitle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),
              if (onStartReview != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48.0),
                  child: ElevatedButton(
                    key: const Key('start_review_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: AppColors.surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    onPressed: onStartReview,
                    child: Text(
                      'Review now',
                      style: AppTypography.uiHeadline(
                        fontSize: 13.5,
                        color: AppColors.surface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
