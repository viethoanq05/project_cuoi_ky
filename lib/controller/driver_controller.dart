import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import 'OrderController.dart';

class DriverController extends ChangeNotifier {
  final OrderController _orderController = OrderController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<OrderData> _allOrders = [];
  List<OrderData> _nearbyOrders = [];
  LatLng? _currentLocation;
  double _radiusKm = 5.0;
  bool _isLoading = false;
  bool _isScanning = false;
  int _scanTimeoutSeconds = 0;
  Timer? _cooldownTimer;
  bool _updatingStatus = false;

  // Getters
  List<OrderData> get nearbyOrders => _nearbyOrders;
  LatLng? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  int get scanTimeoutSeconds => _scanTimeoutSeconds;
  bool get updatingStatus => _updatingStatus;

  StreamSubscription? _orderSubscription;

  void init() {
    _startLocationUpdates();
    _listenToOrders();
  }

  // Chức năng theo dõi đơn hàng
  void _listenToOrders() {
    _orderSubscription?.cancel();
    _orderSubscription = _orderController.watchAvailableOrders().listen((orders) {
      _allOrders = orders;
      _filterOrders();
    });
  }

  // Lấy và cập nhật vị trí
  Future<void> _startLocationUpdates() async {
    _isLoading = true;
    notifyListeners();

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = LatLng(position.latitude, position.longitude);
      _filterOrders();
    } catch (e) {
      debugPrint('Lỗi lấy vị trí: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 100),
    ).listen((position) {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _filterOrders();
    });
  }

  // Quét đơn hàng xung quanh
  Future<void> scanNearbyOrders() async {
    if (_isScanning || _scanTimeoutSeconds > 0) return;

    _isScanning = true;
    notifyListeners();

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = LatLng(position.latitude, position.longitude);
      _filterOrders();
    } catch (e) {
      debugPrint('Lỗi quét đơn: $e');
    }

    _isScanning = false;
    _scanTimeoutSeconds = 5;
    notifyListeners();

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_scanTimeoutSeconds > 0) {
        _scanTimeoutSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  // Bật/Tắt trạng thái Online (Chuyển từ View sang Controller)
  Future<void> toggleOnlineStatus(bool currentStatus) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _updatingStatus = true;
    notifyListeners();

    try {
      await _firestore.collection('Users').doc(uid).update({
        'driver_info.is_online': !currentStatus,
        'driver_info.status': !currentStatus ? 'online' : 'offline',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Lỗi cập nhật trạng thái: $e');
    } finally {
      _updatingStatus = false;
      notifyListeners();
    }
  }

  // Lắng nghe thông tin tài xế từ Firestore
  Stream<Map<String, dynamic>?> watchDriverInfo() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _firestore.collection('Users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      final raw = data['driver_info'];
      if (raw is Map<String, dynamic>) return raw;
      return null;
    });
  }

  // Lọc đơn hàng
  void _filterOrders() {
    if (_currentLocation == null) {
      _nearbyOrders = [];
    } else {
      _nearbyOrders = _orderController.filterOrdersByLocation(
        orders: _allOrders,
        currentPosition: _currentLocation!,
        radiusInKm: _radiusKm,
      );
    }
    notifyListeners();
  }

  void logout() {
    AuthService.instance.logout();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
