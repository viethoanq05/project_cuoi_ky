import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../controller/driver_controller.dart';
import '../../widgets/order_card.dart';
import 'profile_screen.dart';
import 'activity_screen.dart';
import 'active_orders_screen.dart';
import 'order_detail_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key, required this.authService});

  final AuthService authService;

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  late final DriverController _driverController;

  @override
  void initState() {
    super.initState();
    _driverController = DriverController()..init();
  }

  @override
  void dispose() {
    _driverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _driverController,
      child: Consumer<DriverController>(
        builder: (context, controller, _) {
          final user = widget.authService.currentUser;
          if (user == null)
            return const Scaffold(body: Center(child: Text('Chưa đăng nhập')));

          return Scaffold(
            body: IndexedStack(
              index: (controller.selectedIndex ?? 0).clamp(0, 3),
              children: [
                _buildMainDashboard(user, controller),
                const DriverActiveOrdersScreen(),
                const DriverActivityScreen(),
                DriverProfileScreen(
                  user: user,
                  authService: widget.authService,
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: (controller.selectedIndex ?? 0).clamp(0, 3),
              onDestinationSelected: (index) => controller.setSelectedIndex(index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Trang chủ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  selectedIcon: Icon(Icons.shopping_bag),
                  label: 'Đơn hàng',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'Hoạt động',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Tài khoản',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainDashboard(AppUser user, DriverController controller) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18, color: Colors.black),
            children: [
              const TextSpan(text: 'Xin chào: '),
              TextSpan(
                text: user.fullName.isNotEmpty ? user.fullName : user.userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildStatusToggle(controller),
          Expanded(child: _buildOrderList(controller)),
        ],
      ),
    );
  }

  Widget _buildStatusToggle(DriverController controller) {
    final theme = Theme.of(context);
    return StreamBuilder<Map<String, dynamic>?>(
      stream: controller.watchDriverInfo(),
      builder: (context, snapshot) {
        final driverInfo = snapshot.data ?? {};
        final isOnline = driverInfo['is_online'] == true;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isOnline
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOnline
                        ? Colors.green.withValues(alpha: 0.5)
                        : Colors.grey.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnline
                          ? Icons.online_prediction_rounded
                          : Icons.offline_bolt_rounded,
                      color: isOnline ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOnline ? 'Đang nhận đơn' : 'Đang nghỉ ngơi',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isOnline ? Colors.green : Colors.grey[700],
                            ),
                          ),
                          Text(
                            isOnline
                                ? 'Hệ thống đang tìm đơn cho bạn'
                                : 'Bật để bắt đầu kiếm thu nhập',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    controller.updatingStatus
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch.adaptive(
                            value: isOnline,
                            activeColor: Colors.green,
                            onChanged: (val) =>
                                controller.toggleOnlineStatus(isOnline),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Hiển thị vị trí HIỆN TẠI từ controller thay vì từ user profile
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vị trí thực tế: ${controller.currentAddress}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blueGrey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderList(DriverController controller) {
    final theme = Theme.of(context);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: controller.watchDriverInfo(),
      builder: (context, snapshot) {
        final driverInfo = snapshot.data ?? {};
        final isOnline = driverInfo['is_online'] == true;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Danh sách đơn hàng',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: !isOnline
                    ? _buildEmptyState(
                        icon: Icons.notifications_off_outlined,
                        message:
                            'Hãy bật trạng thái nhận đơn để cập nhật đơn hàng',
                      )
                    : controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : controller.nearbyOrders.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.map_outlined,
                        message: 'Không có đơn hàng trong phạm vi hoạt động',
                      )
                    : ListView.builder(
                        itemCount: controller.nearbyOrders.length,
                        itemBuilder: (context, index) {
                          final order = controller.nearbyOrders[index];
                          return OrderCard(order: order);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
