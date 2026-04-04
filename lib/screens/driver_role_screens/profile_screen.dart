import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import 'wallet_screen.dart';
import 'edit_profile_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key, required this.user, required this.authService});

  final AppUser user;
  final AuthService authService;

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.authService.logout();
    }
  }

  /* 
  // Tạm thời vô hiệu hóa chức năng liên kết ngân hàng
  void _showLinkBankDialog(BuildContext context) {
    // ... code cũ ...
  }
  */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ tài khoản'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.person, size: 60, color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.fullName.isNotEmpty ? user.fullName : user.userName,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(user.email, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            
            _buildProfileItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Ví của tôi',
              subtitle: currencyFormat.format(user.walletBalance),
              textColor: Colors.blue[700],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriverWalletScreen(),
                  ),
                );
              },
            ),
            
            /* 
            // Tạm thời ẩn nút liên kết ngân hàng
            _buildProfileItem(
              icon: Icons.account_balance_outlined,
              title: 'Tài khoản ngân hàng',
              subtitle: user.bankAccount.isNotEmpty 
                ? 'Đã liên kết: ${user.bankAccount}' 
                : 'Chưa liên kết',
              onTap: () => _showLinkBankDialog(context),
            ),
            */

            _buildProfileItem(
              icon: Icons.phone_outlined,
              title: 'Số điện thoại',
              subtitle: user.phone.isNotEmpty ? user.phone : 'Chưa cập nhật',
            ),
            _buildProfileItem(
              icon: Icons.location_on_outlined,
              title: 'Địa chỉ',
              subtitle: user.address.isNotEmpty ? user.address : 'Chưa cập nhật',
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
              child: Divider(),
            ),
            
            _buildProfileItem(
              icon: Icons.settings_outlined,
              title: 'Cài đặt tài khoản',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(
                      user: user,
                      authService: widget.authService,
                    ),
                  ),
                );
              },
            ),
            _buildProfileItem(
              icon: Icons.logout,
              title: 'Đăng xuất',
              textColor: Colors.red,
              onTap: () => _confirmLogout(context),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}
