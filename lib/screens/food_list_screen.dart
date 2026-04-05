import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../services/menu_service.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';
import 'cart_screen.dart';

class FoodListScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const FoodListScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<FoodListScreen> createState() => _FoodListScreenState();
}

class _FoodListScreenState extends State<FoodListScreen> {
  late MenuService _menuService;
  late CartService _cartService;
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _menuService = MenuService.instance;
    _cartService = CartService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeName),
        elevation: 0,
        actions: [
          ListenableBuilder(
            listenable: _cartService,
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
                if (_cartService.itemCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '${_cartService.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Tìm kiếm món ăn...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Categories stream
          SizedBox(
            height: 50,
            child: StreamBuilder<List<dynamic>>(
              stream: _menuService.watchCategories(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final categories = snapshot.data ?? [];
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategory == category.categoryId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = selected
                                ? category.categoryId
                                : null;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: AppColors.primary,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Foods list
          Expanded(
            child: StreamBuilder<List<FoodItem>>(
              stream: _menuService.watchStoreFoods(widget.storeId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var foods = snapshot.data ?? [];

                // Lọc theo danh mục
                if (_selectedCategory != null) {
                  foods = foods
                      .where((f) => f.categoryId == _selectedCategory)
                      .toList();
                }

                // Tìm kiếm
                if (_searchQuery.isNotEmpty) {
                  foods = foods
                      .where(
                        (f) =>
                            f.name.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            f.description.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                      )
                      .toList();
                }

                // Chỉ lấy những món có sẵn
                foods = foods.where((f) => f.isAvailable).toList();

                if (foods.isEmpty) {
                  return const Center(child: Text('Không có món ăn nào'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
      ),
    );
  }

  Widget _buildFoodCard(FoodItem food) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showFoodDetails(food);
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
                  child: food.image.isNotEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final dpr = MediaQuery.devicePixelRatioOf(context);
                            final cacheWidth = (constraints.maxWidth * dpr)
                                .round();
                            final cacheHeight = (120 * dpr).round();

                            return Image.network(
                              food.image,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                              isAntiAlias: true,
                              cacheWidth: cacheWidth > 0 ? cacheWidth : null,
                              cacheHeight: cacheHeight > 0 ? cacheHeight : null,
                              errorBuilder: (_, _, _) =>
                                  const Center(child: Icon(Icons.broken_image)),
                            );
                          },
                        )
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
                    food.avgRating.toStringAsFixed(1),
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

  void _showFoodDetails(FoodItem food) {
    int quantity = 1;
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
                        : const Icon(Icons.restaurant),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  food.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (food.description.trim().isNotEmpty) ...[
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
                  'Giá: ${food.price}đ',
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
                      _cartService.addItem(
                        foodId: food.foodId,
                        foodName: food.name,
                        foodImage: food.image,
                        price: food.price.toDouble(),
                        storeId: widget.storeId,
                        storeName: widget.storeName,
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
                        _showClearCartDialog(food, quantity);
                      } else {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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

  void _showClearCartDialog(FoodItem food, int quantity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi cửa hàng?'),
        content: const Text(
          'Giỏ hàng của bạn đang có món từ quán khác. Bạn có muốn xóa giỏ cũ để đặt món tại quán này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bỏ qua'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              _cartService.clear();
              _cartService.addItem(
                foodId: food.foodId,
                foodName: food.name,
                foodImage: food.image,
                price: food.price.toDouble(),
                storeId: widget.storeId,
                storeName: widget.storeName,
                quantity: quantity,
              );
              Navigator.pop(this.context); // Đóng bottom sheet
              ScaffoldMessenger.of(this.context).showSnackBar(
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
