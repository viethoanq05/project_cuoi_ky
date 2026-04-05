import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';

class OrderService extends ChangeNotifier {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _ordersCollection = 'Orders';
  static const String _usersCollection = 'Users';

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

    final ordersRef = _firestore.collection(_ordersCollection).doc(orderId);
    final userRef = _firestore.collection(_usersCollection).doc(customerId);
    final storeRef = _firestore.collection(_usersCollection).doc(storeId);

    if (paymentMethod == 'wallet') {
      await _firestore.runTransaction((transaction) async {
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
          'updated_at': now,
        });

        transaction.set(ordersRef, order.toMap());
        transaction.set(
          userRef.collection(_ordersCollection).doc(orderId),
          order.toMap(),
        );
        transaction.set(
          storeRef.collection(_ordersCollection).doc(orderId),
          order.toMap(),
        );
      });
    } else {
      await ordersRef.set(order.toMap());
      await userRef
          .collection(_ordersCollection)
          .doc(orderId)
          .set(order.toMap());
      await storeRef
          .collection(_ordersCollection)
          .doc(orderId)
          .set(order.toMap());
    }

    notifyListeners();
    return order;
  }

  Stream<List<OrderData>> watchCustomerOrders(String customerId) {
    return _firestore
        .collection(_usersCollection)
        .doc(customerId)
        .collection(_ordersCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => OrderData.fromMap({...doc.data(), 'orderId': doc.id}),
              )
              .toList();
        });
  }

  Stream<List<OrderData>> watchStoreOrders(String storeId) {
    return _firestore
        .collection(_usersCollection)
        .doc(storeId)
        .collection(_ordersCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => OrderData.fromMap({...doc.data(), 'orderId': doc.id}),
              )
              .toList();
        });
  }

  Future<bool> validateWalletBalance(String customerId, double amount) async {
    final doc = await _firestore
        .collection(_usersCollection)
        .doc(customerId)
        .get();
    if (!doc.exists) {
      throw Exception('User không tồn tại');
    }

    final walletBalance =
        (doc.data()?['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    return walletBalance >= amount;
  }

  Stream<List<OrderData>> watchDriverActiveOrders(String driverId) {
    return _firestore
        .collection(_ordersCollection)
        .where('driverId', isEqualTo: driverId)
        .where(
          'status',
          whereIn: ['delivering', 'on_the_way', 'ready', 'preparing'],
        )
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map(
                (doc) => OrderData.fromMap({...doc.data(), 'orderId': doc.id}),
              )
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  Stream<List<OrderData>> watchDriverHistory(String driverId) {
    return _firestore
        .collection(_ordersCollection)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered')
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map(
                (doc) => OrderData.fromMap({...doc.data(), 'orderId': doc.id}),
              )
              .toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  Future<void> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? driverId,
    String? proofImage,
  }) async {
    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{'status': newStatus, 'updatedAt': now};

    if (driverId != null) {
      data['driverId'] = driverId;
    }

    if (proofImage != null) {
      data['proofImage'] = proofImage;
    }

    await _updateOrderAndMirrors(orderId, data);
    notifyListeners();
  }

  Future<void> cancelOrder(String orderId) async {
    await updateOrderStatus(orderId, 'cancelled');
  }

  Future<void> addReview(String orderId, double rating, String review) async {
    final data = {
      'rating': rating,
      'review': review,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _updateOrderAndMirrors(orderId, data);
    notifyListeners();
  }

  Future<OrderData?> getOrderDetail(String orderId) async {
    final doc = await _firestore
        .collection(_ordersCollection)
        .doc(orderId)
        .get();
    if (!doc.exists) {
      return null;
    }
    final data = doc.data();
    if (data == null) {
      return null;
    }

    return OrderData.fromMap({...data, 'orderId': doc.id});
  }

  Future<void> acceptOrder(String orderId, String driverId) async {
    await updateOrderStatus(orderId, 'delivering', driverId: driverId);
  }

  Future<void> driverCancelOrder(String orderId) async {
    final data = {
      'status': 'pending',
      'driverId': '',
      'driver_name': '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _updateOrderAndMirrors(orderId, data);
    notifyListeners();
  }

  Future<String?> uploadProofImage(String orderId, Uint8List bytes) async {
    try {
      const bucketName = 'food-images';
      final path = 'proofimages/proof_$orderId.jpg';

      await _supabase.storage
          .from(bucketName)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      return _supabase.storage.from(bucketName).getPublicUrl(path);
    } catch (e) {
      debugPrint('Lỗi upload ảnh minh chứng: $e');
      return null;
    }
  }

  Future<void> _updateOrderAndMirrors(
    String orderId,
    Map<String, dynamic> updateData,
  ) async {
    final orderRef = _firestore.collection(_ordersCollection).doc(orderId);

    // Update main order doc.
    await orderRef.update(updateData);

    // Best-effort mirror into user subcollections.
    final orderDoc = await orderRef.get();
    final orderData = orderDoc.data();
    if (orderData == null) {
      return;
    }

    final mirrorData = <String, dynamic>{...orderData, ...updateData};

    final order = OrderData.fromMap({...orderData, 'orderId': orderId});

    final customerOrderRef = _firestore
        .collection(_usersCollection)
        .doc(order.customerId)
        .collection(_ordersCollection)
        .doc(orderId);
    final storeOrderRef = _firestore
        .collection(_usersCollection)
        .doc(order.storeId)
        .collection(_ordersCollection)
        .doc(orderId);

    try {
      await customerOrderRef.set(mirrorData, SetOptions(merge: true));
    } catch (_) {}

    try {
      await storeOrderRef.set(mirrorData, SetOptions(merge: true));
    } catch (_) {}
  }
}
