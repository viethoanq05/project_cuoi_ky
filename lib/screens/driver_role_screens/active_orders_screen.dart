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
      appBar: AppBar(
        title: const Text('Đơn hàng hiện tại'),
        centerTitle: true,
      ),
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
                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
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
              final canCancel = ['preparing', 'pending', 'searching', 'finding_driver'].contains(order.status.toLowerCase());
              
              return OrderCard(
                order: order,
                bottomAction: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusButton(context, order, orderService),
                    TextButton.icon(
                      onPressed: canCancel ? () => _confirmCancel(context, order, orderService) : null,
                      icon: Icon(Icons.cancel_outlined, color: canCancel ? Colors.red : Colors.grey),
                      label: Text('Hủy đơn', style: TextStyle(color: canCancel ? Colors.red : Colors.grey)),
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

  Widget _buildStatusButton(BuildContext context, OrderData order, OrderService service) {
    String currentStatus = order.status.toLowerCase();
    String nextStatus = '';
    String buttonText = '';
    Color buttonColor = Colors.blue;

    if (currentStatus == 'preparing') {
      nextStatus = 'ready';
      buttonText = 'Xác nhận lấy hàng';
      buttonColor = Colors.orange;
    } else if (currentStatus == 'ready') {
      nextStatus = 'on_the_way';
      buttonText = 'Bắt đầu giao';
      buttonColor = Colors.blueAccent;
    } else if (currentStatus == 'on_the_way') {
      nextStatus = 'delivered';
      buttonText = 'Hoàn thành';
      buttonColor = Colors.green;
    } else {
      return const SizedBox.shrink();
    }

    return FilledButton(
      onPressed: () => _confirmStatusChange(context, order, nextStatus, service),
      style: FilledButton.styleFrom(
        backgroundColor: buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  void _confirmStatusChange(BuildContext context, OrderData order, String newStatus, OrderService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chuyển trạng thái'),
        content: Text('Bạn muốn chuyển đơn hàng sang trạng thái ${_getStatusName(newStatus)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (newStatus == 'delivered') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DeliveryConfirmationScreen(order: order)),
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

  void _confirmCancel(BuildContext context, OrderData order, OrderService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy đơn hàng'),
        content: const Text('Bạn có chắc chắn muốn hủy nhận đơn hàng này? Đơn hàng sẽ được trả về danh sách chờ.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              service.driverCancelOrder(order.orderId);
            },
            child: const Text('Đồng ý hủy', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getStatusName(String status) {
    switch (status) {
      case 'preparing': return 'Đang chuẩn bị';
      case 'ready': return 'Đã lấy hàng';
      case 'on_the_way': return 'Đang giao hàng';
      case 'delivered': return 'Hoàn thành';
      default: return status;
    }
  }
}
