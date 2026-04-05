import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../services/user_service.dart';
import '../controller/driver_controller.dart';
import '../theme/app_colors.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Nhận đơn hàng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn có chắc chắn muốn nhận đơn hàng này?'),
            const SizedBox(height: 12),
            Text(
              'Cửa hàng: ${widget.order.storeName}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              'Tổng thu nhập: ${currencyFormat.format(widget.order.totalAmount + widget.order.deliveryFee)}',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Đóng dialog
              Navigator.pop(context); // Đóng bottom sheet
              final error = await controller.acceptOrder(widget.order.orderId);
              if (mounted) {
                if (error != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Lỗi: $error')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Nhận đơn thành công! Hãy vào tab Đơn hàng để thực hiện',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
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
    final itemNames = widget.order.items
        .map((item) => item['name'] ?? 'Sản phẩm')
        .join(', ');
    final isPending = [
      'pending',
      'searching',
      'dang_tim_xe',
    ].contains(widget.order.status.toLowerCase());

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Chi tiết đơn hàng',
                              style: theme.textTheme.titleLarge,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  widget.order.status,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getStatusText(widget.order.status),
                                style: TextStyle(
                                  color: _getStatusColor(widget.order.status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mã đơn: ${widget.order.orderId}',
                          style: theme.textTheme.labelMedium,
                        ),
                        const SizedBox(height: 24),

                        _buildInfoSection(
                          title: 'Thông tin cửa hàng',
                          icon: Icons.store_rounded,
                          children: [
                            _buildDetailRow(
                              'Tên cửa hàng',
                              _storeData?['fullName'] ?? widget.order.storeName,
                            ),
                            _buildDetailRow(
                              'Địa chỉ lấy hàng',
                              _storeData?['address'] ?? 'Đang cập nhật...',
                            ),
                          ],
                        ),

                        _buildInfoSection(
                          title: 'Thông tin khách hàng',
                          icon: Icons.person_rounded,
                          children: [
                            _buildDetailRow(
                              'Người nhận',
                              _customerData?['fullName'] ??
                                  _customerData?['userName'] ??
                                  'Khách hàng',
                            ),
                            _buildDetailRow(
                              'Số điện thoại',
                              _customerData?['phone'] ?? 'Chưa cập nhật',
                            ),
                            _buildDetailRow(
                              'Địa chỉ giao',
                              widget.order.deliveryAddress ?? 'Không rõ',
                            ),
                          ],
                        ),

                        _buildInfoSection(
                          title: 'Chi tiết mặt hàng',
                          icon: Icons.inventory_2_rounded,
                          children: [
                            Text(
                              itemNames.isEmpty
                                  ? 'Không có dữ liệu'
                                  : itemNames,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),

                        _buildInfoSection(
                          title: 'Thanh toán',
                          icon: Icons.payments_rounded,
                          isLast: true,
                          children: [
                            _buildMoneyRow(
                              'Tiền đơn hàng',
                              widget.order.totalAmount,
                            ),
                            _buildMoneyRow(
                              'Phí giao hàng',
                              widget.order.deliveryFee,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                height: 1,
                                color: AppColors.divider,
                              ),
                            ),
                            _buildMoneyRow(
                              'Tổng cộng thu nhập',
                              widget.order.totalAmount +
                                  widget.order.deliveryFee,
                              isTotal: true,
                            ),
                          ],
                        ),

                        if (widget.order.proofImage != null &&
                            widget.order.proofImage!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Ảnh minh chứng giao hàng',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              widget.order.proofImage!,
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Nút hành động chính
                        if (isPending &&
                            (widget.order.driverId == null ||
                                widget.order.driverId!.isEmpty))
                          Consumer<DriverController>(
                            builder: (context, controller, _) => SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton(
                                onPressed: () =>
                                    _confirmAcceptOrder(context, controller),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('NHẬN ĐƠN HÀNG NÀY'),
                              ),
                            ),
                          ),

                        if (widget.actionButton != null) widget.actionButton!,
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyRow(String label, double amount, {bool isTotal = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : theme.textTheme.bodyMedium,
          ),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Chờ nhận';
      case 'finding_driver':
      case 'searching':
        return 'Đang tìm xe';
      case 'dang_tim_xe':
        return 'Đang tìm xe';
      case 'preparing':
        return 'Đang chuẩn bị';
      case 'ready':
        return 'Đã lấy hàng';
      case 'delivering':
        return 'Đang giao';
      case 'on_the_way':
        return 'Đang giao';
      case 'delivered':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      case 'preparing':
      case 'delivering':
      case 'on_the_way':
        return AppColors.accent;
      default:
        return AppColors.info;
    }
  }
}
