import 'package:flutter/foundation.dart';
import '../domain/entities/review_entity.dart';
import '../domain/repositories/review_repository_interface.dart';

enum ReviewState { initial, checking, submitting, success, error }

class ReviewProvider extends ChangeNotifier {
  final ReviewRepositoryInterface _reviewRepository;

  ReviewProvider({required ReviewRepositoryInterface reviewRepository})
      : _reviewRepository = reviewRepository;

  ReviewState _state = ReviewState.initial;
  String _errorMessage = '';
  ReviewEntity? _currentReview;
  bool _hasReviewed = false;

  ReviewState get state => _state;
  String get errorMessage => _errorMessage;
  ReviewEntity? get currentReview => _currentReview;
  bool get hasReviewed => _hasReviewed;
  bool get isSubmitting => _state == ReviewState.submitting;
  bool get isSuccess => _state == ReviewState.success;
  bool get isError => _state == ReviewState.error;

  Future<void> checkIfReviewed(String orderId) async {
    _state = ReviewState.checking;
    notifyListeners();

    try {
      _hasReviewed = await _reviewRepository.hasReviewedOrder(orderId);
      final review = await _reviewRepository.getReviewByOrderId(orderId);
      _currentReview = review;
      _state = ReviewState.initial;
      _errorMessage = '';
    } catch (e) {
      _state = ReviewState.error;
      _errorMessage = e.toString();
      _hasReviewed = false;
    }

    notifyListeners();
  }

  Future<void> submitReview({
    required String orderId,
    required String userId,
    required String storeId,
    required int rating,
    required String comment,
  }) async {
    // Prevent duplicate submissions
    if (_hasReviewed) {
      _state = ReviewState.error;
      _errorMessage = 'This order has already been reviewed';
      notifyListeners();
      return;
    }

    _state = ReviewState.submitting;
    _errorMessage = '';
    notifyListeners();

    try {
      // Double-check that no review exists
      final existingReview =
          await _reviewRepository.getReviewByOrderId(orderId);
      if (existingReview != null) {
        _state = ReviewState.error;
        _errorMessage = 'This order has already been reviewed';
        _hasReviewed = true;
        notifyListeners();
        return;
      }

      // Validate input
      if (rating < 1 || rating > 5) {
        _state = ReviewState.error;
        _errorMessage = 'Rating must be between 1 and 5';
        notifyListeners();
        return;
      }

      if (comment.isEmpty) {
        _state = ReviewState.error;
        _errorMessage = 'Comment cannot be empty';
        notifyListeners();
        return;
      }

      // Create review
      _currentReview = await _reviewRepository.createReview(
        orderId: orderId,
        userId: userId,
        storeId: storeId,
        rating: rating,
        comment: comment,
      );

      _hasReviewed = true;
      _state = ReviewState.success;
      _errorMessage = '';
    } catch (e) {
      _state = ReviewState.error;
      _errorMessage = e.toString();
      _hasReviewed = false;
    }

    notifyListeners();
  }

  void resetState() {
    _state = ReviewState.initial;
    _errorMessage = '';
    _currentReview = null;
    _hasReviewed = false;
    notifyListeners();
  }
}
