import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

class DriverWalletScreen extends StatelessWidget {
  const DriverWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final String driverId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.currentUser;
        if (user == null) return const Scaffold(body: Center(child: Text('Lỗi tải dữ liệu')));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ví của tôi'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Thẻ số dư
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blueAccent, Colors.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 16),
                      const Text('Số dư hiện tại', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(user.walletBalance),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // Tiêu đề Lịch sử giao dịch
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Lịch sử giao dịch',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Danh sách giao dịch
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // BỎ .orderBy() ở đây để không bị lỗi Index
                  stream: FirebaseFirestore.instance
                      .collection('WalletTransactions')
                      .where('driverId', isEqualTo: driverId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Lỗi: ${snapshot.error}'));
                    }

                    // Chuyển dữ liệu sang List và sắp xếp tại Client
                    final docs = snapshot.data?.docs ?? [];
                    final sortedDocs = docs.toList()
                      ..sort((a, b) {
                        final t1 = (a.data() as Map)['timestamp'] as Timestamp?;
                        final t2 = (b.data() as Map)['timestamp'] as Timestamp?;
                        if (t1 == null) return 1;
                        if (t2 == null) return -1;
                        return t2.compareTo(t1); // Giảm dần (mới nhất lên đầu)
                      });

                    if (sortedDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text('Chưa có giao dịch nào', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: sortedDocs.length,
                      separatorBuilder: (_, __) => const Divider(height: 24, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final data = sortedDocs[index].data() as Map<String, dynamic>;
                        final double amount = (data['amount'] ?? 0).toDouble();
                        final timestamp = data['timestamp'] as Timestamp?;
                        final String orderId = data['orderId'] ?? 'N/A';
                        final String type = data['type'] ?? 'unknown';

                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_circle_outline_rounded, color: AppColors.success, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    type == 'receive_order_payment' ? 'Thu nhập đơn hàng' : 'Cộng tiền vào ví',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    'Mã đơn: #$orderId',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                  if (timestamp != null)
                                    Text(
                                      dateFormat.format(timestamp.toDate()),
                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '+${currencyFormat.format(amount)}',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
