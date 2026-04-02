import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_user.dart';
import '../models/food_item.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/menu_service.dart';
import '../widgets/food_grid_card.dart';
import '../widgets/store_status_card.dart';
import 'customer_home_screen.dart';
import 'food_editor_screen.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  final MenuService _menuService = MenuService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  bool _checkingProfile = false;
  bool _savingProfile = false;
  bool _loadingLocation = false;
  bool _updatingStoreStatus = false;
  bool _updatingDriverOnline = false;
  String? _storeStatusError;
  LatLng? _currentLatLng;
  String _currentAddress = 'Dang xac dinh vi tri...';
  String? _locationError;

  final Set<String> _acceptingOrderIds = <String>{};
  final Map<String, LatLng> _orderGeoCache = <String, LatLng>{};
  final Set<String> _geocodingOrderIds = <String>{};

  static const String _usersCollection = 'Users';
  static const String _ordersCollection = 'Orders';
  static const String _orderStatusField = 'order_status';

  static const double _nearbyRadiusKm = 5.0;

  static const List<String> _findingOrderStatuses = <String>[
    'dang_tim_xe',
    'finding_driver',
    'Searching',
    'searching',
  ];
  static const String _orderStatusPreparing = 'dang_chuan_bi';
  static const String _orderStatusPreparingEn = 'Preparing';
  static const String _driverStatusDelivering = 'dang_giao';

  String _acceptedOrderStatus(String existingStatus) {
    final normalized = existingStatus.trim().toLowerCase();
    if (normalized == 'searching' || normalized == 'finding_driver') {
      return _orderStatusPreparingEn;
    }
    return _orderStatusPreparing;
  }

  @override
  void initState() {
    super.initState();
    final existingLocation =
        widget.authService.currentUser?.address.trim() ?? '';
    if (existingLocation.isNotEmpty) {
      _currentAddress = existingLocation;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapAfterFirstFrame();
    });
  }

  Future<void> _bootstrapAfterFirstFrame() async {
    await _ensureProfileCompleted();
    if (!mounted) {
      return;
    }

    final role = widget.authService.currentUser?.role;
    if (role != UserRole.driver) {
      await _loadCurrentLocation();
    }
  }

  Future<void> _ensureProfileCompleted() async {
    if (_checkingProfile) {
      return;
    }
    _checkingProfile = true;

    try {
      final needsProfile = await widget.authService.needsProfileCompletion();
      if (!mounted || !needsProfile) {
        return;
      }

      final profile = await _showProfileDialog(
        initialFullName: widget.authService.currentUser?.fullName ?? '',
        initialPhone: widget.authService.currentUser?.phone ?? '',
      );
      if (!mounted || profile == null) {
        return;
      }

      setState(() {
        _savingProfile = true;
      });

      final saveError = await widget.authService.updateProfileInfo(
        fullName: profile.fullName,
        phone: profile.phone,
      );

      if (mounted) {
        setState(() {
          _savingProfile = false;
        });
      }

      if (!mounted) {
        return;
      }

      if (saveError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(saveError)));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureProfileCompleted();
        });
      } else {
        if (widget.authService.currentUser?.role != UserRole.driver) {
          await _loadCurrentLocation();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Luu thong tin that bai: $e')));
      }
    } finally {
      _checkingProfile = false;
      if (mounted && _savingProfile) {
        setState(() {
          _savingProfile = false;
        });
      }
    }
  }

  Future<void> _loadCurrentLocation() async {
    if (_loadingLocation) {
      return;
    }

    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Dich vu vi tri dang tat.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Ban chua cap quyen truy cap vi tri.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));

      List<Placemark> placemarks = const <Placemark>[];
      try {
        placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        // Keep coordinate fallback if reverse geocoding is slow/unavailable.
      }

      String address =
          '[${position.latitude.toStringAsFixed(5)} N, ${position.longitude.toStringAsFixed(5)} E]';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.street ?? '').isNotEmpty) p.street!,
          if ((p.subAdministrativeArea ?? '').isNotEmpty)
            p.subAdministrativeArea!,
          if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
          if ((p.country ?? '').isNotEmpty) p.country!,
        ];
        if (parts.isNotEmpty) {
          address = parts.join(', ');
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _currentAddress = address;
      });

      final saveError = await widget.authService.updateCurrentLocationInfo(
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (saveError != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(saveError)));
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationError = 'Lay vi tri qua lau, vui long thu lai.';
        _currentAddress = 'Khong lay duoc vi tri hien tai';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationError = e.toString();
        _currentAddress = 'Khong lay duoc vi tri hien tai';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  Future<_ProfileInput?> _showProfileDialog({
    required String initialFullName,
    required String initialPhone,
  }) {
    return showDialog<_ProfileInput>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ProfileCompletionDialog(
          initialFullName: initialFullName,
          initialPhone: initialPhone,
        );
      },
    );
  }

  Future<void> _openCreateFoodScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodEditorScreen(menuService: _menuService),
      ),
    );
  }

  Future<void> _openEditFoodScreen(FoodItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FoodEditorScreen(menuService: _menuService, initial: item),
      ),
    );
  }

  Future<void> _deleteFood(FoodItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xoa mon an'),
          content: Text('Ban chac chan muon xoa ${item.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xoa'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    final error = await _menuService.deleteFood(item);
    if (!mounted || error == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _openFoodDetail(FoodItem item, String categoryName) async {
    var localItem = item; // Local mutable copy for UI updates
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: localItem.image.trim().isEmpty
                            ? Container(
                                height: 180,
                                alignment: Alignment.center,
                                color: Colors.black12,
                                child: const Icon(Icons.fastfood, size: 34),
                              )
                            : Image.network(
                                localItem.image,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  height: 140,
                                  alignment: Alignment.center,
                                  color: Colors.black12,
                                  child: const Text('Khong tai duoc anh'),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        localItem.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('Danh muc: $categoryName')),
                          Chip(
                            label: Text(
                              'Size: ${(localItem.options['size'] ?? '-').toString()}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              localItem.isAvailable ? 'Dang ban' : 'Tam an',
                            ),
                            avatar: Icon(
                              localItem.isAvailable
                                  ? Icons.check_circle_outline
                                  : Icons.pause_circle_outline,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gia ${localItem.price}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localItem.description.isEmpty
                            ? 'Chua co mo ta.'
                            : localItem.description,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Dang ban'),
                        value: localItem.isAvailable,
                        onChanged: (value) async {
                          final messenger = ScaffoldMessenger.of(context);
                          final error = await _menuService.toggleAvailability(
                            localItem,
                            value,
                          );
                          if (!mounted) {
                            return;
                          }
                          setModalState(() {
                            localItem = localItem.copyWith(isAvailable: value);
                          });
                          if (error != null) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _openEditFoodScreen(localItem);
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Sua'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _deleteFood(localItem);
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Xoa'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _setStoreOpenStatus(bool value) async {
    if (_updatingStoreStatus) {
      return;
    }

    setState(() {
      _updatingStoreStatus = true;
      _storeStatusError = null;
    });

    final error = await widget.authService.updateStoreOpenStatus(value);
    if (!mounted) {
      return;
    }

    setState(() {
      _updatingStoreStatus = false;
      _storeStatusError = error;
    });
  }

  String _displayName(AppUser user) {
    final fullName = user.fullName.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final userName = user.userName.trim();
    if (userName.isNotEmpty) {
      return userName;
    }

    return user.email;
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection(_usersCollection).doc(uid);
  }

  Stream<Map<String, dynamic>?> _watchDriverInfo(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) {
        return null;
      }
      final raw = data['driver_info'];
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is Map) {
        final normalized = <String, dynamic>{};
        for (final entry in raw.entries) {
          normalized[entry.key.toString()] = entry.value;
        }
        return normalized;
      }
      return null;
    });
  }

  Future<void> _setDriverOnline({
    required String uid,
    required bool value,
  }) async {
    if (_updatingDriverOnline) {
      return;
    }

    setState(() {
      _updatingDriverOnline = true;
    });

    try {
      await _userDoc(uid).update({
        'driver_info.is_online': value,
        'driver_info.status': value ? 'online' : 'offline',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // Fallback if the user doc doesn't exist yet.
      if (e.code == 'not-found') {
        await _userDoc(uid).set({
          'driver_info': <String, dynamic>{
            'is_online': value,
            'status': value ? 'online' : 'offline',
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Khong cap nhat duoc trang thai online: ${e.message ?? e.code}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Khong cap nhat duoc trang thai online: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingDriverOnline = false;
        });
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchFindingOrders() {
    return _firestore
        .collection(_ordersCollection)
        .where(_orderStatusField, whereIn: _findingOrderStatuses)
        .snapshots();
  }

  num? _asNum(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value;
    }
    if (value is String) {
      return num.tryParse(value.trim());
    }
    return null;
  }

  LatLng? _extractOrderLatLng(Map<String, dynamic> data) {
    final candidates = <List<String>>[
      ['pickup_lat', 'pickup_lng'],
      ['pickup_latitude', 'pickup_longitude'],
      ['store_lat', 'store_lng'],
      ['store_latitude', 'store_longitude'],
      ['lat', 'lng'],
      ['latitude', 'longitude'],
    ];

    for (final pair in candidates) {
      final lat = _asNum(data[pair[0]]);
      final lng = _asNum(data[pair[1]]);
      if (lat == null || lng == null) {
        continue;
      }
      final latD = lat.toDouble();
      final lngD = lng.toDouble();
      if (latD.abs() > 90 || lngD.abs() > 180) {
        continue;
      }
      return LatLng(latD, lngD);
    }

    return null;
  }

  String _extractDeliveryAddress(Map<String, dynamic> data) {
    return (data['delivery_address'] ?? data['address'] ?? '')
        .toString()
        .trim();
  }

  Future<LatLng?> _geocodeAddressToLatLng(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final locations = await locationFromAddress(
        trimmed,
      ).timeout(const Duration(seconds: 8));
      if (locations.isEmpty) {
        return null;
      }

      final loc = locations.first;
      final lat = loc.latitude;
      final lng = loc.longitude;
      if (lat.abs() > 90 || lng.abs() > 180) {
        return null;
      }
      return LatLng(lat, lng);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void _ensureOrderGeocoded({
    required String orderId,
    required String address,
  }) {
    if (orderId.trim().isEmpty) {
      return;
    }
    if (_orderGeoCache.containsKey(orderId)) {
      return;
    }
    if (_geocodingOrderIds.contains(orderId)) {
      return;
    }

    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _geocodingOrderIds.add(orderId);
    _geocodeAddressToLatLng(trimmed).then((point) {
      if (!mounted) {
        return;
      }
      setState(() {
        _geocodingOrderIds.remove(orderId);
        if (point != null) {
          _orderGeoCache[orderId] = point;
        }
      });
    });
  }

  bool _shouldAutoLoadDriverLocation({required bool isOnline}) {
    return isOnline && !_loadingLocation && _currentLatLng == null;
  }

  Future<void> _acceptOrder({
    required DocumentReference<Map<String, dynamic>> orderRef,
    required String driverUid,
    required String driverName,
  }) async {
    if (_acceptingOrderIds.contains(orderRef.id)) {
      return;
    }

    setState(() {
      _acceptingOrderIds.add(orderRef.id);
    });

    try {
      await _firestore.runTransaction((tx) async {
        final orderSnap = await tx.get(orderRef);
        final order = orderSnap.data();
        if (order == null) {
          throw Exception('Don hang khong ton tai nua.');
        }

        final existingStatus =
            (order[_orderStatusField] ?? order['status'] ?? '')
                .toString()
                .trim();
        if (!_findingOrderStatuses.contains(existingStatus)) {
          throw Exception('Don hang da duoc cap nhat boi nguoi khac.');
        }

        final existingDriverId = (order['driver_id'] ?? '').toString().trim();
        if (existingDriverId.isNotEmpty) {
          throw Exception('Don hang da co tai xe nhan.');
        }

        final nextStatus = _acceptedOrderStatus(existingStatus);
        tx.update(orderRef, <String, dynamic>{
          _orderStatusField: nextStatus,
          'status': nextStatus,
          'driver_id': driverUid,
          'driver_name': driverName,
          'accepted_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        final driverRef = _userDoc(driverUid);
        tx.update(driverRef, <String, dynamic>{
          'driver_info.status': _driverStatusDelivering,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Da nhan don.')));
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nhan don that bai: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Nhan don that bai: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _acceptingOrderIds.remove(orderRef.id);
        });
      }
    }
  }

  Widget _buildDriverHome(AppUser user) {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('Ban chua dang nhap.')));
    }

    final driverUid = firebaseUser.uid;
    final driverName = _displayName(user);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tai xe', style: theme.textTheme.labelMedium),
            Text(
              'Xin chao, $driverName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.authService.logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Dang xuat',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _watchDriverInfo(driverUid),
          builder: (context, driverSnapshot) {
            final driverInfo = driverSnapshot.data ?? const <String, dynamic>{};
            final isOnlineRaw = driverInfo['is_online'];
            final isOnline = isOnlineRaw is bool
                ? isOnlineRaw
                : (isOnlineRaw is num
                      ? isOnlineRaw != 0
                      : (isOnlineRaw?.toString().toLowerCase() == 'true'));

            if (_shouldAutoLoadDriverLocation(isOnline: isOnline)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadCurrentLocation();
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isOnline
                                ? Icons.wifi_tethering_rounded
                                : Icons.wifi_off_rounded,
                            color: isOnline
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOnline ? 'Dang san sang' : 'Dang offline',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isOnline
                                    ? 'Ban co the xem va nhan don gan ban'
                                    : 'Bat Online de xem va nhan don',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isOnline,
                          onChanged: _updatingDriverOnline
                              ? null
                              : (value) => _setDriverOnline(
                                  uid: driverUid,
                                  value: value,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Don hang dang tim xe',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: !isOnline
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Icon(
                                    Icons.wifi_off_rounded,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Dang Offline',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Bat Online de xem don hang gan ban va nhan don.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _watchFindingOrders(),
                          builder: (context, ordersSnapshot) {
                            if (ordersSnapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Khong tai duoc don hang: ${ordersSnapshot.error}',
                                ),
                              );
                            }

                            if (!ordersSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final docs = ordersSnapshot.data!.docs;
                            if (docs.isEmpty) {
                              return Center(
                                child: Text(
                                  'Chua co don hang nao dang tim xe.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              );
                            }

                            final driverPoint = _currentLatLng;
                            if (driverPoint == null) {
                              return Center(
                                child: _loadingLocation
                                    ? const CircularProgressIndicator()
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Can quyen vi tri de loc don gan ban.',
                                            style: theme.textTheme.bodyMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 10),
                                          FilledButton.icon(
                                            onPressed: _loadCurrentLocation,
                                            icon: const Icon(Icons.my_location),
                                            label: const Text('Lay vi tri'),
                                          ),
                                        ],
                                      ),
                              );
                            }

                            final distance = const Distance();
                            final nearby =
                                <
                                  ({
                                    QueryDocumentSnapshot<Map<String, dynamic>>
                                    doc,
                                    double km,
                                  })
                                >[];

                            for (final doc in docs) {
                              final data = doc.data();
                              final orderId = doc.id;

                              var orderPoint = _extractOrderLatLng(data);
                              if (orderPoint == null) {
                                final address = _extractDeliveryAddress(data);
                                _ensureOrderGeocoded(
                                  orderId: orderId,
                                  address: address,
                                );
                                orderPoint = _orderGeoCache[orderId];
                              }

                              if (orderPoint == null) {
                                continue;
                              }
                              final meters = distance(driverPoint, orderPoint);
                              final km = meters / 1000.0;
                              if (km <= _nearbyRadiusKm) {
                                nearby.add((doc: doc, km: km));
                              }
                            }

                            nearby.sort((a, b) => a.km.compareTo(b.km));
                            if (nearby.isEmpty) {
                              return Center(
                                child: Text(
                                  'Khong co don hang nao gan ban (<= ${_nearbyRadiusKm.toStringAsFixed(0)} km).',
                                  style: theme.textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: nearby.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final doc = nearby[index].doc;
                                final data = doc.data();
                                final orderId = doc.id;
                                final km = nearby[index].km;

                                final address =
                                    (data['delivery_address'] ??
                                            data['address'] ??
                                            '')
                                        .toString()
                                        .trim();
                                final storeName =
                                    (data['store_name'] ??
                                            data['storeName'] ??
                                            '')
                                        .toString()
                                        .trim();
                                final customerName =
                                    (data['customer_name'] ??
                                            data['customerName'] ??
                                            '')
                                        .toString()
                                        .trim();

                                final accepting = _acceptingOrderIds.contains(
                                  orderId,
                                );

                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                storeName.isNotEmpty
                                                    ? storeName
                                                    : 'Don hang moi',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '${km.toStringAsFixed(1)} km',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .onPrimaryContainer,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ma don: $orderId',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (customerName.isNotEmpty)
                                          _driverInfoRow(
                                            icon: Icons.person_outline_rounded,
                                            text: customerName,
                                          ),
                                        if (address.isNotEmpty)
                                          _driverInfoRow(
                                            icon: Icons.location_on_outlined,
                                            text: address,
                                          ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton(
                                            onPressed: accepting
                                                ? null
                                                : () => _acceptOrder(
                                                    orderRef: doc.reference,
                                                    driverUid: driverUid,
                                                    driverName: driverName,
                                                  ),
                                            child: accepting
                                                ? const SizedBox(
                                                    height: 18,
                                                    width: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Text('Nhan don'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _driverInfoRow({required IconData icon, required String text}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  String _displayCategoryName(String categoryId, Map<String, String> names) {
    final id = categoryId.trim();
    if (id.isEmpty) {
      return '-';
    }
    return names[id] ?? id;
  }

  Widget _buildStoreHome(AppUser user) {
    final storeName = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()
        : (user.userName.trim().isNotEmpty ? user.userName.trim() : user.email);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cua hang', style: Theme.of(context).textTheme.labelMedium),
            Text(
              _currentAddress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadingLocation ? null : _loadCurrentLocation,
            icon: const Icon(Icons.refresh),
            tooltip: 'Cap nhat dia chi',
          ),
          IconButton(
            onPressed: widget.authService.logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Dang xuat',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateFoodScreen,
        icon: const Icon(Icons.add),
        label: const Text('Them mon'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF155E75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chao, $storeName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Quan ly menu cua ban nhanh hon',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            StoreStatusCard(
              isOpen: user.isStoreOpen,
              loading: _updatingStoreStatus,
              onChanged: _setStoreOpenStatus,
            ),
            if (_storeStatusError != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _storeStatusError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Danh sach mon an',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<List<MenuCategory>>(
                stream: _menuService.watchCategories(),
                builder: (context, categorySnapshot) {
                  final categoryMap = <String, String>{};
                  for (final category
                      in categorySnapshot.data ?? const <MenuCategory>[]) {
                    categoryMap[category.id] = category.name;
                  }

                  return StreamBuilder<List<FoodItem>>(
                    stream: _menuService.watchCurrentStoreFoods(),
                    builder: (context, foodSnapshot) {
                      if (foodSnapshot.hasError) {
                        return Center(
                          child: Text('Loi tai menu: ${foodSnapshot.error}'),
                        );
                      }

                      if (!foodSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final foods = foodSnapshot.data!;
                      if (foods.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(
                                  Icons.fastfood_rounded,
                                  size: 34,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Chua co mon an nao',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Them mon dau tien de bat dau ban hang.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount = width >= 1100
                              ? 4
                              : (width >= 760 ? 3 : 2);

                          return GridView.builder(
                            padding: const EdgeInsets.only(bottom: 90),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.78,
                                ),
                            itemCount: foods.length,
                            itemBuilder: (context, index) {
                              final item = foods[index];
                              final categoryName = _displayCategoryName(
                                item.categoryId,
                                categoryMap,
                              );

                              return FoodGridCard(
                                item: item,
                                categoryName: categoryName,
                                onTap: () =>
                                    _openFoodDetail(item, categoryName),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Khong tim thay nguoi dung.')),
      );
    }

    if (user.role == UserRole.store) {
      return _buildStoreHome(user);
    }

    if (user.role == UserRole.driver) {
      return _buildDriverHome(user);
    }

    if (user.role == UserRole.customer) {
      return CustomerHomeScreen(authService: widget.authService);
    }

    final info = roleInfo(user.role);

    return Scaffold(
      appBar: AppBar(
        title: Text(info.title),
        actions: [
          IconButton(
            onPressed: widget.authService.logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Dang xuat',
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chao: ${user.email}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quyen: ${user.role.label}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(info.description),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Dia chi hien tai: $_currentAddress',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            IconButton(
                              onPressed: _loadingLocation
                                  ? null
                                  : _loadCurrentLocation,
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Cap nhat vi tri',
                            ),
                          ],
                        ),
                        if (_locationError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _locationError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _currentLatLng == null
                                ? Container(
                                    color: Colors.black12,
                                    alignment: Alignment.center,
                                    child: _loadingLocation
                                        ? const CircularProgressIndicator()
                                        : const Text('Chua co du lieu vi tri'),
                                  )
                                : FlutterMap(
                                    options: MapOptions(
                                      initialCenter: _currentLatLng!,
                                      initialZoom: 16,
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName:
                                            'com.example.project_cuoi_ky',
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: _currentLatLng!,
                                            width: 44,
                                            height: 44,
                                            child: const Icon(
                                              Icons.location_on,
                                              color: Colors.red,
                                              size: 40,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_savingProfile)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Dang luu thong tin...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  _RoleInfo roleInfo(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return const _RoleInfo(
          title: 'Trang khach hang',
          description:
              'Ban co the tim kiem cua hang, dat don va theo doi don hang.',
        );
      case UserRole.store:
        return const _RoleInfo(
          title: 'Trang cua hang',
          description:
              'Ban co the quan ly mon an, don hang va doanh thu cua cua hang.',
        );
      case UserRole.driver:
        return const _RoleInfo(
          title: 'Trang tai xe',
          description:
              'Ban co the nhan don giao, cap nhat trang thai va xem thu nhap.',
        );
    }
  }
}

class _ProfileInput {
  const _ProfileInput({required this.fullName, required this.phone});

  final String fullName;
  final String phone;
}

class _ProfileCompletionDialog extends StatefulWidget {
  const _ProfileCompletionDialog({
    required this.initialFullName,
    required this.initialPhone,
  });

  final String initialFullName;
  final String initialPhone;

  @override
  State<_ProfileCompletionDialog> createState() =>
      _ProfileCompletionDialogState();
}

class _ProfileCompletionDialogState extends State<_ProfileCompletionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.initialFullName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    Navigator.of(context).pop(
      _ProfileInput(
        fullName: _fullNameController.text,
        phone: _phoneController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cap nhat thong tin'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nhap full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_submitting) {
                    _submit();
                  }
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nhap so dien thoai';
                  }
                  if (value.trim().length < 9) {
                    return 'So dien thoai khong hop le';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Luu'),
        ),
      ],
    );
  }
}

class _RoleInfo {
  const _RoleInfo({required this.title, required this.description});

  final String title;
  final String description;
}
