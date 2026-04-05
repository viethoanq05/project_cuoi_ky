import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../services/menu_service.dart';
import '../theme/app_colors.dart';
import 'booking_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late CartService _cartService;

  @override
  void initState() {
    super.initState();
    _cartService = CartService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giỏ hàng'), elevation: 0),
      body: ListenableBuilder(
        listenable: _cartService,
        builder: (context, _) {
          if (_cartService.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Giỏ hàng trống',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hãy thêm món ăn yêu thích của bạn',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tiếp tục mua sắm'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cartService.items.length,
                  itemBuilder: (context, index) {
                    final item = _cartService.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Builder(
                                    builder: (context) {
                                      final imageUrl =
                                          MenuService.getPublicImageUrl(
                                            (item.foodImage ?? '').trim(),
                                          );

                                      if (imageUrl.isEmpty) {
                                        return const Icon(Icons.restaurant);
                                      }

                                      return Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.medium,
                                        isAntiAlias: true,
                                        cacheWidth:
                                            (80 *
                                                    MediaQuery.devicePixelRatioOf(
                                                      context,
                                                    ))
                                                .round(),
                                        cacheHeight:
                                            (80 *
                                                    MediaQuery.devicePixelRatioOf(
                                                      context,
                                                    ))
                                                .round(),
                                        errorBuilder: (_, _, _) =>
                                            const Icon(Icons.restaurant),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.foodName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.price}đ',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            if (item.quantity > 1) {
                                              _cartService.updateQuantity(
                                                item.cartItemId,
                                                item.quantity - 1,
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.remove_circle),
                                          iconSize: 20,
                                          color: AppColors.primary,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          item.quantity.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () {
                                            _cartService.updateQuantity(
                                              item.cartItemId,
                                              item.quantity + 1,
                                            );
                                          },
                                          icon: const Icon(Icons.add_circle),
                                          iconSize: 20,
                                          color: AppColors.primary,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      _cartService.removeItem(item.cartItemId);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Đã xóa khỏi giỏ hàng'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.delete),
                                    color: AppColors.danger,
                                  ),
                                  Text(
                                    '${item.subtotal.toStringAsFixed(0)}đ',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
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
                ),
              ),

              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tạm tính:', style: TextStyle(fontSize: 14)),
                        Text(
                          '${_cartService.subtotal.toStringAsFixed(0)}đ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Phí giao hàng:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const Text(
                          'Miễn phí',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tổng cộng:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${_cartService.total.toStringAsFixed(0)}đ',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BookingScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text(
                        'Tiếp tục',
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
            ],
          );
        },
      ),
    );
  }
}
