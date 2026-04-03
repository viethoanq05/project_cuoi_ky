import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'Categories';

  Future<List<Category>> getAllCategories() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('displayOrder')
          .get();

      if (snapshot.docs.isEmpty) {
        return _getDefaultCategories();
      }

      return snapshot.docs.map((doc) => Category.fromMap({
        ...doc.data(),
        'categoryId': doc.id,
      })).toList();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return _getDefaultCategories();
    }
  }

  List<Category> _getDefaultCategories() {
    return [
      Category(categoryId: 'com', storeId: 'system', name: 'Cơm', displayOrder: 1, icon: 'lunch_dining'),
      Category(categoryId: 'mi', storeId: 'system', name: 'Mì', displayOrder: 2, icon: 'ramen_dining'),
      Category(categoryId: 'banh', storeId: 'system', name: 'Bánh', displayOrder: 3, icon: 'bakery_dining'),
      Category(categoryId: 'nuoc', storeId: 'system', name: 'Đồ uống', displayOrder: 4, icon: 'local_drink'),
      Category(categoryId: 'trangmieng', storeId: 'system', name: 'Tráng miệng', displayOrder: 5, icon: 'icecream'),
    ];
  }

  IconData getIconData(String? iconName) {
    switch (iconName) {
      case 'lunch_dining': return Icons.lunch_dining;
      case 'ramen_dining': return Icons.ramen_dining;
      case 'bakery_dining': return Icons.bakery_dining;
      case 'local_drink': return Icons.local_drink;
      case 'icecream': return Icons.icecream;
      case 'fastfood': return Icons.fastfood;
      case 'breakfast_dining': return Icons.breakfast_dining;
      case 'dinner_dining': return Icons.dinner_dining;
      default: return Icons.restaurant;
    }
  }

  Color getCategoryColor(String name) {
    switch (name.toLowerCase()) {
      case 'cơm': return Colors.orange.shade100;
      case 'mì': return Colors.yellow.shade100;
      case 'bánh': return Colors.brown.shade100;
      case 'đồ uống': return Colors.blue.shade100;
      case 'tráng miệng': return Colors.pink.shade100;
      default: return Colors.green.shade100;
    }
  }
}
