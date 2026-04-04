import 'package:cloud_firestore/cloud_firestore.dart';

class SampleOrderSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> seedSampleOrders() async {
    try {
      // Sample user ID - replace with actual user ID when testing
      const String sampleUserId = 'sample_user_123';

      // Sample store IDs - these should exist in your Firestore
      const String store1Id = 'store_1';
      const String store2Id = 'store_2';

      // Sample orders data
      final List<Map<String, dynamic>> sampleOrders = [
        {
          'id': 'order_001_${DateTime.now().millisecondsSinceEpoch}',
          'user_id': sampleUserId,
          'store_id': store1Id,
          'store_name': 'Nhà Hàng Việt Nam',
          'items': [
            {
              'food_id': 'food_1',
              'food_name': 'Cơm tấm sườn',
              'quantity': 2,
              'price': 45000,
              'subtotal': 90000,
            },
            {
              'food_id': 'food_2',
              'food_name': 'Trà đá',
              'quantity': 1,
              'price': 15000,
              'subtotal': 15000,
            },
          ],
          'total_price': 105000,
          'delivery_fee': 15000,
          'status': 'completed',
          'payment_method': 'cod',
          'delivery_address': '123 Đường ABC, Quận 1, TP.HCM',
          'created_at': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
          'updated_at': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(),
          'rating': 5.0,
          'review': 'Món ăn ngon, giao hàng nhanh!',
        },
        {
          'id': 'order_002_${DateTime.now().millisecondsSinceEpoch}',
          'user_id': sampleUserId,
          'store_id': store2Id,
          'store_name': 'Pizza Hut',
          'items': [
            {
              'food_id': 'food_3',
              'food_name': 'Pizza Hải Sản',
              'quantity': 1,
              'price': 120000,
              'subtotal': 120000,
            },
            {
              'food_id': 'food_4',
              'food_name': 'Coca Cola',
              'quantity': 2,
              'price': 20000,
              'subtotal': 40000,
            },
          ],
          'total_price': 160000,
          'delivery_fee': 20000,
          'status': 'completed',
          'payment_method': 'wallet',
          'delivery_address': '456 Đường XYZ, Quận 2, TP.HCM',
          'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
          'updated_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
          'rating': 4.0,
          'review': 'Pizza ngon nhưng hơi mặn.',
        },
        {
          'id': 'order_003_${DateTime.now().millisecondsSinceEpoch}',
          'user_id': sampleUserId,
          'store_id': store1Id,
          'store_name': 'Nhà Hàng Việt Nam',
          'items': [
            {
              'food_id': 'food_5',
              'food_name': 'Phở bò',
              'quantity': 1,
              'price': 40000,
              'subtotal': 40000,
            },
          ],
          'total_price': 55000,
          'delivery_fee': 15000,
          'status': 'completed',
          'payment_method': 'cod',
          'delivery_address': '789 Đường DEF, Quận 3, TP.HCM',
          'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
          'updated_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          'rating': 5.0,
          'review': 'Phở rất ngon, sẽ order lại!',
        },
        {
          'id': 'order_004_${DateTime.now().millisecondsSinceEpoch}',
          'user_id': sampleUserId,
          'store_id': store2Id,
          'store_name': 'Pizza Hut',
          'items': [
            {
              'food_id': 'food_6',
              'food_name': 'Burger Bò',
              'quantity': 1,
              'price': 65000,
              'subtotal': 65000,
            },
            {
              'food_id': 'food_7',
              'food_name': 'Khoai tây chiên',
              'quantity': 1,
              'price': 35000,
              'subtotal': 35000,
            },
          ],
          'total_price': 120000,
          'delivery_fee': 20000,
          'status': 'completed',
          'payment_method': 'wallet',
          'delivery_address': '101 Đường GHI, Quận 4, TP.HCM',
          'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'updated_at': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(),
          'rating': null, // Not reviewed yet
          'review': null,
        },
      ];

      // Add orders to Firestore
      for (final order in sampleOrders) {
        await _firestore.collection('orders').doc(order['id']).set(order);
        print('Added sample order: ${order['id']}');
      }

      print('Successfully seeded ${sampleOrders.length} sample orders');

    } catch (e) {
      print('Error seeding sample orders: $e');
      rethrow;
    }
  }
}