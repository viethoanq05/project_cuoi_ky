import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StoreStatusCard extends StatelessWidget {
  const StoreStatusCard({
    super.key,
    required this.isOpen,
    required this.loading,
    required this.onChanged,
  });

  final bool isOpen;
  final bool loading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final statusText = isOpen ? 'Đang mở cửa' : 'Đang đóng cửa';
    final statusColor = isOpen ? AppColors.success : AppColors.danger;
    final statusIcon = isOpen
        ? Icons.storefront_rounded
        : Icons.store_mall_directory_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trạng thái cửa hàng',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: statusColor,
                ),
              )
            else
              Switch(value: isOpen, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
