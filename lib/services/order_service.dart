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

  // Tạo đơn hàng (Dùng cho booking_screen)
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

  // Lấy đơn hàng đang thực hiện
  Stream<List<OrderData>> watchDriverActiveOrders(String driverId) {
    return _firestore
        .collection(_ordersCollection)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['preparing', 'on_the_way', 'ready'])
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs.map((doc) => OrderData.fromMap({...doc.data(), 'orderId': doc.id})).toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  // Lấy lịch sử hoàn thành
  Stream<List<OrderData>> watchDriverHistory(String driverId) {
    return _firestore
        .collection(_ordersCollection)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered')
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs.map((doc) => OrderData.fromMap({...doc.data(), 'orderId': doc.id})).toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  // Cập nhật trạng thái (Sửa lỗi không lưu bằng cách ghi cả snake_case và camelCase)
  Future<void> updateOrderStatus(String orderId, String newStatus, {String? proofImage}) async {
    final now = FieldValue.serverTimestamp();
    final data = {
      'status': newStatus,
      'order_status': newStatus, // snake_case cho tương thích
      'updatedAt': now,
      'updated_at': now,
    };
    if (proofImage != null) {
      data['proofImage'] = proofImage;
      data['proof_image'] = proofImage;
    }
    await _firestore.collection(_ordersCollection).doc(orderId).update(data);
    notifyListeners();
  }

  // Tài xế hủy đơn
  Future<void> driverCancelOrder(String orderId) async {
    await _firestore.collection(_ordersCollection).doc(orderId).update({
      'status': 'pending',
      'order_status': 'pending',
      'driverId': '',
      'driver_id': '',
      'driver_name': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  // Upload ảnh lên Supabase
  Future<String?> uploadProofImage(String orderId, Uint8List bytes) async {
    try {
      final path = 'order_proofs/proof_$orderId.jpg';
      await _supabase.storage.from('food_images').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
      return _supabase.storage.from('food_images').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  // Nhận đơn hàng (Sửa lỗi không lưu)
  Future<void> acceptOrder(String orderId, String driverId) async {
    final now = FieldValue.serverTimestamp();
    await _firestore.collection(_ordersCollection).doc(orderId).update({
      'status': 'preparing',
      'order_status': 'preparing',
      'driverId': driverId,
      'driver_id': driverId,
      'updatedAt': now,
      'updated_at': now,
    });
    notifyListeners();
  }
}
