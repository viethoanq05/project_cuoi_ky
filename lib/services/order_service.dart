import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order.dart';

class OrderService extends ChangeNotifier {
  static final OrderService _instance = OrderService._internal();

  factory OrderService() {
    return _instance;
  }

  OrderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _ordersCollection = 'Orders';

  // Tạo đơn hàng
  Future<OrderData> createOrder({
    required String customerId,
    required String storeId,
    required String storeName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double deliveryFee,
    DateTime? scheduledTime,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? notes,
  }) async {
    try {
      final orderId = _firestore.collection(_ordersCollection).doc().id;
      final now = DateTime.now();

      final order = OrderData(
        orderId: orderId,
        customerId: customerId,
        storeId: storeId,
        storeName: storeName,
        items: items,
        totalAmount: totalAmount,
        deliveryFee: deliveryFee,
        status: 'pending',
        scheduledTime: scheduledTime,
        createdAt: now,
        updatedAt: now,
        deliveryAddress: deliveryAddress,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        notes: notes,
      );

      await _firestore.collection(_ordersCollection).doc(orderId).set(order.toMap());
      
      notifyListeners();
      return order;
    } catch (e) {
      rethrow;
    }
  }

  // Lấy tất cả đơn hàng
  Stream<List<OrderData>> watchAllOrders() {
    return _firestore
        .collection(_ordersCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderData.fromMap(doc.data())).toList();
    });
  }

  // Lấy danh sách đơn hàng của khách hàng
  Stream<List<OrderData>> watchCustomerOrders(String customerId) {
    return _firestore
        .collection(_ordersCollection)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderData.fromMap(doc.data())).toList();
    });
  }

  // Lấy danh sách đơn hàng của tài xế
  Stream<List<OrderData>> watchDriverOrders(String driverId) {
    return _firestore
        .collection(_ordersCollection)
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderData.fromMap(doc.data())).toList();
    });
  }

  // Cập nhật trạng thái đơn hàng
  Future<void> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? driverId,
  }) async {
    try {
      final now = DateTime.now();
      final updateData = {
        'status': newStatus,
        'updatedAt': now,
        if (driverId != null) 'driverId': driverId,
      };

      await _firestore.collection(_ordersCollection).doc(orderId).update(updateData);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Nhận đơn hàng (Cho tài xế)
  Future<void> acceptOrder(String orderId, String driverId) async {
    try {
      await updateOrderStatus(orderId, 'preparing', driverId: driverId);
      
      // Lưu vào collection DriverAccepted để theo dõi (theo yêu cầu)
      await _firestore.collection('DriverAccepted').doc(orderId).set({
        'orderId': orderId,
        'driverId': driverId,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }
}
