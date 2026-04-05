import '../../domain/entities/review_entity.dart';
import '../../domain/repositories/review_repository_interface.dart';
import '../datasources/firestore_datasource.dart';

class ReviewRepository implements ReviewRepositoryInterface {
  final FirestoreDatasource _datasource;

  ReviewRepository({required FirestoreDatasource datasource})
      : _datasource = datasource;

  @override
  Future<bool> hasReviewedOrder(String orderId) async {
    try {
      return await _datasource.hasReviewedOrder(orderId);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<ReviewEntity> createReview({
    required String orderId,
    required String userId,
    required String storeId,
    required int rating,
    required String comment,
  }) async {
    try {
      final reviewId = DateTime.now().millisecondsSinceEpoch.toString();

      final model = await _datasource.createReview(
        reviewId: reviewId,
        orderId: orderId,
        userId: userId,
        storeId: storeId,
        rating: rating,
        comment: comment,
      );

      return model.toEntity();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ReviewEntity?> getReviewByOrderId(String orderId) async {
    try {
      final model = await _datasource.getReviewByOrderId(orderId);
      return model?.toEntity();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ReviewEntity>> getStoreReviews(String storeId) async {
    try {
      final models = await _datasource.getStoreReviews(storeId);
      return models.map((model) => model.toEntity()).toList();
    } catch (e) {
      rethrow;
    }
  }
}
