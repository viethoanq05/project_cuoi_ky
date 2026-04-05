import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import '../../models/order.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';

class OrderMapScreen extends StatefulWidget {
  final OrderData order;
  final LatLng? currentLocation;
  final bool isHistory;

  const OrderMapScreen({
    super.key, 
    required this.order, 
    this.currentLocation,
    this.isHistory = false,
  });

  @override
  State<OrderMapScreen> createState() => _OrderMapScreenState();
}

class _OrderMapScreenState extends State<OrderMapScreen> {
  final UserService _userService = UserService();
  final MapController _mapController = MapController();
  
  List<LatLng> _routePoints = [];
  LatLng? _storeLocation;
  LatLng? _deliveryLocation;
  bool _isLoading = true;
  String _primaryDistanceText = "";
  String _secondaryDistanceText = "";
  String _timeEstimateText = "";

  bool get _isRouting => _routePoints.isNotEmpty;

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.toStringAsFixed(0)} m";
    }
    return "${(meters / 1000).toStringAsFixed(1)} km";
  }

  @override
  void initState() {
    super.initState();
    // Khởi tạo nếu có sẵn tọa độ
    if (widget.order.deliveryLat != null && widget.order.deliveryLng != null) {
      _deliveryLocation = LatLng(widget.order.deliveryLat!, widget.order.deliveryLng!);
    }
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    // 1. Phân giải địa chỉ nếu thiếu tọa độ khách hàng
    if (_deliveryLocation == null && widget.order.deliveryAddress != null && widget.order.deliveryAddress!.isNotEmpty) {
      try {
        if (kIsWeb) {
          // Web Geocoding via Nominatim
          final encodedAddr = Uri.encodeComponent(widget.order.deliveryAddress!);
          final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedAddr&format=json&limit=1');
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final List data = json.decode(response.body);
            if (data.isNotEmpty) {
              _deliveryLocation = LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
            }
          }
        } else {
          // Mobile Geocoding via native package
          final List<Location> locations = await locationFromAddress(widget.order.deliveryAddress!);
          if (locations.isNotEmpty) {
            _deliveryLocation = LatLng(locations.first.latitude, locations.first.longitude);
          }
        }
      } catch (e) {
        debugPrint('Lỗi Geocoding địa chỉ khách: $e');
      }
    }

    _storeLocation = await _userService.getUserCoordinates(widget.order.storeId);
    
    // 3. Nếu vẫn không có tọa độ khách hàng, dùng tọa độ mặc định (Hà Nội) hoặc bỏ qua
    if (_deliveryLocation == null) {
      _deliveryLocation = const LatLng(21.028511, 105.804817); // Fallback Hanoi
    }
    
    // 4. Xác định mode hiển thị
    final String status = widget.order.status.toLowerCase();
    final bool isAccepted = widget.order.driverId != null && widget.order.driverId!.isNotEmpty;
    final bool isCompleted = ['delivered', 'cancelled'].contains(status);
    final bool isActive = isAccepted && !isCompleted;
    
    if (widget.isHistory) {
      // 1. Nếu là Lịch sử -> Chế độ Chim bay + Marker
      _calculateDistances();
      _secondaryDistanceText = "";
    } else if (isActive && widget.currentLocation != null) {
      // 2. Nếu là Đơn đang làm -> Chế độ Dẫn đường Me -> Destination
      final bool hasPickedUp = ['on_the_way', 'ready'].contains(status);
      final LatLng destination = hasPickedUp ? _deliveryLocation! : (_storeLocation ?? _deliveryLocation!);
      
      await _getRoute(widget.currentLocation!, destination);
      _primaryDistanceText = "Dẫn đường: $_primaryDistanceText";
      _secondaryDistanceText = hasPickedUp ? "Đã lấy hàng" : "Chưa lấy hàng";
    } else if (_storeLocation != null && _deliveryLocation != null) {
      // 3. Nếu là Đơn chưa nhận (Dashboard) -> Chế độ Lộ trình Store -> Customer
      await _getRoute(_storeLocation!, _deliveryLocation!);
      _primaryDistanceText = "Lộ trình giao: $_primaryDistanceText";
      
      // Tính thêm khoảng cách Tôi -> Shop (chim bay)
      if (widget.currentLocation != null) {
        final dist = const Distance();
        double meters = dist(widget.currentLocation!, _storeLocation!);
        _secondaryDistanceText = "Cách shop: ${_formatDistance(meters)}";
      }
    } else {
      _calculateDistances();
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _fitBounds();
    }
  }

  void _calculateDistances() {
    const Distance distance = Distance();
    
    // Khoảng cách Shop -> Khách
    if (_storeLocation != null && _deliveryLocation != null) {
      double meters = distance(_storeLocation!, _deliveryLocation!);
      _primaryDistanceText = "Lộ trình: ${_formatDistance(meters)}";
    }

    // Khoảng cách Tôi -> Điểm gần nhất (nếu không phải history)
    if (!widget.isHistory && widget.currentLocation != null) {
      if (_storeLocation != null) {
        double meters = distance(widget.currentLocation!, _storeLocation!);
        _secondaryDistanceText = "Đến cửa hàng: ${_formatDistance(meters)}";
      } else if (_deliveryLocation != null) {
        double meters = distance(widget.currentLocation!, _deliveryLocation!);
        _secondaryDistanceText = "Đến khách hàng: ${_formatDistance(meters)}";
      }
    }
  }

  Future<void> _getRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        _routePoints = coordinates.map((c) => LatLng(c[1], c[0])).toList();
        
        double meters = data['routes'][0]['distance'].toDouble();
        double seconds = data['routes'][0]['duration'].toDouble();
        
        _primaryDistanceText = _formatDistance(meters);
        _timeEstimateText = "~ ${(seconds / 60).toStringAsFixed(0)} phút";
      }
    } catch (e) {
      debugPrint("Lỗi lấy đường đi: $e");
    }
  }

  void _fitBounds() {
    List<LatLng> points = [];
    if (_deliveryLocation != null) points.add(_deliveryLocation!);
    if (_storeLocation != null) points.add(_storeLocation!);
    if (_routePoints.isNotEmpty) points.addAll(_routePoints);

    // Nếu không phải history hoặc driver ở gần (trong 10km) thì mới add vị trí hiện tại vào bounds
    if (widget.currentLocation != null) {
      bool shouldIncludeMe = !widget.isHistory;
      if (widget.isHistory && points.isNotEmpty) {
        const dist = Distance();
        double d = dist(widget.currentLocation!, points.first);
        if (d < 10000) shouldIncludeMe = true; // Dưới 10km thì show, xa quá thì thôi để nhìn rõ lộ trình cũ
      }
      if (shouldIncludeMe) points.add(widget.currentLocation!);
    }

    if (points.length > 1) {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(70)));
    } else if (points.length == 1) {
      _mapController.move(points.first, 15);
    }
  }

  Future<void> _openExternalMap() async {
    final status = widget.order.status.toLowerCase();
    final bool hasPickedUp = ['on_the_way', 'ready'].contains(status);
    final LatLng destination = hasPickedUp ? _deliveryLocation! : (_storeLocation ?? _deliveryLocation!);

    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isHistory ? 'Lịch sử di chuyển' : 'Bản đồ chi dẫn'),
        actions: [
          IconButton(
            onPressed: _fitBounds,
            icon: const Icon(Icons.center_focus_strong_rounded),
            tooltip: 'Căn giữa bản đồ',
          ),
          IconButton(
            onPressed: _openExternalMap,
            icon: const Icon(Icons.navigation_rounded),
            tooltip: 'Mở Google Maps',
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.currentLocation ?? _deliveryLocation!,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.project_cuoi_ky',
              ),
              if (_isRouting)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: AppColors.primary,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (widget.currentLocation != null)
                    Marker(
                      point: widget.currentLocation!,
                      width: 50,
                      height: 50,
                      child: _buildLocationMarker(Icons.my_location, Colors.blue, "Tôi"),
                    ),
                  if (_storeLocation != null)
                    Marker(
                      point: _storeLocation!,
                      width: 50,
                      height: 50,
                      child: _buildLocationMarker(Icons.store_rounded, Colors.orange, widget.isHistory ? "Điểm lấy" : "Shop"),
                    ),
                  if (_deliveryLocation != null)
                    Marker(
                      point: _deliveryLocation!,
                      width: 50,
                      height: 50,
                      child: _buildLocationMarker(Icons.person_pin_circle_rounded, Colors.red, widget.isHistory ? "Điểm giao" : "Khách"),
                    ),
                ],
              ),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          
          // Thông tin tóm tắt bên trên
          if (_isRouting && _timeEstimateText.isNotEmpty)
            Positioned(
              top: 16,
              left: 50,
              right: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('Dự kiến: $_timeEstimateText', 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          // Nút focus nhanh (Tôi, Shop, Khách) ở bên phải
          Positioned(
            right: 12,
            top: MediaQuery.of(context).size.height * 0.15,
            child: Column(
              children: [
                if (widget.currentLocation != null)
                  _buildFocusButton(Icons.my_location, Colors.blue, "Tôi", widget.currentLocation!),
                const SizedBox(height: 12),
                if (_storeLocation != null)
                  _buildFocusButton(Icons.store_rounded, Colors.orange, "Shop", _storeLocation!),
                const SizedBox(height: 12),
                if (_deliveryLocation != null)
                  _buildFocusButton(Icons.person_pin_circle_rounded, Colors.red, "Khách", _deliveryLocation!),
              ],
            ),
          ),

          // Panel thông tin dưới cùng
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: _buildInfoPanel(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMarker(IconData icon, Color color, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)]),
          child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
        ),
        Icon(icon, color: color, size: 30),
      ],
    );
  }

  Widget _buildFocusButton(IconData icon, Color color, String label, LatLng point) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _mapController.move(point, 16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))
              ],
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
            shadows: const [
              Shadow(color: Colors.white, blurRadius: 2, offset: Offset(1, 1))
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRouting ? "Tuyến đường tối ưu" : "Thông tin khoảng cách",
                        style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)
                      ),
                      const SizedBox(height: 2),
                      Text(_primaryDistanceText.isEmpty ? "Đang cập nhật..." : _primaryDistanceText, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
                if (_secondaryDistanceText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_secondaryDistanceText, 
                      style: TextStyle(color: Colors.blueGrey[700], fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Địa chỉ giao hàng", style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text(widget.order.deliveryAddress ?? "Không rõ địa chỉ", 
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), 
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _openExternalMap, 
                  icon: const Icon(Icons.map, size: 16), 
                  label: const Text("Mở bản đồ"),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
