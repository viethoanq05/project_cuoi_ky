import '../../../domain/entities/user_profile_entity.dart';

class UserProfileModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double walletBalance;
  final double latitude;
  final double longitude;

  UserProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.walletBalance,
    required this.latitude,
    required this.longitude,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'wallet_balance': walletBalance,
      'lat': latitude,
      'lng': longitude,
    };
  }

  UserProfileEntity toEntity() {
    return UserProfileEntity(
      id: id,
      name: name,
      phone: phone,
      address: address,
      walletBalance: walletBalance,
      latitude: latitude,
      longitude: longitude,
    );
  }

  UserProfileModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    double? walletBalance,
    double? latitude,
    double? longitude,
  }) {
    return UserProfileModel(
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
