import '../models/review_item.dart';
import '../persistence/storage_interface.dart';
import 'review_repository.dart';

class LocalReviewRepository implements ReviewRepository {
  static const String collection = 'reviews';
  final StorageInterface _storage;

  LocalReviewRepository({required StorageInterface storage}) : _storage = storage;

  @override
  Future<List<ReviewItem>> getDueReviews({DateTime? asOf}) async {
    final threshold = asOf ?? DateTime.now();
    final all = await getAllReviews();
    return all.where((item) => item.dueAt.isBefore(threshold) || item.dueAt.isAtSameMomentAs(threshold)).toList();
  }

  @override
  Future<List<ReviewItem>> getAllReviews() async {
    final items = await _storage.getAll(collection);
    return items.map((item) => ReviewItem.fromJson(item)).toList();
  }

  @override
  Future<ReviewItem?> getReviewForNote(String noteId) async {
    final all = await getAllReviews();
    try {
      return all.firstWhere((item) => item.noteId == noteId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveReview(ReviewItem reviewItem) async {
    await _storage.set(collection, reviewItem.id, reviewItem.toJson());
  }

  @override
  Future<void> deleteReview(String id) async {
    await _storage.delete(collection, id);
  }
}
