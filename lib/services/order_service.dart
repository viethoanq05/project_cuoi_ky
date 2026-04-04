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

  // Tạo đơn hàng
  Future<OrderData> createOrder({
    required String customerId,
    required String storeId,
    required String storeName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double deliveryFee,
    required String paymentMethod,
    DateTime? scheduledTime,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? notes,
  }) async {
    try {
      final orderId = _firestore.collection('Orders').doc().id;
      final now = DateTime.now();

      final order = OrderData(
        orderId: orderId,
        customerId: customerId,
        storeId: storeId,
        storeName: storeName,
        items: items,
        totalAmount: totalAmount,
        deliveryFee: deliveryFee,
        paymentMethod: paymentMethod,
        status: 'pending',
        scheduledTime: scheduledTime,
        createdAt: now,
        updatedAt: now,
        deliveryAddress: deliveryAddress,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        notes: notes,
      );

      if (paymentMethod == 'wallet') {
        await _firestore.runTransaction((transaction) async {
          final userRef = _firestore.collection('Users').doc(customerId);
          final userSnapshot = await transaction.get(userRef);

          if (!userSnapshot.exists) {
            throw Exception('User không tồn tại');
          }

          final walletBalance =
              (userSnapshot.data()?['wallet_balance'] as num?)?.toDouble() ?? 0.0;

          if (walletBalance < totalAmount) {
            throw Exception('Số dư ví không đủ');
          }

          transaction.update(userRef, {
            'wallet_balance': FieldValue.increment(-totalAmount),
            'updatedAt': now,
          });

          final ordersRef = _firestore.collection('Orders').doc(orderId);
          transaction.set(ordersRef, order.toMap());

          final customerOrderRef = userRef.collection('Orders').doc(orderId);
          transaction.set(customerOrderRef, order.toMap());

          final storeOrderRef = _firestore
              .collection('Users')
              .doc(storeId)
              .collection('Orders')
              .doc(orderId);
          transaction.set(storeOrderRef, order.toMap());
        });
      } else {
        await _firestore.collection('Orders').doc(orderId).set(order.toMap());

        // Thêm vào collection của khách hàng
        await _firestore
            .collection('Users')
            .doc(customerId)
            .collection('Orders')
            .doc(orderId)
            .set(order.toMap());

        // Thêm vào collection của cửa hàng
        await _firestore
            .collection('Users')
            .doc(storeId)
            .collection('Orders')
            .doc(orderId)
            .set(order.toMap());
      }

      notifyListeners();
      return order;
    } catch (e) {
      rethrow;
    }
  }

  // Lấy danh sách đơn hàng của khách hàng
  Stream<List<OrderData>> watchCustomerOrders(String customerId) {
    return _firestore
        .collection('Users')
        .doc(customerId)
        .collection('Orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderData.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<bool> validateWalletBalance(String customerId, double amount) async {
    final doc = await _firestore.collection('Users').doc(customerId).get();
    if (!doc.exists) {
      throw Exception('User không tồn tại');
    }

    final walletBalance =
        (doc.data()?['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    return walletBalance >= amount;
  }

  // Lấy danh sách đơn hàng của cửa hàng
  Stream<List<OrderData>> watchStoreOrders(String storeId) {
    return _firestore
        .collection('Users')
        .doc(storeId)
        .collection('Orders')
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

      // Cập nhật collection orders chính
      await _firestore.collection('Orders').doc(orderId).update(updateData);

      // Lấy order để cập nhật ở user collections
      final orderDoc = await _firestore.collection('Orders').doc(orderId).get();
      if (orderDoc.exists) {
        final order = OrderData.fromMap(orderDoc.data() as Map<String, dynamic>);
        
        // Cập nhật ở khách hàng
        await _firestore
            .collection('Users')
            .doc(order.customerId)
            .collection('Orders')
            .doc(orderId)
            .update(updateData);

        // Cập nhật ở cửa hàng
        await _firestore
            .collection('Users')
            .doc(order.storeId)
            .collection('Orders')
            .doc(orderId)
            .update(updateData);
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Thêm đánh giá
  Future<void> addReview(
    String orderId,
    double rating,
    String review,
  ) async {
    try {
      await _firestore.collection('Orders').doc(orderId).update({
        'rating': rating,
        'review': review,
        'updatedAt': DateTime.now(),
      });

      final orderDoc = await _firestore.collection('Orders').doc(orderId).get();
      if (orderDoc.exists) {
        final order = OrderData.fromMap(orderDoc.data() as Map<String, dynamic>);
        
        await _firestore
            .collection('Users')
            .doc(order.customerId)
            .collection('Orders')
            .doc(orderId)
            .update({'rating': rating, 'review': review});

        await _firestore
            .collection('Users')
            .doc(order.storeId)
            .collection('Orders')
            .doc(orderId)
            .update({'rating': rating, 'review': review});
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Hủy đơn hàng
  Future<void> cancelOrder(String orderId) async {
    try {
      await updateOrderStatus(orderId, 'cancelled');
    } catch (e) {
      rethrow;
    }
  }

  // Lấy chi tiết đơn hàng
  Future<OrderData?> getOrderDetail(String orderId) async {
    try {
      final doc = await _firestore.collection('Orders').doc(orderId).get();
      if (doc.exists) {
        return OrderData.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
