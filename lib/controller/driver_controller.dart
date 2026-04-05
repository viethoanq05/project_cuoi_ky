import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
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
  String _currentAddress = 'Đang xác định vị trí...';
  double _radiusKm = 5.0;
  bool _isLoading = false;
  bool _updatingStatus = false;
  int _selectedIndex = 0;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription? _orderSubscription;

  // Getters
  List<OrderData> get nearbyOrders => _nearbyOrders;
  LatLng? get currentLocation => _currentLocation;
  String get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  bool get updatingStatus => _updatingStatus;
  int get selectedIndex => _selectedIndex;

  void init() {
    _startLocationTracking();
    _listenToOrders();
  }

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void _listenToOrders() {
    _orderSubscription?.cancel();
    _orderSubscription = _orderController.watchAvailableOrders().listen((orders) {
      print("CONTROLLER: Nhận được ${orders.length} đơn hàng. Cập nhật Dashboard...");
      _allOrders = orders;
      _filterOrders();
    }, onError: (error) {
      print("CONTROLLER ERROR: Lỗi lắng nghe đơn hàng: $error");
    });
  }

  Future<void> _fetchAddress(double lat, double lng) async {
    try {
      String address = "";
      if (kIsWeb) {
        // Fallback cho Web: Sử dụng Nominatim API
        final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
        final response = await http.get(url, headers: {'Accept-Language': 'vi'});
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          address = data['display_name'] ?? "";
        }
      } else {
        // Mobile: Sử dụng thư viện geocoding native
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          Placemark p = placemarks.first;
          List<String> parts = [];
          if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
          if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) parts.add(p.subAdministrativeArea!);
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) parts.add(p.administrativeArea!);
          address = parts.join(', ');
        }
      }

      if (address.isNotEmpty) {
        _currentAddress = address;
      } else {
        _currentAddress = "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}";
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi lấy địa chỉ: $e');
      _currentAddress = "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}";
      notifyListeners();
    }
  }

  Future<void> _fetchCurrentLocationAndLoad() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      Position? position;
      
      // 1. Thử lấy vị trí cuối cùng được biết (nhanh) - Không hỗ trợ trên Web
      if (!kIsWeb) {
        try {
          position = await Geolocator.getLastKnownPosition();
          if (position != null) {
            _currentLocation = LatLng(position.latitude, position.longitude);
            _fetchAddress(position.latitude, position.longitude);
            _filterOrders();
          }
        } catch (e) {
          debugPrint('Lỗi lấy LastKnownPosition: $e');
        }
      }

      // 2. Thử lấy vị trí hiện tại với độ chính xác vừa phải (nhanh hơn cao)
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium, 
            timeLimit: Duration(seconds: 5),
          ),
        ).timeout(const Duration(seconds: 8));
      } catch (e) {
        // Chỉ log lỗi timeout nếu thực sự chưa có vị trí nào
        if (_currentLocation == null) {
          debugPrint('Thử lấy vị trí Medium bị lỗi/timeout: $e');
          rethrow;
        }
      }

      if (position != null) {
        _currentLocation = LatLng(position.latitude, position.longitude);
        await _fetchAddress(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Lỗi lấy vị trí: $e');
      // Không để app crash hoặc đứng im khi lỗi vị trí
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
        await _fetchCurrentLocationAndLoad();
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
      
      await _fetchCurrentLocationAndLoad();

      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation, 
          distanceFilter: 10
        ),
      ).listen((Position position) {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _fetchAddress(position.latitude, position.longitude);
        _filterOrders();
      });
    } catch (e) {
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
