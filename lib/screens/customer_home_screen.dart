import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/store_info.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/recommendation_service.dart';
import '../theme/app_colors.dart';
import 'food_list_screen.dart';
import 'search_filter_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final AuthService authService;

  const CustomerHomeScreen({
    super.key,
    required this.authService,
  });

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late RecommendationService _recommendationService;
  List<StoreInfo> _stores = [];
  List<StoreInfo> _recommendedStores = [];
  bool _isLoading = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _recommendationService = RecommendationService();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    try {
      // Todo: Lấy danh sách tất cả cửa hàng từ Firestore
      // Tạm thời sử dụng danh sách trống
      // final stores = await _getAllStores();
      
      // Gợi ý cửa hàng dựa trên vị trí và thời tiết
      final currentUser = widget.authService.currentUser;
      if (currentUser != null && currentUser.position != null) {
        final recommended = await _recommendationService.getWeatherBasedRecommendations(
          _stores,
          currentUser.position!['latitude']!,
          currentUser.position!['longitude']!,
        );
        setState(() => _recommendedStores = recommended);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: _performLogout,
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    Navigator.pop(context);
    
    // Xóa giỏ hàng
    CartService().clear();
    
    // Đăng xuất
    try {
      await widget.authService.logout();
      // App sẽ tự động quay về LoginScreen vì currentUser = null
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đăng xuất: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchFilterScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutConfirmation,
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStores,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header với vị trí hiện tại
                  if (currentUser != null) ...[
                    Text(
                      'Đơn hàng được giao đến',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentUser.address ?? 'Chưa cập nhật địa chỉ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Danh mục gợi ý
                  _buildCategoryChips(context),
                  const SizedBox(height: 24),

                  // Cửa hàng gợi ý
                  if (_recommendedStores.isNotEmpty) ...[
                    Text(
                      'Gợi ý cho bạn',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildRecommendedStores(),
                    const SizedBox(height: 24),
                  ],

                  // Tất cả cửa hàng
                  Text(
                    'Tất cả cửa hàng',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _recommendedStores.isEmpty
                      ? const Center(
                          child: Text('Không có cửa hàng nào gần bạn'),
                        )
                      : _buildStoresList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    final categories = [
      'Cơm',
      'Mì',
      'Bánh',
      'Nước uống',
      'Tráng miệng',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : null;
                });
              },
              backgroundColor: Colors.grey[200],
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecommendedStores() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _recommendedStores.take(5).map((store) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FoodListScreen(
                          storeId: store.storeId,
                          storeName: store.storeName,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 100,
                            color: Colors.grey[300],
                            child: const Icon(Icons.restaurant),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          store.storeName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 12, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              '${store.rating?.toStringAsFixed(1) ?? 'N/A'}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${store.distance?.toStringAsFixed(1) ?? '?'} km',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStoresList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recommendedStores.length,
      itemBuilder: (context, index) {
        final store = _recommendedStores[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FoodListScreen(
                      storeId: store.storeId,
                      storeName: store.storeName,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: const Icon(Icons.restaurant),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.storeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                '${store.rating?.toStringAsFixed(1) ?? 'N/A'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (store.totalRatings != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${store.totalRatings})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                )
                              ]
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${store.distance?.toStringAsFixed(1) ?? '?'} km',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const Spacer(),
                              if (store.deliveryFee != null)
                                Text(
                                  'Phí: ${store.deliveryFee}đ',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
