import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/store_management_models.dart';
import '../../services/store_management_service.dart';
import '../../widgets/store_management/store_profile_form.dart';

class StoreProfileTab extends StatefulWidget {
  const StoreProfileTab({super.key});

  @override
  State<StoreProfileTab> createState() => _StoreProfileTabState();
}

class _StoreProfileTabState extends State<StoreProfileTab> {
  static const LatLng _defaultCenter = LatLng(21.027763, 105.83416);

  late Future<StoreProfile> _profileFuture;
  final MapController _mapController = MapController();
  final GlobalKey _mapKey = GlobalKey();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _openingHoursController = TextEditingController();
  LatLng? _selectedLocation;
  String _storeImageUrl = '';
  bool _isResolvingAddress = false;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _storeNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _openingHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoreProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Không tải được hồ sơ cửa hàng: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StoreProfileForm(
          storeNameController: _storeNameController,
          phoneController: _phoneController,
          addressController: _addressController,
          openingHoursController: _openingHoursController,
          header: _buildImageSection(),
          locationPicker: _buildLocationPicker(),
          isSaving: _isSaving,
          onSave: _updateProfile,
        );
      },
    );
  }

  Future<StoreProfile> _loadProfile() async {
    final profile = await context
        .read<StoreManagementService>()
        .getStoreProfile();
    final initialPoint = await _initialLocationFromProfile(profile);

    _storeNameController.text = profile.storeName;
    _phoneController.text = profile.phone;
    _openingHoursController.text = profile.openingHours;
    _storeImageUrl = profile.imageUrl;
    _selectedLocation = initialPoint;

    final rawAddress = profile.address.trim();
    if (rawAddress.isEmpty || _looksLikeCoordinateAddress(rawAddress)) {
      await _fillAddressFromCoordinates(initialPoint);
    } else {
      _addressController.text = rawAddress;
    }

    return profile;
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ảnh quán', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 170,
            width: double.infinity,
            child: _storeImageUrl.trim().isEmpty
                ? Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.storefront_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : Image.network(
                    _storeImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, size: 40),
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _isUploadingImage ? null : _pickAndUploadStoreImage,
          icon: _isUploadingImage
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_outlined),
          label: Text(
            _storeImageUrl.trim().isEmpty
                ? 'Upload ảnh quán'
                : 'Upload lại ảnh',
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadStoreImage() async {
    if (_isUploadingImage) {
      return;
    }

    XFile? picked;
    try {
      final picker = ImagePicker();
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Image picker chưa được khởi tạo. Hãy tắt app và chạy lại.',
            ),
          ),
        );
      }
      return;
    }

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final bytes = await picked.readAsBytes();
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';
      final url = await context.read<StoreManagementService>().uploadStoreImage(
        bytes: bytes,
        fileExtension: extension,
      );
      await context.read<StoreManagementService>().updateStoreImageUrl(url);

      if (!mounted) {
        return;
      }

      setState(() {
        _storeImageUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload ảnh quán thành công')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload ảnh quán thất bại: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<LatLng> _initialLocationFromProfile(StoreProfile profile) async {
    final lat = profile.latitude;
    final lng = profile.longitude;
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }

    final address = profile.address.trim();
    if (address.isNotEmpty) {
      try {
        final results = await locationFromAddress(address);
        if (results.isNotEmpty) {
          final point = results.first;
          return LatLng(point.latitude, point.longitude);
        }
      } catch (_) {
        // Keep default center when geocoding fails.
      }
    }

    return _defaultCenter;
  }

  Widget _buildLocationPicker() {
    final markerPoint = _selectedLocation ?? _defaultCenter;
    final currentAddress = _addressController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vị trí cửa hàng (kéo marker để thay đổi)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final mapHeight = constraints.maxWidth < 420
                ? 180.0
                : (constraints.maxWidth > 900 ? 280.0 : 220.0);

            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                key: _mapKey,
                height: mapHeight,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: markerPoint,
                    initialZoom: 16,
                    onTap: (_, point) =>
                        _setMarker(point, reverseGeocode: true),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.project_cuoi_ky',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: markerPoint,
                          width: 48,
                          height: 48,
                          child: Draggable<int>(
                            data: 1,
                            feedback: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 44,
                            ),
                            childWhenDragging: const Icon(
                              Icons.location_on,
                              color: Colors.redAccent,
                              size: 36,
                            ),
                            onDragEnd: _onMarkerDragEnd,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 44,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          currentAddress.isEmpty
              ? 'Chưa có địa chỉ. Hãy chạm hoặc kéo marker để chọn vị trí.'
              : 'Địa chỉ hiện tại: $currentAddress',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_isResolvingAddress)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Đang cập nhật địa chỉ từ vị trí...'),
              ],
            ),
          ),
      ],
    );
  }

  void _onMarkerDragEnd(DraggableDetails details) {
    final renderObject = _mapKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }

    final localOffset = renderObject.globalToLocal(details.offset);
    final point = _mapController.camera.offsetToCrs(localOffset);
    _setMarker(point, reverseGeocode: true);
  }

  Future<void> _setMarker(LatLng point, {required bool reverseGeocode}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedLocation = point;
    });

    if (reverseGeocode) {
      await _fillAddressFromCoordinates(point);
    }
  }

  Future<void> _fillAddressFromCoordinates(LatLng point) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isResolvingAddress = true;
    });

    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) {
        return;
      }

      final place = placemarks.first;
      final parts = _formatDisplayAddressParts(place);

      if (parts.isNotEmpty) {
        _addressController.text = parts.join(', ');
      }
    } catch (_) {
      // Ignore reverse-geocoding failures and keep manually entered address.
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingAddress = false;
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_isSaving) {
      return;
    }

    final service = context.read<StoreManagementService>();

    setState(() {
      _isSaving = true;
    });

    try {
      await _syncMarkerFromAddress();

      final profile = StoreProfile(
        storeName: _storeNameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        openingHours: _openingHoursController.text.trim(),
        imageUrl: _storeImageUrl.trim(),
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
      );

      await service.updateStoreProfile(
        profile,
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
      );

      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Cập nhật hồ sơ thành công')),
      );
      setState(() {
        _profileFuture = _loadProfile();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Cập nhật thất bại: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _syncMarkerFromAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      return;
    }

    try {
      final locations = await locationFromAddress(address);
      if (locations.isEmpty || !mounted) {
        return;
      }

      final point = LatLng(locations.first.latitude, locations.first.longitude);
      setState(() {
        _selectedLocation = point;
      });
      _mapController.move(point, _mapController.camera.zoom);
    } catch (_) {
      // Keep current marker when address geocoding fails.
    }
  }

  bool _looksLikeCoordinateAddress(String value) {
    final trimmed = value.trim();
    final coordinatePattern = RegExp(
      r'^\[?\s*-?\d+(\.\d+)?\s*[NS]?,\s*-?\d+(\.\d+)?\s*[EW]?\s*\]?$',
    );
    return coordinatePattern.hasMatch(trimmed);
  }

  List<String> _formatDisplayAddressParts(Placemark place) {
    final street = [place.subThoroughfare, place.thoroughfare]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ')
        .trim();

    final fallbackStreet = [street, place.street]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .firstWhere((_) => true, orElse: () => '');

    final parts = <String>[
      if (fallbackStreet.isNotEmpty) fallbackStreet,
      if ((place.subLocality ?? '').trim().isNotEmpty)
        place.subLocality!.trim(),
      if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
      if ((place.administrativeArea ?? '').trim().isNotEmpty)
        place.administrativeArea!.trim(),
    ];

    final uniqueParts = <String>[];
    for (final item in parts) {
      final normalized = item.toLowerCase();
      if (!uniqueParts.any(
        (existing) => existing.toLowerCase() == normalized,
      )) {
        uniqueParts.add(item);
      }
    }

    return uniqueParts;
  }
}
