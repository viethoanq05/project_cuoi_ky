import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/entities/order_entity.dart';
import '../providers/cart_provider.dart';
import '../providers/checkout_provider.dart';
import '../providers/user_profile_provider.dart';
import 'order_tracking_screen.dart';
import 'payment_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final String userId;

  const CheckoutScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late TextEditingController _deliveryAddressController;
  String _selectedPaymentMethod = 'cod';
  double _deliveryFee = 15000;

  @override
  void initState() {
    super.initState();
    _deliveryAddressController = TextEditingController();
    Future.microtask(() {
      final userProvider = context.read<UserProfileProvider>();
      if (userProvider.userProfile == null) {
        userProvider.loadUserProfile(widget.userId);
      } else {
        _deliveryAddressController.text = userProvider.userProfile!.address;
      }

      final checkoutProvider = context.read<CheckoutProvider>();
      checkoutProvider.fetchWalletBalance(widget.userId);
    });
  }

  @override
  void dispose() {
    _deliveryAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        elevation: 0,
      ),
      body: Consumer2<CartProvider, CheckoutProvider>(
        builder: (context, cartProvider, checkoutProvider, _) {
          if (cartProvider.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cart is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final totalPrice = cartProvider.totalPrice + _deliveryFee;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Items
                const Text(
                  'Order Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildOrderItemsList(cartProvider),
                const SizedBox(height: 24),

                // Delivery Address
                const Text(
                  'Delivery Address',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deliveryAddressController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter delivery address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Payment Method
                const Text(
                  'Payment Method',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildPaymentMethodSelector(),
                const SizedBox(height: 24),

                // Price Summary
                _buildPriceSummary(cartProvider, totalPrice),
                const SizedBox(height: 24),

                // Error Message
                if (checkoutProvider.isError)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Lỗi: ${checkoutProvider.errorMessage}',
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                const SizedBox(height: 16),

                // Checkout Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: checkoutProvider.isProcessing
                        ? null
                        : () async {
                            await _processCheckout(
                              context,
                              cartProvider,
                              checkoutProvider,
                              totalPrice,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: checkoutProvider.isProcessing
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Đặt hàng'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderItemsList(CartProvider cartProvider) {
    return Column(
      children: cartProvider.items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.foodName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quantity: ${item.quantity}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Text(
                '${item.subtotal.toStringAsFixed(0)}đ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildPaymentOption(
            title: 'Thanh toán khi nhận hàng',
            subtitle: 'Trả tiền trực tiếp cho tài xế',
            value: 'cod',
          ),
          Divider(height: 0, color: Colors.grey.shade200),
          Consumer<CheckoutProvider>(
            builder: (context, checkoutProvider, _) {
              return _buildPaymentOption(
                title: 'Ví điện tử',
                subtitle:
                    'Số dư: ${checkoutProvider.walletBalance.toStringAsFixed(0)}đ',
                value: 'wallet',
              );
            },
          ),
          Divider(height: 0, color: Colors.grey.shade200),
          _buildPaymentOption(
            title: 'Thanh toán trực tuyến',
            subtitle: 'Thẻ tín dụng, chuyển khoản',
            value: 'online',
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required String value,
  }) {
    return RadioListTile<String>(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      groupValue: _selectedPaymentMethod,
      onChanged: (newValue) {
        setState(() {
          _selectedPaymentMethod = newValue ?? 'cod';
        });
      },
    );
  }

  Widget _buildPriceSummary(CartProvider cartProvider, double totalPrice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildPriceLine(
            label: 'Subtotal',
            price: cartProvider.totalPrice,
          ),
          const SizedBox(height: 8),
          _buildPriceLine(
            label: 'Delivery Fee',
            price: _deliveryFee,
          ),
          Divider(color: Colors.grey.shade300, height: 16),
          _buildPriceLine(
            label: 'Total',
            price: totalPrice,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceLine({
    required String label,
    required double price,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${price.toStringAsFixed(0)}đ',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Future<void> _processCheckout(
    BuildContext context,
    CartProvider cartProvider,
    CheckoutProvider checkoutProvider,
    double totalPrice,
  ) async {
    final deliveryAddress = _deliveryAddressController.text.trim();

    if (deliveryAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ giao hàng')),
      );
      return;
    }

    if (_selectedPaymentMethod == 'wallet') {
      final isValid = await checkoutProvider.validateWalletBalance(
        widget.userId,
        totalPrice,
      );

      if (!isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(checkoutProvider.errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Show payment processing dialog for online payment
    if (_selectedPaymentMethod == 'online' && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildPaymentProcessingDialog(checkoutProvider),
      );
    }

    await checkoutProvider.processCheckout(
      userId: widget.userId,
      storeId: cartProvider.storeId,
      items: cartProvider.items,
      totalPrice: totalPrice,
      paymentMethod: _selectedPaymentMethod,
      deliveryAddress: deliveryAddress,
    );

    if (mounted) {
      if (checkoutProvider.isSuccess && _selectedPaymentMethod == 'online') {
        Navigator.of(context).pop(); // Close processing dialog
      }

      if (checkoutProvider.isSuccess) {
        cartProvider.clearCart();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              orderId: checkoutProvider.createdOrder!.id,
              totalPrice: totalPrice,
              paymentMethod: _selectedPaymentMethod,
              userId: widget.userId,
            ),
          ),
        );
      } else if (checkoutProvider.isError) {
        if (_selectedPaymentMethod == 'online') {
          Navigator.of(context).pop(); // Close processing dialog
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(checkoutProvider.errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPaymentProcessingDialog(CheckoutProvider provider) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Đang xử lý giao dịch...',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: provider.processingProgress,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${(provider.processingProgress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
