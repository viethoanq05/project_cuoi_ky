import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';
import '../models/store_info.dart';

class SearchService {
  static final SearchService _instance = SearchService._internal();

  factory SearchService() {
    return _instance;
  }

  SearchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tìm kiếm cửa hàng theo tên
  Future<List<StoreInfo>> searchStores(String query) async {
    try {
      if (query.isEmpty) {
        return [];
      }

      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'store')
          .get();

      final stores = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final storeName = (data['fullName'] ?? '').toString().toLowerCase();
            return storeName.contains(query.toLowerCase());
          })
          .map((doc) {
            final data = doc.data();
            return StoreInfo(
              storeId: doc.id,
              storeOwnerId: doc.id,
              storeName: data['fullName'] ?? '',
              latitude: (data['position']?['latitude'] ?? 0).toDouble(),
              longitude: (data['position']?['longitude'] ?? 0).toDouble(),
              address: data['address'] ?? '',
              phone: data['phone'] ?? '',
              rating: (data['avgRating'] as num?)?.toDouble(),
              totalRatings: data['totalRatings'] as int?,
              isOpen: data['isStoreOpen'] ?? true,
            );
          })
          .toList();

      return stores;
    } catch (e) {
      rethrow;
    }
  }

  // Tìm kiếm món ăn theo tên
  Future<List<FoodItem>> searchFoods(
    String query, {
    String? storeId,
    String? categoryId,
  }) async {
    try {
      if (query.isEmpty) {
        return [];
      }

      Query foodQuery = _firestore.collection('foods');

      if (storeId != null) {
        foodQuery = foodQuery.where('storeId', isEqualTo: storeId);
      }

      if (categoryId != null) {
        foodQuery = foodQuery.where('categoryId', isEqualTo: categoryId);
      }

      final snapshot = await foodQuery.get();

      final foods = snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final description = (data['description'] ?? '').toString().toLowerCase();
            return name.contains(query.toLowerCase()) ||
                description.contains(query.toLowerCase());
          })
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return FoodItem.fromMap({...data, 'foodId': doc.id});
          })
          .toList();

      return foods;
    } catch (e) {
      rethrow;
    }
  }

  // Lọc theo danh mục
  Future<List<FoodItem>> filterByCategory(
    String categoryId, {
    String? storeId,
  }) async {
    try {
      Query query = _firestore
          .collection('foods')
          .where('categoryId', isEqualTo: categoryId)
          .where('isAvailable', isEqualTo: true);

      if (storeId != null) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return FoodItem.fromMap({...data, 'foodId': doc.id});
          })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Lọc theo khoảng giá
  Future<List<FoodItem>> filterByPrice(
    double minPrice,
    double maxPrice, {
    String? storeId,
  }) async {
    try {
      Query query = _firestore
          .collection('foods')
          .where('price', isGreaterThanOrEqualTo: minPrice)
          .where('price', isLessThanOrEqualTo: maxPrice)
          .where('isAvailable', isEqualTo: true);

      if (storeId != null) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return FoodItem.fromMap({...data, 'foodId': doc.id});
          })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Lọc theo rating
  Future<List<FoodItem>> filterByRating(
    double minRating, {
    String? storeId,
  }) async {
    try {
      Query query = _firestore
          .collection('foods')
          .where('avgRating', isGreaterThanOrEqualTo: minRating)
          .where('isAvailable', isEqualTo: true);

      if (storeId != null) {
        query = query.where('storeId', isEqualTo: storeId);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return FoodItem.fromMap({...data, 'foodId': doc.id});
          })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Lấy thực đơn của cửa hàng dengan tìm kiếm
  Future<List<FoodItem>> getStoreMenuWithSearch(
    String storeId,
    String query,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('foods')
          .where('storeId', isEqualTo: storeId)
          .where('isAvailable', isEqualTo: true)
          .get();

      final foods = snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            return name.contains(query.toLowerCase());
          })
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return FoodItem.fromMap({...data, 'foodId': doc.id});
          })
          .toList();

      return foods;
    } catch (e) {
      rethrow;
    }
  }

  // Gợi ý món ăn phổ biến
  Future<List<FoodItem>> getPopularFoods({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('foods')
          .where('isAvailable', isEqualTo: true)
          .orderBy('avgRating', descending: true)
          .orderBy('totalRatings', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return FoodItem.fromMap({...data, 'foodId': doc.id});
          })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Gợi ý mới nhất
  Future<List<FoodItem>> getNewestFoods({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('foods')
          .where('isAvailable', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return FoodItem.fromMap({...data, 'foodId': doc.id});
          })
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
