import 'package:add_2_calendar/add_2_calendar.dart';
import '../models/order.dart';

class CalendarService {
  static Future<bool> addOrderToCalendar(OrderData order) async {
    if (order.scheduledTime == null) return false;

    // Build event description
    final itemsList = order.items.map((item) {
      final name = item['foodName'] ?? 'Món ăn';
      final qty = item['quantity'] ?? 1;
      return '- $name x$qty';
    }).join('\n');

    final description = 'Đơn hàng từ: ${order.storeName}\n\n'
        'Chi tiết món ăn:\n$itemsList\n\n'
        'Tổng tiền: ${order.totalAmount.toStringAsFixed(0)}đ\n'
        'Ghi chú: ${order.notes ?? "Không có"}';

    final event = Event(
      title: 'Đơn hàng ${order.storeName} - ${order.orderId.substring(0, 5)}',
      description: description,
      location: order.deliveryAddress ?? 'Địa chỉ của bạn',
      startDate: order.scheduledTime!,
      endDate: order.scheduledTime!.add(const Duration(minutes: 30)),
      allDay: false,
    );

    try {
      return await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      print('Error adding to calendar: $e');
      return false;
    }
  }
}
