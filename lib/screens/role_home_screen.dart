import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'driver_role_screens/dashboard.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  final MenuService _menuService = MenuService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _checkingProfile = false;
  bool _savingProfile = false;
  bool _loadingLocation = false;
  bool _updatingStoreStatus = false;
  String? _storeStatusError;
  LatLng? _currentLatLng;
  String _currentAddress = 'Dang xac dinh vi tri...';
  String? _locationError;

  static const String _usersCollection = 'Users';

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
      return DriverDashboard(authService: widget.authService);
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
