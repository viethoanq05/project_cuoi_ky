import 'package:flutter/material.dart';

import '../../models/store_management_models.dart';

class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.review,
    required this.replyController,
    required this.saving,
    required this.onSubmitReply,
  });

  final StoreReview review;
  final TextEditingController replyController;
  final bool saving;
  final Future<void> Function() onSubmitReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.customerName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Row(
                  children: List<Widget>.generate(5, (index) {
                    final filled = index < review.rating;
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18,
                      color: filled
                          ? const Color(0xFFE0A100)
                          : theme.colorScheme.outline,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(review.content, style: theme.textTheme.bodyMedium),
            if (review.hasReply) ...[
              const SizedBox(height: 8),
              Text(
                'Phản hồi hiện tại: ${review.ownerReply}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: replyController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Trả lời đánh giá',
                hintText: 'Nhập phản hồi của cửa hàng',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: saving ? null : onSubmitReply,
                child: Text(saving ? 'Đang lưu...' : 'Gửi phản hồi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
