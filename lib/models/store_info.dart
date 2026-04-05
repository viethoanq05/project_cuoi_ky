class StoreInfo {
  final String storeId;
  final String storeOwnerId;
  final String storeName;
  final String? storeImage;
  final double latitude;
  final double longitude;
  final String address;
  final String phone;
  final double? rating;
  final int? totalRatings;
  final bool isOpen;
  final String? openingHours;
  final bool acceptsScheduling;
  final double? distance; // Khoảng cách tính từ vị trí hiện tại (km)
  final String? weatherCondition; // Gợi ý dựa trên thời tiết
  final double? deliveryFee;
  final int? estimatedDeliveryTime; // Phút

  StoreInfo({
    required this.storeId,
    required this.storeOwnerId,
    required this.storeName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.phone,
    this.storeImage,
    this.rating,
    this.totalRatings,
    this.isOpen = true,
    this.openingHours,
    this.acceptsScheduling = true,
    this.distance,
    this.weatherCondition,
    this.deliveryFee,
    this.estimatedDeliveryTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'storeOwnerId': storeOwnerId,
      'storeName': storeName,
      'storeImage': storeImage,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'phone': phone,
      'rating': rating,
      'totalRatings': totalRatings,
      'isOpen': isOpen,
      'openingHours': openingHours,
      'acceptsScheduling': acceptsScheduling,
      'distance': distance,
      'weatherCondition': weatherCondition,
      'deliveryFee': deliveryFee,
      'estimatedDeliveryTime': estimatedDeliveryTime,
    };
  }

  factory StoreInfo.fromMap(Map<String, dynamic> map) {
    final rawImage = map['storeImage'] ?? map['image_url'] ?? map['imageUrl'];
    final normalizedImage = rawImage?.toString().trim();

    return StoreInfo(
      storeId: map['storeId'] as String,
      storeOwnerId: map['storeOwnerId'] as String,
      storeName: map['storeName'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'] as String,
      phone: map['phone'] as String,
      storeImage: (normalizedImage != null && normalizedImage.isNotEmpty)
          ? normalizedImage
          : null,
      rating: (map['rating'] as num?)?.toDouble(),
      totalRatings: map['totalRatings'] as int?,
      isOpen: map['isOpen'] as bool? ?? true,
      openingHours: map['openingHours'] as String?,
      acceptsScheduling: map['acceptsScheduling'] as bool? ?? true,
      distance: (map['distance'] as num?)?.toDouble(),
      weatherCondition: map['weatherCondition'] as String?,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble(),
      estimatedDeliveryTime: map['estimatedDeliveryTime'] as int?,
    );
  }

  StoreInfo copyWith({
    double? distance,
    String? weatherCondition,
    double? deliveryFee,
    int? estimatedDeliveryTime,
  }) {
    return StoreInfo(
      storeId: storeId,
      storeOwnerId: storeOwnerId,
      storeName: storeName,
      latitude: latitude,
      longitude: longitude,
      address: address,
      phone: phone,
      storeImage: storeImage,
      rating: rating,
      totalRatings: totalRatings,
      isOpen: isOpen,
      openingHours: openingHours,
      acceptsScheduling: acceptsScheduling,
      distance: distance ?? this.distance,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
    );
  }
}
