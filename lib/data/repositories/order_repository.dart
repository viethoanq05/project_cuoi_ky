import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository_interface.dart';
import '../datasources/firestore_datasource.dart';
import '../models/order_model.dart';

class OrderRepository implements OrderRepositoryInterface {
  final FirestoreDatasource _datasource;

  OrderRepository({required FirestoreDatasource datasource})
      : _datasource = datasource;

  @override
  Future<OrderEntity> createOrder({
    required String userId,
    required String storeId,
    required List<OrderItemEntity> items,
    required double totalPrice,
    required String paymentMethod,
    required String deliveryAddress,
  }) async {
    try {
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      final itemsData = items
          .map((item) => {
                'food_id': item.foodId,
                'food_name': item.foodName,
                'quantity': item.quantity,
                'price': item.price,
                'subtotal': item.subtotal,
              })
          .toList();

      if (paymentMethod == 'wallet') {
        await _datasource.processWalletPayment(
          userId: userId,
          storeId: storeId,
          orderId: orderId,
          items: itemsData,
          totalPrice: totalPrice,
          deliveryAddress: deliveryAddress,
        );
      } else {
        // COD payment
        final orderModel = await _datasource.createOrder(
          orderId: orderId,
          userId: userId,
          storeId: storeId,
          items: itemsData,
          totalPrice: totalPrice,
          paymentMethod: paymentMethod,
          deliveryAddress: deliveryAddress,
        );
        return orderModel.toEntity();
      }

      final orderModel = await _datasource.getOrderById(orderId);
      if (orderModel != null) {
        return orderModel.toEntity();
      }

      throw Exception('Failed to create order');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<OrderEntity>> getUserOrders(String userId) async {
    try {
      final orderModels = await _datasource.getUserOrders(userId);
      return orderModels.map((model) => model.toEntity()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<OrderEntity?> watchOrder(String orderId) {
    return _datasource.watchOrder(orderId).map((model) {
      if (model != null) {
        return model.toEntity();
      }
      return null;
    });
  }

  @override
  Future<OrderEntity?> getOrderById(String orderId) async {
    try {
      final orderModel = await _datasource.getOrderById(orderId);
      return orderModel?.toEntity();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _datasource.updateOrderStatus(orderId, newStatus);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> canCancelOrder(String orderId) async {
    try {
      final order = await _datasource.getOrderById(orderId);
      if (order == null) return false;

      final cancelableStatuses = ['pending', 'confirmed'];
      return cancelableStatuses.contains(order.status);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    try {
      await _datasource.updateOrderStatus(orderId, 'cancelled');
    } catch (e) {
      rethrow;
    }
  }
}
