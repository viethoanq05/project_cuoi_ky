import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/entities/order_entity.dart';

class OrderModel {
  final String id;
  final String userId;
  final String storeId;
  final String? driverId;
  final List<OrderItemModel> items;
  final double totalPrice;
  final String status;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? scheduledTime;
  final String? deliveryAddress;

  OrderModel({
    required this.id,
    required this.userId,
    required this.storeId,
    this.driverId,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    this.updatedAt,
    this.scheduledTime,
    this.deliveryAddress,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final createdAt =
        _asDateTime(
          json['created_at'] ?? json['createdAt'] ?? json['order_time'],
        ) ??
        DateTime.now();
    final updatedAt = _asDateTime(json['updated_at'] ?? json['updatedAt']);
    final scheduledTime = _asDateTime(
      json['scheduled_time'] ?? json['scheduledTime'],
    );

    final rawItems = (json['items'] is List)
        ? (json['items'] as List)
        : ((json['order_items'] is List)
              ? (json['order_items'] as List)
              : const []);

    final items = rawItems
        .whereType<Map>()
        .map((item) => OrderItemModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final totalFromField =
        (json['total_price'] as num?)?.toDouble() ??
        (json['totalAmount'] as num?)?.toDouble() ??
        (json['total_amount'] as num?)?.toDouble() ??
        (json['totalPrice'] as num?)?.toDouble() ??
        0.0;
    final computedTotal = items.fold<double>(
      0.0,
      (sum, item) => sum + item.subtotal,
    );

    return OrderModel(
      id: (json['id'] ?? json['orderId'] ?? json['order_id'] ?? '').toString(),
      userId:
          (json['user_id'] ??
                  json['customerId'] ??
                  json['customer_id'] ??
                  json['userId'] ??
                  '')
              .toString(),
      storeId: (json['store_id'] ?? json['storeId'] ?? '').toString(),
      driverId: (json['driver_id'] ?? json['driverId'])?.toString(),
      items: items,
      totalPrice: totalFromField > 0 ? totalFromField : computedTotal,
      status: (json['status'] ?? json['order_status'] ?? 'pending').toString(),
      paymentMethod: (json['payment_method'] ?? json['paymentMethod'] ?? 'cod')
          .toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      scheduledTime: scheduledTime,
      deliveryAddress: (json['delivery_address'] ?? json['deliveryAddress'])
          ?.toString(),
    );
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();

    if (value is int) {
      // Common pattern: millisecondsSinceEpoch.
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    // ISO-8601 strings.
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    // Fallback: numeric string epoch.
    final epoch = int.tryParse(text);
    if (epoch == null) return null;

    // Heuristic: treat 10-digit as seconds, 13-digit as millis.
    if (text.length == 10) {
      return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(epoch);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'store_id': storeId,
      'driver_id': driverId,
      'items': items.map((item) => item.toJson()).toList(),
      'total_price': totalPrice,
      'status': status,
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'scheduled_time': scheduledTime?.toIso8601String(),
      'delivery_address': deliveryAddress,
    };
  }

  OrderEntity toEntity() {
    return OrderEntity(
      id: id,
      userId: userId,
      storeId: storeId,
      driverId: driverId,
      items: items.map((item) => item.toEntity()).toList(),
      totalPrice: totalPrice,
      status: status,
      paymentMethod: paymentMethod,
      createdAt: createdAt,
      updatedAt: updatedAt,
      scheduledTime: scheduledTime,
      deliveryAddress: deliveryAddress,
    );
  }

  OrderModel copyWith({
    String? id,
    String? userId,
    String? storeId,
    String? driverId,
    List<OrderItemModel>? items,
    double? totalPrice,
    String? status,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? scheduledTime,
    String? deliveryAddress,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storeId: storeId ?? this.storeId,
      driverId: driverId ?? this.driverId,
      items: items ?? this.items,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    );
  }
}

class OrderItemModel {
  final String foodId;
  final String foodName;
  final int quantity;
  final double price;
  final double subtotal;

  OrderItemModel({
    required this.foodId,
    required this.foodName,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final qty =
        (json['quantity'] as num?)?.toInt() ??
        int.tryParse(json['quantity']?.toString() ?? '') ??
        1;
    final price =
        (json['price'] as num?)?.toDouble() ??
        double.tryParse(json['price']?.toString() ?? '') ??
        0.0;
    final subtotal =
        (json['subtotal'] as num?)?.toDouble() ??
        double.tryParse(json['subtotal']?.toString() ?? '') ??
        (price * qty);

    return OrderItemModel(
      foodId: (json['food_id'] ?? json['foodId'] ?? '').toString(),
      foodName: (json['food_name'] ?? json['foodName'] ?? json['name'] ?? '')
          .toString(),
      quantity: qty,
      price: price,
      subtotal: subtotal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food_id': foodId,
      'food_name': foodName,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
    };
  }

  OrderItemEntity toEntity() {
    return OrderItemEntity(
      foodId: foodId,
      foodName: foodName,
      quantity: quantity,
      price: price,
      subtotal: subtotal,
    );
  }
}
