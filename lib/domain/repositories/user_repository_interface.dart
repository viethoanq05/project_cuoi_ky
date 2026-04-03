import '../entities/user_profile_entity.dart';

abstract class UserRepositoryInterface {
  Future<UserProfileEntity> getUserProfile(String userId);

  Stream<UserProfileEntity?> watchUserProfile(String userId);

  Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String phone,
    required String address,
    required double latitude,
    required double longitude,
  });

  Future<bool> validateWalletBalance(String userId, double amount);

  Future<void> deductWalletBalance(String userId, double amount);

  Future<void> addWalletBalance(String userId, double amount);
}
