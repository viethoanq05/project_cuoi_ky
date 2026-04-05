class OrderEntity {
  final String id;
  final String userId;
  final String storeId;
  final String? driverId;
  final List<OrderItemEntity> items;
  final double totalPrice;
  final String status;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? scheduledTime;
  final String? deliveryAddress;

  OrderEntity({
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

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isPreparing => status == 'preparing';
  bool get isDelivering => status == 'delivering';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  OrderEntity copyWith({
    String? id,
    String? userId,
    String? storeId,
    String? driverId,
    List<OrderItemEntity>? items,
    double? totalPrice,
    String? status,
    String? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? scheduledTime,
    String? deliveryAddress,
  }) {
    return OrderEntity(
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

class OrderItemEntity {
  final String foodId;
  final String foodName;
  final int quantity;
  final double price;
  final double subtotal;

  OrderItemEntity({
    required this.foodId,
    required this.foodName,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  OrderItemEntity copyWith({
    String? foodId,
    String? foodName,
    int? quantity,
    double? price,
    double? subtotal,
  }) {
    return OrderItemEntity(
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}
