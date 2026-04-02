import 'package:flutter/material.dart';

import '../../services/store_management_service.dart';
import 'store_dashboard_tab.dart';
import 'store_profile_tab.dart';
import 'store_reviews_tab.dart';
import 'store_tickets_tab.dart';

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  late final StoreManagementService _service;

  @override
  void initState() {
    super.initState();
    _service = StoreManagementService();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý cửa hàng'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Thống kê'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Đơn hàng'),
              Tab(icon: Icon(Icons.reviews_outlined), text: 'Đánh giá'),
              Tab(icon: Icon(Icons.store_outlined), text: 'Hồ sơ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StoreDashboardTab(service: _service),
            StoreTicketsTab(service: _service),
            StoreReviewsTab(service: _service),
            StoreProfileTab(service: _service),
          ],
        ),
      ),
    );
  }
}
