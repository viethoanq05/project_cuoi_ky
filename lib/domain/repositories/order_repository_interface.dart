import '../entities/order_entity.dart';

abstract class OrderRepositoryInterface {
  Future<OrderEntity> createOrder({
    required String userId,
    required String storeId,
    required List<OrderItemEntity> items,
    required double totalPrice,
    required String paymentMethod,
    required String deliveryAddress,
  });

  Future<List<OrderEntity>> getUserOrders(String userId);

  Stream<OrderEntity?> watchOrder(String orderId);

  Future<OrderEntity?> getOrderById(String orderId);

  Future<void> updateOrderStatus(String orderId, String newStatus);

  Future<bool> canCancelOrder(String orderId);

  Future<void> cancelOrder(String orderId);
}
