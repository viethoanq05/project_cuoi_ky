class UserProfileEntity {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double walletBalance;
  final double latitude;
  final double longitude;

  UserProfileEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.walletBalance,
    required this.latitude,
    required this.longitude,
  });

  UserProfileEntity copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    double? walletBalance,
    double? latitude,
    double? longitude,
  }) {
    return UserProfileEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      walletBalance: walletBalance ?? this.walletBalance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
