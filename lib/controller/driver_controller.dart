import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import 'OrderController.dart';

class DriverController extends ChangeNotifier {
  final OrderController _orderController = OrderController();
  final OrderService _orderService = OrderService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<OrderData> _allOrders = [];
  List<OrderData> _nearbyOrders = [];
  LatLng? _currentLocation;
  double _radiusKm = 5.0;
  bool _isLoading = false;
  bool _updatingStatus = false;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription? _orderSubscription;

  // Getters
  List<OrderData> get nearbyOrders => _nearbyOrders;
  LatLng? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  bool get updatingStatus => _updatingStatus;

  void init() {
    _startLocationTracking();
    _listenToOrders(); // Real-time listener for Firestore changes
  }

  // Lắng nghe Firestore: Tự động cập nhật khi có thay đổi trên server
  void _listenToOrders() {
    _orderSubscription?.cancel();
    _orderSubscription = _orderController.watchAvailableOrders().listen((orders) {
      _allOrders = orders;
      _filterOrders();
    });
  }

  // Lấy vị trí và Load dữ liệu (Đảm bảo luôn kết thúc dù có lỗi)
  Future<void> _fetchCurrentLocationAndLoad() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      // Sử dụng Future.timeout để đảm bảo không bị treo vĩnh viễn (đặc biệt trên Web)
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, 
          timeLimit: Duration(seconds: 8),
        ),
      ).timeout(const Duration(seconds: 10));
      
      _currentLocation = LatLng(position.latitude, position.longitude);
      debugPrint('Vị trí cập nhật: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
    } catch (e) {
      debugPrint('Lỗi hoặc Timeout khi lấy vị trí: $e');
      // Tiếp tục thực hiện lọc đơn hàng dựa trên vị trí cũ hoặc hiện tất cả
    } finally {
      _filterOrders();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Dịch vụ vị trí đang tắt');
        await _fetchCurrentLocationAndLoad(); // Cố gắng load đơn hàng dù không có vị trí
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await _fetchCurrentLocationAndLoad();
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        await _fetchCurrentLocationAndLoad();
        return;
      }
      
      // Load lần đầu khi vào App
      await _fetchCurrentLocationAndLoad();

      // Theo dõi di chuyển Real-time (Cập nhật ngầm)
      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation, 
          distanceFilter: 5
        ),
      ).listen((Position position) {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _filterOrders();
      });
    } catch (e) {
      debugPrint('Lỗi khởi tạo vị trí: $e');
      await _fetchCurrentLocationAndLoad();
    }
  }

  Future<String?> acceptOrder(String orderId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'Chưa đăng nhập';

    try {
      await _orderService.acceptOrder(orderId, uid);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> toggleOnlineStatus(bool currentStatus) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final willBeOnline = !currentStatus;
    _updatingStatus = true;
    notifyListeners();

    try {
      await _firestore.collection('Users').doc(uid).update({
        'driver_info.is_online': willBeOnline,
        'driver_info.status': willBeOnline ? 'online' : 'offline',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Nếu bật nhận đơn, tự động tải dữ liệu
      if (willBeOnline) {
        await _fetchCurrentLocationAndLoad();
      }
    } catch (e) {
      debugPrint('Lỗi cập nhật trạng thái: $e');
    } finally {
      _updatingStatus = false;
      notifyListeners();
    }
  }

  Stream<Map<String, dynamic>?> watchDriverInfo() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _firestore.collection('Users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return data['driver_info'] as Map<String, dynamic>?;
    });
  }

  void _filterOrders() {
    // TẠM THỜI: Hiện tất cả đơn hàng để test
    _nearbyOrders = List.from(_allOrders);
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _orderSubscription?.cancel();
    super.dispose();
  }
}
