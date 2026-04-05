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
          .toList();
      items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
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
      return snapshot.docs.map((doc) {
        final item = FoodItem.fromMap(doc.data(), docId: doc.id);
        // Resolve image path to public URL
        return item.copyWith(image: getPublicImageUrl(item.image));
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
  const MenuCategory({required this.id, required this.name});

  final String id;
  final String name;

  String get categoryId => id;

  factory MenuCategory.fromMap(Map<String, dynamic> map, String docId) {
    final resolvedName = _asText(map['name']).isNotEmpty
        ? _asText(map['name'])
        : (_asText(map['category_name']).isNotEmpty
              ? _asText(map['category_name'])
              : docId);

    final resolvedId = _asText(map['category_id']).isNotEmpty
        ? _asText(map['category_id'])
        : (_asText(map['id']).isNotEmpty ? _asText(map['id']) : docId);

    return MenuCategory(id: resolvedId, name: resolvedName);
  }

  static String _asText(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }
}
