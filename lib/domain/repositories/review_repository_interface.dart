import '../entities/review_entity.dart';

abstract class ReviewRepositoryInterface {
  Future<bool> hasReviewedOrder(String orderId);

  Future<ReviewEntity> createReview({
    required String orderId,
    required String userId,
    required String storeId,
    required int rating,
    required String comment,
  });

  Future<ReviewEntity?> getReviewByOrderId(String orderId);

  Future<List<ReviewEntity>> getStoreReviews(String storeId);
}
