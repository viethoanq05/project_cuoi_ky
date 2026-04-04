import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/user_profile_model.dart';
import '../models/review_model.dart';

class FirestoreDatasource {
  final FirebaseFirestore _firebaseFirestore;

  FirestoreDatasource({FirebaseFirestore? firebaseFirestore})
      : _firebaseFirestore = firebaseFirestore ?? FirebaseFirestore.instance;

  // ============ ORDER OPERATIONS ============

  Future<OrderModel> createOrder({
    required String orderId,
    required String userId,
    required String storeId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String paymentMethod,
    required String deliveryAddress,
    DateTime? scheduledTime,
  }) async {
    try {
      final orderData = {
        'id': orderId,
        'user_id': userId,
        'store_id': storeId,
        'items': items,
        'total_price': totalPrice,
        'status': 'pending',
        'payment_method': paymentMethod,
        'delivery_address': deliveryAddress,
        'scheduled_time': scheduledTime?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _firebaseFirestore.collection('Orders').doc(orderId).set(orderData);

      return OrderModel.fromJson(orderData);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<OrderModel>> getUserOrders(String userId) async {
    try {
      final snapshot = await _firebaseFirestore
          .collection('Orders')
          .where('user_id', isEqualTo: userId)
          .get();

      final orders = snapshot.docs
          .map((doc) => OrderModel.fromJson(doc.data()))
          .toList();

      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (e) {
      rethrow;
    }
  }

  Stream<OrderModel?> watchOrder(String orderId) {
    return _firebaseFirestore
        .collection('Orders')
        .doc(orderId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return OrderModel.fromJson(snapshot.data()!);
      }
      return null;
    });
  }

  Stream<OrderModel?> watchOrderFromUser(String orderId, String userId) {
    return _firebaseFirestore
        .collection('Users')
        .doc(userId)
        .collection('Orders')
        .doc(orderId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return OrderModel.fromJson(snapshot.data()!);
      }
      return null;
    });
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final doc =
          await _firebaseFirestore.collection('Orders').doc(orderId).get();
      if (doc.exists && doc.data() != null) {
        return OrderModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firebaseFirestore.collection('Orders').doc(orderId).update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // ============ USER PROFILE OPERATIONS ============

  Future<UserProfileModel> getUserProfile(String userId) async {
    try {
      final doc =
          await _firebaseFirestore.collection('Users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return UserProfileModel.fromJson(doc.data()!);
      }
      throw Exception('User profile not found');
    } catch (e) {
      rethrow;
    }
  }

  Stream<UserProfileModel?> watchUserProfile(String userId) {
    return _firebaseFirestore
        .collection('Users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserProfileModel.fromJson(snapshot.data()!);
      }
      return null;
    });
  }

  Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String phone,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _firebaseFirestore.collection('Users').doc(userId).update({
        'fullName': name,
        'name': name,
        'phone': phone,
        'address': address,
        'lat': latitude,
        'lng': longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> validateWalletBalance(String userId, double amount) async {
    try {
      final doc =
          await _firebaseFirestore.collection('Users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final walletBalance =
            (doc.data()!['wallet_balance'] as num?)?.toDouble() ?? 0.0;
        return walletBalance >= amount;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deductWalletBalance(String userId, double amount) async {
    try {
      await _firebaseFirestore
          .collection('Users')
          .doc(userId)
          .update({
            'wallet_balance': FieldValue.increment(-amount),
          });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addWalletBalance(String userId, double amount) async {
    try {
      await _firebaseFirestore
          .collection('Users')
          .doc(userId)
          .update({
            'wallet_balance': FieldValue.increment(amount),
          });
    } catch (e) {
      rethrow;
    }
  }

  // ============ REVIEW OPERATIONS ============

  Future<bool> hasReviewedOrder(String orderId) async {
    try {
      final snapshot = await _firebaseFirestore
          .collection('reviews')
          .where('order_id', isEqualTo: orderId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }

  Future<ReviewModel> createReview({
    required String reviewId,
    required String orderId,
    required String userId,
    required String storeId,
    required int rating,
    required String comment,
  }) async {
    try {
      final reviewData = {
        'id': reviewId,
        'order_id': orderId,
        'user_id': userId,
        'store_id': storeId,
        'rating': rating,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _firebaseFirestore.collection('reviews').doc(reviewId).set(reviewData);

      return ReviewModel.fromJson(reviewData);
    } catch (e) {
      rethrow;
    }
  }

  Future<ReviewModel?> getReviewByOrderId(String orderId) async {
    try {
      final snapshot = await _firebaseFirestore
          .collection('reviews')
          .where('order_id', isEqualTo: orderId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ReviewModel.fromJson(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ReviewModel>> getStoreReviews(String storeId) async {
    try {
      final snapshot = await _firebaseFirestore
          .collection('reviews')
          .where('store_id', isEqualTo: storeId)
          .get();

      final reviews = snapshot.docs
          .map((doc) => ReviewModel.fromJson(doc.data()))
          .toList();
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    } catch (e) {
      rethrow;
    }
  }

  // ============ TRANSACTION OPERATIONS ============

  Future<void> processWalletPayment({
    required String userId,
    required String storeId,
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String deliveryAddress,
    DateTime? scheduledTime,
  }) async {
    try {
      await _firebaseFirestore.runTransaction((transaction) async {
        final userRef = _firebaseFirestore.collection('Users').doc(userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final walletBalance =
            (userDoc.data()?['wallet_balance'] as num?)?.toDouble() ?? 0.0;

        if (walletBalance < totalPrice) {
          throw Exception('Insufficient wallet balance');
        }

        // Deduct wallet
        transaction.update(userRef, {
          'wallet_balance': FieldValue.increment(-totalPrice),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Create order
        final orderRef = _firebaseFirestore.collection('Orders').doc(orderId);
        transaction.set(orderRef, {
          'id': orderId,
          'user_id': userId,
          'store_id': storeId,
          'items': items,
          'total_price': totalPrice,
          'status': 'pending',
          'payment_method': 'wallet',
          'delivery_address': deliveryAddress,
          'scheduled_time': scheduledTime?.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      });
    } catch (e) {
      rethrow;
    }
  }
}
