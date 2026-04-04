import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Firebase options inline
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyDGxIS_XJqpbl-IwKR0I7gqNlJZvGouWWs',
      appId: '1:395193582854:web:16a872c4c92b77d3a54a87',
      messagingSenderId: '395193582854',
      projectId: 'project-cuoi-ky-595c4',
      authDomain: 'project-cuoi-ky-595c4.firebaseapp.com',
      storageBucket: 'project-cuoi-ky-595c4.firebasestorage.app',
      measurementId: 'G-M2XDR3M0CP',
    );
  }
}

void main() async {
  print('Starting Firebase initialization...');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Firebase initialized successfully');

  final seeder = SampleOrderSeeder();
  await seeder.seedSampleOrders();

  print('Seeding completed!');
}

class SampleOrderSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> seedSampleOrders() async {
    try {
      // Sample user ID - replace with actual user ID when testing
      const String sampleUserId = 'sample_user_123';
      const String sampleUserName = 'samplecustomer';
      const String sampleUserEmail = 'samplecustomer@example.com';
      const String samplePassword = 'test123456';

      // Sample store IDs - these should exist in your Firestore
      const String store1Id = 'store_1';
      const String store2Id = 'store_2';

      // Create Firebase Auth user
      try {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: sampleUserEmail,
          password: samplePassword,
        );
        print('Created Firebase Auth user: ${userCredential.user?.uid}');
      } catch (e) {
        print('Auth user might already exist: $e');
        // Try to sign in to check if exists
        try {
          await _auth.signInWithEmailAndPassword(
            email: sampleUserEmail,
            password: samplePassword,
          );
          await _auth.signOut();
          print('Auth user already exists');
        } catch (signInError) {
          print('Failed to create or verify auth user: $signInError');
          rethrow;
        }
      }

      // Create sample customer profile
      await _firestore.collection('Users').doc(sampleUserId).set({
        'id': sampleUserId,
        'user_id': sampleUserId,
        'user_name': sampleUserName,
        'email': sampleUserEmail,
        'role': 'Customer',
        'created_at': DateTime.now().toIso8601String(),
        'fullName': 'Sample Customer',
        'phone': '0901234567',
        'address': '123 Đường ABC, Quận 1, TP.HCM',
        'position': {'latitude': 10.77653, 'longitude': 106.70098},
        'wallet_balance': 250000,
        'profile_completed': true,
      });
      await _firestore.collection('Usernames').doc(sampleUserName.toLowerCase()).set({
        'user_id': sampleUserId,
        'user_name': sampleUserName,
        'user_name_norm': sampleUserName.toLowerCase(),
        'email': sampleUserEmail,
      });

      print('Test account credentials:');
      print('Username: $sampleUserName');
      print('Email: $sampleUserEmail');
      print('Password: $samplePassword');

      // Create sample stores
      await _firestore.collection('Users').doc(store1Id).set({
        'id': store1Id,
        'user_id': store1Id,
        'user_name': 'viet_restaurant',
        'email': 'viet_restaurant@example.com',
        'role': 'Store',
        'created_at': DateTime.now().toIso8601String(),
        'fullName': 'Nhà Hàng Việt Nam',
        'phone': '0902223333',
        'address': '50 Đường 1, Quận 1, TP.HCM',
        'store_info': [
          {'is_open': true, 'rating': 4.7},
        ],
      });
      await _firestore.collection('Usernames').doc('viet_restaurant').set({
        'user_id': store1Id,
        'user_name': 'viet_restaurant',
        'user_name_norm': 'viet_restaurant',
        'email': 'viet_restaurant@example.com',
      });

      await _firestore.collection('Users').doc(store2Id).set({
        'id': store2Id,
        'user_id': store2Id,
        'user_name': 'pizza_hut',
        'email': 'pizza_hut@example.com',
        'role': 'Store',
        'created_at': DateTime.now().toIso8601String(),
        'fullName': 'Pizza Hut',
        'phone': '0904445555',
        'address': '200 Đường 2, Quận 2, TP.HCM',
        'store_info': [
          {'is_open': true, 'rating': 4.5},
        ],
      });
      await _firestore.collection('Usernames').doc('pizza_hut').set({
        'user_id': store2Id,
        'user_name': 'pizza_hut',
        'user_name_norm': 'pizza_hut',
        'email': 'pizza_hut@example.com',
      });
      await _firestore.collection('Users').doc(store1Id).set({
        'id': store1Id,
        'user_id': store1Id,
        'user_name': 'viet_restaurant',
        'email': 'viet_restaurant@example.com',
        'role': 'Store',
        'created_at': DateTime.now().toIso8601String(),
        'fullName': 'Nhà Hàng Việt Nam',
        'phone': '0902223333',
        'address': '50 Đường 1, Quận 1, TP.HCM',
        'store_info': [
          {'is_open': true, 'rating': 4.7},
        ],
      });
      await _firestore.collection('Usernames').doc('viet_restaurant').set({
        'user_id': store1Id,
        'user_name': 'viet_restaurant',
        'user_name_norm': 'viet_restaurant',
        'email': 'viet_restaurant@example.com',
      });

      await _firestore.collection('Users').doc(store2Id).set({
        'id': store2Id,
        'user_id': store2Id,
        'user_name': 'pizza_hut',
        'email': 'pizza_hut@example.com',
        'role': 'Store',
        'created_at': DateTime.now().toIso8601String(),
        'fullName': 'Pizza Hut',
        'phone': '0904445555',
        'address': '200 Đường 2, Quận 2, TP.HCM',
        'store_info': [
          {'is_open': true, 'rating': 4.5},
        ],
      });
      await _firestore.collection('Usernames').doc('pizza_hut').set({
        'user_id': store2Id,
        'user_name': 'pizza_hut',
        'user_name_norm': 'pizza_hut',
        'email': 'pizza_hut@example.com',
      });

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