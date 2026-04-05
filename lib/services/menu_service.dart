import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_item.dart';
import 'supabase_config.dart';

class MenuService {
  MenuService._();

  static final MenuService instance = MenuService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _foodsCollection = 'Foods';
  static const String _categoriesCollection = 'Categories';

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

  Future<
    ({
      Map<String, ({double avg, int count})> foodAgg,
      ({double avg, int count}) storeAgg,
    })
  >
  _computeFoodAggregatesFromReviewsForStore(
    String storeId,
    Set<String> foodIds,
  ) async {
    final reviewSnapshot = await _firestore
        .collection('reviews')
        .where('store_id', isEqualTo: storeId)
        .get();

    final orderRating = <String, double>{};
    double storeSum = 0.0;
    var storeCount = 0;

    for (final doc in reviewSnapshot.docs) {
      final data = doc.data();
      final orderId = _asText(data['order_id']);
      if (orderId.isEmpty) continue;
      final rating = _asDouble(data['rating']);
      if (rating <= 0) continue;
      orderRating[orderId] = rating;
      storeSum += rating;
      storeCount += 1;
    }

    final foodSum = <String, double>{};
    final foodCount = <String, int>{};

    final orderIds = orderRating.keys.toList();
    const chunkSize = 10;
    for (final chunk in _chunks(orderIds, chunkSize)) {
      final ordersSnap = await _firestore
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
          if (!foodIds.contains(foodId)) continue;
          foodSum[foodId] = (foodSum[foodId] ?? 0.0) + rating;
          foodCount[foodId] = (foodCount[foodId] ?? 0) + 1;
        }
      }
    }

    final foodAgg = <String, ({double avg, int count})>{};
    for (final foodId in foodIds) {
      final count = foodCount[foodId] ?? 0;
      final sum = foodSum[foodId] ?? 0.0;
      foodAgg[foodId] = (avg: count > 0 ? (sum / count) : 0.0, count: count);
    }

    return (
      foodAgg: foodAgg,
      storeAgg: (
        avg: storeCount > 0 ? (storeSum / storeCount) : 0.0,
        count: storeCount,
      ),
    );
  }

  Future<void> syncRatingsForStore(String storeId) async {
    if (storeId.trim().isEmpty) return;
    try {
      final foodsSnap = await _firestore
          .collection(_foodsCollection)
          .where('store_id', isEqualTo: storeId)
          .get();

      final foodIds = foodsSnap.docs.map((d) => d.id).toSet();
      final agg = await _computeFoodAggregatesFromReviewsForStore(
        storeId,
        foodIds,
      );

      final batch = _firestore.batch();

      // Store aggregates
      final storeRef = _firestore.collection('Users').doc(storeId);
      batch.set(storeRef, <String, dynamic>{
        'rating': agg.storeAgg.avg,
        'avgRating': agg.storeAgg.avg,
        'avg_rating': agg.storeAgg.avg,
        'totalRatings': agg.storeAgg.count,
        'total_ratings': agg.storeAgg.count,
        'updated_at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final doc in foodsSnap.docs) {
        final foodId = doc.id;
        final a = agg.foodAgg[foodId];
        if (a == null) continue;

        batch.set(doc.reference, <String, dynamic>{
          'avgRating': a.avg,
          'avg_rating': a.avg,
          'rating': a.avg,
          'totalRatings': a.count,
          'total_ratings': a.count,
          'updated_at': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      debugPrint('syncRatingsForStore failed: $e');
    }
  }

  static String getPublicImageUrl(String path) {
    if (path.isEmpty) {
      return '';
    }
    if (path.startsWith('http')) {
      return path;
    }

    try {
      if (Supabase.instance.isInitialized) {
        final storageBucket = SupabaseConfig.instance.storageBucket;
        return Supabase.instance.client.storage
            .from(storageBucket)
            .getPublicUrl(path);
      }
    } catch (_) {
      // Supabase not initialized or other error
    }
    return ''; // Return empty if we can't resolve it (fallback to icon)
  }

  String? get currentStoreId => _auth.currentUser?.uid;

  Stream<List<MenuCategory>> watchCategories() {
    return _firestore.collection(_categoriesCollection).snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs
          .map((doc) => MenuCategory.fromMap(doc.data(), doc.id))
          .where((category) => category.isActive)
          .toList();

      items.sort((a, b) {
        final orderCompare = a.displayOrder.compareTo(b.displayOrder);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return items;
    });
  }

  Stream<List<FoodItem>> watchCurrentStoreFoods({String? storeId}) {
    final finalStoreId = storeId ?? currentStoreId;
    if (finalStoreId == null || finalStoreId.isEmpty) {
      return const Stream<List<FoodItem>>.empty();
    }

    return _firestore
        .collection(_foodsCollection)
        .where('store_id', isEqualTo: finalStoreId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map((doc) {
            final item = FoodItem.fromMap(doc.data(), docId: doc.id);
            // Resolve image path to public URL
            return item.copyWith(image: getPublicImageUrl(item.image));
          }).toList();
          items.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return items;
        });
  }

  Stream<List<FoodItem>> watchStoreFoods(String storeId) {
    if (storeId.isEmpty) {
      return const Stream<List<FoodItem>>.empty();
    }

    return _firestore
        .collection(_foodsCollection)
        .where('store_id', isEqualTo: storeId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map((doc) {
            final item = FoodItem.fromMap(doc.data(), docId: doc.id);
            // Resolve image path to public URL
            return item.copyWith(image: getPublicImageUrl(item.image));
          }).toList();
          items.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return items;
        });
  }

  Future<List<FoodItem>> getAllFoods() async {
    try {
      final snapshot = await _firestore.collection(_foodsCollection).get();
      final foods = snapshot.docs.map((doc) {
        final item = FoodItem.fromMap(doc.data(), docId: doc.id);
        return item.copyWith(image: getPublicImageUrl(item.image));
      }).toList();

      // Compute rating aggregates from source-of-truth reviews + orders.
      final foodsByStore = <String, Set<String>>{};
      for (final food in foods) {
        foodsByStore
            .putIfAbsent(food.storeId, () => <String>{})
            .add(food.foodId);
      }

      final foodAgg = <String, ({double avg, int count})>{};
      for (final entry in foodsByStore.entries) {
        final storeId = entry.key;
        final ids = entry.value;
        final agg = await _computeFoodAggregatesFromReviewsForStore(
          storeId,
          ids,
        );
        foodAgg.addAll(agg.foodAgg);
      }

      return foods.map((food) {
        final a = foodAgg[food.foodId];
        if (a == null) return food;
        return food.copyWith(avgRating: a.avg, totalRatings: a.count);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching all foods: $e');
      return [];
    }
  }

  Future<String?> createFood({
    required String name,
    required String description,
    required String categoryId,
    required String image,
    required num price,
    required Map<String, dynamic> options,
    required bool isAvailable,
  }) async {
    final storeId = currentStoreId;
    if (storeId == null || storeId.isEmpty) {
      return 'Ban chua dang nhap.';
    }

    try {
      final docRef = _firestore.collection(_foodsCollection).doc();
      final food = FoodItem(
        foodId: docRef.id,
        storeId: storeId,
        name: name.trim(),
        description: description.trim(),
        categoryId: categoryId.trim(),
        image: image.trim(),
        price: price,
        isAvailable: isAvailable,
        options: _sanitizeOptions(options),
        avgRating: 0,
        totalRatings: 0,
      );

      await docRef.set(<String, dynamic>{
        ...food.toMap(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseException catch (e) {
      return _errorMessage(e);
    } catch (e) {
      return 'Khong tao duoc mon an: $e';
    }
  }

  Future<String?> updateFood(FoodItem item) async {
    final storeId = currentStoreId;
    if (storeId == null || storeId.isEmpty) {
      return 'Ban chua dang nhap.';
    }

    if (item.storeId != storeId) {
      return 'Ban khong co quyen sua mon an nay.';
    }

    try {
      await _firestore
          .collection(_foodsCollection)
          .doc(item.foodId)
          .set(<String, dynamic>{
            ...item.copyWith(options: _sanitizeOptions(item.options)).toMap(),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      return null;
    } on FirebaseException catch (e) {
      return _errorMessage(e);
    } catch (e) {
      return 'Khong cap nhat duoc mon an: $e';
    }
  }

  Future<String?> toggleAvailability(FoodItem item, bool value) async {
    final updated = item.copyWith(isAvailable: value);
    return updateFood(updated);
  }

  Future<String?> deleteFood(FoodItem item) async {
    final storeId = currentStoreId;
    if (storeId == null || storeId.isEmpty) {
      return 'Ban chua dang nhap.';
    }

    if (item.storeId != storeId) {
      return 'Ban khong co quyen xoa mon an nay.';
    }

    try {
      await _firestore.collection(_foodsCollection).doc(item.foodId).delete();
      return null;
    } on FirebaseException catch (e) {
      return _errorMessage(e);
    } catch (e) {
      return 'Khong xoa duoc mon an: $e';
    }
  }

  Future<String> uploadFoodImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final storeId = currentStoreId;
    if (storeId == null || storeId.isEmpty) {
      throw Exception('Ban chua dang nhap.');
    }

    if (!Supabase.instance.isInitialized) {
      throw StateError(
        'Supabase chua duoc khoi tao. Kiem tra `main()` da goi Supabase.initialize() '
        'va app duoc chay voi --dart-define=SUPABASE_URL=... va --dart-define=SUPABASE_ANON_KEY=....',
      );
    }

    final SupabaseClient supabase = Supabase.instance.client;
    final storageBucket = SupabaseConfig.instance.storageBucket;

    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        'foods/$storeId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await supabase.storage
        .from(storageBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return supabase.storage.from(storageBucket).getPublicUrl(path);
  }

  Map<String, dynamic> _sanitizeOptions(Map<String, dynamic> source) {
    final sanitized = <String, dynamic>{};

    for (final entry in source.entries) {
      final key = entry.key.toString();
      sanitized[key] = entry.value;
    }

    if (!sanitized.containsKey('size')) {
      return sanitized;
    }

    final rawSize = (sanitized['size']?.toString() ?? '').trim().toUpperCase();
    if (rawSize.isEmpty) {
      sanitized.remove('size');
      return sanitized;
    }

    if (!['S', 'M', 'L'].contains(rawSize)) {
      sanitized.remove('size');
      return sanitized;
    }

    sanitized['size'] = rawSize;
    return sanitized;
  }

  String _errorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Khong co quyen thao tac menu (permission-denied).';
      case 'unavailable':
        return 'He thong tam thoi khong kha dung, vui long thu lai.';
      default:
        return 'Firestore error (${e.code}): ${e.message ?? 'unknown'}';
    }
  }
}

class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    this.isActive = true,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final bool isActive;
  final int displayOrder;

  String get categoryId => id;

  factory MenuCategory.fromMap(Map<String, dynamic> map, String docId) {
    final resolvedName = _asText(map['name']).isNotEmpty
        ? _asText(map['name'])
        : (_asText(map['category_name']).isNotEmpty
              ? _asText(map['category_name'])
              : docId);

    final resolvedId = _asText(map['category_id']).isNotEmpty
        ? _asText(map['category_id'])
        : (_asText(map['categoryId']).isNotEmpty
              ? _asText(map['categoryId'])
              : docId);

    final active =
        map['isActive'] as bool? ?? map['is_active'] as bool? ?? true;
    final orderRaw = map['displayOrder'] ?? map['display_order'] ?? 0;
    final displayOrder = orderRaw is num
        ? orderRaw.toInt()
        : int.tryParse(orderRaw.toString()) ?? 0;

    return MenuCategory(
      id: resolvedId,
      name: resolvedName,
      isActive: active,
      displayOrder: displayOrder,
    );
  }

  static String _asText(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }
}
