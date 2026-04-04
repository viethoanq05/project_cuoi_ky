import 'package:flutter/foundation.dart';
import '../domain/entities/order_entity.dart';

class CartProvider extends ChangeNotifier {
  final List<OrderItemEntity> _items = [];
  String _storeId = '';

  List<OrderItemEntity> get items => _items.toList();
  String get storeId => _storeId;
  int get itemCount => _items.length;
  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + item.subtotal);

  void setStoreId(String storeId) {
    _storeId = storeId;
    notifyListeners();
  }

  void addItem(OrderItemEntity item) {
    final existingIndex =
        _items.indexWhere((element) => element.foodId == item.foodId);

    if (existingIndex != -1) {
      final existingItem = _items[existingIndex];
      _items[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + item.quantity,
        subtotal: existingItem.subtotal + item.subtotal,
      );
    } else {
      _items.add(item);
    }

    notifyListeners();
  }

  void removeItem(String foodId) {
    _items.removeWhere((item) => item.foodId == foodId);
    notifyListeners();
  }

  void updateQuantity(String foodId, int quantity) {
    final index = _items.indexWhere((item) => item.foodId == foodId);
    if (index != -1) {
      final item = _items[index];
      if (quantity <= 0) {
        removeItem(foodId);
      } else {
        final newSubtotal = item.price * quantity;
        _items[index] = item.copyWith(
          quantity: quantity,
          subtotal: newSubtotal,
        );
        notifyListeners();
      }
    }
  }

  void clearCart() {
    _items.clear();
    _storeId = '';
    notifyListeners();
  }

  bool canCheckout() {
    return _items.isNotEmpty && _storeId.isNotEmpty;
  }
}
