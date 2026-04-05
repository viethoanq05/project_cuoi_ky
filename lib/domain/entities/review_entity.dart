class ReviewEntity {
  final String id;
  final String orderId;
  final String userId;
  final String storeId;
  final int rating;
  final String comment;
  final DateTime createdAt;

  ReviewEntity({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.storeId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  ReviewEntity copyWith({
    String? id,
    String? orderId,
    String? userId,
    String? storeId,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return ReviewEntity(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      storeId: storeId ?? this.storeId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
