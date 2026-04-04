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
          .get();

      // Lọc và sắp xếp thủ công để tránh lỗi đòi Index (failed-precondition)
      final docs = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['isActive'] == true;
      }).toList();
      
      docs.sort((a, b) {
        final aOrder = (a.data()['displayOrder'] as num?) ?? 0;
        final bOrder = (b.data()['displayOrder'] as num?) ?? 0;
        return aOrder.compareTo(bOrder);
      });

      if (docs.isEmpty) {
        return _getDefaultCategories();
      }

      return docs.map((doc) => Category.fromMap(
        doc.data(),
        docId: doc.id,
      )).toList();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return _getDefaultCategories();
    }
  }

  List<Category> _getDefaultCategories() {
    return [
      Category(categoryId: 'com', storeId: 'system', name: 'Cơm', displayOrder: 1, icon: 'lunch_dining'),
      Category(categoryId: 'bunmipho', storeId: 'system', name: 'Bún, Mì, Phở', displayOrder: 2, icon: 'ramen_dining'),
      Category(categoryId: 'doanvat', storeId: 'system', name: 'Đồ ăn vặt', displayOrder: 3, icon: 'fastfood'),
      Category(categoryId: 'douong', storeId: 'system', name: 'Đồ uống', displayOrder: 4, icon: 'local_drink'),
      Category(categoryId: 'banhmy', storeId: 'system', name: 'Bánh mì', displayOrder: 5, icon: 'bakery_dining'),
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
    final n = name.toLowerCase();
    if (n.contains('cơm')) return Colors.orange.shade100;
    if (n.contains('mì') || n.contains('bún') || n.contains('phở')) return Colors.yellow.shade100;
    if (n.contains('vặt')) return Colors.green.shade100;
    if (n.contains('uống') || n.contains('nước')) return Colors.blue.shade100;
    if (n.contains('bánh')) return Colors.brown.shade100;
    return Colors.green.shade100;
  }
}
