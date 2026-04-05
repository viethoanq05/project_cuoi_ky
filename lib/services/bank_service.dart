import 'dart:convert';
import 'package:http/http.dart' as http;

class BankService {
  // Cập nhật URL API thực tế của bạn
  static const baseUrl = 'http://localhost/Bank/public/api';
  static const String _loginUrl = 'http://localhost/Bank/public/api/login.php';
  static const String _withdrawUrl = 'http://localhost/Bank/public/api/deposit.php';
  static const String _depositUrl = 'http://localhost/Bank/public/api/external_deposit.php';

  static Future<Map<String, dynamic>> loginBank({
    required String name,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'name': data['name'],
          'amount': data['amount'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Lỗi đăng nhập: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Lỗi kết nối ngân hàng: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> withdrawMoney({
    required String account,
    required double amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_withdrawUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'account': account,
          'amount': amount,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Rút tiền thành công',
          'new_balance': data['amount'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Lỗi từ hệ thống ngân hàng: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Lỗi kết nối khi rút tiền: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> depositMoney({
    required String username,
    required double amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_depositUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'amount': amount,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      // Phù hợp với response: status => ok, user => [amount, name, ...]
      if (response.statusCode == 200 && data['status'] == 'ok') {
        final userData = data['user'] ?? {};
        return {
          'success': true,
          'message': 'Nạp tiền thành công',
          'name': userData['name'],
          'new_balance': userData['amount'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Lỗi từ hệ thống nạp tiền: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Lỗi kết nối API nạp tiền: $e',
      };
    }
  }
}
