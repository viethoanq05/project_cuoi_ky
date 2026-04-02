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

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      categoryId: map['categoryId'] as String,
      storeId: map['storeId'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: map['icon'] as String?,
      displayOrder: map['displayOrder'] as int,
      isActive: map['isActive'] as bool? ?? true,
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
