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
import 'cart_screen.dart';

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
  List<FoodItem> _allFoods = []; // Store the full list of foods
  List<model.Category> _categories = [];
  WeatherData? _currentWeather;
  List<FoodItem> _weatherRecommendations = [];
  bool _isLoading = true;
  String? _selectedCategory;
  double _userLat = 10.7769;
  double _userLon = 106.7009;

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
      // Sử dụng catchError cho từng future để một tiến trình lỗi không làm dừng toàn bộ
      final results = await Future.wait([
        _recommendationService.getWeatherData(lat, lon).catchError((e) {
          debugPrint('Error fetching weather: $e');
          return null;
        }),
        SearchService().getAllStores().catchError((e) {
          debugPrint('Error fetching stores: $e');
          return <StoreInfo>[];
        }),
        _menuService.getAllFoods().catchError((e) {
          debugPrint('Error fetching foods: $e');
          return <FoodItem>[];
        }),
        CategoryService().getAllCategories().catchError((e) {
          debugPrint('Error fetching categories: $e');
          return <model.Category>[];
        }),
      ]);

      final weather = results[0] as WeatherData?;
      final allStores = results[1] as List<StoreInfo>;
      final allFoods = results[2] as List<FoodItem>;
      final categories = results[3] as List<model.Category>;

      // 3. Lấy gợi ý dựa trên dữ liệu đã tải
      final recommended = await _recommendationService.getWeatherBasedRecommendations(
        allStores,
        lat,
        lon,
      ).catchError((e) => allStores);

      final foodSuggestions = await _recommendationService.getDistanceBasedFoodRecommendations(
        allFoods,
        allStores,
        lat,
        lon,
      ).catchError((e) => allFoods.take(10).toList());

      final weatherRecommendations = await _recommendationService.getWeatherBasedFoodRecommendations(
        allFoods,
        weather,
        currentTime: DateTime.now(),
      ).catchError((e) => <FoodItem>[]);

      if (mounted) {
        setState(() {
          _currentWeather = weather;
          _userLat = lat;
          _userLon = lon;
          _stores = recommended; // Use stores with calculated distances
          _recommendedStores = recommended;
          _allDistanceSuggestions = foodSuggestions;
          _allFoods = allFoods;
          _weatherRecommendations = weatherRecommendations;
          _categories = categories;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cảnh báo: Một số dữ liệu không thể tải đầy đủ ($e)'),
            duration: const Duration(seconds: 5),
          ),
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
          ListenableBuilder(
            listenable: CartService(),
            builder: (context, _) => Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CartScreen(),
                      ),
                    );
                  },
                ),
                if (CartService().itemCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${CartService().itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
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

                  // Weather Recommendations
                  if (_weatherRecommendations.isNotEmpty) ...[
                    _buildWeatherFoodSuggestionsHeader(),
                    const SizedBox(height: 12),
                    _buildWeatherFoodSuggestions(),
                    const SizedBox(height: 24),
                  ],

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
    if (_selectedCategory == null) {
      _distanceSuggestions = List.from(_allDistanceSuggestions);
    } else {
      final selectedId = _selectedCategory!.trim().toLowerCase();
      
      // 1. Lọc tất cả các món ăn theo danh mục
      List<FoodItem> filteredByCategory = _allFoods.where((f) {
        final foodCatId = f.categoryId.trim().toLowerCase();
        
        // So khớp trực tiếp ID
        if (foodCatId == selectedId) return true;
        
        // So khớp tên danh mục (trong trường hợp categoryId của food là tên tiếng Việt)
        return _categories.any((c) => 
          c.categoryId.trim().toLowerCase() == selectedId && 
          c.name.trim().toLowerCase() == foodCatId
        );
      }).toList();

      // Debug: In ra số lượng tìm thấy để kiểm tra
      debugPrint('Filtering for category: $selectedId. Found: ${filteredByCategory.length} items out of ${_allFoods.length}');

      // 2. Tính toán khoảng cách và sắp xếp lại các món trong danh mục này
      final Map<String, double> storeDistances = {};
      for (var store in _stores) {
        storeDistances[store.storeId] = store.distance ?? 999;
      }

      final List<MapEntry<FoodItem, double>> foodWithDistance = [];
      for (var food in filteredByCategory) {
        final dist = storeDistances[food.storeId] ?? 999;
        foodWithDistance.add(MapEntry(food, dist));
      }

      foodWithDistance.sort((a, b) => a.value.compareTo(b.value));
      
      // Lấy top 50 món ăn gần nhất của danh mục này
      _distanceSuggestions = foodWithDistance.map((e) => e.key).take(50).toList();
    }
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

  Widget _buildWeatherFoodSuggestionsHeader() {
    String title = 'Món ngon cho bạn';
    IconData icon = Icons.recommend;
    
    if (_currentWeather != null) {
      final condition = _currentWeather!.condition;
      final temp = _currentWeather!.temp;
      final hour = DateTime.now().hour;
      
      String timeStr = '';
      if (hour >= 5 && hour < 10) timeStr = 'bữa sáng';
      else if (hour >= 10 && hour < 15) timeStr = 'bữa trưa';
      else if (hour >= 15 && hour < 18) timeStr = 'ăn chiều';
      else if (hour >= 18 && hour < 22) timeStr = 'bữa tối';
      else timeStr = 'ăn đêm';

      if (condition == 'Rain' || condition == 'Drizzle' || condition == 'Thunderstorm') {
        title = 'Ăn gì $timeStr ngày mưa?';
        icon = Icons.umbrella;
      } else if (temp > 28) {
        title = 'Món $timeStr giải nhiệt';
        icon = Icons.wb_sunny;
      } else if (temp < 22) {
        title = '$timeStr ấm nóng';
        icon = Icons.ac_unit;
      } else {
        title = 'Gợi ý $timeStr tuyệt vời';
        icon = Icons.wb_cloudy;
      }
    }
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
        ),
      ],
    );
  }

  Widget _buildWeatherFoodSuggestions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _weatherRecommendations.map((food) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                      child: Stack(
                        children: [
                          Container(
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
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, size: 10, color: Colors.amber),
                                  const SizedBox(width: 2),
                                  Text(
                                    food.avgRating.toStringAsFixed(1),
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
    int quantity = 1;
    final cartService = CartService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, controller) => Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: controller,
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
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: food.image.isNotEmpty
                        ? Image.network(
                            food.image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.fastfood,
                                    size: 48, color: Colors.grey)),
                          )
                        : const Center(
                            child: Icon(Icons.fastfood,
                                size: 48, color: Colors.grey)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  food.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                if (food.description.isNotEmpty) ...[
                  Text(
                    food.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                ],
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
                const SizedBox(height: 16),
                Text(
                  'Giá: ${food.price.toStringAsFixed(0)}đ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (quantity > 1) {
                          setState(() => quantity--);
                        }
                      },
                      icon: const Icon(Icons.remove_circle),
                      color: AppColors.primary,
                    ),
                    Text(
                      quantity.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() => quantity++);
                      },
                      icon: const Icon(Icons.add_circle),
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    // Tìm tên quán trong list stores hiện tại hoặc fetch nếu cần
                    String storeName = 'Cửa hàng';
                    final storeIndex =
                        _stores.indexWhere((s) => s.storeId == food.storeId);
                    if (storeIndex != -6) {
                      if (storeIndex != -1) {
                        storeName = _stores[storeIndex].storeName;
                      } else {
                        // Fetch tên quán nếu không có sẵn
                        storeName = await SearchService()
                            .getStoreNameById(food.storeId);
                      }
                    }

                    try {
                      cartService.addItem(
                        foodId: food.foodId,
                        foodName: food.name,
                        price: food.price.toDouble(),
                        storeId: food.storeId,
                        storeName: storeName,
                        quantity: quantity,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã thêm vào giỏ hàng'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (e.toString().contains('diff_store')) {
                        if (context.mounted) {
                          _showClearCartDialog(
                              context, food, quantity, storeName);
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e')),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text(
                    'Thêm vào giỏ hàng',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClearCartDialog(
      BuildContext context, FoodItem food, int quantity, String storeName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi cửa hàng?'),
        content: const Text(
          'Giỏ hàng của bạn đang có món từ quán khác. Bạn có muốn xóa giỏ cũ để đặt món tại quán này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Bỏ qua'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Đóng dialog
              CartService().clear();
              CartService().addItem(
                foodId: food.foodId,
                foodName: food.name,
                price: food.price.toDouble(),
                storeId: food.storeId,
                storeName: storeName,
                quantity: quantity,
              );
              Navigator.pop(context); // Đóng bottom sheet
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa giỏ cũ và thêm món mới')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Đồng ý', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
