import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';

class DeliveryConfirmationScreen extends StatefulWidget {
  const DeliveryConfirmationScreen({super.key, required this.order});

  final OrderData order;

  @override
  State<DeliveryConfirmationScreen> createState() => _DeliveryConfirmationScreenState();
}

class _DeliveryConfirmationScreenState extends State<DeliveryConfirmationScreen> {
  final OrderService _orderService = OrderService();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _isUploading = false;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn ảnh: $e')),
      );
    }
  }

  Future<void> _submitConfirmation() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng cung cấp ảnh minh chứng giao hàng thành công')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload ảnh lên Storage
      final imageUrl = await _orderService.uploadProofImage(widget.order.orderId, _imageBytes!);
      
      if (imageUrl == null) throw 'Không thể tải ảnh lên hệ thống';

      // 2. Cập nhật đơn hàng thành công
      await _orderService.updateOrderStatus(widget.order.orderId, 'delivered', proofImage: imageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đơn hàng đã được giao thành công!')),
        );
        Navigator.pop(context); // Quay lại danh sách đơn hàng
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận hoàn thành'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chi tiết đơn hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            _buildInfoBox(),
            const SizedBox(height: 24),
            const Text('Ảnh minh chứng giao hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildImagePicker(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton(
                onPressed: _isUploading ? null : _submitConfirmation,
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('HOÀN THÀNH GIAO HÀNG', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _infoRow('Cửa hàng', widget.order.storeName),
          _infoRow('Khách hàng', widget.order.customerId.substring(0, 8) + '...'),
          _infoRow('Địa chỉ', widget.order.deliveryAddress ?? 'Không rõ'),
          const Divider(),
          _infoRow('Tổng tiền', currencyFormat.format(widget.order.totalAmount), isBold: true),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: _imageBytes == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Chưa có ảnh chụp', style: TextStyle(color: Colors.grey)),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Chụp ảnh'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Chọn từ thư viện'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
