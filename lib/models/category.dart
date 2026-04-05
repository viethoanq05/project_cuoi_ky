class Category {
  final String categoryId;
  final String storeId;
  final String name;
  final String? description;
  final String? icon;
  final int displayOrder;
  final bool isActive;

  Category({
    required this.categoryId,
    required this.storeId,
    required this.name,
    this.description,
    this.icon,
    required this.displayOrder,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'storeId': storeId,
      'name': name,
      'description': description,
      'icon': icon,
      'displayOrder': displayOrder,
      'isActive': isActive,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map, {String? docId}) {
    final id =
        (map['category_id']?.toString() ??
                map['categoryId']?.toString() ??
                map['id']?.toString() ??
                docId ??
                '')
            .trim();

    final displayOrderRaw = map['displayOrder'] ?? map['display_order'] ?? 0;
    final resolvedDisplayOrder = displayOrderRaw is num
        ? displayOrderRaw.toInt()
        : int.tryParse(displayOrderRaw.toString()) ?? 0;

    return Category(
      categoryId: id,
      storeId: (map['store_id'] ?? map['storeId'] ?? '').toString().trim(),
      name: (map['name'] ?? map['category_name'] ?? '').toString().trim(),
      description: map['description'] as String?,
      icon: map['icon'] as String?,
      displayOrder: resolvedDisplayOrder,
      isActive: map['isActive'] as bool? ?? map['is_active'] as bool? ?? true,
    );
  }

  Category copyWith({
    String? name,
    String? description,
    String? icon,
    int? displayOrder,
    bool? isActive,
  }) {
    return Category(
      categoryId: categoryId,
      storeId: storeId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}
