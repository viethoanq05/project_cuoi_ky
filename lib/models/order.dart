import 'package:cloud_firestore/cloud_firestore.dart';

class OrderData {
  final String orderId;
  final String customerId;
  final String storeId;
  final String storeName;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final double deliveryFee;
  final String paymentMethod;
  final String status; // pending, confirmed, preparing, ready, on_the_way, delivered, cancelled
  final DateTime? scheduledTime; // Nếu là đặt lịch
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? driverId;
  final String? notes;
  final double? rating;
  final String? review;

  OrderData({
    required this.orderId,
    required this.customerId,
    required this.storeId,
    required this.storeName,
    required this.items,
    required this.totalAmount,
    required this.deliveryFee,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.scheduledTime,
    this.updatedAt,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.driverId,
    this.notes,
    this.rating,
    this.review,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'storeId': storeId,
      'storeName': storeName,
      'items': items,
      'totalAmount': totalAmount,
      'deliveryFee': deliveryFee,
      'paymentMethod': paymentMethod,
      'status': status,
      'scheduledTime': scheduledTime,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deliveryAddress': deliveryAddress,
      'deliveryLat': deliveryLat,
      'deliveryLng': deliveryLng,
      'driverId': driverId,
      'notes': notes,
      'rating': rating,
      'review': review,
    };
  }

  factory OrderData.fromMap(Map<String, dynamic> map) {
    return OrderData(
      orderId: map['orderId'] as String,
      customerId: map['customerId'] as String,
      storeId: map['storeId'] as String,
      storeName: map['storeName'] as String,
      items: List<Map<String, dynamic>>.from(map['items'] as List),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      deliveryFee: (map['deliveryFee'] as num).toDouble(),
      paymentMethod: map['paymentMethod'] as String? ?? 'cod',
      status: map['status'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      scheduledTime: map['scheduledTime'] != null 
          ? (map['scheduledTime'] as Timestamp).toDate() 
          : null,
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
      deliveryAddress: map['deliveryAddress'] as String?,
      deliveryLat: (map['deliveryLat'] as num?)?.toDouble(),
      deliveryLng: (map['deliveryLng'] as num?)?.toDouble(),
      driverId: map['driverId'] as String?,
      notes: map['notes'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
      review: map['review'] as String?,
    );
  }

  OrderData copyWith({
    String? status,
    DateTime? updatedAt,
    String? driverId,
    String? notes,
    double? rating,
    String? review,
    String? paymentMethod,
  }) {
    return OrderData(
      orderId: orderId,
      customerId: customerId,
      storeId: storeId,
      storeName: storeName,
      items: items,
      totalAmount: totalAmount,
      deliveryFee: deliveryFee,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      scheduledTime: scheduledTime,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryAddress: deliveryAddress,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      driverId: driverId ?? this.driverId,
      notes: notes ?? this.notes,
      rating: rating ?? this.rating,
      review: review ?? this.review,
    );
  }

  bool get isScheduled => scheduledTime != null;
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
}
