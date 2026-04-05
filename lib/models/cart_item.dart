class CartItem {
  final String cartItemId;
  final String foodId;
  final String foodName;
  final double price;
  int quantity;
  final Map<String, String>? selectedOptions;
  final String storeId;
  final String? storeName;

  CartItem({
    required this.cartItemId,
    required this.foodId,
    required this.foodName,
    required this.price,
    required this.quantity,
    required this.storeId,
    this.selectedOptions,
    this.storeName,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'cartItemId': cartItemId,
      'foodId': foodId,
      'foodName': foodName,
      'price': price,
      'quantity': quantity,
      'selectedOptions': selectedOptions,
      'storeId': storeId,
      'storeName': storeName,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      cartItemId: map['cartItemId'] as String,
      foodId: map['foodId'] as String,
      foodName: map['foodName'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      storeId: map['storeId'] as String,
      selectedOptions: map['selectedOptions'] as Map<String, String>?,
      storeName: map['storeName'] as String?,
    );
  }

  CartItem copyWith({
    String? cartItemId,
    String? foodId,
    String? foodName,
    double? price,
    int? quantity,
    Map<String, String>? selectedOptions,
    String? storeId,
    String? storeName,
  }) {
    return CartItem(
      cartItemId: cartItemId ?? this.cartItemId,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      storeId: storeId ?? this.storeId,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      storeName: storeName ?? this.storeName,
    );
  }
}
