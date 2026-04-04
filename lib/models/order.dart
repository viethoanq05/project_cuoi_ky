import 'package:cloud_firestore/cloud_firestore.dart';

class OrderData {
  final String orderId;
  final String customerId;
  final String storeId;
  final String storeName;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final double deliveryFee;
  final String status;
  final DateTime? scheduledTime;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? driverId;
  final String? notes;
  final double? rating;
  final String? review;
  final String? proofImage;

  OrderData({
    required this.orderId,
    required this.customerId,
    required this.storeId,
    required this.storeName,
    required this.items,
    required this.totalAmount,
    required this.deliveryFee,
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
    this.proofImage,
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
      'proofImage': proofImage,
    };
  }

  factory OrderData.fromMap(Map<String, dynamic> map) {
    double? lat = _asDouble(map['deliveryLat'] ?? map['delivery_lat'] ?? map['lat'] ?? map['latitude']);
    double? lng = _asDouble(map['deliveryLng'] ?? map['delivery_lng'] ?? map['lng'] ?? map['longitude']);

    if (lat == null || lng == null) {
      lat = 21.028511; 
      lng = 105.804817;
    }

    return OrderData(
      orderId: (map['orderId'] ?? map['order_id'] ?? '').toString(),
      customerId: (map['customerId'] ?? map['customer_id'] ?? map['user_id'] ?? '').toString(),
      storeId: (map['storeId'] ?? map['store_id'] ?? '').toString(),
      storeName: (map['storeName'] ?? map['store_name'] ?? 'Cửa hàng').toString(),
      items: map['items'] is List 
          ? List<Map<String, dynamic>>.from(map['items']) 
          : (map['order_items'] is List ? List<Map<String, dynamic>>.from(map['order_items']) : []),
      totalAmount: _asDouble(map['totalAmount'] ?? map['total_amount'] ?? 0)!,
      deliveryFee: _asDouble(map['deliveryFee'] ?? map['shipping_fee'] ?? 0)!,
      status: (map['status'] ?? map['order_status'] ?? 'pending').toString(),
      createdAt: _asDateTime(map['createdAt'] ?? map['order_time'] ?? map['created_at']),
      scheduledTime: _asDateTime(map['scheduledTime'] ?? map['scheduled_time']),
      updatedAt: _asDateTime(map['updatedAt'] ?? map['updated_at']),
      deliveryAddress: (map['deliveryAddress'] ?? map['delivery_address'] ?? 'Không rõ địa chỉ').toString(),
      deliveryLat: lat,
      deliveryLng: lng,
      driverId: (map['driverId'] ?? map['driver_id'] ?? map['driveId'] ?? '').toString(),
      notes: map['notes']?.toString(),
      rating: _asDouble(map['rating']),
      review: map['review']?.toString(),
      proofImage: (map['proofImage'] ?? map['proof_image'])?.toString(),
    );
  }

  static double? _asDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  static DateTime _asDateTime(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }
}
