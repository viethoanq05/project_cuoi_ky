import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/bank_service.dart';
import '../../services/wallet_service.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final TextEditingController _withdrawController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  bool _isProcessing = false;
  bool _isWithdrawMode = true;

  void _onAmountSelected(int amount) {
    if (_isWithdrawMode) {
      _withdrawController.text = amount.toString();
    } else {
      _depositController.text = amount.toString();
    }
  }

  Future<void> _handleWithdraw(AppUser user, AuthService authService) async {
    final amountText = _withdrawController.text.replaceAll('.', '');
    final amount = double.tryParse(amountText) ?? 0;

    final error = WalletService.validateWithdrawal(user.walletBalance, amount);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    if (user.bankAccount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng liên kết ngân hàng trước')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận rút tiền'),
        content: Text(
          'Bạn muốn rút ${currencyFormat.format(amount)} về tài khoản ${user.bankAccount}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    
    final result = await BankService.withdrawMoney(
      account: user.bankAccount,
      amount: amount,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final newBalance = WalletService.calculateNewBalance(user.walletBalance, amount, false);
      final updateError = await authService.updateWalletBalance(newBalance);
      
      if (mounted) {
        setState(() => _isProcessing = false);
        if (updateError == null) {
          _withdrawController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Rút tiền thành công!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi cập nhật số dư: $updateError')),
          );
        }
      }
    } else {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Giao dịch thất bại')),
      );
    }
  }

  Future<void> _handleDeposit(AppUser user, AuthService authService) async {
    final amountText = _depositController.text.replaceAll('.', '');
    final amount = double.tryParse(amountText) ?? 0;

    final error = WalletService.validateDeposit(amount);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    if (user.bankAccount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng liên kết ngân hàng trước')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận nạp tiền'),
        content: Text(
          'Bạn muốn nạp ${currencyFormat.format(amount)} vào ví?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    
    // Gọi API nạp tiền thực tế
    final result = await BankService.depositMoney(
      username: user.bankAccount,
      amount: amount,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final newBalance = WalletService.calculateNewBalance(user.walletBalance, amount, true);
      final updateError = await authService.updateWalletBalance(newBalance);

      if (mounted) {
        setState(() => _isProcessing = false);
        if (updateError == null) {
          _depositController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Nạp tiền thành công!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi cập nhật số dư: $updateError')),
          );
        }
      }
    } else {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Nạp tiền thất bại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final authService = AuthService.instance;
        final user = authService.currentUser;
        if (user == null) return const Scaffold(body: Center(child: Text('Lỗi tải dữ liệu')));

        return Scaffold(
          appBar: AppBar(title: const Text('Ví của tôi'), centerTitle: true),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildWalletCard(user),
                const SizedBox(height: 30),
                _buildTabOptions(),
                const SizedBox(height: 30),
                _isWithdrawMode 
                  ? _buildTransactionForm(
                      title: 'Nhập số tiền muốn rút',
                      controller: _withdrawController,
                      buttonLabel: 'RÚT TIỀN VỀ NGÂN HÀNG',
                      infoText: 'Tối thiểu 10.000đ • Miễn phí giao dịch',
                      onAction: () => _handleWithdraw(user, authService),
                      buttonColor: Colors.green,
                    )
                  : _buildTransactionForm(
                      title: 'Nhập số tiền muốn nạp',
                      controller: _depositController,
                      buttonLabel: 'NẠP TIỀN VÀO VÍ',
                      infoText: 'Tối thiểu 10.000đ • Xử lý tức thì',
                      onAction: () => _handleDeposit(user, authService),
                      buttonColor: Colors.blue,
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWalletCard(AppUser user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blueAccent, Colors.blue]
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white, size: 35),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.userName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('Tài xế đối tác', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text('Số dư hiện tại', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 5),
          Text(
            currencyFormat.format(user.walletBalance),
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTabOptions() {
    return Row(
      children: [
        _buildOptionBtn(
          icon: Icons.add_card_rounded,
          label: 'Nạp tiền',
          color: Colors.blue,
          onTap: () => setState(() => _isWithdrawMode = false),
          isSelected: !_isWithdrawMode,
        ),
        const SizedBox(width: 15),
        _buildOptionBtn(
          icon: Icons.account_balance_rounded,
          label: 'Rút tiền',
          color: Colors.green,
          onTap: () => setState(() => _isWithdrawMode = true),
          isSelected: _isWithdrawMode,
        ),
      ],
    );
  }

  Widget _buildTransactionForm({
    required String title,
    required TextEditingController controller,
    required String buttonLabel,
    required String infoText,
    required VoidCallback onAction,
    required Color buttonColor,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '0',
                suffixText: 'đ',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(infoText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [50000, 100000, 200000, 500000].map((amount) {
                return ActionChip(
                  label: Text(currencyFormat.format(amount)),
                  onPressed: () => _onAmountSelected(amount),
                );
              }).toList(),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isProcessing ? null : onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? color : Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(
                      color: isSelected ? color : Colors.black87, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
