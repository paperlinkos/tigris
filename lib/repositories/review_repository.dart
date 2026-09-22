import '../models/review_item.dart';

abstract class ReviewRepository {
  Future<List<ReviewItem>> getDueReviews({DateTime? asOf});
  Future<List<ReviewItem>> getAllReviews();
  Future<ReviewItem?> getReviewForNote(String noteId);
  Future<void> saveReview(ReviewItem reviewItem);
  Future<void> deleteReview(String id);
}
