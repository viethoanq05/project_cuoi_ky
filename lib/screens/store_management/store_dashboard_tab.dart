import 'package:flutter/material.dart';

import '../../models/store_management_models.dart';
import '../../services/store_management_service.dart';
import '../../widgets/store_management/stats_card.dart';
import 'store_management_formatters.dart';

class StoreDashboardTab extends StatelessWidget {
  const StoreDashboardTab({super.key, required this.service});

  final StoreManagementService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StoreStats>(
      stream: service.watchStats(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Không tải được thống kê: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data ?? StoreStats.empty;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StatsCard(
              title: 'Tổng doanh thu',
              value: formatStoreCurrency(stats.totalRevenue),
              icon: Icons.payments_outlined,
              color: const Color(0xFF0F766E),
            ),
            const SizedBox(height: 12),
            StatsCard(
              title: 'Tổng số đơn hàng',
              value: '${stats.totalTickets}',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF1D4ED8),
            ),
            const SizedBox(height: 12),
            StatsCard(
              title: 'Đơn hàng trong ngày',
              value: '${stats.todayTickets}',
              icon: Icons.today_outlined,
              color: const Color(0xFFB45309),
            ),
          ],
        );
      },
    );
  }
}
