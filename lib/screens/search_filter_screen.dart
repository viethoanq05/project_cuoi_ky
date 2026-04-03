import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../models/store_info.dart';
import '../services/search_service.dart';
import '../theme/app_colors.dart';
import 'food_list_screen.dart';
import 'cart_screen.dart';
import '../services/cart_service.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen>
    with SingleTickerProviderStateMixin {
  late SearchService _searchService;
  late TabController _tabController;
  String _searchQuery = '';
  double _minPrice = 0;
  double _maxPrice = 200000;
  double _minRating = 0;

  @override
  void initState() {
    super.initState();
    _searchService = SearchService();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm & Lọc'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Cửa hàng'),
            Tab(text: 'Món ăn'),
          ],
        ),
        actions: [
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
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Tìm kiếm...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStoresTab(),
                _buildFoodsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoresTab() {
    return FutureBuilder<List<StoreInfo>>(
      future: _searchService.searchStores(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final stores = snapshot.data ?? [];

        if (stores.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isEmpty
                      ? 'Nhập tên cửa hàng để tìm kiếm'
                      : 'Không tìm thấy cửa hàng nào',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stores.length,
          itemBuilder: (context, index) {
            final store = stores[index];
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
                              Text(
                                store.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${store.rating?.toStringAsFixed(1) ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
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
      },
    );
  }

  Widget _buildFoodsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lọc theo giá (${_minPrice.toStringAsFixed(0)} - ${_maxPrice.toStringAsFixed(0)}đ)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              RangeSlider(
                values: RangeValues(_minPrice, _maxPrice),
                min: 0,
                max: 200000,
                divisions: 40,
                activeColor: Colors.green,
                inactiveColor: Colors.green.withOpacity(0.2),
                labels: RangeLabels(
                  '${_minPrice.toStringAsFixed(0)}đ',
                  '${_maxPrice.toStringAsFixed(0)}đ',
                ),
                onChanged: (values) {
                  setState(() {
                    _minPrice = values.start;
                    _maxPrice = values.end;
                  });
                },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [20000, 30000, 50000, 100000].map((price) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text('Dưới ${price ~/ 1000}k'),
                        onPressed: () {
                          setState(() {
                            _minPrice = 0;
                            _maxPrice = price.toDouble();
                          });
                        },
                        backgroundColor: Colors.green.withOpacity(0.1),
                        labelStyle: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Lọc theo rating (từ ${_minRating.toStringAsFixed(1)} sao)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _minRating,
                min: 0,
                max: 5,
                divisions: 5,
                label: '${_minRating.toStringAsFixed(1)} sao',
                onChanged: (value) {
                  setState(() => _minRating = value);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<FoodItem>>(
            future: _searchQuery.isEmpty
                ? _searchService.filterByPrice(_minPrice, _maxPrice)
                : _searchService.searchFoods(_searchQuery),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Lỗi: ${snapshot.error}'));
              }

              var foods = snapshot.data ?? [];

              // Lọc thêm theo rating
              foods = foods.where((f) => (f.avgRating ?? 0) >= _minRating).toList();

              if (foods.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Không tìm thấy món ăn nào',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: foods.length,
                itemBuilder: (context, index) {
                  final food = foods[index];
                  return _buildFoodCard(food);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFoodCard(FoodItem food) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // Lấy tên cửa hàng trước khi mở chi tiết
          final storeName = await _searchService.getStoreNameById(food.storeId);
          if (context.mounted) {
            _showFoodDetails(context, food, storeName);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 120,
                  color: Colors.grey[300],
                  child: food.image != null
                      ? Image.network(food.image!, fit: BoxFit.cover)
                      : const Icon(Icons.restaurant),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                food.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${food.price}đ',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.star, size: 12, color: Colors.orange),
                  const SizedBox(width: 2),
                  Text(
                    '${food.avgRating?.toStringAsFixed(1) ?? 'N/A'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFoodDetails(BuildContext context, FoodItem food, String storeName) {
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
                    color: Colors.grey[300],
                    child: food.image.isNotEmpty
                        ? Image.network(food.image, fit: BoxFit.cover)
                        : const Icon(Icons.restaurant, size: 48),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  food.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cung cấp bởi $storeName',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                  onPressed: () {
                    try {
                      cartService.addItem(
                        foodId: food.foodId,
                        foodName: food.name,
                        price: food.price.toDouble(),
                        storeId: food.storeId,
                        storeName: storeName,
                        quantity: quantity,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã thêm vào giỏ hàng'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } catch (e) {
                      if (e.toString().contains('diff_store')) {
                        _showClearCartDialog(context, food, quantity, storeName);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.primary,
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
