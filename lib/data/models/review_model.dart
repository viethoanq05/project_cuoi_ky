import '../../../domain/entities/review_entity.dart';

class ReviewModel {
  final String id;
  final String orderId;
  final String userId;
  final String storeId;
  final int rating;
  final String comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.storeId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      storeId: json['store_id'] as String? ?? '',
      rating: json['rating'] as int? ?? 5,
      comment: json['comment'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'store_id': storeId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ReviewEntity toEntity() {
    return ReviewEntity(
      id: id,
      orderId: orderId,
      userId: userId,
      storeId: storeId,
      rating: rating,
      comment: comment,
      createdAt: createdAt,
    );
  }

  ReviewModel copyWith({
    String? id,
    String? orderId,
    String? userId,
    String? storeId,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return ReviewModel(
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
