import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user, required this.authService});

  final AppUser user;
  final AuthService authService;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  LatLng? _selectedLocation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);
    _addressController = TextEditingController(text: widget.user.address);

    if (widget.user.position != null && 
        widget.user.position!['latitude'] != null && 
        widget.user.position!['longitude'] != null) {
      _selectedLocation = LatLng(
        widget.user.position!['latitude']!,
        widget.user.position!['longitude']!,
      );
    } else {
      _selectedLocation = const LatLng(21.028511, 105.804817); // Default Hà Nội
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng latLng) async {
    setState(() {
      _selectedLocation = latLng;
    });

    try {
      String address = "";
      if (kIsWeb) {
        // Fallback cho Web: Sử dụng Nominatim API
        final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&zoom=18&addressdetails=1');
        final response = await http.get(url, headers: {'Accept-Language': 'vi'});
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          address = data['display_name'] ?? "";
        }
      } else {
        // Mobile: Sử dụng thư viện geocoding native
        List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
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
        setState(() {
          _addressController.text = address;
        });
      }
    } catch (e) {
      debugPrint("Lỗi lấy địa chỉ: $e");
      // Fallback cuối cùng: Hiển thị tọa độ nếu không lấy được tên địa chỉ
      _addressController.text = "${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}";
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final profileError = await widget.authService.updateProfileInfo(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (profileError != null) throw profileError;

      if (_selectedLocation != null) {
        final locationError = await widget.authService.updateCurrentLocationInfo(
          address: _addressController.text.trim(),
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
        );
        if (locationError != null) throw locationError;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveProfile,
            icon: const Icon(Icons.check),
          )
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Họ và tên', 
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập tên' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại', 
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập SĐT' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ hiển thị',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                        hintText: 'Chọn trên bản đồ để tự động điền',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    const Text('Chọn vị trí trên bản đồ:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 350,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: _selectedLocation!,
                                initialZoom: 15,
                                onTap: _onMapTap,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.example.project_cuoi_ky',
                                ),
                                if (_selectedLocation != null)
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _selectedLocation!,
                                        width: 40,
                                        height: 40,
                                        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: FloatingActionButton.small(
                                onPressed: () {
                                  // Reset map về vị trí hiện tại của marker
                                  setState(() {});
                                },
                                child: const Icon(Icons.my_location),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: FilledButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save),
                        label: const Text('LƯU THÔNG TIN HỒ SƠ', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
