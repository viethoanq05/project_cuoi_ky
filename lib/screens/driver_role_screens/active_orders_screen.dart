import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/order_card.dart';
import 'delivery_confirmation_screen.dart';

class DriverActiveOrdersScreen extends StatelessWidget {
  const DriverActiveOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driverId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final orderService = OrderService();

    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hàng hiện tại'), centerTitle: true),
      body: StreamBuilder<List<OrderData>>(
        stream: orderService.watchDriverActiveOrders(driverId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text('Bạn không có đơn hàng nào đang thực hiện'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return OrderCard(
                order: order,
                bottomAction: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusDropdown(context, order, orderService),
                    TextButton.icon(
                      onPressed: () =>
                          _confirmCancel(context, order, orderService),
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Hủy đơn',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusDropdown(
    BuildContext context,
    OrderData order,
    OrderService service,
  ) {
    final statuses = {
      'preparing': 'Đang chuẩn bị',
      'delivering': 'Đang giao',
      'ready': 'Đã lấy hàng',
      'on_the_way': 'Đang giao hàng',
      'delivered': 'Hoàn thành',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: statuses.containsKey(order.status)
              ? order.status
              : 'preparing',
          items: statuses.entries.map((e) {
            return DropdownMenuItem(value: e.key, child: Text(e.value));
          }).toList(),
          onChanged: (newStatus) {
            if (newStatus != null && newStatus != order.status) {
              _confirmStatusChange(context, order, newStatus, service);
            }
          },
        ),
      ),
    );
  }

  void _confirmStatusChange(
    BuildContext context,
    OrderData order,
    String newStatus,
    OrderService service,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chuyển trạng thái'),
        content: Text(
          'Bạn muốn chuyển đơn hàng sang trạng thái ${_getStatusName(newStatus)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (newStatus == 'delivered') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeliveryConfirmationScreen(order: order),
                  ),
                );
              } else {
                service.updateOrderStatus(order.orderId, newStatus);
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(
    BuildContext context,
    OrderData order,
    OrderService service,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đơn hàng'),
        content: const Text(
          'Bạn có chắc chắn muốn hủy nhận đơn hàng này? Đơn hàng sẽ được trả về danh sách chờ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              service.driverCancelOrder(order.orderId);
            },
            child: const Text(
              'Đồng ý hủy',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusName(String status) {
    switch (status) {
      case 'preparing':
        return 'Đang chuẩn bị';
      case 'delivering':
        return 'Đang giao';
      case 'ready':
        return 'Đã lấy hàng';
      case 'on_the_way':
        return 'Đang giao hàng';
      case 'delivered':
        return 'Hoàn thành';
      default:
        return status;
    }
  }
}
