import 'package:flutter/foundation.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/user_repository_interface.dart';

enum UserProfileState { initial, loading, loaded, updating, error }

class UserProfileProvider extends ChangeNotifier {
  final UserRepositoryInterface _userRepository;

  UserProfileProvider({required UserRepositoryInterface userRepository})
      : _userRepository = userRepository;

  UserProfileState _state = UserProfileState.initial;
  UserProfileEntity? _userProfile;
  String _errorMessage = '';

  UserProfileState get state => _state;
  UserProfileEntity? get userProfile => _userProfile;
  String get errorMessage => _errorMessage;

  bool get isLoading => _state == UserProfileState.loading;
  bool get isLoaded => _state == UserProfileState.loaded;
  bool get isUpdating => _state == UserProfileState.updating;
  bool get isError => _state == UserProfileState.error;

  Future<void> loadUserProfile(String userId) async {
    _state = UserProfileState.loading;
    notifyListeners();

    try {
      _userProfile = await _userRepository.getUserProfile(userId);
      _state = UserProfileState.loaded;
      _errorMessage = '';
    } catch (e) {
      _state = UserProfileState.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  void watchUserProfile(String userId) {
    _userRepository.watchUserProfile(userId).listen(
      (profile) {
        _userProfile = profile;
        if (profile != null) {
          _state = UserProfileState.loaded;
          _errorMessage = '';
        } else {
          _state = UserProfileState.error;
          _errorMessage = 'User profile not found';
        }
        notifyListeners();
      },
      onError: (e) {
        _state = UserProfileState.error;
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String phone,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    _state = UserProfileState.updating;
    notifyListeners();

    try {
      // Validation
      if (name.isEmpty || phone.isEmpty || address.isEmpty) {
        _state = UserProfileState.error;
        _errorMessage = 'Name, phone, and address cannot be empty';
        notifyListeners();
        return;
      }

      if (phone.length < 10) {
        _state = UserProfileState.error;
        _errorMessage = 'Phone number must be at least 10 digits';
        notifyListeners();
        return;
      }

      await _userRepository.updateUserProfile(
        userId: userId,
        name: name,
        phone: phone,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );

      // Update local state
      _userProfile = _userProfile!.copyWith(
        name: name,
        phone: phone,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );

      _state = UserProfileState.loaded;
      _errorMessage = '';
    } catch (e) {
      _state = UserProfileState.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  void resetError() {
    if (_userProfile != null) {
      _state = UserProfileState.loaded;
    } else {
      _state = UserProfileState.initial;
    }
    _errorMessage = '';
    notifyListeners();
  }
}
