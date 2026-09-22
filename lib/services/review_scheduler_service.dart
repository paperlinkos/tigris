import '../models/review_item.dart';

abstract class ReviewSchedulerService {
  ReviewItem scheduleInitialReview({required String noteId});
  ReviewItem scheduleNextReview({
    required ReviewItem currentItem,
    required int rating, // 1 to 5 recall rating
  });
}

class StandardReviewSchedulerService implements ReviewSchedulerService {
  const StandardReviewSchedulerService();

  @override
  ReviewItem scheduleInitialReview({required String noteId}) {
    return ReviewItem(
      id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
      noteId: noteId,
      dueAt: DateTime.now().add(const Duration(days: 1)),
      intervalDays: 1,
      repetitionCount: 0,
      easeFactor: 2.5,
    );
  }

  @override
  ReviewItem scheduleNextReview({
    required ReviewItem currentItem,
    required int rating,
  }) {
    // Standard SM-2 spaced repetition calculation foundation
    final double newEaseFactor = (currentItem.easeFactor + (0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02)))
        .clamp(1.3, 3.0);

    int nextInterval;
    int nextRepetition;

    if (rating < 3) {
      nextRepetition = 0;
      nextInterval = 1;
    } else {
      nextRepetition = currentItem.repetitionCount + 1;
      if (nextRepetition == 1) {
        nextInterval = 1;
      } else if (nextRepetition == 2) {
        nextInterval = 6;
      } else {
        nextInterval = (currentItem.intervalDays * newEaseFactor).round();
      }
    }

    final now = DateTime.now();
    return currentItem.copyWith(
      intervalDays: nextInterval,
      repetitionCount: nextRepetition,
      easeFactor: newEaseFactor,
      lastReviewedAt: now,
      dueAt: now.add(Duration(days: nextInterval)),
    );
  }
}
