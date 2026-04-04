import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../services/user_service.dart';
import '../controller/driver_controller.dart';
import '../theme/app_colors.dart';
import '../screens/driver_role_screens/order_detail_screen.dart';

class OrderCard extends StatefulWidget {
  final OrderData order;
  final VoidCallback? onTap;
  final Widget? bottomAction;

  const OrderCard({super.key, required this.order, this.onTap, this.bottomAction});

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  final UserService _userService = UserService();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  String _storeAddress = 'Đang tải địa chỉ...';
  String _displayStoreName = '';

  @override
  void initState() {
    super.initState();
    _displayStoreName = widget.order.storeName;
    _loadStoreInfo();
  }

  Future<void> _loadStoreInfo() async {
    final store = await _userService.getUserById(widget.order.storeId);
    if (mounted && store != null) {
      setState(() {
        _storeAddress = store['address'] ?? 'Không rõ địa chỉ';
        _displayStoreName = store['fullName'] ?? store['userName'] ?? widget.order.storeName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemNames = widget.order.items.map((item) => item['name'] ?? 'Sản phẩm').join(', ');
    final double totalEarnings = widget.order.totalAmount + widget.order.deliveryFee;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: widget.onTap ?? () {
            final driverController = Provider.of<DriverController>(context, listen: false);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChangeNotifierProvider.value(
                  value: driverController,
                  child: OrderDetailScreen(order: widget.order),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _displayStoreName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(totalEarnings),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                        if (widget.order.deliveryFee > 0)
                          Text(
                            '(Gồm ${currencyFormat.format(widget.order.deliveryFee)} ship)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildIconRow(Icons.store_rounded, 'Từ: $_storeAddress', AppColors.accent),
                const SizedBox(height: 8),
                _buildIconRow(Icons.location_on_rounded, 'Giao đến: ${widget.order.deliveryAddress}', AppColors.danger),
                const SizedBox(height: 8),
                _buildIconRow(Icons.inventory_2_rounded, 'Món: ${itemNames.isEmpty ? "Đang cập nhật" : itemNames}', AppColors.textSecondary),
                
                if (widget.bottomAction != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: AppColors.divider),
                  ),
                  widget.bottomAction!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconRow(IconData icon, String text, Color iconColor) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
