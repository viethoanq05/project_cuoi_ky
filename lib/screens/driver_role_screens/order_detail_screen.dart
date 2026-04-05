import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../models/order.dart';
import '../../services/user_service.dart';
import '../../controller/driver_controller.dart';
import '../../theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'order_map_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderData order;
  final Widget? actionButton;

  const OrderDetailScreen({super.key, required this.order, this.actionButton});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final UserService _userService = UserService();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  
  Map<String, dynamic>? _storeData;
  Map<String, dynamic>? _customerData;
  String _parsedStoreAddress = "Đang tải...";
  String _parsedDeliveryAddress = "Đang tải...";
  bool _isLoading = true;
  final Map<String, String?> _foodImages = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final store = await _userService.getUserById(widget.order.storeId);
    final customer = await _userService.getUserById(widget.order.customerId);
    
    // Parse delivery address if it's coordinates
    String deliveryAddr = widget.order.deliveryAddress ?? "Không rõ";
    if (widget.order.deliveryLat != null && widget.order.deliveryLng != null) {
      deliveryAddr = await _userService.getAddressFromCoords(widget.order.deliveryLat, widget.order.deliveryLng);
    }

    // Fetch food images
    for (var item in widget.order.items) {
      final foodId = item['foodId'] ?? item['food_id'];
      if (foodId != null && !_foodImages.containsKey(foodId)) {
        final foodDoc = await FirebaseFirestore.instance.collection('Foods').doc(foodId).get();
        if (foodDoc.exists) {
          _foodImages[foodId] = foodDoc.data()?['image'];
        } else {
          _foodImages[foodId] = null;
        }
      }
    }

    if (mounted) {
      setState(() {
        _storeData = store;
        _customerData = customer;
        _parsedStoreAddress = store?['address'] ?? "Chưa có địa chỉ";
        _parsedDeliveryAddress = deliveryAddr;
        _isLoading = false;
      });
    }
  }

  void _confirmAcceptOrder(BuildContext context, DriverController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Nhận đơn hàng', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn có chắc chắn muốn nhận đơn hàng này?'),
            const SizedBox(height: 12),
            Text('Cửa hàng: ${widget.order.storeName}', style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('Tổng thu nhập: ${currencyFormat.format(widget.order.totalAmount + widget.order.deliveryFee)}', 
              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Đóng dialog
              final error = await controller.acceptOrder(widget.order.orderId);
              if (mounted) {
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $error')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Nhận đơn thành công!'),
                    backgroundColor: AppColors.success,
                  ));
                  controller.setSelectedIndex(1); // Chuyển sang Tab Đơn hàng
                  Navigator.pop(context); // Quay lại dashboard
                }
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = ['pending', 'searching', 'dang_tim_xe', 'finding_driver', 'finding-driver']
        .contains(widget.order.status.toLowerCase());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              final driverController = context.read<DriverController>();
              final bool isHistory = ['delivered', 'cancelled'].contains(widget.order.status.toLowerCase());
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderMapScreen(
                    order: widget.order,
                    currentLocation: driverController.currentLocation,
                    isHistory: isHistory,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.map_rounded),
            tooltip: 'Xem bản đồ',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Thông tin vận chuyển', style: theme.textTheme.titleMedium),
                    _buildStatusBadge(widget.order.status),
                  ],
                ),
                const SizedBox(height: 24),
                
                _buildInfoSection(
                  title: 'Cửa hàng',
                  icon: Icons.store_rounded,
                  children: [
                    _buildDetailRow('Tên', _storeData?['fullName'] ?? widget.order.storeName),
                    _buildDetailRow('Địa chỉ', _parsedStoreAddress),
                  ],
                ),

                _buildInfoSection(
                  title: 'Khách hàng',
                  icon: Icons.person_rounded,
                  children: [
                    _buildDetailRow('Người nhận', _customerData?['fullName'] ?? "Khách hàng"),
                    _buildDetailRow('SĐT', _customerData?['phone'] ?? "Chưa cập nhật"),
                    _buildDetailRow('Giao đến', _parsedDeliveryAddress),
                  ],
                ),

                _buildInfoSection(
                  title: 'Mặt hàng',
                  icon: Icons.inventory_2_rounded,
                  children: widget.order.items.map((item) {
                    final foodId = item['foodId'] ?? item['food_id'];
                    final imageUrl = _foodImages[foodId];
                    final name = item['foodName'] ?? item['name'] ?? 'Sản phẩm';
                    final price = item['price'] ?? 0;
                    final qty = item['quantity'] ?? 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imageUrl != null
                                ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                                : Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.fastfood)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text("${currencyFormat.format(price)} x $qty", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              ],
                            ),
                          ),
                          Text(currencyFormat.format(price * qty), style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                _buildInfoSection(
                  title: 'Thanh toán',
                  icon: Icons.payments_rounded,
                  isLast: true,
                  children: [
                    _buildMoneyRow('Giá tiền món', widget.order.totalAmount),
                    _buildMoneyRow('Phí dịch vụ', widget.order.deliveryFee),
                    const Divider(height: 24),
                    _buildMoneyRow('TỔNG THU NHẬP', widget.order.totalAmount + widget.order.deliveryFee, isTotal: true),
                  ],
                ),

                if (widget.order.proofImage != null && widget.order.proofImage!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Minh chứng giao hàng', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(widget.order.proofImage!, width: double.infinity, height: 250, fit: BoxFit.cover),
                  ),
                ],

                const SizedBox(height: 40),
                
                if (isPending && (widget.order.driverId == null || widget.order.driverId!.isEmpty))
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () => _confirmAcceptOrder(context, context.read<DriverController>()),
                      child: const Text('NHẬN ĐƠN HÀNG NÀY'),
                    ),
                  ),
                
                if (widget.actionButton != null) widget.actionButton!,
              ],
            ),
          ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildInfoSection({required String title, required IconData icon, required List<Widget> children, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildMoneyRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        Text(currencyFormat.format(amount), style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isTotal ? 18 : 14,
          color: isTotal ? AppColors.success : Colors.black
        )),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'Chờ nhận';
      case 'searching': return 'Đang tìm xe';
      case 'preparing': return 'Đang chuẩn bị';
      case 'ready': return 'Đã lấy hàng';
      case 'on_the_way': return 'Đang giao';
      case 'delivered': return 'Hoàn thành';
      case 'cancelled': return 'Đã hủy';
      case 'finding_driver':
      case 'finding-driver': return 'Đang tìm tài xế';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered': return AppColors.success;
      case 'cancelled': return AppColors.danger;
      case 'preparing':
      case 'on_the_way': return AppColors.accent;
      default: return AppColors.info;
    }
  }
}
