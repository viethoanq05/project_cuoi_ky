import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../models/store_info.dart';

class SearchService {
  static final SearchService _instance = SearchService._internal();

  factory SearchService() {
    return _instance;
  }

  SearchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lấy tên cửa hàng theo ID
  Future<String> getStoreNameById(String storeId) async {
    try {
      final doc = await _firestore.collection('Users').doc(storeId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['fullName'] ?? data?['storeName'] ?? 'Cửa hàng';
      }
      return 'Cửa hàng';
    } catch (e) {
      debugPrint('Error getting store name: $e');
      return 'Cửa hàng';
    }
  }

  // Lấy tất cả cửa hàng
  Future<List<StoreInfo>> getAllStores() async {
    try {
      final snapshot = await _firestore
          .collection('Users')
          .where('role', isEqualTo: 'Store')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return StoreInfo(
          storeId: doc.id,
          storeOwnerId: doc.id,
          storeName: data['fullName'] ?? data['storeName'] ?? '',
          storeImage: _extractStoreImageUrl(data),
          latitude: _parseLat(data['position']),
          longitude: _parseLon(data['position']),
          address: data['address'] ?? '',
          phone: data['phone'] ?? '',
          rating: _extractStoreRating(data),
          totalRatings: _extractTotalRatings(data),
          isOpen: data['isStoreOpen'] ?? true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching all stores: $e');
      return [];
    }
  }

  // Tìm kiếm cửa hàng theo tên
  Future<List<StoreInfo>> searchStores(String query) async {
    try {
      if (query.isEmpty) {
        return [];
      }

      final snapshot = await _firestore
          .collection('Users')
          .where('role', isEqualTo: 'Store')
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
              storeImage: _extractStoreImageUrl(data),
              latitude: _parseLat(data['position']),
              longitude: _parseLon(data['position']),
              address: data['address'] ?? '',
              phone: data['phone'] ?? '',
              rating: _extractStoreRating(data),
              totalRatings: _extractTotalRatings(data),
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

      Query foodQuery = _firestore.collection('Foods');

      if (storeId != null) {
        foodQuery = foodQuery.where('store_id', isEqualTo: storeId);
      }

      if (categoryId != null) {
        foodQuery = foodQuery.where('category_id', isEqualTo: categoryId);
      }

      final snapshot = await foodQuery.get();

      final foods = snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final description = (data['description'] ?? '')
                .toString()
                .toLowerCase();
            return name.contains(query.toLowerCase()) ||
                description.contains(query.toLowerCase());
          })
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return FoodItem.fromMap(data, docId: doc.id);
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
          .collection('Foods')
          .where('category_id', isEqualTo: categoryId)
          .where('is_available', isEqualTo: true);

      if (storeId != null) {
        query = query.where('store_id', isEqualTo: storeId);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return FoodItem.fromMap(data, docId: doc.id);
      }).toList();
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
          .collection('Foods')
          .where('price', isGreaterThanOrEqualTo: minPrice)
          .where('price', isLessThanOrEqualTo: maxPrice);

      if (storeId != null) {
        query = query.where('store_id', isEqualTo: storeId);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return FoodItem.fromMap(data, docId: doc.id);
          })
          .where((f) => f.isAvailable) // Lọc thủ công để tránh lỗi index
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
          .collection('Foods')
          .where('avgRating', isGreaterThanOrEqualTo: minRating);

      if (storeId != null) {
        query = query.where('store_id', isEqualTo: storeId);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return FoodItem.fromMap(data, docId: doc.id);
          })
          .where((f) => f.isAvailable) // Lọc thủ công để tránh lỗi index
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
          .collection('Foods')
          .where('store_id', isEqualTo: storeId)
          .where('is_available', isEqualTo: true)
          .get();

      final foods = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString().toLowerCase();
            return name.contains(query.toLowerCase());
          })
          .map((doc) {
            return FoodItem.fromMap(doc.data(), docId: doc.id);
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
          .collection('Foods')
          .orderBy('avgRating', descending: true)
          .orderBy('totalRatings', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) {
            return FoodItem.fromMap(doc.data(), docId: doc.id);
          })
          .where((f) => f.isAvailable) // Lọc thủ công để tránh lỗi index
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Gợi ý mới nhất
  Future<List<FoodItem>> getNewestFoods({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('Foods')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) {
            return FoodItem.fromMap(doc.data(), docId: doc.id);
          })
          .where((f) => f.isAvailable) // Lọc thủ công để tránh lỗi index
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  double _parseLat(dynamic pos) {
    if (pos is GeoPoint) return pos.latitude;
    if (pos is Map) {
      final lat = pos['latitude'];
      if (lat is num) return lat.toDouble();
      if (lat is String) return double.tryParse(lat.trim()) ?? 0.0;
    }
    if (pos is String) {
      // Handle the case where position is saved as "[10.776 N, 106.700 E]"
      final match = RegExp(r"\[([\d.]+)\s*N").firstMatch(pos);
      if (match != null) return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  double _parseLon(dynamic pos) {
    if (pos is GeoPoint) return pos.longitude;
    if (pos is Map) {
      final lon = pos['longitude'];
      if (lon is num) return lon.toDouble();
      if (lon is String) return double.tryParse(lon.trim()) ?? 0.0;
    }
    if (pos is String) {
      // Handle the case where position is saved as "[10.776 N, 106.700 E]"
      final match = RegExp(r",\s*([\d.]+)\s*E").firstMatch(pos);
      if (match != null) return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  String _asTrimmedText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0.0;
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? 0;
  }

  Map<String, dynamic> _extractStoreInfoMap(Map<String, dynamic> data) {
    final info = data['storeInfo'] ?? data['store_info'];
    if (info is List && info.isNotEmpty && info.first is Map) {
      return Map<String, dynamic>.from(info.first as Map);
    }
    if (info is Map) {
      return Map<String, dynamic>.from(info);
    }
    return const <String, dynamic>{};
  }

  double _extractStoreRating(Map<String, dynamic> data) {
    final rootCandidate =
        data['avgRating'] ??
        data['avg_rating'] ??
        data['rating'] ??
        data['stars'] ??
        data['storeRating'];
    final rootRating = _asDouble(rootCandidate);
    if (rootRating > 0) return rootRating;

    final storeInfo = _extractStoreInfoMap(data);
    final nestedCandidate =
        storeInfo['avgRating'] ??
        storeInfo['avg_rating'] ??
        storeInfo['rating'] ??
        storeInfo['stars'];
    final nestedRating = _asDouble(nestedCandidate);
    return nestedRating;
  }

  int _extractTotalRatings(Map<String, dynamic> data) {
    final rootCandidate =
        data['totalRatings'] ?? data['total_ratings'] ?? data['ratingCount'];
    final rootCount = _asInt(rootCandidate);
    if (rootCount > 0) return rootCount;

    final storeInfo = _extractStoreInfoMap(data);
    final nestedCandidate =
        storeInfo['totalRatings'] ??
        storeInfo['total_ratings'] ??
        storeInfo['ratingCount'];
    return _asInt(nestedCandidate);
  }

  String _extractStoreImageUrl(Map<String, dynamic> data) {
    final rootImage = _asTrimmedText(
      data['image_url'] ?? data['imageUrl'] ?? data['storeImage'],
    );
    if (rootImage.isNotEmpty) return rootImage;

    final info = data['storeInfo'] ?? data['store_info'];
    if (info is Map) {
      return _asTrimmedText(
        info['image_url'] ?? info['imageUrl'] ?? info['storeImage'],
      );
    }
    return '';
  }
}
