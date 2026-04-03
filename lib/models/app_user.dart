import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.email,
    required this.role,
    required this.userName,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.position,
    required this.profileCompleted,
    required bool? isStoreOpen,
    this.walletBalance = 0.0,
    this.bankAccount = '',
  }) : isStoreOpen = isStoreOpen ?? false;

  final String email;
  final UserRole role;
  final String userName;
  final String fullName;
  final String phone;
  final String address;
  final Map<String, double>? position; // {latitude: double, longitude: double}
  final bool profileCompleted;
  final bool isStoreOpen;
  final double walletBalance;
  final String bankAccount;
}
