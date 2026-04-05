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
      final now = DateTime.now();
      final orderData = {
        'id': orderId,
        'user_id': userId,
        'store_id': storeId,
        'items': items,
        'total_price': totalPrice,
        'status': 'pending',
        'payment_method': paymentMethod,
        'delivery_address': deliveryAddress,
        'scheduled_time': scheduledTime,
        'created_at': now,
        'updated_at': now,
      };

      await _firebaseFirestore.collection('Orders').doc(orderId).set(orderData);

      // Mirror into user subcollections for realtime UIs that watch
      // Users/{id}/Orders/{orderId}.
      await _firebaseFirestore
          .collection('Users')
          .doc(userId)
          .collection('Orders')
          .doc(orderId)
          .set(orderData);

      await _firebaseFirestore
          .collection('Users')
          .doc(storeId)
          .collection('Orders')
          .doc(orderId)
          .set(orderData);

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
    return _firebaseFirestore.collection('Orders').doc(orderId).snapshots().map(
      (snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = <String, dynamic>{...snapshot.data()!};
          data.putIfAbsent('id', () => snapshot.id);
          return OrderModel.fromJson(data);
        }
        return null;
      },
    );
  }

  Stream<OrderModel?> watchOrderFromUser(String orderId, String userId) {
    // For backwards-compatibility (older orders may not have been mirrored
    // into Users/{id}/Orders). Prefer the main Orders collection.
    return watchOrder(orderId);
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final doc = await _firebaseFirestore
          .collection('Orders')
          .doc(orderId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = <String, dynamic>{...doc.data()!};
        data.putIfAbsent('id', () => doc.id);
        return OrderModel.fromJson(data);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final updateData = {
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      };

      final orderRef = _firebaseFirestore.collection('Orders').doc(orderId);
      await orderRef.update(updateData);

      // Best-effort mirror update.
      final orderDoc = await orderRef.get();
      final order = orderDoc.data();
      if (order == null) {
        return;
      }

      final userId = (order['user_id'] ?? order['customer_id'] ?? '')
          .toString();
      final storeId = (order['store_id'] ?? order['storeId'] ?? '').toString();

      final fallbackCustomerId = (order['customerId'] ?? '').toString();
      final resolvedUserId = userId.trim().isNotEmpty
          ? userId.trim()
          : fallbackCustomerId.trim();

      if (resolvedUserId.isNotEmpty) {
        try {
          await _firebaseFirestore
              .collection('Users')
              .doc(resolvedUserId)
              .collection('Orders')
              .doc(orderId)
              .set(updateData, SetOptions(merge: true));
        } catch (_) {}
      }

      if (storeId.trim().isNotEmpty) {
        try {
          await _firebaseFirestore
              .collection('Users')
              .doc(storeId)
              .collection('Orders')
              .doc(orderId)
              .set(updateData, SetOptions(merge: true));
        } catch (_) {}
      }
    } catch (e) {
      rethrow;
    }
  }

  // ============ USER PROFILE OPERATIONS ============

  Future<UserProfileModel> getUserProfile(String userId) async {
    try {
      final doc = await _firebaseFirestore
          .collection('Users')
          .doc(userId)
          .get();
      if (doc.exists && doc.data() != null) {
        return UserProfileModel.fromJson(doc.data()!);
      }
      throw Exception('User profile not found');
    } catch (e) {
      rethrow;
    }
  }

  Stream<UserProfileModel?> watchUserProfile(String userId) {
    return _firebaseFirestore.collection('Users').doc(userId).snapshots().map((
      snapshot,
    ) {
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
      final doc = await _firebaseFirestore
          .collection('Users')
          .doc(userId)
          .get();
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
      await _firebaseFirestore.collection('Users').doc(userId).update({
        'wallet_balance': FieldValue.increment(-amount),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addWalletBalance(String userId, double amount) async {
    try {
      await _firebaseFirestore.collection('Users').doc(userId).update({
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

      double asDouble(dynamic value) {
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value.trim()) ?? 0.0;
        return 0.0;
      }

      int asInt(dynamic value) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value.trim()) ?? 0;
        return 0;
      }

      String asTrimmedText(dynamic value) => value?.toString().trim() ?? '';

      await _firebaseFirestore.runTransaction((transaction) async {
        final reviewRef = _firebaseFirestore
            .collection('reviews')
            .doc(reviewId);
        final orderRef = _firebaseFirestore.collection('Orders').doc(orderId);
        final storeRef = _firebaseFirestore.collection('Users').doc(storeId);

        // Firestore transactions require all reads to happen before any writes.
        final existingReviewSnap = await transaction.get(reviewRef);
        if (existingReviewSnap.exists) {
          throw Exception('This order has already been reviewed');
        }

        final orderSnap = await transaction.get(orderRef);
        if (!orderSnap.exists) {
          throw Exception('Order not found');
        }

        final orderData = orderSnap.data() ?? <String, dynamic>{};
        final existingReviewText = asTrimmedText(orderData['review']);
        final existingRatingValue = asDouble(orderData['rating']);
        if (existingRatingValue > 0 || existingReviewText.isNotEmpty) {
          throw Exception('This order has already been reviewed');
        }

        final orderStoreId = asTrimmedText(
          orderData['store_id'] ?? orderData['storeId'],
        );
        if (orderStoreId.isNotEmpty && orderStoreId != storeId) {
          throw Exception('Invalid store for this order');
        }

        // Read store + all involved foods before writing.
        final storeSnap = await transaction.get(storeRef);
        final storeData = storeSnap.data() ?? <String, dynamic>{};

        final rawItems = orderData['items'] ?? orderData['order_items'];
        final items = rawItems is List ? rawItems : const [];
        final uniqueFoodIds = <String>{};
        for (final item in items) {
          if (item is! Map) continue;
          final foodId = asTrimmedText(
            item['food_id'] ?? item['foodId'] ?? item['id'],
          );
          if (foodId.isNotEmpty) {
            uniqueFoodIds.add(foodId);
          }
        }

        final foodSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final foodId in uniqueFoodIds) {
          final foodRef = _firebaseFirestore.collection('Foods').doc(foodId);
          foodSnaps[foodId] = await transaction.get(foodRef);
        }

        // ---- Writes (after all reads) ----
        transaction.set(reviewRef, reviewData);

        final orderUpdate = <String, dynamic>{
          'rating': rating.toDouble(),
          'review': comment,
          'updated_at': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        transaction.set(orderRef, orderUpdate, SetOptions(merge: true));

        // Mirror into Users/{customerId}/Orders and Users/{storeId}/Orders if present.
        final customerId = asTrimmedText(
          orderData['user_id'] ??
              orderData['customer_id'] ??
              orderData['customerId'],
        );
        if (customerId.isNotEmpty) {
          final userOrderRef = _firebaseFirestore
              .collection('Users')
              .doc(customerId)
              .collection('Orders')
              .doc(orderId);
          transaction.set(userOrderRef, orderUpdate, SetOptions(merge: true));
        }

        final storeOrderRef = _firebaseFirestore
            .collection('Users')
            .doc(storeId)
            .collection('Orders')
            .doc(orderId);
        transaction.set(storeOrderRef, orderUpdate, SetOptions(merge: true));

        // Update store aggregate rating.

        Map<String, dynamic>? storeInfo;
        final rawStoreInfo = storeData['store_info'] ?? storeData['storeInfo'];
        if (rawStoreInfo is List &&
            rawStoreInfo.isNotEmpty &&
            rawStoreInfo.first is Map) {
          storeInfo = Map<String, dynamic>.from(rawStoreInfo.first as Map);
        } else if (rawStoreInfo is Map) {
          storeInfo = Map<String, dynamic>.from(rawStoreInfo);
        }

        final prevStoreCount = asInt(
          storeData['totalRatings'] ??
              storeData['total_ratings'] ??
              storeData['ratingCount'] ??
              storeInfo?['totalRatings'] ??
              storeInfo?['total_ratings'] ??
              storeInfo?['ratingCount'],
        );

        final prevStoreAvgRaw =
            storeData['avgRating'] ??
            storeData['avg_rating'] ??
            storeData['rating'] ??
            storeInfo?['avgRating'] ??
            storeInfo?['avg_rating'] ??
            storeInfo?['rating'];
        final prevStoreAvg = asDouble(prevStoreAvgRaw);

        final nextStoreCount = prevStoreCount + 1;
        final nextStoreAvg =
            ((prevStoreAvg * prevStoreCount) + rating) / nextStoreCount;

        transaction.set(storeRef, <String, dynamic>{
          'rating': nextStoreAvg,
          'avgRating': nextStoreAvg,
          'avg_rating': nextStoreAvg,
          'totalRatings': nextStoreCount,
          'total_ratings': nextStoreCount,
          'updated_at': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update each food's aggregate rating once per order.
        for (final foodId in uniqueFoodIds) {
          final foodSnap = foodSnaps[foodId];
          if (foodSnap == null || !foodSnap.exists) {
            continue;
          }
          final foodData = foodSnap.data() ?? <String, dynamic>{};
          final prevFoodCount = asInt(
            foodData['totalRatings'] ??
                foodData['total_ratings'] ??
                foodData['ratingCount'],
          );
          final prevFoodAvg = asDouble(
            foodData['avgRating'] ??
                foodData['avg_rating'] ??
                foodData['rating'],
          );

          final nextFoodCount = prevFoodCount + 1;
          final nextFoodAvg =
              ((prevFoodAvg * prevFoodCount) + rating) / nextFoodCount;

          final foodRef = _firebaseFirestore.collection('Foods').doc(foodId);
          transaction.set(foodRef, <String, dynamic>{
            'avgRating': nextFoodAvg,
            'avg_rating': nextFoodAvg,
            'rating': nextFoodAvg,
            'totalRatings': nextFoodCount,
            'total_ratings': nextFoodCount,
            'updated_at': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });

      // Best-effort: rebuild aggregates from source-of-truth reviews so
      // displayed stars/counts are always correct.
      try {
        await _syncAggregatesFromReviewsForStore(storeId);
      } catch (_) {
        // Ignore sync failures; the review itself has already been created.
      }

      return ReviewModel.fromJson(reviewData);
    } catch (e) {
      rethrow;
    }
  }

  Iterable<List<T>> _chunks<T>(List<T> items, int size) sync* {
    for (var start = 0; start < items.length; start += size) {
      yield items.sublist(start, (start + size).clamp(0, items.length));
    }
  }

  String _asText(dynamic value) => value?.toString().trim() ?? '';

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_asText(value)) ?? 0.0;
  }

  Future<void> _syncAggregatesFromReviewsForStore(String storeId) async {
    final trimmedStoreId = storeId.trim();
    if (trimmedStoreId.isEmpty) return;

    // 1) Read all reviews for this store
    final reviewsSnap = await _firebaseFirestore
        .collection('reviews')
        .where('store_id', isEqualTo: trimmedStoreId)
        .get();

    final orderRating = <String, double>{};
    double storeSum = 0.0;
    var storeCount = 0;

    for (final doc in reviewsSnap.docs) {
      final data = doc.data();
      final orderId = _asText(data['order_id']);
      if (orderId.isEmpty) continue;
      final rating = _asDouble(data['rating']);
      if (rating <= 0) continue;
      orderRating[orderId] = rating;
      storeSum += rating;
      storeCount += 1;
    }

    // 2) Load orders in chunks and aggregate per food
    final foodSum = <String, double>{};
    final foodCount = <String, int>{};

    const chunkSize = 10;
    for (final chunk in _chunks(orderRating.keys.toList(), chunkSize)) {
      final ordersSnap = await _firebaseFirestore
          .collection('Orders')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final orderDoc in ordersSnap.docs) {
        final rating = orderRating[orderDoc.id] ?? 0.0;
        if (rating <= 0) continue;

        final orderData = orderDoc.data();
        final rawItems = orderData['items'] ?? orderData['order_items'];
        final items = rawItems is List ? rawItems : const [];

        final uniqueFoodIds = <String>{};
        for (final item in items) {
          if (item is! Map) continue;
          final foodId = _asText(
            item['food_id'] ?? item['foodId'] ?? item['id'],
          );
          if (foodId.isNotEmpty) uniqueFoodIds.add(foodId);
        }

        for (final foodId in uniqueFoodIds) {
          foodSum[foodId] = (foodSum[foodId] ?? 0.0) + rating;
          foodCount[foodId] = (foodCount[foodId] ?? 0) + 1;
        }
      }
    }

    // 3) Write back aggregates
    final batch = _firebaseFirestore.batch();

    final storeAvg = storeCount > 0 ? (storeSum / storeCount) : 0.0;
    final storeRef = _firebaseFirestore.collection('Users').doc(trimmedStoreId);
    batch.set(storeRef, <String, dynamic>{
      'rating': storeAvg,
      'avgRating': storeAvg,
      'avg_rating': storeAvg,
      'totalRatings': storeCount,
      'total_ratings': storeCount,
      'updated_at': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final entry in foodCount.entries) {
      final foodId = entry.key;
      final count = entry.value;
      final sum = foodSum[foodId] ?? 0.0;
      final avg = count > 0 ? (sum / count) : 0.0;

      final foodRef = _firebaseFirestore.collection('Foods').doc(foodId);
      batch.set(foodRef, <String, dynamic>{
        'avgRating': avg,
        'avg_rating': avg,
        'rating': avg,
        'totalRatings': count,
        'total_ratings': count,
        'updated_at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
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
      final now = DateTime.now();

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
        final orderData = {
          'id': orderId,
          'user_id': userId,
          'store_id': storeId,
          'items': items,
          'total_price': totalPrice,
          'status': 'pending',
          'payment_method': 'wallet',
          'delivery_address': deliveryAddress,
          'scheduled_time': scheduledTime,
          'created_at': now,
          'updated_at': now,
        };

        transaction.set(orderRef, orderData);

        // Mirror into user subcollections.
        final userOrderRef = _firebaseFirestore
            .collection('Users')
            .doc(userId)
            .collection('Orders')
            .doc(orderId);
        transaction.set(userOrderRef, orderData);

        final storeOrderRef = _firebaseFirestore
            .collection('Users')
            .doc(storeId)
            .collection('Orders')
            .doc(orderId);
        transaction.set(storeOrderRef, orderData);
      });
    } catch (e) {
      rethrow;
    }
  }
}
