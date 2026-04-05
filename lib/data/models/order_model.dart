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
    return OrderModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      storeId: json['store_id'] as String? ?? '',
      driverId: json['driver_id'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      paymentMethod: json['payment_method'] as String? ?? 'cod',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.parse(json['scheduled_time'] as String)
          : null,
      deliveryAddress: json['delivery_address'] as String?,
    );
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
    return OrderItemModel(
      foodId: json['food_id'] as String? ?? '',
      foodName: json['food_name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
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
