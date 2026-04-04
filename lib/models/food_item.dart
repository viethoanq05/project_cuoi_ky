class FoodItem {
  const FoodItem({
    required this.foodId,
    required this.storeId,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.image,
    required this.price,
    required this.isAvailable,
    required this.options,
    required this.avgRating,
    required this.totalRatings,
  });

  final String foodId;
  final String storeId;
  final String name;
  final String description;
  final String categoryId;
  final String image;
  final num price;
  final bool isAvailable;
  final Map<String, dynamic> options;
  final num avgRating;
  final int totalRatings;

  factory FoodItem.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawOptions = map['options'];
    final parsedOptions = <String, dynamic>{};
    if (rawOptions is Map) {
      rawOptions.forEach((key, value) {
        parsedOptions[key.toString()] = value;
      });
    } else if (rawOptions is List && rawOptions.isNotEmpty) {
      // Backward compatibility for old list format.
      final first = rawOptions.first;
      if (first is Map) {
        first.forEach((key, value) {
          parsedOptions[key.toString()] = value;
        });
      }
    }

    return FoodItem(
      foodId: _asString(map['food_id']).isNotEmpty
          ? _asString(map['food_id'])
          : (_asString(map['foodId']).isNotEmpty ? _asString(map['foodId']) : (docId ?? '')),
      storeId: _asString(map['store_id']).isNotEmpty
          ? _asString(map['store_id'])
          : _asString(map['storeId']),
      name: _asString(map['name']),
      description: _asString(map['description']),
      categoryId: _asString(map['category_id']).isNotEmpty
          ? _asString(map['category_id'])
          : _asString(map['categoryId']),
      image: _asString(map['image']),
      price: _asNum(map['price']),
      isAvailable: _asBool(map['is_available']) || _asBool(map['isAvailable']),
      options: parsedOptions,
      avgRating: _asNum(map['avg_rating']) != 0 ? _asNum(map['avg_rating']) : _asNum(map['avgRating']),
      totalRatings: _asInt(map['total_ratings']) != 0 ? _asInt(map['total_ratings']) : _asInt(map['totalRatings']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'food_id': foodId,
      'store_id': storeId,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'image': image,
      'price': price,
      'is_available': isAvailable,
      'options': options,
      'avg_rating': avgRating,
      'total_ratings': totalRatings,
    };
  }

  FoodItem copyWith({
    String? foodId,
    String? storeId,
    String? name,
    String? description,
    String? categoryId,
    String? image,
    num? price,
    bool? isAvailable,
    Map<String, dynamic>? options,
    num? avgRating,
    int? totalRatings,
  }) {
    return FoodItem(
      foodId: foodId ?? this.foodId,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      image: image ?? this.image,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      options: options ?? this.options,
      avgRating: avgRating ?? this.avgRating,
      totalRatings: totalRatings ?? this.totalRatings,
    );
  }

  static String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  static num _asNum(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(_asString(value)) ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(_asString(value)) ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    final text = _asString(value).toLowerCase();
    return text == 'true' || text == '1';
  }
}
