import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/cart_item.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();

  factory CartService() {
    return _instance;
  }

  CartService._internal();

  final Map<String, CartItem> _cartItems = {};
  String? _currentStoreId;
  static const String _prefKey = 'shopping_cart_items';

  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_prefKey);
      if (cartJson != null) {
        final Map<String, dynamic> decoded = json.decode(cartJson);
        _cartItems.clear();
        decoded.forEach((key, value) {
          _cartItems[key] = CartItem.fromMap(value as Map<String, dynamic>);
        });
        if (_cartItems.isNotEmpty) {
          _currentStoreId = _cartItems.values.first.storeId;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart from prefs: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> cartData = {};
      _cartItems.forEach((key, value) {
        cartData[key] = value.toMap();
      });
      await prefs.setString(_prefKey, json.encode(cartData));
    } catch (e) {
      debugPrint('Error saving cart to prefs: $e');
    }
  }

  // Getters
  List<CartItem> get items => _cartItems.values.toList();
  String? get currentStoreId => _currentStoreId;
  int get itemCount => _cartItems.length;

  double get subtotal {
    return _cartItems.values.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get total => subtotal; // Có thể thêm delivery fee, tax sau

  bool get isEmpty => _cartItems.isEmpty;
  bool get isNotEmpty => _cartItems.isNotEmpty;

  // Thêm item vào giỏ
  void addItem({
    required String foodId,
    required String foodName,
    required double price,
    required String storeId,
    required String storeName,
    int quantity = 1,
    Map<String, String>? selectedOptions,
  }) {
    if (_currentStoreId != null && _currentStoreId != storeId) {
      throw Exception('diff_store'); // Trả về mã lỗi cụ thể để UI xử lý
    }

    _currentStoreId = storeId;

    final key = '${foodId}_${selectedOptions.toString()}';
    
    if (_cartItems.containsKey(key)) {
      // Nếu món đã có trong giỏ, tăng số lượng
      _cartItems[key] = _cartItems[key]!.copyWith(
        quantity: _cartItems[key]!.quantity + quantity,
      );
    } else {
      // Thêm mới
      _cartItems[key] = CartItem(
        cartItemId: const Uuid().v4(),
        foodId: foodId,
        foodName: foodName,
        price: price,
        quantity: quantity,
        storeId: storeId,
        storeName: storeName,
        selectedOptions: selectedOptions,
      );
    }

    _saveToPrefs();
    notifyListeners();
  }

  // Cập nhật số lượng
  void updateQuantity(String cartItemId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(cartItemId);
      return;
    }

    final key = _cartItems.keys.firstWhere(
      (k) => _cartItems[k]!.cartItemId == cartItemId,
      orElse: () => '',
    );

    if (key.isNotEmpty && _cartItems.containsKey(key)) {
      _cartItems[key] = _cartItems[key]!.copyWith(quantity: newQuantity);
      _saveToPrefs();
      notifyListeners();
    }
  }

  // Xóa item
  void removeItem(String cartItemId) {
    final key = _cartItems.keys.firstWhere(
      (k) => _cartItems[k]!.cartItemId == cartItemId,
      orElse: () => '',
    );

    if (key.isNotEmpty) {
      _cartItems.remove(key);
      
      if (_cartItems.isEmpty) {
        _currentStoreId = null;
      }
      
      _saveToPrefs();
      notifyListeners();
    }
  }

  // Xóa tất cả
  void clear() {
    _cartItems.clear();
    _currentStoreId = null;
    _saveToPrefs();
    notifyListeners();
  }

  // Lấy item theo ID
  CartItem? getItem(String cartItemId) {
    try {
      return _cartItems.values.firstWhere(
        (item) => item.cartItemId == cartItemId,
      );
    } catch (e) {
      return null;
    }
  }

  // Chuyển đổi giỏ hàng thành Order format
  Map<String, dynamic> toOrderMap() {
    return {
      'items': _cartItems.values.map((item) => {
        'foodId': item.foodId,
        'foodName': item.foodName,
        'price': item.price,
        'quantity': item.quantity,
        'selectedOptions': item.selectedOptions,
      }).toList(),
      'storeId': _currentStoreId,
      'totalAmount': total,
    };
  }
}
