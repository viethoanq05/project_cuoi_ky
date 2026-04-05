import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../models/order.dart';
import '../services/order_service.dart';

class OrderController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OrderService _orderService = OrderService();
  static const String _ordersCollection = 'Orders';

  // Lấy danh sách đơn hàng đang tìm tài xế
  Stream<List<OrderData>> watchAvailableOrders() {
    return _firestore
        .collection(_ordersCollection)
        .where(
          'status',
          whereIn: ['finding_driver', 'searching', 'dang_tim_xe'],
        )
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => OrderData.fromMap({...doc.data(), 'orderId': doc.id}),
              )
              .toList();
        });
  }

  // Lọc đơn hàng theo vị trí và bán kính (km)
  List<OrderData> filterOrdersByLocation({
    required List<OrderData> orders,
    required LatLng currentPosition,
    required double radiusInKm,
  }) {
    final Distance distance = const Distance();

    return orders.where((order) {
      if (order.deliveryLat == null || order.deliveryLng == null) return false;

      final double meters = distance(
        currentPosition,
        LatLng(order.deliveryLat!, order.deliveryLng!),
      );

      return (meters / 1000) <= radiusInKm;
    }).toList();
  }

  // Nhận đơn hàng
  Future<String?> acceptOrder(String orderId, String driverId) async {
    try {
      await _orderService.updateOrderStatus(
        orderId,
        'delivering',
        driverId: driverId,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
