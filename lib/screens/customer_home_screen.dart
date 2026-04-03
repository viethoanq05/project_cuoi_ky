import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/app_user.dart';
import '../models/store_info.dart';
import '../models/food_item.dart';
import '../models/category.dart' as model;
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/recommendation_service.dart';
import '../services/menu_service.dart';
import '../services/search_service.dart';
import '../services/category_service.dart';
import '../theme/app_colors.dart';
import '../widgets/weather_widget.dart';
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
  late MenuService _menuService;
  List<StoreInfo> _stores = [];
  List<StoreInfo> _recommendedStores = [];
  List<FoodItem> _distanceSuggestions = [];
  List<FoodItem> _allDistanceSuggestions = []; // Raw data before filtering
  List<model.Category> _categories = [];
  WeatherData? _currentWeather;
  bool _isLoading = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _recommendationService = RecommendationService();
    _menuService = MenuService.instance;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Xác định vị trí: ưu tiên từ user profile, nếu không thì lấy từ GPS
      double lat = 10.7769; // Default: Ho Chi Minh City
      double lon = 106.7009;

      final currentUser = widget.authService.currentUser;
      if (currentUser != null && currentUser.position != null) {
        lat = currentUser.position!['latitude']!;
        lon = currentUser.position!['longitude']!;
      } else {
        // Thử lấy vị trí từ GPS (parallelize location fetch as well if needed)
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
            ),
          ).timeout(const Duration(seconds: 5));
          lat = position.latitude;
          lon = position.longitude;
        } catch (_) {
          // Dùng vị trí mặc định nếu không lấy được GPS
        }
      }

      // 2. Chạy lấy các luồng dữ liệu song song (thời tiết, cửa hàng, món ăn)
      final weatherFuture = _recommendationService.getWeatherData(lat, lon);
      final allStoresFuture = SearchService().getAllStores();
      final allFoodsFuture = _menuService.getAllFoods();

      final results = await Future.wait([
        weatherFuture,
        allStoresFuture,
        allFoodsFuture,
      ]);

      final weather = results[0] as WeatherData?;
      final allStores = results[1] as List<StoreInfo>;
      final allFoods = results[2] as List<FoodItem>;

      // 3. Lấy gợi ý dựa trên dữ liệu đã tải
      final recommended = await _recommendationService.getWeatherBasedRecommendations(
        allStores,
        lat,
        lon,
      );

      final foodSuggestions = await _recommendationService.getDistanceBasedFoodRecommendations(
        allFoods,
        allStores,
        lat,
        lon,
      );

      final categories = await CategoryService().getAllCategories();

      if (mounted) {
        setState(() {
          _currentWeather = weather;
          _stores = allStores;
          _recommendedStores = recommended;
          _allDistanceSuggestions = foodSuggestions;
          _categories = categories;
          _applyFilters(); // Apply current filters to the new data
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              onRefresh: _loadData,
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

                  // Weather Widget
                  WeatherWidget(
                    weather: _currentWeather,
                    onRefresh: _loadData,
                  ),

                  // Danh mục gợi ý
                  _buildCategorySection(context),
                  const SizedBox(height: 24),

                  // Món ăn gợi ý theo khoảng cách
                  if (_allDistanceSuggestions.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedCategory == null 
                              ? 'Gợi ý món ngon gần bạn'
                              : 'Món ${_categories.firstWhere((c) => c.categoryId == _selectedCategory).name} dành cho bạn',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (_selectedCategory != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = null;
                                _applyFilters();
                              });
                            },
                            child: const Text('Xóa lọc', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_distanceSuggestions.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('Không tìm thấy món ăn phù hợp'),
                        ),
                      )
                    else
                      _buildDistanceFoodSuggestions(),
                    const SizedBox(height: 24),
                  ],

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

  void _applyFilters() {
    List<FoodItem> filtered = List.from(_allDistanceSuggestions);

    // 1. Lọc theo danh mục (nếu có chọn)
    if (_selectedCategory != null) {
      // Tìm category name tương ứng với ID nếu cần, hoặc lọc trực tiếp ID
      filtered = filtered.where((f) {
        // Hỗ trợ cả lọc theo ID hoặc theo Name để tránh sai sót dữ liệu
        return f.categoryId == _selectedCategory || 
               _categories.any((c) => c.categoryId == _selectedCategory && c.name == f.categoryId);
      }).toList();
    }

    _distanceSuggestions = filtered;
  }

  Widget _buildCategorySection(BuildContext context) {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Danh mục món ăn',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category.categoryId;
              final catService = CategoryService();
              
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedCategory == category.categoryId) {
                        _selectedCategory = null;
                      } else {
                        _selectedCategory = category.categoryId;
                      }
                      _applyFilters();
                    });
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Colors.green 
                              : catService.getCategoryColor(category.name),
                          shape: BoxShape.circle,
                          boxShadow: isSelected 
                              ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)]
                              : [],
                        ),
                        child: Icon(
                          catService.getIconData(category.icon),
                          color: isSelected ? Colors.white : Colors.green.shade700,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.green : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
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

  Widget _buildDistanceFoodSuggestions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _distanceSuggestions.map((food) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showFoodDetail(food),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Container(
                        height: 90,
                        width: double.infinity,
                        color: Colors.grey[100],
                        child: food.image.isNotEmpty
                            ? Image.network(
                                food.image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.fastfood, color: Colors.grey),
                              )
                            : const Icon(Icons.fastfood, color: Colors.grey),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            food.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${food.price.toStringAsFixed(0)}đ',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showFoodDetail(FoodItem food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 180,
                width: double.infinity,
                color: Colors.grey[200],
                child: food.image.isNotEmpty
                    ? Image.network(
                        food.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Center(child: Icon(Icons.fastfood, size: 48, color: Colors.grey)),
                      )
                    : const Center(child: Icon(Icons.fastfood, size: 48, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              food.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (food.description.isNotEmpty)
              Text(
                food.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  food.avgRating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${food.totalRatings} đánh giá)',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Giá: ${food.price.toStringAsFixed(0)}đ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final store = _stores.firstWhere(
                    (s) => s.storeId == food.storeId,
                    orElse: () => StoreInfo(
                      storeId: food.storeId,
                      storeOwnerId: '',
                      storeName: 'Cửa hàng',
                      latitude: 0,
                      longitude: 0,
                      address: '',
                      phone: '',
                    ),
                  );
                  
                  CartService().addItem(
                    foodId: food.foodId,
                    foodName: food.name,
                    price: food.price.toDouble(),
                    storeId: food.storeId,
                    storeName: store.storeName,
                    quantity: 1,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã thêm vào giỏ hàng'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                label: const Text(
                  'Thêm vào giỏ hàng',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
