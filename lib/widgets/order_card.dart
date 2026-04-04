import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../services/user_service.dart';
import '../controller/driver_controller.dart';
import 'order_detail_sheet.dart';

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
    final itemNames = widget.order.items.map((item) => item['name'] ?? 'Sản phẩm').join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: widget.onTap ?? () {
          // Lấy controller hiện tại từ context
          final driverController = Provider.of<DriverController>(context, listen: false);
          
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ChangeNotifierProvider.value(
              value: driverController,
              child: OrderDetailSheet(order: widget.order),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.blueAccent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    currencyFormat.format(widget.order.totalAmount),
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildIconRow(Icons.storefront, 'Từ: $_storeAddress', Colors.orange),
              const SizedBox(height: 6),
              _buildIconRow(Icons.location_on_outlined, 'Giao đến: ${widget.order.deliveryAddress}', Colors.redAccent),
              const SizedBox(height: 6),
              _buildIconRow(Icons.fastfood_outlined, 'Món: ${itemNames.isEmpty ? "Đang cập nhật" : itemNames}', Colors.grey[600]!),
              
              if (widget.bottomAction != null) ...[
                const Divider(height: 32),
                widget.bottomAction!,
              ] else ...[
                const Divider(height: 32),
                const Center(
                  child: Text(
                    'Xem chi tiết', 
                    style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w500)
                  )
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconRow(IconData icon, String text, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
