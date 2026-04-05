class CartItem {
  final String cartItemId;
  final String foodId;
  final String foodName;
  final String? foodImage;
  final double price;
  int quantity;
  final Map<String, String>? selectedOptions;
  final String storeId;
  final String? storeName;

  CartItem({
    required this.cartItemId,
    required this.foodId,
    required this.foodName,
    this.foodImage,
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
      'foodImage': foodImage,
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
      foodImage: map['foodImage']?.toString(),
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
    String? foodImage,
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
      foodImage: foodImage ?? this.foodImage,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      storeId: storeId ?? this.storeId,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      storeName: storeName ?? this.storeName,
    );
  }
}
