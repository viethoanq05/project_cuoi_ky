import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import '../services/calendar_service.dart';
import '../theme/app_colors.dart';
import '../models/order.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late CartService _cartService;
  late OrderService _orderService;
  late AuthService _authService;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _deliveryOption = 'now'; // 'now' hoặc 'scheduled'
  final _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _cartService = CartService();
    _orderService = OrderService();
    _authService = AuthService.instance;
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _selectedTime = const TimeOfDay(hour: 12, minute: 0);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đặt đơn hàng')),
        body: const Center(child: Text('Vui lòng đăng nhập để tiếp tục')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt đơn hàng'), elevation: 0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin giao hàng
              _buildSectionTitle('Địa chỉ giao hàng'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.fullName.trim().isNotEmpty
                          ? currentUser.fullName
                          : 'Không có tên',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(currentUser.phone.trim()),
                    const SizedBox(height: 8),
                    Text(
                      currentUser.address.trim().isNotEmpty
                          ? currentUser.address
                          : 'Chưa cập nhật',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tùy chọn giao hàng
              _buildSectionTitle('Thời gian giao hàng'),
              const SizedBox(height: 12),
              _buildDeliveryOptions(),
              const SizedBox(height: 24),

              // Calendar & Time (nếu chọn scheduled)
              if (_deliveryOption == 'scheduled') ...[
                _buildSectionTitle('Chọn ngày & giờ'),
                const SizedBox(height: 12),
                _buildDateTimePicker(),
                const SizedBox(height: 24),
              ],

              // Ghi chú
              _buildSectionTitle('Ghi chú thêm'),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Thêm ghi chú cho cửa hàng hoặc tài xế...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tóm tắt đơn hàng
              _buildSectionTitle('Tóm tắt'),
              const SizedBox(height: 12),
              _buildOrderSummary(),
              const SizedBox(height: 24),

              // Nút xác nhận
              ElevatedButton(
                onPressed: _isProcessing ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.grey[400],
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Xác nhận đơn hàng',
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
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDeliveryOptions() {
    return RadioGroup<String>(
      groupValue: _deliveryOption,
      onChanged: (value) {
        setState(() => _deliveryOption = value ?? 'now');
      },
      child: Column(
        children: const [
          RadioListTile<String>(
            title: Text('Giao hàng ngay'),
            subtitle: Text('Trong 30-45 phút'),
            activeColor: AppColors.primary,
            value: 'now',
          ),
          RadioListTile<String>(
            title: Text('Đặt hàng trước (Pre-order)'),
            subtitle: Text('Chọn thời gian nhận hàng phù hợp'),
            activeColor: AppColors.primary,
            value: 'scheduled',
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      children: [
        // Date picker
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? DateFormat(
                          'EEEE, dd/MM/yyyy',
                          'vi_VN',
                        ).format(_selectedDate!)
                      : 'Chọn ngày',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Time picker
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime:
                  _selectedTime ?? const TimeOfDay(hour: 12, minute: 0),
            );
            if (picked != null) {
              setState(() => _selectedTime = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  _selectedTime != null
                      ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                      : 'Chọn giờ',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tạm tính:'),
              Text('${_cartService.subtotal.toStringAsFixed(0)}đ'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text('Phí giao hàng:'), const Text('Miễn phí')],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng cộng:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '${_cartService.total.toStringAsFixed(0)}đ',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (_deliveryOption == 'scheduled' &&
        (_selectedDate == null || _selectedTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày và giờ giao hàng')),
      );
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    setState(() => _isProcessing = true);

    try {
      DateTime? scheduledTime;
      if (_deliveryOption == 'scheduled' &&
          _selectedDate != null &&
          _selectedTime != null) {
        scheduledTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      }

      final orderData = _cartService.toOrderMap();
      final String storeName = _cartService.items.isNotEmpty
          ? (_cartService.items.first.storeName ?? 'Cửa hàng')
          : 'Cửa hàng';

      final OrderData order = await _orderService.createOrder(
        customerId: currentUser.email,
        storeId: orderData['storeId'],
        storeName: storeName,
        items: orderData['items'],
        totalAmount: orderData['totalAmount'],
        deliveryFee: 0,
        scheduledTime: scheduledTime,
        deliveryAddress: currentUser.address,
        deliveryLat: currentUser.position?['latitude'],
        deliveryLng: currentUser.position?['longitude'],
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      _cartService.clear();

      if (!context.mounted) return;

      if (scheduledTime != null) {
        _showCalendarPrompt(order);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đơn hàng đã được tạo thành công'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showCalendarPrompt(OrderData order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Đặt hàng thành công!'),
        content: const Text(
          'Bạn có muốn thêm lịch nhắc hẹn vào Google Calendar để không bỏ lỡ đơn hàng này không?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Bỏ qua'),
          ),
          ElevatedButton(
            onPressed: () async {
              await CalendarService.addOrderToCalendar(order);
              if (mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Thêm vào lịch',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
