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
  }) : isStoreOpen = isStoreOpen ?? false;

  final String email;
  final UserRole role;
  final String userName;
  final String fullName;
  final String phone;
  final String address;
  final String position;
  final bool profileCompleted;
  final bool isStoreOpen;
}
