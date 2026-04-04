import 'package:flutter/material.dart';

class StoreProfileForm extends StatelessWidget {
  const StoreProfileForm({
    super.key,
    required this.storeNameController,
    required this.phoneController,
    required this.addressController,
    required this.openingHoursController,
    this.header,
    this.onSave,
    this.isSaving = false,
    this.isEditable = true,
    this.locationPicker,
  });

  final TextEditingController storeNameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController openingHoursController;
  final Widget? header;
  final Future<void> Function()? onSave;
  final bool isSaving;
  final bool isEditable;
  final Widget? locationPicker;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (header != null) ...[header!, const SizedBox(height: 12)],
        TextField(
          controller: storeNameController,
          readOnly: !isEditable,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Tên cửa hàng',
            prefixIcon: Icon(Icons.storefront_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phoneController,
          readOnly: !isEditable,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        if (locationPicker != null) ...[
          const SizedBox(height: 12),
          locationPicker!,
        ],
        const SizedBox(height: 12),
        TextField(
          controller: addressController,
          readOnly: !isEditable,
          minLines: 2,
          maxLines: 3,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Địa chỉ',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: openingHoursController,
          readOnly: !isEditable,
          decoration: const InputDecoration(
            labelText: 'Giờ mở cửa',
            hintText: 'VD: 08:00 - 22:00',
            prefixIcon: Icon(Icons.access_time_outlined),
          ),
        ),
        if (isEditable) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: isSaving ? null : () => onSave?.call(),
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(isSaving ? 'Đang cập nhật...' : 'Cập nhật hồ sơ'),
          ),
        ],
      ],
    );
  }
}
