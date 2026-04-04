import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../services/user_service.dart';
import '../controller/driver_controller.dart';
import 'package:provider/provider.dart';

class OrderDetailSheet extends StatefulWidget {
  final OrderData order;
  final Widget? actionButton;

  const OrderDetailSheet({super.key, required this.order, this.actionButton});

  @override
  State<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<OrderDetailSheet> {
  final UserService _userService = UserService();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  
  Map<String, dynamic>? _storeData;
  Map<String, dynamic>? _customerData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final store = await _userService.getUserById(widget.order.storeId);
    final customer = await _userService.getUserById(widget.order.customerId);
    
    if (mounted) {
      setState(() {
        _storeData = store;
        _customerData = customer;
        _isLoading = false;
      });
    }
  }

  void _confirmAcceptOrder(BuildContext context, DriverController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhận đơn hàng'),
        content: Text('Bạn có chắc chắn muốn nhận đơn hàng từ ${widget.order.storeName}?\nTổng tiền: ${currencyFormat.format(widget.order.totalAmount)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Đóng dialog
              Navigator.pop(context); // Đóng bottom sheet
              final error = await controller.acceptOrder(widget.order.orderId);
              if (mounted) {
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $error')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhận đơn thành công!')));
                }
              }
            },
            child: const Text('Xác nhận nhận đơn'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemNames = widget.order.items.map((item) => item['name'] ?? 'Sản phẩm').join(', ');
    final isPending = ['pending', 'searching', 'dang_tim_xe'].contains(widget.order.status.toLowerCase());

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: _isLoading 
        ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chi tiết đơn hàng', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Mã đơn: ${widget.order.orderId}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      const Divider(height: 32),

                      _buildSection('Thông tin cửa hàng', [
                        _infoItem(Icons.storefront, 'Tên cửa hàng', _storeData?['fullName'] ?? widget.order.storeName),
                        _infoItem(Icons.location_on_outlined, 'Địa chỉ cửa hàng', _storeData?['address'] ?? 'Đang cập nhật...'),
                      ]),

                      const SizedBox(height: 20),
                      _buildSection('Thông tin người nhận', [
                        _infoItem(Icons.person_outline, 'Họ và tên', _customerData?['fullName'] ?? _customerData?['userName'] ?? 'Khách hàng'),
                        _infoItem(Icons.phone_outlined, 'Số điện thoại', _customerData?['phone'] ?? 'Chưa cập nhật'),
                        _infoItem(Icons.local_shipping_outlined, 'Địa chỉ giao hàng', widget.order.deliveryAddress ?? 'Không rõ'),
                      ]),

                      const SizedBox(height: 20),
                      _buildSection('Mặt hàng', [
                        _infoItem(Icons.fastfood_outlined, 'Danh sách món', itemNames.isEmpty ? 'Không có dữ liệu' : itemNames),
                      ]),

                      const SizedBox(height: 20),
                      _buildSection('Thanh toán', [
                        _moneyItem('Tiền đơn hàng', widget.order.totalAmount),
                        _moneyItem('Phí giao hàng', widget.order.deliveryFee),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(),
                        ),
                        _moneyItem('Tổng cộng', widget.order.totalAmount + widget.order.deliveryFee, isBold: true),
                      ]),

                      const SizedBox(height: 20),
                      _buildSection('Trạng thái hiện tại', [
                        _infoItem(Icons.info_outline, 'Trạng thái', _getStatusText(widget.order.status), color: _getStatusColor(widget.order.status)),
                      ]),

                      if (widget.order.proofImage != null && widget.order.proofImage!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text('Ảnh minh chứng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent)),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.order.proofImage!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      
                      // Nút nhận đơn hàng (Chỉ hiện ở Dashboard/Trang chủ cho các đơn trống)
                      if (isPending && (widget.order.driverId == null || widget.order.driverId!.isEmpty))
                        Consumer<DriverController>(
                          builder: (context, controller, _) => SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: () => _confirmAcceptOrder(context, controller),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('NHẬN ĐƠN HÀNG NÀY', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
                            ),
                          ),
                        ),

                      if (widget.actionButton != null) widget.actionButton!,
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent)),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _infoItem(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyItem(String label, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isBold ? Colors.black : Colors.grey[600], fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(currencyFormat.format(amount), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: isBold ? Colors.green : Colors.black)),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'Chờ xác nhận';
      case 'searching': return 'Đang tìm tài xế';
      case 'preparing': return 'Đang chuẩn bị';
      case 'ready': return 'Chờ lấy hàng';
      case 'on_the_way': return 'Đang giao hàng';
      case 'delivered': return 'Đã hoàn thành';
      case 'cancelled': return 'Đã hủy';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'preparing':
      case 'on_the_way': return Colors.orange;
      default: return Colors.blue;
    }
  }
}
