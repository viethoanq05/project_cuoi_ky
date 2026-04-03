import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const String _usersCollection = 'Users';
  static const String _userNamesCollection = 'Usernames';

  static const Map<String, dynamic> _defaultDriverInfo = <String, dynamic>{
    'biensoxe': '',
    'is_online': false,
    'status': 'offline',
  };

  static const Map<String, dynamic> _defaultStoreInfo = <String, dynamic>{
    'is_open': false,
    'rating': 0,
  };

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  AppUser? _currentUser;
  bool _isRegistering = false;

  AppUser? get currentUser => _currentUser;
  bool get isRegistering => _isRegistering;

  Future<void> init() async {
    _authSubscription ??= _auth.authStateChanges().listen(_onAuthChanged);
    await _attachUserListener(_auth.currentUser);
  }

  Future<String?> login({
    required String userName,
    required String password,
  }) async {
    final trimmedUserName = userName.trim();
    if (trimmedUserName.isEmpty) {
      return 'Nhap user name';
    }

    try {
      String? email = await _findEmailByUserName(trimmedUserName);
      if ((email == null || email.isEmpty) && trimmedUserName.contains('@')) {
        email = trimmedUserName;
      }

      if (email == null || email.isEmpty) {
        return 'Sai user name hoac mat khau.';
      }

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await _ensureUserNameIndexForCurrentUser(
        preferredUserName: trimmedUserName,
        preferredEmail: email.trim(),
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'Da xay ra loi, vui long thu lai: $e';
    }
  }

  Future<String?> register({
    required String userName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final trimmedUserName = userName.trim();
    if (trimmedUserName.isEmpty) {
      return 'Nhap user name';
    }
    if (trimmedUserName.length < 3) {
      return 'User name toi thieu 3 ky tu';
    }

    final trimmedEmail = email.trim();

    _isRegistering = true;
    notifyListeners();

    try {
      final existedEmail = await _findEmailByUserName(trimmedUserName);
      if (existedEmail != null) {
        return 'User name da ton tai.';
      }

      final credentials = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = credentials.user;
      if (user == null) {
        return 'Khong tao duoc tai khoan, vui long thu lai.';
      }

      final uid = user.uid;
      final roleValue = _roleValue(role);

      final payload = <String, dynamic>{
        'id': uid,
        'user_id': uid,
        'user_name': trimmedUserName,
        'email': trimmedEmail,
        'role': roleValue,
        'created_at': Timestamp.now(),
        'fullName': '',
        'phone': '',
        'address': '',
        'position': '',
        'wallet_balance': 0,
        'profile_completed': false,
        ..._roleSpecificPayload(role),
      };

      await _firestore.collection(_usersCollection).doc(uid).set(payload);
      await _upsertUserNameIndex(
        uid: uid,
        userName: trimmedUserName,
        email: trimmedEmail,
      );

      await _auth.signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } on FirebaseException catch (e) {
      return e.message ?? 'Khong tao duoc tai khoan, vui long thu lai.';
    } catch (e) {
      return 'Khong tao duoc tai khoan, vui long thu lai: $e';
    } finally {
      if (_isRegistering) {
        _isRegistering = false;
        notifyListeners();
      }
    }
  }

  Future<String?> updateProfileInfo({
    required String fullName,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return 'Ban chua dang nhap.';
    }

    try {
      final payload = <String, dynamic>{
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'profile_completed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .update(payload);
      _updateCurrentUserLocal(
        fullName: fullName.trim(),
        phone: phone.trim(),
        profileCompleted: true,
      );
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Khong the luu thong tin.';
    } catch (e) {
      return 'Khong the luu thong tin: $e';
    }
  }

  Future<String?> updateCurrentLocationInfo({
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return 'Ban chua dang nhap.';
    }

    try {
      final pos =
          '[${latitude.toStringAsFixed(5)} N, ${longitude.toStringAsFixed(5)} E]';

      final payload = <String, dynamic>{
        'address': address.trim(),
        'position': pos,
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .update(payload);
      _updateCurrentUserLocal(
        address: address.trim(),
        position: {'latitude': latitude, 'longitude': longitude},
      );
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Khong the cap nhat vi tri.';
    } catch (e) {
      return 'Khong the cap nhat vi tri: $e';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<String?> updateStoreOpenStatus(bool isOpen) async {
    final user = _auth.currentUser;
    if (user == null) {
      return 'Ban chua dang nhap.';
    }

    try {
      final docRef = _firestore.collection(_usersCollection).doc(user.uid);

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final data = snap.data() ?? <String, dynamic>{};

        final storeInfoList = _normalizeStoreInfoList(data['store_info']);
        if (storeInfoList.isEmpty) {
          storeInfoList.add(<String, dynamic>{..._defaultStoreInfo});
        }

        final first = <String, dynamic>{...storeInfoList.first};
        first['is_open'] = isOpen;
        first['rating'] ??= _defaultStoreInfo['rating'];
        storeInfoList[0] = first;

        tx.update(docRef, <String, dynamic>{
          'store_info': storeInfoList,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      _updateCurrentUserLocal(isStoreOpen: isOpen);
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Khong cap nhat duoc trang thai cua hang.';
    } catch (e) {
      return 'Khong cap nhat duoc trang thai cua hang: $e';
    }
  }

  Future<bool> needsProfileCompletion() async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    try {
      final snap = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();
      final data = snap.data();
      if (data == null) {
        return true;
      }

      final fullName = _asTrimmedString(data['fullName']);
      final phone = _asTrimmedString(data['phone']);
      final role = UserRoleDisplay.fromAny(data['role']);

      if (fullName.isEmpty || phone.isEmpty) {
        return true;
      }

      if (role == UserRole.driver && data['driver_info'] is! Map) {
        return true;
      }

      if (role == UserRole.store && !_hasValidStoreInfo(data['store_info'])) {
        return true;
      }

      return false;
    } catch (_) {
      return true;
    }
  }

  void _onAuthChanged(User? user) {
    unawaited(_attachUserListener(user));
  }

  Future<void> _attachUserListener(User? user) async {
    await _userSubscription?.cancel();
    _userSubscription = null;

    if (user == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    final docRef = _firestore.collection(_usersCollection).doc(user.uid);
    _userSubscription = docRef.snapshots().listen(
      (snap) {
        _currentUser = _buildAppUserFromFirestore(
          user: user,
          data: snap.data(),
        );
        notifyListeners();
      },
      onError: (_) {
        _currentUser = _buildAppUserFromFirestore(user: user, data: null);
        notifyListeners();
      },
    );
  }

  AppUser _buildAppUserFromFirestore({
    required User user,
    required Map<String, dynamic>? data,
  }) {
    final roleKey = _asTrimmedString(data?['role']).isNotEmpty
        ? _asTrimmedString(data?['role'])
        : 'Customer';

    final userName = _asTrimmedString(data?['user_name']).isNotEmpty
        ? _asTrimmedString(data?['user_name'])
        : _asTrimmedString(data?['userName']);

    final fullName = _asTrimmedString(data?['fullName']);
    final phone = _asTrimmedString(data?['phone']);
    final address = _asTrimmedString(data?['address']).isNotEmpty
        ? _asTrimmedString(data?['address'])
        : _asTrimmedString(data?['location']);
    final position = _asPositionMap(data?['position']);
    final profileCompleted = _asBool(data?['profile_completed']);

    bool isStoreOpen = false;
    final storeInfo = _normalizeStoreInfoList(data?['store_info']);
    if (storeInfo.isNotEmpty) {
      isStoreOpen = _asBool(storeInfo.first['is_open']);
    }

    return AppUser(
      email: user.email?.trim() ?? _asTrimmedString(data?['email']),
      role: UserRoleDisplay.fromKey(roleKey),
      userName: userName,
      fullName: fullName,
      phone: phone,
      address: address,
      position: position,
      profileCompleted: profileCompleted,
      isStoreOpen: isStoreOpen,
    );
  }

  Future<void> _ensureUserNameIndexForCurrentUser({
    String? preferredUserName,
    String? preferredEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final snap = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();
      final data = snap.data();

      final storedUserName = _asTrimmedString(data?['user_name']).isNotEmpty
          ? _asTrimmedString(data?['user_name'])
          : (_asTrimmedString(data?['userName']).isNotEmpty
                ? _asTrimmedString(data?['userName'])
                : (preferredUserName ?? ''));
      final userName = storedUserName.trim();

      final email = _asTrimmedString(data?['email']).isNotEmpty
          ? _asTrimmedString(data?['email'])
          : (preferredEmail ?? user.email?.trim() ?? '');

      if (userName.isEmpty || email.isEmpty) {
        return;
      }

      await _upsertUserNameIndex(
        uid: user.uid,
        userName: userName,
        email: email,
      );
    } catch (_) {
      // Keep login success even if index backfill fails.
    }
  }

  Future<String?> _findEmailByUserName(String userName) async {
    final normalized = _normalizeUserName(userName);
    if (normalized.isEmpty) {
      return null;
    }

    try {
      final snap = await _firestore
          .collection(_userNamesCollection)
          .doc(normalized)
          .get();
      final email = _asTrimmedString(snap.data()?['email']);
      if (email.isEmpty) {
        return null;
      }
      return email;
    } catch (_) {
      return null;
    }
  }

  Future<void> _upsertUserNameIndex({
    required String uid,
    required String userName,
    required String email,
  }) async {
    final normalized = _normalizeUserName(userName);
    if (normalized.isEmpty) {
      return;
    }

    final docRef = _firestore.collection(_userNamesCollection).doc(normalized);
    try {
      await docRef.set(<String, dynamic>{
        'user_id': uid,
        'user_name': userName.trim(),
        'user_name_norm': normalized,
        'email': email.trim(),
      });
    } on FirebaseException {
      // Ignore (e.g., doc belongs to another user due to rules).
    }
  }

  void _updateCurrentUserLocal({
    String? fullName,
    String? phone,
    String? address,
    Map<String, double>? position,
    bool? profileCompleted,
    bool? isStoreOpen,
  }) {
    final existing = _currentUser;
    if (existing == null) {
      return;
    }

    _currentUser = AppUser(
      email: existing.email,
      role: existing.role,
      userName: existing.userName,
      fullName: fullName ?? existing.fullName,
      phone: phone ?? existing.phone,
      address: address ?? existing.address,
      position: position ?? existing.position,
      profileCompleted: profileCompleted ?? existing.profileCompleted,
      isStoreOpen: isStoreOpen ?? existing.isStoreOpen,
    );
    notifyListeners();
  }

  String _normalizeUserName(String value) {
    return value.trim().toLowerCase();
  }

  String _roleValue(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.store:
        return 'Store';
      case UserRole.driver:
        return 'Driver';
    }
  }

  Map<String, dynamic> _roleSpecificPayload(UserRole role) {
    if (role == UserRole.driver) {
      return <String, dynamic>{'driver_info': _defaultDriverInfo};
    }

    if (role == UserRole.store) {
      return <String, dynamic>{
        'store_info': <Map<String, dynamic>>[
          <String, dynamic>{..._defaultStoreInfo},
        ],
      };
    }

    return const <String, dynamic>{};
  }

  bool _hasValidStoreInfo(dynamic value) {
    final list = _normalizeStoreInfoList(value);
    if (list.isEmpty) {
      return false;
    }

    final first = list.first;
    return first.containsKey('is_open') && first.containsKey('rating');
  }

  List<Map<String, dynamic>> _normalizeStoreInfoList(dynamic value) {
    final result = <Map<String, dynamic>>[];

    if (value is List) {
      for (final item in value) {
        if (item is Map<String, dynamic>) {
          result.add(<String, dynamic>{...item});
          continue;
        }

        if (item is Map) {
          final normalized = <String, dynamic>{};
          for (final entry in item.entries) {
            normalized[entry.key.toString()] = entry.value;
          }
          result.add(normalized);
        }
      }
      return result;
    }

    if (value is Map<String, dynamic>) {
      return <Map<String, dynamic>>[
        <String, dynamic>{...value},
      ];
    }

    if (value is Map) {
      final normalized = <String, dynamic>{};
      for (final entry in value.entries) {
        normalized[entry.key.toString()] = entry.value;
      }
      return <Map<String, dynamic>>[normalized];
    }

    return result;
  }

  String _asTrimmedString(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value.trim();
    }
    return value.toString().trim();
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  Map<String, double>? _asPositionMap(dynamic value) {
    if (value == null) return null;

    if (value is GeoPoint) {
      return {
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }

    if (value is Map) {
      try {
        final lat = value['latitude'];
        final lon = value['longitude'];
        return {
          'latitude': (lat is num) ? lat.toDouble() : double.parse(lat.toString()),
          'longitude': (lon is num) ? lon.toDouble() : double.parse(lon.toString()),
        };
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Vui lòng kiểm tra Wifi/4G hoặc cấu hình DNS trên giả lập.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Sai user name hoac mat khau.';
      case 'invalid-email':
        return 'Email khong hop le.';
      case 'email-already-in-use':
        return 'Email da duoc su dung.';
      case 'weak-password':
        return 'Mat khau toi thieu 6 ky tu.';
      default:
        return e.message ?? 'Da xay ra loi, vui long thu lai.';
    }
  }
}
