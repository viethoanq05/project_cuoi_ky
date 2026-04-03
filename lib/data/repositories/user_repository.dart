import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/user_repository_interface.dart';
import '../datasources/firestore_datasource.dart';

class UserRepository implements UserRepositoryInterface {
  final FirestoreDatasource _datasource;

  UserRepository({required FirestoreDatasource datasource})
      : _datasource = datasource;

  @override
  Future<UserProfileEntity> getUserProfile(String userId) async {
    try {
      final model = await _datasource.getUserProfile(userId);
      return model.toEntity();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<UserProfileEntity?> watchUserProfile(String userId) {
    return _datasource.watchUserProfile(userId).map((model) {
      if (model != null) {
        return model.toEntity();
      }
      return null;
    });
  }

  @override
  Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String phone,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _datasource.updateUserProfile(
        userId: userId,
        name: name,
        phone: phone,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> validateWalletBalance(String userId, double amount) async {
    try {
      return await _datasource.validateWalletBalance(userId, amount);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> deductWalletBalance(String userId, double amount) async {
    try {
      await _datasource.deductWalletBalance(userId, amount);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> addWalletBalance(String userId, double amount) async {
    try {
      await _datasource.addWalletBalance(userId, amount);
    } catch (e) {
      rethrow;
    }
  }
}
